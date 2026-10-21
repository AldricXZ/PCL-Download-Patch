#Requires -Version 5.1
# PCL 下载补丁 · WPF 图形界面
# 使用系统自带 .NET Framework 的 WPF 引擎渲染 MainWindow.xaml，
# 视觉与 HTML 预览稿一致（同一套 SVG 路径坐标）。
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'GUI 内部辅助函数')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'GUI 内部辅助函数')]
param()

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# 高 DPI 感知：必须在创建窗口前声明
try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DpiAware {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
'@
    [DpiAware]::SetProcessDPIAware() | Out-Null
} catch {
    Write-Verbose ("DPI 设置失败：" + $_.Exception.Message)
}

$script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:patcher = Join-Path $script:here 'Patcher.ps1'
$script:busy = $false

# ---------- 加载 XAML ----------
$xamlPath = Join-Path $script:here 'MainWindow.xaml'
if (-not (Test-Path -LiteralPath $xamlPath)) {
    [System.Windows.MessageBox]::Show('缺少 MainWindow.xaml，请确认补丁包完整。', 'PCL 下载补丁',
        'OK', 'Error') | Out-Null
    exit 1
}

$reader = New-Object System.IO.StreamReader($xamlPath, [Text.Encoding]::UTF8)
try {
    $xamlText = $reader.ReadToEnd()
} finally {
    $reader.Close()
}

$window = [System.Windows.Markup.XamlReader]::Parse($xamlText)

# ---------- 取控件引用 ----------
function Find-El([string]$name) { $window.FindName($name) }

$txtPath      = Find-El 'TxtPath'
$lnkBrowse    = Find-El 'LnkBrowse'
$lnkClean     = Find-El 'LnkClean'
$lnkRepo      = Find-El 'LnkRepo'
$lblStatus    = Find-El 'LblStatus'
$radioHost    = Find-El 'RadioHost'
$logPanel     = Find-El 'LogPanel'
$logScroll    = Find-El 'LogScroll'
$btnPatch     = Find-El 'BtnPatch'
$btnLaunch    = Find-El 'BtnLaunch'
$btnUninstall = Find-El 'BtnUninstall'
$chkBackup    = Find-El 'ChkBackup'
$chkBox       = Find-El 'ChkBox'
$chkMark      = Find-El 'ChkMark'

$script:placeholder = $true
$script:chkChecked = $false
$script:radios = @()

# ---------- 颜色 ----------
$C_Text        = [Windows.Media.Color]::FromRgb(0x3d, 0x44, 0x4d)
$C_Placeholder = [Windows.Media.Color]::FromRgb(0xb3, 0xba, 0xc4)
$C_Muted       = [Windows.Media.Color]::FromRgb(0x9a, 0xa3, 0xaf)
$C_Ok          = [Windows.Media.Color]::FromRgb(0x16, 0xa3, 0x4a)
$C_Err         = [Windows.Media.Color]::FromRgb(0xdc, 0x26, 0x26)
$C_Log         = [Windows.Media.Color]::FromRgb(0x6b, 0x72, 0x80)
$C_Accent      = [Windows.Media.Color]::FromRgb(0x3b, 0x82, 0xf6)
$C_Gray        = [Windows.Media.Color]::FromRgb(0xcf, 0xd4, 0xda)

function New-Brush($color) {
    $b = New-Object Windows.Media.SolidColorBrush($color)
    $b.Freeze()
    return $b
}

