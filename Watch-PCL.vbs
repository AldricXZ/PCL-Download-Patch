Option Explicit
Dim fso, sh, wmi, exe, launcherExe, here
Const LauncherName = "Plain Craft Launcher 2.exe"
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("Wscript.Shell")
here = fso.GetParentFolderName(WScript.ScriptFullName)

exe = ""
If fso.FileExists(here & "\wrapper-path.txt") Then
    exe = Trim(fso.OpenTextFile(here & "\wrapper-path.txt", 1, False, -1).ReadLine)
End If
If exe = "" Or Not fso.FileExists(exe) Then WScript.Quit
launcherExe = fso.GetFileName(exe)

Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
Do While True
    Dim procs
    Set procs = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & launcherExe & "'")
    If procs.Count > 0 Then
        sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & here & "\Watch-Once.ps1""", 0, False
        Do While True
            WScript.Sleep 3000
            Set procs = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & launcherExe & "'")
            If procs.Count = 0 Then Exit Do
        Loop
        WScript.Sleep 2000
    End If
    WScript.Sleep 5000
Loop
