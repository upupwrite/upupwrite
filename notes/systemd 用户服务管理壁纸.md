## systemd 用户服务管理壁纸

如果你希望以后更换壁纸时不用每次都注销，可以把 `swaybg` 配置成一个 **systemd 用户服务**。这样你就可以通过 `systemctl --user restart` 命令随时让新壁纸生效，而无需重启整个 niri 会话。

1. **创建服务文件** `~/.config/systemd/user/swaybg.service`：

   ```ini
   [Unit]
   PartOf=graphical-session.target
   After=graphical-session.target
   Requisite=graphical-session.target
   
   [Service]
   ExecStart=/usr/bin/swaybg -m fill -i "/home/kemil/Pictures/Wallpaper/5wp.png"
   Restart=on-failure
   ```

2. **重新加载 systemd 并挂载服务**到 niri 会话：

   ```bash
   systemctl --user daemon-reload
   systemctl --user add-wants niri.service swaybg.service
   ```

   配置完成后，从**下一次 niri 启动**开始，`swaybg` 就会由 systemd 管理。

3. **以后更换壁纸的流程**：
   修改服务文件中的图片路径，然后执行：

   ```bash
   systemctl --user daemon-reload
   systemctl --user restart swaybg.service
   ```

   壁纸会立即更新，无需注销。
