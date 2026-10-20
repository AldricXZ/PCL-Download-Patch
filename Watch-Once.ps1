$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$lock = Join-Path $here '.watch.lock'
if (Test-Path $lock) { exit 0 }   # 已有实例在处理（防止更新重启后并发）
Set-Content $lock $PID -Encoding ascii
try {
    $pathFile = Join-Path $here 'wrapper-path.txt'
    if (-not (Test-Path $pathFile)) { return }
    $exe = (Get-Content $pathFile -TotalCount 1).Trim()
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) { return }
    $launcherName = 'Plain Craft Launcher 2'
    $hashFile = Join-Path $here '.lastpatched.sha256'
    $log = Join-Path $here 'watcher.log'

    function Get-ExeHash { (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash }
    $last = ''
    if (Test-Path $hashFile) { $last = (Get-Content $hashFile -TotalCount 1 -Encoding Unicode).Trim() }
    $cur = Get-ExeHash
    if ($last -ieq $cur) { return }   # 已是修复后的版本

    # 启动器有更新：弹一次提示（每个更新版本只弹一次）
    $flag = Join-Path $here ('.notified_' + $cur.Substring(0, 16) + '.flag')
    if (-not (Test-Path $flag)) {
        Set-Content $flag $cur -Encoding ascii
        $wsh = New-Object -ComObject WScript.Shell
        $null = $wsh.Popup("检测到 PCL 启动器已更新。`n`n关闭启动器后，补丁将自动完成，下次打开即恢复正常，无需任何操作。", 15, "PCL 自动补丁", 64)
    }

    # 等待启动器完全关闭（运行中无法替换文件）
    while (Get-Process -Name $launcherName -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 2
        try { $cur = Get-ExeHash } catch { }
    }

    # 关闭后最终判定并修复
    $cur = Get-ExeHash
    if ($cur -ieq $last) { return }
    $patcher = Join-Path $here 'Patcher.ps1'
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] 检测到启动器更新，自动重打补丁……" | Out-File $log -Append -Encoding utf8
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $patcher -ExePath $exe 2>&1 | Out-File $log -Append -Encoding utf8
    if ($LASTEXITCODE -eq 0) {
        Set-Content $hashFile (Get-ExeHash) -Encoding ascii
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] 补丁完成，下次启动即恢复正常功能。" | Out-File $log -Append -Encoding utf8
    } else {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] 自动补丁失败（新版本结构可能变化，需要更新补丁器）。" | Out-File $log -Append -Encoding utf8
    }
} finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
