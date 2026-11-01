#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
配置同步工具 (Config Sync Tool) — PySide6 版
=============================================
用于在「目标文件夹」和「备份文件夹」之间同步指定的文件 / 文件夹。

功能:
  * 设置目标 / 备份文件夹（带路径自动补全）
  * 左右双栏可视化浏览两侧内容（懒加载树，可多选）
  * 添加、删除、查看跟踪项（文件或目录）
  * 检查一致性（大小 → mtime → 内容哈希；目录递归比较）
  * 双向同步（同步到备份 / 从备份恢复）
  * JSON 配置保存 / 加载
  * 菜单栏、工具栏、右键菜单、状态栏
  * QThread 后台执行，界面不冻结

用法:
  python3 config_sync_tool_qt.py [config.json]
"""

import os
import sys
import json
import shutil
import hashlib
import subprocess
from pathlib import Path
from datetime import datetime

from PySide6.QtCore import (
    Qt, QThread, Signal, QTimer, QStringListModel, QItemSelectionModel,
)
from PySide6.QtGui import (
    QAction, QKeySequence, QColor, QShortcut, QBrush,
)
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QGridLayout,
    QLabel, QLineEdit, QPushButton, QCompleter, QFileDialog, QMessageBox,
    QTableWidget, QTableWidgetItem, QHeaderView, QAbstractItemView,
    QProgressBar, QDialog, QDialogButtonBox, QMenu, QGroupBox, QFrame,
    QTreeWidget, QTreeWidgetItem, QSplitter, QStyle,
)


APP_TITLE = "配置同步工具"
CONFIG_EXT = ".jsync.json"
DEFAULT_CONFIG_NAME = "sync_config" + CONFIG_EXT

STATUS_COLORS = {
    # 跟踪列表状态
    "一致":     "#2e7d32",
    "不一致":   "#c62828",
    "仅目标有": "#ef6c00",
    "仅备份有": "#ef6c00",
    "缺失":     "#b71c1c",
    "未检查":   "#757575",
    "检查中":   "#1565c0",
    "同步中":   "#1565c0",
    "错误":     "#c62828",
    # 浏览器状态
    "目录":     "#555555",
    "仅此侧有": "#ef6c00",
    "大小不同": "#c62828",
    "时间不同": "#ef6c00",
    "类型不同": "#c62828",
    "—":        "#999999",
}


# =============================================================================
#  纯逻辑工具函数
# =============================================================================
def safe_join(base: Path, rel: str) -> Path:
    rel_p = Path(rel)
    if rel_p.is_absolute():
        raise ValueError(f"路径必须为相对路径: {rel}")
    if ".." in rel_p.parts:
        raise ValueError(f"路径不能包含 '..': {rel}")
    return base / rel_p


def fmt_size(size: int) -> str:
    if size < 1024:
        return f"{size} B"
    v = float(size)
    for unit in ("KB", "MB", "GB", "TB"):
        v /= 1024
        if v < 1024:
            return f"{v:.1f} {unit}"
    return f"{v:.1f} PB"


def file_hash(p: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for block in iter(lambda: f.read(chunk), b""):
            h.update(block)
    return h.hexdigest()


def same_content(a: Path, b: Path) -> bool:
    if a.stat().st_size != b.stat().st_size:
        return False
    return file_hash(a) == file_hash(b)


def describe(p: Path) -> str:
    if p.is_file():
        st = p.stat()
        ts = datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M")
        return f"文件，{fmt_size(st.st_size)}，修改于 {ts}"
    if p.is_dir():
        n = sum(1 for _ in p.rglob("*") if _.is_file())
        return f"目录，含 {n} 个文件"
    return "?"


def compare_files(a: Path, b: Path):
    sa, sb = a.stat(), b.stat()
    if sa.st_size != sb.st_size:
        return "不一致", f"大小不同: {fmt_size(sa.st_size)} ↔ {fmt_size(sb.st_size)}"
    if abs(sa.st_mtime - sb.st_mtime) < 2:
        return "一致", f"{fmt_size(sa.st_size)}，修改时间一致"
    if same_content(a, b):
        return "一致", f"{fmt_size(sa.st_size)}，内容相同（mtime 不同）"
    return "不一致", f"内容不同，大小 {fmt_size(sa.st_size)}"


def collect_files(root: Path) -> dict:
    result = {}
    root_str = str(root)
    for dirpath, _dirnames, filenames in os.walk(root_str):
        for f in filenames:
            full = os.path.join(dirpath, f)
            rel = os.path.relpath(full, root_str)
            result[rel] = Path(full)
    return result


def compare_dirs(a: Path, b: Path):
    files_a = collect_files(a)
    files_b = collect_files(b)
    only_a = set(files_a) - set(files_b)
    only_b = set(files_b) - set(files_a)
    common = set(files_a) & set(files_b)

    diff = []
    for rel in common:
        pa, pb = files_a[rel], files_b[rel]
        if pa.stat().st_size != pb.stat().st_size:
            diff.append(rel)
            continue
        if not same_content(pa, pb):
            diff.append(rel)

    if not only_a and not only_b and not diff:
        return "一致", f"{len(common)} 个文件一致"

    parts = []
    if only_a:
        parts.append(f"仅目标有 {len(only_a)} 个")
    if only_b:
        parts.append(f"仅备份有 {len(only_b)} 个")
    if diff:
        parts.append(f"内容不同 {len(diff)} 个")
    return "不一致", "；".join(parts)


def check_one(item, target_root: Path, backup_root: Path):
    tp = safe_join(target_root, item["path"])
    bp = safe_join(backup_root, item["path"])

    t_exists = tp.exists()
    b_exists = bp.exists()

    if not t_exists and not b_exists:
        return "缺失", "目标端与备份端均不存在"
    if t_exists and not b_exists:
        return "仅目标有", describe(tp)
    if not t_exists and b_exists:
        return "仅备份有", describe(bp)

    if tp.is_file() and bp.is_file():
        return compare_files(tp, bp)
    if tp.is_dir() and bp.is_dir():
        return compare_dirs(tp, bp)

    return (
        "不一致",
        f"类型不一致：目标={'目录' if tp.is_dir() else '文件'}，"
        f"备份={'目录' if bp.is_dir() else '文件'}",
    )


# =============================================================================
#  后台工作线程
# =============================================================================
class FunctionThread(QThread):
    done = Signal(object)
    failed = Signal(str)

    def __init__(self, func, parent=None):
        super().__init__(parent)
        self._func = func

    def run(self):
        try:
            result = self._func()
            self.done.emit(result)
        except Exception as e:
            self.failed.emit(str(e))


# =============================================================================
#  自动补全 LineEdit
# =============================================================================
class AutocompleteLineEdit(QLineEdit):
    def __init__(self, parent=None, base_dir=None):
        super().__init__(parent)
        self.base_dir = base_dir
        self._model = QStringListModel(self)
        self._completer = QCompleter(self._model, self)
        self._completer.setCaseSensitivity(Qt.CaseInsensitive)
        self._completer.setCompletionMode(QCompleter.PopupCompletion)
        self._completer.setFilterMode(Qt.MatchContains)
        self._completer.setMaxVisibleItems(12)
        self.setCompleter(self._completer)

        self.textEdited.connect(self._on_text_edited)

    def _compute_abs(self, raw: str) -> str:
        if not raw:
            if self.base_dir and os.path.isdir(str(self.base_dir)):
                return str(self.base_dir)
            return os.getcwd()
        if os.path.isabs(raw):
            return os.path.expanduser(raw)
        if self.base_dir:
            return os.path.join(str(self.base_dir), raw)
        return os.path.abspath(os.path.expanduser(raw))

    def _to_display(self, full: str, isdir: bool) -> str:
        suffix = os.sep if isdir else ""
        if self.base_dir:
            try:
                rel = os.path.relpath(full, str(self.base_dir))
                if not rel.startswith(".."):
                    return rel + suffix
            except ValueError:
                pass
        return full + suffix

    def _on_text_edited(self, _text):
        QTimer.singleShot(0, self._update_matches)

    def _update_matches(self):
        raw = self.text()
        if not raw:
            return

        abs_text = self._compute_abs(raw)
        if abs_text.endswith(os.sep):
            dirname, prefix = abs_text, ""
        else:
            dirname = os.path.dirname(abs_text) or os.sep
            prefix = os.path.basename(abs_text)

        try:
            entries = sorted(os.listdir(dirname))
        except OSError:
            return

        display = []
        for e in entries:
            if e.startswith(".") and not prefix.startswith("."):
                continue
            if e.startswith(prefix):
                full = os.path.join(dirname, e)
                display.append(self._to_display(full, os.path.isdir(full)))

        if not display:
            return

        self._model.setStringList(display)
        self._completer.setCompletionPrefix("")
        try:
            popup = self._completer.popup()
            popup.setMinimumWidth(max(self.width(), 320))
        except Exception:
            pass
        self._completer.complete()


# =============================================================================
#  添加跟踪项对话框
# =============================================================================
class AddTrackDialog(QDialog):
    def __init__(self, parent, base_dirs, existing_paths):
        super().__init__(parent)
        self.setWindowTitle("添加跟踪项")
        self.setModal(True)
        self.result_data = None
        self.base_dirs = base_dirs
        self.existing = set(existing_paths)

        base_for_entry = None
        for key in ("target", "backup"):
            d = base_dirs.get(key)
            if d and Path(d).exists():
                base_for_entry = str(d)
                break

        layout = QVBoxLayout(self)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(8)

        form = QHBoxLayout()
        form.addWidget(QLabel("相对路径:"))
        self.entry = AutocompleteLineEdit(base_dir=base_for_entry)
        form.addWidget(self.entry, 1)
        layout.addLayout(form)

        btn_row = QHBoxLayout()
        self.btn_file = QPushButton("浏览文件…")
        self.btn_dir = QPushButton("浏览文件夹…")
        btn_row.addWidget(self.btn_file)
        btn_row.addWidget(self.btn_dir)
        btn_row.addStretch()
        layout.addLayout(btn_row)

        hint = QLabel("相对路径相对于目标/备份文件夹，例如：.config/nvim/init.lua")
        hint.setStyleSheet("color: #888;")
        layout.addWidget(hint)

        self.preview = QLabel("")
        self.preview.setStyleSheet("color: #555;")
        layout.addWidget(self.preview)

        btns = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        btns.button(QDialogButtonBox.Ok).setText("添加")
        btns.button(QDialogButtonBox.Cancel).setText("取消")
        btns.accepted.connect(self._on_ok)
        btns.rejected.connect(self.reject)
        layout.addWidget(btns)

        self.entry.textChanged.connect(self._update_preview)
        self.entry.returnPressed.connect(self._on_ok)
        self.btn_file.clicked.connect(self._browse_file)
        self.btn_dir.clicked.connect(self._browse_dir)

        self.resize(640, 220)
        self.entry.setFocus()

    def _base_for_browse(self):
        for key in ("target", "backup"):
            d = self.base_dirs.get(key)
            if d and Path(d).exists():
                return str(d)
        return str(Path.home())

    def _browse_file(self):
        p, _ = QFileDialog.getOpenFileName(
            self, "选择要跟踪的文件", self._base_for_browse()
        )
        if p:
            self._set_rel(p)

    def _browse_dir(self):
        p = QFileDialog.getExistingDirectory(
            self, "选择要跟踪的文件夹", self._base_for_browse()
        )
        if p:
            self._set_rel(p)

    def _set_rel(self, abs_path):
        abs_path = os.path.abspath(os.path.expanduser(abs_path))
        for key in ("target", "backup"):
            base = self.base_dirs.get(key)
            if base and Path(base).exists():
                base_abs = os.path.abspath(str(base))
                try:
                    rel = os.path.relpath(abs_path, base_abs)
                except ValueError:
                    continue
                if not rel.startswith(".."):
                    self.entry.setText(rel.replace(os.sep, "/"))
                    return
        self.entry.setText(abs_path)

    def _update_preview(self):
        rel = self.entry.text().strip()
        if not rel:
            self.preview.setText("")
            return
        lines = []
        for key, label in (("target", "目标"), ("backup", "备份")):
            base = self.base_dirs.get(key)
            if not base:
                lines.append(f"{label}: (未设置)")
                continue
            p = Path(base) / rel
            if p.exists():
                t = "目录" if p.is_dir() else "文件"
                lines.append(f"{label}: ✓ {t}")
            else:
                lines.append(f"{label}: ✗ 不存在")
        self.preview.setText("     ".join(lines))

    def _on_ok(self):
        rel = self.entry.text().strip().replace(os.sep, "/")
        if not rel:
            QMessageBox.warning(self, "添加跟踪项", "请输入路径")
            return
        if rel in self.existing:
            QMessageBox.warning(self, "添加跟踪项", "该路径已在跟踪列表中")
            return

        ptype = None
        for key in ("target", "backup"):
            base = self.base_dirs.get(key)
            if base:
                p = Path(base) / rel
                if p.exists():
                    ptype = "目录" if p.is_dir() else "文件"
                    break
        if not ptype:
            QMessageBox.critical(
                self, "添加跟踪项",
                "该路径在目标和备份文件夹中都不存在。\n请先在任一侧创建它。",
            )
            return

        self.result_data = {"path": rel, "type": ptype}
        self.accept()


# =============================================================================
#  文件夹浏览器（双栏之一）
# =============================================================================
class FolderBrowser(QWidget):
    """
    单侧文件夹树浏览控件。用于并排展示目标侧 / 备份侧内容。
    - 懒加载子目录
    - ExtendedSelection 多选
    - 状态列着色显示对侧对比结果
    - 信号：add_tracking_requested(list), sync_requested(list)
    """

    add_tracking_requested = Signal(list)
    sync_requested = Signal(list)

    def __init__(self, title_text: str, parent=None):
        super().__init__(parent)
        self.title_text = title_text
        self.root_path = None
        self.peer_root = None

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        header = QHBoxLayout()
        header.setSpacing(4)
        self.title_label = QLabel(title_text)
        self.title_label.setStyleSheet("font-weight: bold; color: #333;")
        header.addWidget(self.title_label, 1)

        self.btn_add = QPushButton("＋ 跟踪")
        self.btn_add.setToolTip("将选中项添加到跟踪列表")
        self.btn_add.clicked.connect(self._on_add_clicked)
        header.addWidget(self.btn_add)

        self.btn_sync = QPushButton("→ 同步")
        self.btn_sync.setToolTip("将选中项复制到对侧")
        self.btn_sync.clicked.connect(self._on_sync_clicked)
        header.addWidget(self.btn_sync)

        self.btn_refresh = QPushButton("⟳ 刷新")
        self.btn_refresh.clicked.connect(self.refresh)
        header.addWidget(self.btn_refresh)

        layout.addLayout(header)

        self.tree = QTreeWidget()
        self.tree.setColumnCount(4)
        self.tree.setHeaderLabels(["名称", "状态", "大小", "修改时间"])
        self.tree.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.tree.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.tree.setAlternatingRowColors(True)
        self.tree.setUniformRowHeights(True)

        hv = self.tree.header()
        hv.setSectionResizeMode(0, QHeaderView.Stretch)
        hv.setSectionResizeMode(1, QHeaderView.Interactive)
        hv.setSectionResizeMode(2, QHeaderView.Interactive)
        hv.setSectionResizeMode(3, QHeaderView.Interactive)
        self.tree.setColumnWidth(1, 90)
        self.tree.setColumnWidth(2, 80)
        self.tree.setColumnWidth(3, 130)

        self.tree.itemExpanded.connect(self._on_item_expanded)
        self.tree.itemDoubleClicked.connect(self._on_double_clicked)
        self.tree.setContextMenuPolicy(Qt.CustomContextMenu)
        self.tree.customContextMenuRequested.connect(self._on_context_menu)

        layout.addWidget(self.tree, 1)

        self.dir_icon = self.style().standardIcon(QStyle.SP_DirIcon)
        self.file_icon = self.style().standardIcon(QStyle.SP_FileIcon)

    # ---------------- 数据加载 ----------------
    def set_paths(self, root, peer):
        """设置本侧根目录和对侧根目录，然后刷新视图。"""
        self.root_path = Path(root).expanduser() if root else None
        self.peer_root = Path(peer).expanduser() if peer else None
        if self.root_path and not self.root_path.is_dir():
            self.root_path = None
        if self.peer_root and not self.peer_root.is_dir():
            self.peer_root = None
        if self.root_path:
            self.title_label.setText(f"{self.title_text}: {self.root_path}")
        else:
            self.title_label.setText(f"{self.title_text}: (未设置)")
        self.refresh()

    def refresh(self):
        self.tree.clear()
        if not self.root_path:
            hint = QTreeWidgetItem(self.tree)
            hint.setText(0, "（请先在上方设置此侧文件夹）")
            hint.setDisabled(True)
            return
        self._populate_children(None, self.root_path, "")

    def _populate_children(self, parent, dir_path: Path, rel_prefix: str):
        try:
            with os.scandir(dir_path) as it:
                entries = list(it)
        except OSError as e:
            if parent is None:
                hint = QTreeWidgetItem(self.tree)
                hint.setText(0, f"（无法读取: {e}）")
                hint.setDisabled(True)
            return

        def sort_key(e):
            try:
                is_dir = e.is_dir(follow_symlinks=False)
            except OSError:
                is_dir = False
            return (not is_dir, e.name.lower())

        entries.sort(key=sort_key)

        for e in entries:
            rel = f"{rel_prefix}/{e.name}" if rel_prefix else e.name
            try:
                is_dir = e.is_dir(follow_symlinks=False)
            except OSError:
                continue

            item = QTreeWidgetItem()
            item.setText(0, e.name)
            item.setData(0, Qt.UserRole, rel)

            if is_dir:
                item.setIcon(0, self.dir_icon)
                item.setData(0, Qt.UserRole + 1, "unloaded")
                placeholder = QTreeWidgetItem()
                placeholder.setText(0, "…")
                placeholder.setDisabled(True)
                item.addChild(placeholder)
            else:
                item.setIcon(0, self.file_icon)
                try:
                    st = e.stat(follow_symlinks=False)
                    item.setText(2, fmt_size(st.st_size))
                    item.setText(
                        3,
                        datetime.fromtimestamp(st.st_mtime)
                        .strftime("%Y-%m-%d %H:%M"),
                    )
                except OSError:
                    pass

            self._apply_status(item, rel)

            if parent is None:
                self.tree.addTopLevelItem(item)
            else:
                parent.addChild(item)

    def _apply_status(self, item: QTreeWidgetItem, rel: str):
        if not self.peer_root:
            item.setText(1, "—")
            item.setForeground(1, QBrush(QColor(STATUS_COLORS["—"])))
            return

        my_path = self.root_path / rel
        peer_path = self.peer_root / rel
        try:
            my_exists = my_path.exists()
            peer_exists = peer_path.exists()
        except OSError:
            item.setText(1, "错误")
            item.setForeground(1, QBrush(QColor(STATUS_COLORS["错误"])))
            return

        if not my_exists:
            status = "缺失"
        elif not peer_exists:
            status = "仅此侧有"
        else:
            my_is_dir = my_path.is_dir()
            peer_is_dir = peer_path.is_dir()
            if my_is_dir and peer_is_dir:
                status = "目录"
            elif my_is_dir != peer_is_dir:
                status = "类型不同"
            elif my_path.is_file():
                try:
                    sa = my_path.stat()
                    sb = peer_path.stat()
                    if sa.st_size != sb.st_size:
                        status = "大小不同"
                    elif abs(sa.st_mtime - sb.st_mtime) < 2:
                        status = "一致"
                    else:
                        status = "时间不同"
                except OSError:
                    status = "错误"
            else:
                status = "一致"

        item.setText(1, status)
        color = STATUS_COLORS.get(status, "#000000")
        item.setForeground(1, QBrush(QColor(color)))

    # ---------------- 事件 ----------------
    def _on_item_expanded(self, item: QTreeWidgetItem):
        if item.data(0, Qt.UserRole + 1) != "unloaded":
            return
        item.setData(0, Qt.UserRole + 1, "loaded")
        item.takeChildren()
        rel = item.data(0, Qt.UserRole)
        if not rel:
            return
        self._populate_children(item, self.root_path / rel, rel)

    def _on_double_clicked(self, item: QTreeWidgetItem, _column: int):
        rel = item.data(0, Qt.UserRole)
        if not rel:
            return
        p = self.root_path / rel
        if p.is_file():
            self._open_path(p)

    def _on_context_menu(self, pos):
        item = self.tree.itemAt(pos)
        if not item:
            return
        if not item.isSelected():
            self.tree.clearSelection()
            item.setSelected(True)

        menu = QMenu(self)
        act_add = menu.addAction("添加到跟踪列表")
        act_sync = menu.addAction("同步到对侧")
        menu.addSeparator()
        act_refresh = menu.addAction("刷新")

        chosen = menu.exec(self.tree.viewport().mapToGlobal(pos))
        if chosen == act_add:
            self._on_add_clicked()
        elif chosen == act_sync:
            self._on_sync_clicked()
        elif chosen == act_refresh:
            self.refresh()

    # ---------------- 选择 / 动作 ----------------
    def selected_rel_paths(self):
        """返回选中的相对路径（自动去掉祖先已被选中的子项）。"""
        selected_set = set()
        for item in self.tree.selectedItems():
            rel = item.data(0, Qt.UserRole)
            if rel:
                selected_set.add(rel)

        result = []
        for rel in selected_set:
            parts = rel.split("/")
            has_ancestor = False
            for i in range(1, len(parts)):
                if "/".join(parts[:i]) in selected_set:
                    has_ancestor = True
                    break
            if not has_ancestor:
                result.append(rel)
        return sorted(result)

    def _on_add_clicked(self):
        paths = self.selected_rel_paths()
        if not paths:
            QMessageBox.information(self, "提示", "请先在树中选择要添加的项")
            return
        self.add_tracking_requested.emit(paths)

    def _on_sync_clicked(self):
        paths = self.selected_rel_paths()
        if not paths:
            QMessageBox.information(self, "提示", "请先在树中选择要同步的项")
            return
        self.sync_requested.emit(paths)

    def _open_path(self, p: Path):
        try:
            if sys.platform.startswith("win"):
                os.startfile(str(p))
            elif sys.platform == "darwin":
                subprocess.Popen(["open", str(p)])
            else:
                subprocess.Popen(["xdg-open", str(p)])
        except Exception:
            pass


# =============================================================================
#  主窗口
# =============================================================================
class ConfigSyncApp(QMainWindow):
    def __init__(self, config_path=None):
        super().__init__()
        self.setWindowTitle(APP_TITLE)
        self.resize(1200, 780)
        self.setMinimumSize(960, 600)

        self.items = []
        self.current_config_path = None
        self._busy = False
        self._worker = None

        self._build_menu()
        self._build_ui()
        self._setup_shortcuts()

        if config_path:
            try:
                self._load_config(config_path)
            except Exception as e:
                self._set_status(f"加载失败: {e}")
                QMessageBox.critical(self, "加载失败", str(e))
        else:
            self._load_default_or_empty()

    # ----------------------------------------------------------- 菜单
    def _build_menu(self):
        menubar = self.menuBar()

        m_file = menubar.addMenu("文件")
        self._add_action(m_file, "新建配置", "Ctrl+N", self.action_new)
        self._add_action(m_file, "打开配置…", "Ctrl+O", self.action_open)
        self._add_action(m_file, "保存配置", "Ctrl+S", self.action_save)
        self._add_action(m_file, "另存为…", None, self.action_save_as)
        m_file.addSeparator()
        self._add_action(m_file, "退出", None, self.close)

        m_edit = menubar.addMenu("编辑")
        self._add_action(m_edit, "添加跟踪项…", None, self.action_add)
        self._add_action(m_edit, "删除选中项", None, self.action_remove)
        m_edit.addSeparator()
        self._add_action(m_edit, "全选跟踪项", "Ctrl+A", self._select_all)
        self._add_action(m_edit, "清空跟踪列表", None, self.action_clear)

        m_op = menubar.addMenu("操作")
        self._add_action(m_op, "刷新浏览视图", "F8", self._refresh_browsers)
        m_op.addSeparator()
        self._add_action(m_op, "检查一致性", "F5",
                         lambda: self.action_check(False))
        m_op.addSeparator()
        self._add_action(m_op, "同步 → 备份", "F6",
                         lambda: self.action_sync("to_backup"))
        self._add_action(m_op, "恢复 ← 备份", "F7",
                         lambda: self.action_sync("to_target"))

        m_help = menubar.addMenu("帮助")
        self._add_action(m_help, "使用说明", None, self.action_help)
        self._add_action(m_help, "关于", None, self.action_about)

    def _add_action(self, menu, text, shortcut, slot):
        act = QAction(text, self)
        if shortcut:
            act.setShortcut(QKeySequence(shortcut))
        act.triggered.connect(slot)
        menu.addAction(act)
        return act

    def _setup_shortcuts(self):
        sc = QShortcut(QKeySequence(Qt.Key_Delete), self.table)
        sc.activated.connect(self.action_remove)

    # ----------------------------------------------------------- UI
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        outer = QVBoxLayout(central)
        outer.setContentsMargins(10, 10, 10, 4)
        outer.setSpacing(6)

        # ---- 目录设置 ----
        dir_box = QGroupBox("同步目录")
        dir_layout = QGridLayout(dir_box)
        dir_layout.setContentsMargins(10, 10, 10, 10)
        dir_layout.setHorizontalSpacing(8)
        dir_layout.setVerticalSpacing(6)

        dir_layout.addWidget(QLabel("目标文件夹:"), 0, 0)
        self.entry_target = AutocompleteLineEdit()
        dir_layout.addWidget(self.entry_target, 0, 1)
        btn = QPushButton("浏览…")
        btn.clicked.connect(self._browse_target)
        dir_layout.addWidget(btn, 0, 2)

        dir_layout.addWidget(QLabel("备份文件夹:"), 1, 0)
        self.entry_backup = AutocompleteLineEdit()
        dir_layout.addWidget(self.entry_backup, 1, 1)
        btn = QPushButton("浏览…")
        btn.clicked.connect(self._browse_backup)
        dir_layout.addWidget(btn, 1, 2)

        dir_layout.setColumnStretch(1, 1)
        outer.addWidget(dir_box)

        self.entry_target.editingFinished.connect(self._refresh_browsers)
        self.entry_backup.editingFinished.connect(self._refresh_browsers)

        # ---- 工具栏 ----
        toolbar = QHBoxLayout()
        toolbar.setSpacing(4)

        self.btn_add = QPushButton("＋ 添加跟踪项")
        self.btn_add.clicked.connect(self.action_add)
        toolbar.addWidget(self.btn_add)

        self.btn_del = QPushButton("－ 删除选中")
        self.btn_del.clicked.connect(self.action_remove)
        toolbar.addWidget(self.btn_del)

        toolbar.addSpacing(6)
        sep1 = QFrame()
        sep1.setFrameShape(QFrame.VLine)
        sep1.setFrameShadow(QFrame.Sunken)
        toolbar.addWidget(sep1)
        toolbar.addSpacing(6)

        self.btn_check = QPushButton("⟳ 检查一致性")
        self.btn_check.clicked.connect(lambda: self.action_check(False))
        toolbar.addWidget(self.btn_check)

        toolbar.addSpacing(6)
        sep2 = QFrame()
        sep2.setFrameShape(QFrame.VLine)
        sep2.setFrameShadow(QFrame.Sunken)
        toolbar.addWidget(sep2)
        toolbar.addSpacing(6)

        self.btn_sync_to = QPushButton("→ 同步到备份")
        self.btn_sync_to.clicked.connect(lambda: self.action_sync("to_backup"))
        toolbar.addWidget(self.btn_sync_to)

        self.btn_restore = QPushButton("← 从备份恢复")
        self.btn_restore.clicked.connect(lambda: self.action_sync("to_target"))
        toolbar.addWidget(self.btn_restore)

        toolbar.addSpacing(6)
        sep3 = QFrame()
        sep3.setFrameShape(QFrame.VLine)
        sep3.setFrameShadow(QFrame.Sunken)
        toolbar.addWidget(sep3)
        toolbar.addSpacing(6)

        self.btn_refresh = QPushButton("⟳ 刷新浏览")
        self.btn_refresh.setToolTip("重新加载左右两侧的目录树（F8）")
        self.btn_refresh.clicked.connect(self._refresh_browsers)
        toolbar.addWidget(self.btn_refresh)

        toolbar.addStretch()
        self.summary_label = QLabel("")
        self.summary_label.setStyleSheet("color: #555;")
        toolbar.addWidget(self.summary_label)

        outer.addLayout(toolbar)

        # ---- 主分割：上=双栏浏览，下=跟踪列表 ----
        main_splitter = QSplitter(Qt.Vertical)

        browse_container = QWidget()
        browse_layout = QHBoxLayout(browse_container)
        browse_layout.setContentsMargins(0, 0, 0, 0)
        browse_layout.setSpacing(6)

        self.browser_target = FolderBrowser("目标文件夹")
        self.browser_backup = FolderBrowser("备份文件夹")
        browse_layout.addWidget(self.browser_target, 1)
        browse_layout.addWidget(self.browser_backup, 1)

        self.browser_target.add_tracking_requested.connect(
            self._on_browser_add_tracking)
        self.browser_target.sync_requested.connect(
            lambda paths: self._on_browser_sync("target", paths))
        self.browser_backup.add_tracking_requested.connect(
            self._on_browser_add_tracking)
        self.browser_backup.sync_requested.connect(
            lambda paths: self._on_browser_sync("backup", paths))

        main_splitter.addWidget(browse_container)

        tracking_box = QGroupBox("跟踪列表")
        tracking_layout = QVBoxLayout(tracking_box)
        tracking_layout.setContentsMargins(6, 6, 6, 6)

        self.table = QTableWidget(0, 4)
        self.table.setHorizontalHeaderLabels(["相对路径", "类型", "状态", "详情"])
        self.table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.table.setEditTriggers(QAbstractItemView.NoEditTriggers)
        self.table.setAlternatingRowColors(True)
        self.table.verticalHeader().setDefaultSectionSize(24)
        self.table.verticalHeader().setFixedWidth(44)

        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.Interactive)
        header.setSectionResizeMode(1, QHeaderView.Interactive)
        header.setSectionResizeMode(2, QHeaderView.Interactive)
        header.setSectionResizeMode(3, QHeaderView.Stretch)
        self.table.setColumnWidth(0, 380)
        self.table.setColumnWidth(1, 70)
        self.table.setColumnWidth(2, 110)

        self.table.doubleClicked.connect(self._on_table_double)
        self.table.setContextMenuPolicy(Qt.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self._on_table_context)

        tracking_layout.addWidget(self.table)
        main_splitter.addWidget(tracking_box)

        main_splitter.setStretchFactor(0, 3)
        main_splitter.setStretchFactor(1, 2)
        main_splitter.setSizes([440, 240])
        outer.addWidget(main_splitter, 1)

        # ---- 状态栏 ----
        self.status_label = QLabel("就绪")
        self.statusBar().addWidget(self.status_label, 1)

        self.progress = QProgressBar()
        self.progress.setRange(0, 1)
        self.progress.setValue(0)
        self.progress.setFixedWidth(160)
        self.progress.setVisible(False)
        self.statusBar().addPermanentWidget(self.progress)

        # 初始化浏览视图
        self._refresh_browsers()

    # ------------------------------------------------------- 基础工具
    def _set_status(self, msg: str):
        self.status_label.setText(msg)

    def _show_progress(self, show: bool):
        if show:
            self.progress.setRange(0, 0)
            self.progress.setVisible(True)
        else:
            self.progress.setRange(0, 1)
            self.progress.setValue(0)
            self.progress.setVisible(False)

    def _browse_target(self):
        start = self.entry_target.text().strip() or str(Path.home())
        p = QFileDialog.getExistingDirectory(self, "选择目标文件夹", start)
        if p:
            self.entry_target.setText(p)
            self._refresh_browsers()

    def _browse_backup(self):
        start = self.entry_backup.text().strip() or str(Path.home())
        p = QFileDialog.getExistingDirectory(self, "选择备份文件夹", start)
        if p:
            self.entry_backup.setText(p)
            self._refresh_browsers()

    def _refresh_browsers(self):
        t = self.entry_target.text().strip()
        b = self.entry_backup.text().strip()
        self.browser_target.set_paths(t, b)
        self.browser_backup.set_paths(b, t)

    def _validate_dirs(self) -> bool:
        t = self.entry_target.text().strip()
        b = self.entry_backup.text().strip()
        if not t or not b:
            QMessageBox.warning(self, "提示",
                                "请先设置「目标文件夹」和「备份文件夹」")
            return False
        tp, bp = Path(t).expanduser(), Path(b).expanduser()
        if not tp.is_dir():
            QMessageBox.critical(self, "错误",
                                 f"目标文件夹不存在或不是目录:\n{tp}")
            return False
        if not bp.is_dir():
            QMessageBox.critical(self, "错误",
                                 f"备份文件夹不存在或不是目录:\n{bp}")
            return False
        return True

    # ------------------------------------------------------- 任务调度
    def _start_job(self, work_func, on_done, title="任务"):
        def _done(result):
            self._busy = False
            self._show_progress(False)
            self._worker = None
            on_done(result)

        def _err(msg):
            self._busy = False
            self._show_progress(False)
            self._worker = None
            self._set_status(f"{title}失败: {msg}")
            QMessageBox.critical(self, f"{title}失败", msg)

        worker = FunctionThread(work_func)
        self._worker = worker
        worker.done.connect(_done)
        worker.failed.connect(_err)
        worker.start()

    # ------------------------------------------------------- 表格刷新
    def _refresh_table(self):
        sel = self._get_selected_indices()

        self.table.blockSignals(True)
        self.table.setRowCount(len(self.items))
        for idx, item in enumerate(self.items):
            status = item.get("status", "未检查")
            color = QColor(STATUS_COLORS.get(status, "#000000"))
            values = (
                item["path"],
                item.get("type", ""),
                status,
                item.get("detail", ""),
            )
            for col, text in enumerate(values):
                cell = QTableWidgetItem(text)
                cell.setForeground(color)
                self.table.setItem(idx, col, cell)
        self.table.blockSignals(False)

        self.table.clearSelection()
        for idx in sel:
            if 0 <= idx < self.table.rowCount():
                self.table.selectionModel().select(
                    self.table.model().index(idx, 0),
                    QItemSelectionModel.Select | QItemSelectionModel.Rows,
                )

        counts = {}
        for item in self.items:
            st = item.get("status", "未检查")
            counts[st] = counts.get(st, 0) + 1
        parts = []
        for k in ("一致", "不一致", "仅目标有", "仅备份有",
                  "缺失", "错误", "未检查"):
            if counts.get(k):
                parts.append(f"{k}: {counts[k]}")
        self.summary_label.setText("    ".join(parts) if parts else "")

    def _get_selected_indices(self):
        return {idx.row() for idx in self.table.selectedIndexes()}

    def _get_selected_items(self):
        return [self.items[i] for i in sorted(self._get_selected_indices())
                if 0 <= i < len(self.items)]

    def _select_all(self):
        self.table.selectAll()

    # ------------------------------------------------------- 浏览器回调
    def _on_browser_add_tracking(self, paths):
        if not paths:
            return
        existing = {it["path"] for it in self.items}
        added = 0
        for rel in paths:
            rel = rel.replace(os.sep, "/")
            if rel in existing:
                continue
            ptype = None
            for base in (self.entry_target.text().strip(),
                         self.entry_backup.text().strip()):
                if not base:
                    continue
                p = Path(base).expanduser() / rel
                if p.exists():
                    ptype = "目录" if p.is_dir() else "文件"
                    break
            if not ptype:
                continue
            self.items.append({
                "path": rel,
                "type": ptype,
                "status": "未检查",
                "detail": "",
            })
            existing.add(rel)
            added += 1

        if added:
            self._refresh_table()
            self._set_status(f"已添加 {added} 项到跟踪列表")
        else:
            self._set_status("没有新增项（可能已存在或路径无效）")

    def _on_browser_sync(self, side: str, paths):
        if not paths:
            return
        if self._busy:
            self._set_status("已有任务在执行，请稍候…")
            return
        if not self._validate_dirs():
            return

        if side == "target":
            src_root = Path(self.entry_target.text().strip()).expanduser()
            dst_root = Path(self.entry_backup.text().strip()).expanduser()
            title = "同步到备份（选中）"
        else:
            src_root = Path(self.entry_backup.text().strip()).expanduser()
            dst_root = Path(self.entry_target.text().strip()).expanduser()
            title = "恢复（选中）"

        ret = QMessageBox.question(
            self, title,
            f"将以下 {len(paths)} 个选中项从\n{src_root}\n复制到\n"
            f"{dst_root}\n\n继续？",
            QMessageBox.Yes | QMessageBox.No,
        )
        if ret != QMessageBox.Yes:
            return

        self._busy = True
        self._set_status(f"{title} 进行中…")
        self._show_progress(True)

        def work():
            errors = []
            for rel in paths:
                try:
                    sp = safe_join(src_root, rel)
                    dp = safe_join(dst_root, rel)
                    if not sp.exists():
                        errors.append(f"{rel}: 源不存在")
                        continue
                    dp.parent.mkdir(parents=True, exist_ok=True)
                    if sp.is_dir():
                        shutil.copytree(sp, dp, dirs_exist_ok=True)
                    else:
                        shutil.copy2(sp, dp)
                except Exception as e:
                    errors.append(f"{rel}: {e}")
            return errors

        def on_done(errors):
            if errors:
                self._set_status(f"{title} 完成，但有 {len(errors)} 个错误")
                QMessageBox.warning(
                    self, title,
                    "以下项失败:\n\n" + "\n".join(errors[:30]),
                )
            else:
                self._set_status(f"{title} 完成")
            self._refresh_browsers()

        self._start_job(work, on_done, title=title)

    # ------------------------------------------------------- 增删
    def action_add(self):
        t = self.entry_target.text().strip()
        b = self.entry_backup.text().strip()
        if not t and not b:
            QMessageBox.warning(self, "提示", "请先设置目标或备份文件夹")
            return
        base_dirs = {"target": t, "backup": b}
        existing = [it["path"] for it in self.items]
        dlg = AddTrackDialog(self, base_dirs, existing)
        if dlg.exec() == QDialog.Accepted and dlg.result_data:
            self.items.append({
                "path": dlg.result_data["path"],
                "type": dlg.result_data["type"],
                "status": "未检查",
                "detail": "",
            })
            self._refresh_table()
            self._set_status(f"已添加跟踪项: {dlg.result_data['path']}")

    def action_remove(self):
        sel = self._get_selected_indices()
        if not sel:
            self._set_status("请选择要删除的跟踪项")
            return
        ret = QMessageBox.question(
            self, "删除跟踪项",
            f"确定删除选中的 {len(sel)} 项？\n（仅删除跟踪记录，不删除磁盘文件）",
            QMessageBox.Yes | QMessageBox.No,
        )
        if ret != QMessageBox.Yes:
            return
        self.items = [it for i, it in enumerate(self.items) if i not in sel]
        self._refresh_table()
        self._set_status(f"已删除 {len(sel)} 项")

    def action_clear(self):
        if not self.items:
            return
        ret = QMessageBox.question(
            self, "清空跟踪列表", "确定清空全部跟踪项？",
            QMessageBox.Yes | QMessageBox.No,
        )
        if ret == QMessageBox.Yes:
            self.items = []
            self._refresh_table()
            self._set_status("已清空跟踪列表")

    # ------------------------------------------------------- 一致性检查
    def action_check(self, only_selected=False):
        if self._busy:
            self._set_status("已有任务在执行，请稍候…")
            return
        if not self._validate_dirs():
            return

        targets = self._get_selected_items() if only_selected else self.items
        if not targets:
            self._set_status("没有要检查的跟踪项")
            return

        target_root = Path(self.entry_target.text().strip()).expanduser()
        backup_root = Path(self.entry_backup.text().strip()).expanduser()

        self._busy = True
        self._set_status("正在检查一致性…")
        self._show_progress(True)

        for it in targets:
            it["status"] = "检查中"
            it["detail"] = ""
        self._refresh_table()

        snapshot = [(it, dict(it)) for it in targets]

        def work():
            results = []
            for real_it, snap in snapshot:
                try:
                    st, detail = check_one(snap, target_root, backup_root)
                except Exception as e:
                    st, detail = "错误", str(e)
                results.append((real_it, st, detail))
            return results

        def on_done(results):
            for it, st, detail in results:
                it["status"] = st
                it["detail"] = detail
            self._refresh_table()
            self._refresh_browsers()
            self._set_status(f"检查完成：共 {len(results)} 项")

        self._start_job(work, on_done, title="检查")

    # ------------------------------------------------------- 同步（跟踪列表）
    def action_sync(self, direction: str):
        if self._busy:
            self._set_status("已有任务在执行，请稍候…")
            return
        if not self._validate_dirs():
            return

        targets = self._get_selected_items()
        if not targets:
            ret = QMessageBox.question(
                self, "同步",
                "未选择任何跟踪项，将对全部项执行同步。继续？",
                QMessageBox.Yes | QMessageBox.No,
            )
            if ret != QMessageBox.Yes:
                return
            targets = self.items
        if not targets:
            self._set_status("没有可同步的跟踪项")
            return

        target_root = Path(self.entry_target.text().strip()).expanduser()
        backup_root = Path(self.entry_backup.text().strip()).expanduser()

        if direction == "to_backup":
            src_root, dst_root = target_root, backup_root
            title = "同步 → 备份"
        else:
            src_root, dst_root = backup_root, target_root
            title = "恢复 ← 备份"

        listing = "\n".join(f"  • {it['path']}" for it in targets[:20])
        if len(targets) > 20:
            listing += f"\n  … 共 {len(targets)} 项"
        ret = QMessageBox.question(
            self, title,
            f"将以下 {len(targets)} 项从\n{src_root}\n复制到\n{dst_root}\n\n"
            f"{listing}\n\n继续？",
            QMessageBox.Yes | QMessageBox.No,
        )
        if ret != QMessageBox.Yes:
            return

        self._busy = True
        self._set_status(f"{title} 进行中…")
        self._show_progress(True)

        for it in targets:
            it["status"] = "同步中"
            it["detail"] = ""
        self._refresh_table()

        paths = [it["path"] for it in targets]

        def work():
            errors = []
            for rel in paths:
                try:
                    sp = safe_join(src_root, rel)
                    dp = safe_join(dst_root, rel)
                    if not sp.exists():
                        errors.append(f"{rel}: 源不存在")
                        continue
                    dp.parent.mkdir(parents=True, exist_ok=True)
                    if sp.is_dir():
                        shutil.copytree(sp, dp, dirs_exist_ok=True)
                    else:
                        shutil.copy2(sp, dp)
                except Exception as e:
                    errors.append(f"{rel}: {e}")
            return errors

        def on_done(errors):
            if errors:
                self._set_status(f"{title} 完成，但有 {len(errors)} 个错误")
                QMessageBox.warning(
                    self, title,
                    "以下项失败:\n\n" + "\n".join(errors[:30]),
                )
            else:
                self._set_status(f"{title} 完成")
                QMessageBox.information(self, title, "同步完成")
            self._refresh_browsers()
            self.action_check(False)

        self._start_job(work, on_done, title=title)

    # ------------------------------------------------------- 右键 / 双击（跟踪列表）
    def _on_table_context(self, pos):
        idx = self.table.indexAt(pos)
        if not idx.isValid():
            return
        row = idx.row()
        if row not in self._get_selected_indices():
            self.table.selectRow(row)

        menu = QMenu(self)
        a1 = menu.addAction("检查此项一致性")
        a1.triggered.connect(lambda: self.action_check(only_selected=True))

        a2 = menu.addAction("同步 → 备份")
        a2.triggered.connect(lambda: self.action_sync("to_backup"))

        a3 = menu.addAction("恢复 ← 备份")
        a3.triggered.connect(lambda: self.action_sync("to_target"))

        menu.addSeparator()

        a4 = menu.addAction("在文件管理器中打开（目标）")
        a4.triggered.connect(lambda: self._open_in_fm("target", row))

        a5 = menu.addAction("在文件管理器中打开（备份）")
        a5.triggered.connect(lambda: self._open_in_fm("backup", row))

        menu.addSeparator()

        a6 = menu.addAction("删除跟踪项")
        a6.triggered.connect(self.action_remove)

        menu.exec(self.table.viewport().mapToGlobal(pos))

    def _on_table_double(self, index):
        row = index.row()
        if row < 0 or row >= len(self.items):
            return
        item = self.items[row]
        t = self.entry_target.text().strip()
        if not t:
            return
        p = Path(t).expanduser() / item["path"]
        if not p.exists():
            self._set_status(f"目标端不存在: {p}")
            return
        self._open_path(p)

    def _open_in_fm(self, which: str, row: int):
        if row < 0 or row >= len(self.items):
            return
        item = self.items[row]
        base = (self.entry_target.text() if which == "target"
                else self.entry_backup.text())
        if not base:
            return
        p = Path(base).expanduser() / item["path"]
        folder = p if p.is_dir() else p.parent
        if not folder.exists():
            self._set_status(f"目录不存在: {folder}")
            return
        self._open_path(folder)

    def _open_path(self, p: Path):
        try:
            if sys.platform.startswith("win"):
                os.startfile(str(p))
            elif sys.platform == "darwin":
                subprocess.Popen(["open", str(p)])
            else:
                subprocess.Popen(["xdg-open", str(p)])
        except Exception as e:
            self._set_status(f"打开失败: {e}")

    # ------------------------------------------------------- 配置管理
    def _to_dict(self):
        return {
            "version": 1,
            "target_dir": self.entry_target.text(),
            "backup_dir": self.entry_backup.text(),
            "items": [
                {"path": it["path"], "type": it.get("type", "")}
                for it in self.items
            ],
        }

    def _from_dict(self, data):
        self.entry_target.setText(data.get("target_dir", ""))
        self.entry_backup.setText(data.get("backup_dir", ""))
        self.items = []
        for it in data.get("items", []):
            path = it.get("path", "")
            if not path:
                continue
            self.items.append({
                "path": path,
                "type": it.get("type", ""),
                "status": "未检查",
                "detail": "",
            })
        self._refresh_table()
        self._refresh_browsers()

    def _load_default_or_empty(self):
        candidates = [
            Path.home() / ".config" / "config-sync-tool" / "config.json",
            Path.cwd() / DEFAULT_CONFIG_NAME,
        ]
        for p in candidates:
            if p.exists():
                try:
                    self._load_config(p)
                    return
                except Exception as e:
                    self._set_status(f"加载 {p} 失败: {e}")
        self._set_status("就绪 — 请设置「目标文件夹」和「备份文件夹」")
        self._refresh_browsers()

    def _load_config(self, path):
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        self._from_dict(data)
        self.current_config_path = str(path)
        self.setWindowTitle(
            f"{APP_TITLE} — {os.path.basename(str(path))}"
        )
        self._set_status(f"已加载配置: {path}")

    def action_new(self):
        if (self.items
                or self.entry_target.text()
                or self.entry_backup.text()):
            ret = QMessageBox.question(
                self, "新建配置", "确定清空当前配置？",
                QMessageBox.Yes | QMessageBox.No,
            )
            if ret != QMessageBox.Yes:
                return
        self.entry_target.setText("")
        self.entry_backup.setText("")
        self.items = []
        self.current_config_path = None
        self._refresh_table()
        self._refresh_browsers()
        self.setWindowTitle(APP_TITLE)
        self._set_status("新配置")

    def action_open(self):
        p, _ = QFileDialog.getOpenFileName(
            self, "打开配置", "",
            f"同步配置 (*{CONFIG_EXT});;JSON 文件 (*.json);;全部文件 (*)",
        )
        if not p:
            return
        try:
            self._load_config(p)
        except Exception as e:
            QMessageBox.critical(self, "打开失败", str(e))

    def action_save(self):
        if not self.current_config_path:
            return self.action_save_as()
        try:
            with open(self.current_config_path, "w", encoding="utf-8") as f:
                json.dump(self._to_dict(), f, ensure_ascii=False, indent=2)
            self._set_status(f"已保存: {self.current_config_path}")
        except Exception as e:
            QMessageBox.critical(self, "保存失败", str(e))

    def action_save_as(self):
        p, _ = QFileDialog.getSaveFileName(
            self, "保存配置", DEFAULT_CONFIG_NAME,
            f"同步配置 (*{CONFIG_EXT});;JSON 文件 (*.json);;全部文件 (*)",
        )
        if not p:
            return
        self.current_config_path = p
        self.setWindowTitle(f"{APP_TITLE} — {os.path.basename(p)}")
        self.action_save()

    # ------------------------------------------------------- 帮助
    def action_help(self):
        QMessageBox.information(
            self, "使用说明",
            "配置同步工具 · 使用说明\n"
            "────────────────────────────\n"
            "1. 设置「目标文件夹」和「备份文件夹」。\n"
            "   上方左右两栏会实时展示两侧内容，状态列显示对侧对比结果。\n"
            "2. 浏览器操作：\n"
            "   · 单击选中，Ctrl/Shift 多选\n"
            "   · 双击文件用系统程序打开\n"
            "   · 右键菜单：添加到跟踪 / 同步到对侧 / 刷新\n"
            "   · 每侧按钮：[＋跟踪] 加入跟踪列表，[→同步] 复制到对侧\n"
            "3. 跟踪列表（下方）：\n"
            "   · 添加/删除跟踪项，控制要纳入同步管理的路径\n"
            "   · F5 检查一致性（大小→mtime→哈希），F6 同步到备份，F7 恢复\n"
            "4. 浏览器状态列含义：\n"
            "   一致 / 时间不同 / 大小不同 / 仅此侧有 / 类型不同 / 目录 / —\n"
            "   （浏览器只比较大小和 mtime；完整哈希比较请用 F5）\n"
            "5. 文件菜单可保存 / 加载 JSON 配置。\n\n"
            "快捷键：Ctrl+N 新建   Ctrl+O 打开   Ctrl+S 保存\n"
            "        F5 检查   F6 同步→备份   F7 恢复←备份   F8 刷新浏览\n"
            "        Del (跟踪列表) 删除选中项",
        )

    def action_about(self):
        QMessageBox.information(
            self, "关于",
            f"{APP_TITLE}\n"
            "────────────────────────────\n"
            "一个基于 PySide6 的单文件配置同步工具。\n"
            "支持左右双栏可视化浏览、多选同步、跟踪列表管理。\n\n"
            "配置格式: JSON\n"
            "许可证: MIT",
        )

    # ------------------------------------------------------- 关闭
    def closeEvent(self, event):
        if self._worker is not None and self._worker.isRunning():
            self._worker.wait(3000)
        super().closeEvent(event)


# =============================================================================
#  入口
# =============================================================================
def main():
    app = QApplication(sys.argv)
    app.setApplicationName(APP_TITLE)

    app.setStyleSheet("""
        QGroupBox {
            font-weight: bold;
            border: 1px solid #ccc;
            border-radius: 4px;
            margin-top: 8px;
            padding-top: 8px;
        }
        QGroupBox::title {
            subcontrol-origin: margin;
            left: 10px;
            padding: 0 4px;
        }
        QTreeWidget, QTableWidget {
            gridline-color: #e0e0e0;
        }
        QHeaderView::section {
            background-color: #f5f5f5;
            padding: 4px;
            border: none;
            border-right: 1px solid #e0e0e0;
            border-bottom: 1px solid #e0e0e0;
        }
    """)

    config_path = sys.argv[1] if len(sys.argv) > 1 else None
    window = ConfigSyncApp(config_path=config_path)
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
