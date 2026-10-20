$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$pathFile = Join-Path $here 'wrapper-path.txt'
if (-not (Test-Path $pathFile)) {
    Write-Output "未找到 wrapper-path.txt：请先打一次补丁。"
    [void][System.Console]::ReadKey($true)
    exit 1
}
$exe = (Get-Content $pathFile -TotalCount 1 -Encoding Unicode).Trim()
if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
    Write-Output "找不到启动器：$exe"
    [void][System.Console]::ReadKey($true)
    exit 1
}

function Get-ExeHash { (Get-FileHash -Algorithm SHA256 -LiteralPath $exe).Hash }
$hashFile = Join-Path $here '.lastpatched.sha256'
$last = ''
if (Test-Path $hashFile) { $last = (Get-Content $hashFile -TotalCount 1 -Encoding ascii).Trim() }
$cur = Get-ExeHash

if ($last -and $cur -ine $last) {
    # 启动器有更新：提示并自动重打补丁
    Write-Output ""
    Write-Output "检测到启动器已更新，正在自动重打补丁……"
    $patcher = Join-Path $here 'Patcher.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $patcher -ExePath $exe -AutoFix shell
    if ($LASTEXITCODE -ne 0) {
        Write-Output "自动补丁失败（新版本结构可能变化，需要更新补丁器）。仍将启动原版启动器。"
        [void][System.Console]::ReadKey($true)
    }
    Set-Content $hashFile (Get-ExeHash) -Encoding ascii
} elseif (-not $last) {
    # 首次：无基线，记录当前哈希即可
    Set-Content $hashFile $cur -Encoding ascii
}

Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)
