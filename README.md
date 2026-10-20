# PCL Download Patch

恢复 PCL（Plain Craft Launcher）新版本中被关闭的 Minecraft 下载与整合包安装功能。

> 官方在新版启动器中关闭了 MC 下载与整合包安装（提示"为遵守相关法律法规……qwq"）。
> 本工具通过修改**你电脑上**的启动器文件来恢复这些功能——不包含、也不分发任何 PCL 程序代码或文件。

## 署名

- **补丁作者**：沐序 · [本项目仓库](https://github.com/AldricXZ/PCL-Download-Patch)
- **启动器原作者**：龙腾猫跃 LTCat · [爱发电](https://meloong.com/afd/a/LTCat)
- **PCL 官方发布页**：[meloong.com/pcl](https://meloong.com/pcl)

本仓库为第三方基于 PCL 的独立二次创作产物，与 PCL 官方无关联。

## 恢复的功能

- MC 版本下载：原版 / Forge / Fabric / OptiFine / NeoForge / LiteLoader 等
- 整合包安装：CurseForge / Modrinth（.mrpack）/ MCBBS / HMCL / MMC / 带启动器压缩包
- 版本修改页的 MC 选择卡片

## 使用方法

1. 从 [Releases](../../releases) 下载 `PCL下载补丁.zip` 并解压
2. 从官方渠道获取启动器：
   - 正式版（免费）：[meloong.com/pcl](https://meloong.com/pcl)
   - 快照版（赞助）：使用你自己的爱发电赞助账号下载
3. 把 `Plain Craft Launcher 2.exe` 拖到「拖我上去.bat」上松手
   （或拖到「拖我上去_备份版.bat」，成功后保留补丁前备份）
4. 重新打开启动器，进"下载"页确认版本列表能加载

## 谁需要打补丁

| 启动器 | 是否需要 |
| --- | --- |
| 新版正式版（官方已限制下载的构建） | 需要 |
| 快照版（赞助版） | 需要 |
| 旧版正式版（如 2.13.1.1，2026-07 构建） | 无限制，无需补丁 |

补丁器会自动判断；也支持**自动修复旧版本补丁包留下的已知缺陷**（直接再拖一次即可）。

补丁成功后还会自动安装**更新自动修复守护**（开机自启、后台约 15MB、无窗口）：以后启动器更新，打开时会提示一次，关闭启动器后自动补好，下次打开即恢复——原桌面快捷方式保持不变。

## 注意事项

- 请勿分发打完补丁的启动器本体；要分享就分享本补丁包
- 快照版仅限赞助者自己使用，请勿转发快照版文件
- 正式版自动更新后限制会回来，把更新后的 exe 再拖一次即可
- 补丁失败不会改动原文件；默认不生成备份，需要备份用「备份版」

## 许可

- 补丁脚本：[MIT License](LICENSE) © 沐序
- 内置 [Mono.Cecil](cecil/LICENSE-MIT.txt)：MIT License
- PCL 版权归 龙腾猫跃 所有
