# 用于记录仓库的目录
from pathlib import Path


class Config:
    def __init__(self, file_dir, target_dir) -> None:
        self.target_dir = Path(target_dir).expanduser().resolve()
        self.file_dir = Path(file_dir).expanduser().resolve()
        self.step_dict: dict = {}
        self.step_num = 0
        self.shell = "bash"
        self.update_file = "update.sh"

    def append(self, step_sh, name: str = ""):
        r = step_sh
        if (self.file_dir / step_sh).exists():
            f = [name, str(r)]
            self.step_dict.update({self.step_num: f})
            self.step_num += 1
        else:
            raise FileNotFoundError

    def select(self, list_num: list) -> str:
        command = f"cd {self.file_dir}\n"
        for num in list_num:
            entry = self.step_dict.get(num)
            if entry is not None:
                command_file = entry[1]
                command += f"{self.shell} {command_file}\n"

        return command

    def update(self) -> str | None:
        r = f"{self.shell} {self.update_file}"
        return f"cd {self.file_dir}\n{r}\n"
        


nvim_config = Config("./nvim", "~/.config/nvim")

nvim_config.append("step1.sh","覆盖配置到目标文件夹")

print(nvim_config.update())
print(nvim_config.select([0]))
