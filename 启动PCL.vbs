Option Explicit
Dim sh, here, ps
Set sh = CreateObject("Wscript.Shell")
here = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\") - 1)
ps = here & "\Watch-Shell.ps1"
sh.CurrentDirectory = here
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps & """", 0, False