# ---------- 构建单选行 ----------
function New-RadioRow([string]$main, [string]$hint, [bool]$isChecked) {
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Height = 22
    $grid.Background = [Windows.Media.Brushes]::Transparent
    $grid.Cursor = [System.Windows.Input.Cursors]::Hand

    # 列宽：圆环自适应、主文自适应、提示文占满剩余
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c0.Width = [System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($c0)

    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = [System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($c1)

    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    [void]$grid.ColumnDefinitions.Add($c2)

    # 圆环
    $host1 = New-Object System.Windows.Controls.Grid
    $host1.Width = 15
    $host1.Height = 15
    $host1.VerticalAlignment = 'Center'

    $ring = New-Object System.Windows.Shapes.Ellipse
    $ring.Width = 15
    $ring.Height = 15
    $ring.StrokeThickness = 1.6
    $ring.Stroke = New-Brush ([Windows.Media.Color]::FromRgb(0xd3, 0xd7, 0xdd))
    $ring.Fill = [Windows.Media.Brushes]::Transparent

    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 7
    $dot.Height = 7
    $dot.Fill = New-Brush $C_Accent
    $dot.Visibility = 'Collapsed'

    [void]$host1.Children.Add($ring)
    [void]$host1.Children.Add($dot)
    [void]$grid.Children.Add($host1)
    [System.Windows.Controls.Grid]::SetColumn($host1, 0)

    # 主文
    $mainTb = New-Object System.Windows.Controls.TextBlock
    $mainTb.Text = $main
    $mainTb.FontSize = 13.5
    $mainTb.Foreground = New-Brush $C_Text
    $mainTb.Margin = New-Object System.Windows.Thickness(9, 0, 0, 0)
    $mainTb.VerticalAlignment = 'Center'
    [void]$grid.Children.Add($mainTb)
    [System.Windows.Controls.Grid]::SetColumn($mainTb, 1)

    # 提示文
    $hintTb = New-Object System.Windows.Controls.TextBlock
    $hintTb.Text = "— $hint"
    $hintTb.FontSize = 12
    $hintTb.Foreground = New-Brush $C_Muted
    $hintTb.Margin = New-Object System.Windows.Thickness(12, 0, 0, 0)
    $hintTb.VerticalAlignment = 'Center'
    [void]$grid.Children.Add($hintTb)
    [System.Windows.Controls.Grid]::SetColumn($hintTb, 2)

    $state = @{ Ring = $ring; Dot = $dot; Checked = $isChecked }
    $grid | Add-Member -NotePropertyName RadioState -NotePropertyValue $state

    if ($isChecked) {
        $ring.Stroke = New-Brush $C_Accent
        $dot.Visibility = 'Visible'
    }

    return $grid
}

$rdoWatch = New-RadioRow '常驻守护（推荐）' '开机自启后台，打开启动器时检测、关闭后自动修复' $true
$rdoShell = New-RadioRow '启动壳检测' '无后台；日常用「启动PCL.vbs」打开启动器' $false
$rdoNone  = New-RadioRow '不自动修复' '更新后把新 exe 再拖一次' $false

$script:radios = @($rdoWatch, $rdoShell, $rdoNone)

foreach ($r in $script:radios) {
    $r.Margin = New-Object System.Windows.Thickness(0, 0, 0, 9)
    [void]$radioHost.Children.Add($r)

    $r.Add_MouseLeftButtonUp({
        param($sender, $e)
        foreach ($other in $script:radios) {
            $st = $other.RadioState
            $isSelf = [object]::ReferenceEquals($other, $sender)
            $st.Checked = $isSelf
            if ($isSelf) {
                $st.Ring.Stroke = New-Brush $C_Accent
                $st.Dot.Visibility = 'Visible'
            } else {
                $st.Ring.Stroke = New-Brush ([Windows.Media.Color]::FromRgb(0xd3, 0xd7, 0xdd))
                $st.Dot.Visibility = 'Collapsed'
            }
        }
    })
}

# ---------- 事件 ----------
$txtPath.Add_GotFocus({
    if ($script:placeholder) {
        $txtPath.Text = ''
        $txtPath.Foreground = New-Brush $C_Text
        $script:placeholder = $false
    }
})

$txtPath.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($txtPath.Text)) {
        $txtPath.Foreground = New-Brush $C_Placeholder
        $txtPath.Text = '把 Plain Craft Launcher 2.exe 拖到这里，或点右侧浏览'
        $script:placeholder = $true
    }
})

function Set-ExePath([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return }
    $path = $path.Trim('"')
    if (-not (Test-Path -LiteralPath $path)) { return }
    if ([IO.Path]::GetExtension($path) -ne '.exe') { return }
    $script:placeholder = $false
    $txtPath.Text = $path
    $txtPath.Foreground = New-Brush $C_Text
}

$dragOver = {
    param($sender, $e)
    if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $e.Effects = 'Copy'
    }
    $e.Handled = $true
}

$dropHandler = {
    param($sender, $e)
    try {
        $files = $e.Data.GetData([Windows.DataFormats]::FileDrop)
        if ($files -and $files.Count -gt 0) { Set-ExePath $files[0] }
    } catch {
        Write-Verbose ("拖放失败：" + $_.Exception.Message)
    }
}

$txtPath.Add_DragOver($dragOver)
$txtPath.Add_Drop($dropHandler)
$window.Add_DragOver($dragOver)
$window.Add_Drop($dropHandler)

