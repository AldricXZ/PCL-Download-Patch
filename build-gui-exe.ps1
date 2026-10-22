$ErrorActionPreference = 'Stop'

$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$root = $PSScriptRoot
$outExe = Join-Path $root 'PCL补丁界面.exe'

# 从 GAC 取 WPF 程序集路径
$gacRefs = @('PresentationFramework', 'PresentationCore', 'WindowsBase', 'System.Xaml') | ForEach-Object {
    [System.Reflection.Assembly]::LoadWithPartialName($_).Location
}

# 内嵌引擎资源：名字必须与 PclPatchGui.cs 释放引擎时的 pcl.engine.* 约定一致
$embedded = [ordered]@{
    'pcl.engine.Patcher.ps1'                         = 'Patcher.ps1'
    'pcl.engine.Watch-Once.ps1'                      = 'Watch-Once.ps1'
    'pcl.engine.Watch-Shell.ps1'                     = 'Watch-Shell.ps1'
    'pcl.engine.Watch-PCL.exe'                       = 'Watch-PCL.exe'
    'pcl.engine.cecil.net40.Mono.Cecil.dll'          = 'cecil/net40/Mono.Cecil.dll'
    'pcl.engine.cecil.netstandard2.0.Mono.Cecil.dll' = 'cecil/netstandard2.0/Mono.Cecil.dll'
}

$args = @()
$args += '/nologo'
$args += '/target:winexe'
$args += '/platform:anycpu'
$args += '/out:"' + $outExe + '"'
$args += '/optimize+'
$args += '/win32icon:"' + (Join-Path $root 'app.ico') + '"'
foreach ($r in $gacRefs) { $args += '/r:"' + $r + '"' }
$args += '/r:System.dll'
$args += '/r:System.Core.dll'
$args += '/r:System.Xml.dll'
$args += '/r:System.Drawing.dll'
foreach ($k in $embedded.Keys) { $args += '/resource:"' + (Join-Path $root $embedded[$k]) + ',' + $k + '"' }
$args += '"' + (Join-Path $root 'PclPatchGui.cs') + '"'

$cmd = '& "' + $csc + '" ' + ($args -join ' ')
Invoke-Expression $cmd

if (Test-Path $outExe) {
    Write-Output ("built: " + $outExe + " (" + (Get-Item $outExe).Length + " bytes)")
} else {
    Write-Output "BUILD FAILED"
    exit 1
}
