$ErrorActionPreference = 'Stop'

$pkg = 'C:\Users\xmz09\.zcode\workspace\default\pcl-patch\package'
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'

# 从 GAC 取 WPF 程序集路径
$gacRefs = @('PresentationFramework', 'PresentationCore', 'WindowsBase', 'System.Xaml') | ForEach-Object {
    $a = [System.Reflection.Assembly]::LoadWithPartialName($_)
    $a.Location
}

$outExe = Join-Path $pkg 'PCL补丁界面.exe'

$args = @()
$args += '/nologo'
$args += '/target:winexe'
$args += '/platform:anycpu'
$args += '/out:"' + $outExe + '"'
$args += '/optimize+'
foreach ($r in $gacRefs) { $args += '/r:"' + $r + '"' }
$args += '/r:System.dll'
$args += '/r:System.Core.dll'
$args += '/r:System.Xml.dll'
$args += '"' + (Join-Path $pkg 'PclPatchGui.cs') + '"'

$cmd = '& "' + $csc + '" ' + ($args -join ' ')
Invoke-Expression $cmd

if (Test-Path $outExe) {
    Write-Output ("built: " + $outExe + " (" + (Get-Item $outExe).Length + " bytes)")
} else {
    Write-Output "BUILD FAILED"
    exit 1
}
