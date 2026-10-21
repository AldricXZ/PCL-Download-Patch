using System;
using System.Windows;

namespace PclPatchLauncher
{
    /// <summary>薄启动器：只负责以无控制台方式调起补丁界面的 PowerShell 脚本。</summary>
    public class Launcher
    {
        [STAThread]
        public static void Main()
        {
            string baseDir = AppDomain.CurrentDomain.SetupInformation.ApplicationBase
                             ?? AppContext.BaseDirectory;
            if (baseDir != null) baseDir = baseDir.TrimEnd('\\');

            string script = System.IO.Path.Combine(baseDir, "GuiWpf.ps1");
            if (!System.IO.File.Exists(script))
            {
                System.Windows.MessageBox.Show(
                    "未找到 GuiWpf.ps1，请确认补丁包完整。",
                    "PCL 下载补丁", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            // 通过 WScript.Shell COM 启动（与 打开补丁界面.vbs 相同方式）
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null)
            {
                System.Windows.MessageBox.Show(
                    "系统缺少 WScript.Shell 组件。", "PCL 下载补丁",
                    MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            dynamic shell = Activator.CreateInstance(shellType);
            string cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File \"" + script + "\"";
            shell.CurrentDirectory = baseDir;
            shell.Run(cmd, 1, false);
        }
    }
}
