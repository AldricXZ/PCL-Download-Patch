using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

namespace PclWatchDaemon
{
    /// <summary>
    /// 常驻守护 agent（替代 Watch-PCL.vbs）：监视启动器进程，
    /// 出现即隐藏调起 Watch-Once.ps1 做检测/修复；启动器关闭后回到轮询循环。
    /// </summary>
    internal static class Daemon
    {
        static void Main()
        {
            string here = AppDomain.CurrentDomain.SetupInformation.ApplicationBase
                          ?? AppContext.BaseDirectory;
            if (here != null) here = here.TrimEnd('\\');

            string pathFile = Path.Combine(here, "wrapper-path.txt");
            string exe = "";
            try {
                if (File.Exists(pathFile)) {
                    using (var sr = new StreamReader(pathFile, System.Text.Encoding.Unicode)) {
                        exe = (sr.ReadLine() ?? "").Trim();
                    }
                }
            } catch { return; }
            if (exe.Length == 0 || !File.Exists(exe)) return;

            string oncePkg = Path.Combine(here, "Watch-Once.ps1");
            if (!File.Exists(oncePkg)) return;

            string procName = Path.GetFileNameWithoutExtension(exe);
            while (true) {
                if (CountProcs(procName) > 0) {
                    RunHidden(oncePkg);
                    while (CountProcs(procName) > 0) Thread.Sleep(3000);
                    Thread.Sleep(2000);
                }
                Thread.Sleep(5000);
            }
        }

        static int CountProcs(string name) {
            try { return Process.GetProcessesByName(name).Length; }
            catch { return 0; }
        }

        // 与补丁包其余入口一致：经 WScript.Shell COM 隐藏启动，命令行只含固定脚本路径
        static void RunHidden(string script) {
            try {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) return;
                dynamic shell = Activator.CreateInstance(shellType);
                shell.Run("powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" +
                          script + "\"", 0, false);
            } catch { }
        }
    }
}