$lnkRepo.Add_MouseLeftButtonUp({
    # 仅允许 https 且限定 github.com 域名，避免被篡改的链接打开任意地址
    $target = 'https://github.com/AldricXZ/PCL-Download-Patch'
    try {
        $uri = [Uri]$target
        if ($uri.Scheme -ne 'https') { return }
        if ($uri.Host -ne 'github.com') { return }
        Start-Process -FilePath $uri.AbsoluteUri
    } catch {
        Write-Verbose ("打开链接失败：" + $_.Exception.Message)
    }
})

$lnkBrowse.Add_MouseLeftButtonUp({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = '启动器 (*.exe)|*.exe'
    $dlg.Title = '选择 Plain Craft Launcher 2.exe'
    if ($dlg.ShowDialog($window) -eq $true) { Set-ExePath $dlg.FileName }
})

$chkBackup.Add_MouseLeftButtonUp({
    $script:chkChecked = -not $script:chkChecked
    if ($script:chkChecked) {
        $chkMark.Visibility = 'Visible'
        $chkBox.BorderBrush = New-Brush $C_Accent
    } else {
        $chkMark.Visibility = 'Collapsed'
        $chkBox.BorderBrush = New-Brush $C_Gray
    }
})

# ---------- 日志 ----------
function Add-Log([string]$text, $color) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $text
    $tb.Foreground = New-Brush $color
    $tb.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
    $tb.FontSize = 12.5
    $tb.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
    $tb.TextWrapping = 'NoWrap'
    [void]$logPanel.Children.Add($tb)
    $logScroll.ScrollToEnd()
    [Windows.Forms.Application]::DoEvents()
}

# ---------- 调用 Patcher（参数数组，不经过 shell 拼接） ----------
function Invoke-Patcher {
    param([string[]]$PatchArgs)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8

    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:patcher) + $PatchArgs
    foreach ($a in $argv) { $psi.ArgumentList.Add($a) }

    $proc = [System.Diagnostics.Process]::Start($psi)
    while (-not $proc.HasExited) {
        $line = $proc.StandardOutput.ReadLine()
        if ($null -ne $line) {
            if ($line -match '成功') { Add-Log $line $C_Ok }
            elseif ($line -match '失败') { Add-Log $line $C_Err }
            else { Add-Log $line $C_Log }
        } else {
            [Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 40
        }
    }
    while ($null -ne ($line = $proc.StandardOutput.ReadLine())) {
        if ($line -match '成功') { Add-Log $line $C_Ok }
        elseif ($line -match '失败') { Add-Log $line $C_Err }
        else { Add-Log $line $C_Log }
    }
    $err = $proc.StandardError.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($err)) { Add-Log $err $C_Err }
    $code = $proc.ExitCode
    $proc.Dispose()
    return $code
}

function Set-Busy([bool]$on) {
    $script:busy = $on
    $btnPatch.IsEnabled = -not $on
    $btnLaunch.IsEnabled = -not $on
    $btnUninstall.IsEnabled = -not $on
    if ($on) { $window.Cursor = 'Wait' } else { $window.Cursor = 'Arrow' }
    [Windows.Forms.Application]::DoEvents()
}

function Test-PathValid {
    if ($script:placeholder) { return $false }
    if ([string]::IsNullOrWhiteSpace($txtPath.Text)) { return $false }
    return (Test-Path -LiteralPath $txtPath.Text)
}

function Update-State {
    try {
        $json = Invoke-Patcher @('-Status')
        # Invoke-Patcher 返回退出码；状态需另行获取
    } catch {
        Write-Verbose ("状态刷新失败：" + $_.Exception.Message)
    }
}

function Get-StatusJson {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:patcher, '-Status')
    foreach ($a in $argv) { $psi.ArgumentList.Add($a) }
    $proc = [System.Diagnostics.Process]::Start($psi)
    $out = $proc.StandardOutput.ReadToEnd()
    $proc.WaitForExit()
    $proc.Dispose()
    return $out
}

function Refresh-UiState {
    try {
        $json = Get-StatusJson
        $st = $json | ConvertFrom-Json
        if ($st.PristineAvailable) {
            $btnUninstall.IsEnabled = $true
            $lnkClean.Visibility = 'Visible'
        } else {
            $btnUninstall.IsEnabled = $false
            $lnkClean.Visibility = 'Collapsed'
        }
    } catch {
        Write-Verbose ("状态解析失败：" + $_.Exception.Message)
    }
}

# ---------- 按钮 ----------
$btnPatch.Add_Click({
    if ($script:busy) { return }
    if (-not (Test-PathValid)) {
        [System.Windows.MessageBox]::Show('请先选择 Plain Craft Launcher 2.exe。', 'PCL 下载补丁',
            'OK', 'Warning') | Out-Null
        return
    }

    $mode = 'watch'
    if ($script:radios[1].RadioState.Checked) { $mode = 'shell' }
    elseif ($script:radios[2].RadioState.Checked) { $mode = 'none' }

    Set-Busy $true
    $logPanel.Children.Clear()
    $lblStatus.Text = '正在打补丁…'
    try {
        $args = @()
        if ($script:chkChecked) { $args += '-Backup' }
        $args += @('-ExePath', $txtPath.Text, '-AutoFix', $mode)

        $code = Invoke-Patcher $args
        if ($code -eq 0) {
            $lblStatus.Text = '补丁完成'
            Add-Log '' $C_Muted
            Add-Log '√ 补丁完成，可以启动启动器了。' $C_Ok
        } else {
            $lblStatus.Text = '补丁失败'
            Add-Log '' $C_Muted
            Add-Log '× 补丁失败，原文件未被改动。' $C_Err
        }
    } finally {
        Set-Busy $false
        Refresh-UiState
    }
})

$btnUninstall.Add_Click({
    if ($script:busy) { return }
    $ans = [System.Windows.MessageBox]::Show(
        "将把启动器还原到打补丁前的状态，并移除开机自启守护。`n`n确定要卸载补丁吗？",
        '卸载补丁', 'YesNo', 'Question')
    if ($ans -ne 'Yes') { return }

    Set-Busy $true
    $logPanel.Children.Clear()
    $lblStatus.Text = '正在卸载…'
    try {
        $args = @()
        if (Test-PathValid) { $args += @('-ExePath', $txtPath.Text) }
        $args += '-Uninstall'

        $code = Invoke-Patcher $args
        if ($code -eq 0) {
            $lblStatus.Text = '已卸载'
            Add-Log '' $C_Muted
            Add-Log '√ 卸载完成，启动器已还原。' $C_Ok
        } elseif ($code -eq 2) {
            $lblStatus.Text = '无法卸载'
            [System.Windows.MessageBox]::Show(
                "未找到原始备份，无法自动卸载。`n`n请从官方渠道重新下载启动器覆盖。",
                '无法卸载', 'OK', 'Warning') | Out-Null
        } else {
            $lblStatus.Text = '卸载失败'
        }
    } finally {
        Set-Busy $false
        Refresh-UiState
    }
})

$lnkClean.Add_MouseLeftButtonUp({
    $ans = [System.Windows.MessageBox]::Show(
        "删除后「卸载补丁」将无法使用，只能从官方重新下载启动器覆盖。`n`n确定要清理原始备份吗？",
        '清理原始备份', 'YesNo', 'Warning')
    if ($ans -ne 'Yes') { return }
    try {
        $dir = Join-Path $script:here '_原始备份'
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        Add-Log '已清理原始备份。' $C_Muted
        Refresh-UiState
    } catch {
        [System.Windows.MessageBox]::Show("清理失败：$($_.Exception.Message)", '清理原始备份',
            'OK', 'Error') | Out-Null
    }
})

$btnLaunch.Add_Click({
    if ($script:busy) { return }
    try {
        $shellPs = Join-Path $script:here 'Watch-Shell.ps1'
        if (Test-Path -LiteralPath $shellPs) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'powershell.exe'
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $shellPs)
            foreach ($a in $argv) { $psi.ArgumentList.Add($a) }
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } elseif (Test-PathValid) {
            Start-Process -FilePath $txtPath.Text
        }
    } catch {
        [System.Windows.MessageBox]::Show("启动失败：$($_.Exception.Message)", 'PCL 下载补丁',
            'OK', 'Error') | Out-Null
    }
})

$window.Add_Loaded({
    Add-Log '就绪。选择启动器 exe 后点「开始打补丁」。' $C_Muted
    Refresh-UiState
})

$window.Add_Closing({
    param($sender, $e)
    if ($script:busy) {
        $ans = [System.Windows.MessageBox]::Show('操作正在进行中，确定要退出吗？', 'PCL 下载补丁',
            'YesNo', 'Question')
        if ($ans -ne 'Yes') { $e.Cancel = $true }
    }
})

# ---------- 显示窗口 ----------
[void]$window.ShowDialog()
