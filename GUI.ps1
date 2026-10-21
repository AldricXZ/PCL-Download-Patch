#Requires -Version 5.1
# GUI 入口脚本：内部辅助函数为 WinForms 事件处理器服务，命名遵循界面语义
# （非 cmdlet 导出函数），故对下列规则做脚本级豁免。
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'GUI 内部辅助函数，不对外导出')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'GUI 内部辅助函数，无副作用可确认')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'WinForms 事件处理器签名固定为 sender/args')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '', Justification = '内部 UI 布局辅助函数的紧凑调用')]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:patcher = Join-Path $script:here 'Patcher.ps1'
$script:busy = $false

# 编译自定义圆角控件（每次启动重新编译，避免缓存旧版本）
$csFile = Join-Path $script:here 'PclPatchUi.cs'
if (-not (Test-Path -LiteralPath $csFile)) {
    [Windows.Forms.MessageBox]::Show("缺少 PclPatchUi.cs，请确认补丁包完整。", 'PCL 下载补丁',
        [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}
$csCode = Get-Content -LiteralPath $csFile -Raw -Encoding UTF8
if (-not ('PclPatchUi.RoundPanel' -as [type])) {
    Add-Type -TypeDefinition $csCode -ReferencedAssemblies System.Drawing, System.Windows.Forms
}

[Windows.Forms.Application]::EnableVisualStyles()
[Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ============================ 配色 ============================
$C_Bg       = [Drawing.ColorTranslator]::FromHtml('#f7f8fa')
$C_Card     = [Drawing.Color]::White
$C_Title    = [Drawing.ColorTranslator]::FromHtml('#262b33')
$C_Sub      = [Drawing.ColorTranslator]::FromHtml('#8791a0')
$C_Text     = [Drawing.ColorTranslator]::FromHtml('#3d444d')
$C_Muted    = [Drawing.ColorTranslator]::FromHtml('#9aa3af')
$C_Hint     = [Drawing.ColorTranslator]::FromHtml('#a8b0bb')
$C_Border   = [Drawing.ColorTranslator]::FromHtml('#e3e6ea')
$C_Primary  = [Drawing.ColorTranslator]::FromHtml('#3b82f6')
$C_Link     = [Drawing.ColorTranslator]::FromHtml('#6f9ad4')
$C_Danger   = [Drawing.ColorTranslator]::FromHtml('#b0413a')
$C_DangerBg = [Drawing.ColorTranslator]::FromHtml('#fdf6f5')
$C_Ok       = [Drawing.ColorTranslator]::FromHtml('#16a34a')
$C_Err      = [Drawing.ColorTranslator]::FromHtml('#dc2626')
$C_Gold2    = [Drawing.ColorTranslator]::FromHtml('#e3c68f')

$F_Base  = New-Object Drawing.Font('Microsoft YaHei UI', 9)
$F_Title = New-Object Drawing.Font('Microsoft YaHei UI', 15)
$F_Mono  = New-Object Drawing.Font('Consolas', 9)
$F_Small = New-Object Drawing.Font('Microsoft YaHei UI', 8)

# ============================ 窗体 ============================
$form = New-Object Windows.Forms.Form
$form.Text = 'PCL 下载补丁'
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
$form.ClientSize = New-Object Drawing.Size(900, 640)
$form.MinimumSize = New-Object Drawing.Size(760, 560)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $C_Bg
$form.Font = $F_Base

# ============================ 头部 ============================
$logo = New-Object Windows.Forms.PictureBox
$logo.Location = New-Object Drawing.Point(32, 20)
$logo.Size = New-Object Drawing.Size(52, 52)
$logo.BackColor = [Drawing.Color]::Transparent
$logo.Add_Paint({
    param($src, $e)
    $g = $e.Graphics
    try {
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $pen = [Drawing.Pen]::new($C_Gold2, 2.6)
        $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
        $g.DrawPolygon($pen, [Drawing.PointF[]]@(
            [Drawing.PointF]::new(6, 16), [Drawing.PointF]::new(26, 16),
            [Drawing.PointF]::new(40, 26), [Drawing.PointF]::new(26, 36),
            [Drawing.PointF]::new(6, 36)))
        $pen.Dispose()
    } catch {
        Write-Verbose ("logo 绘制失败：" + $_.Exception.Message)
    }
})

$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = 'PCL 下载补丁'
$lblTitle.Font = $F_Title
$lblTitle.ForeColor = $C_Title
$lblTitle.AutoSize = $true
$lblTitle.BackColor = [Drawing.Color]::Transparent
$lblTitle.Location = New-Object Drawing.Point(100, 22)

$lblSub = New-Object Windows.Forms.Label
$lblSub.Text = '恢复新版 PCL 被关闭的下载功能'
$lblSub.ForeColor = $C_Sub
$lblSub.AutoSize = $true
$lblSub.BackColor = [Drawing.Color]::Transparent
$lblSub.Location = New-Object Drawing.Point(102, 52)

# ============================ 主卡片 ============================
$card = New-Object PclPatchUi.RoundPanel
$card.Location = New-Object Drawing.Point(32, 92)
$card.Size = New-Object Drawing.Size(836, 272)
$card.Anchor = 'Top,Left,Right'
$card.CornerRadius = 14
$card.FillColor = $C_Card
$card.BorderColor = $C_Border
$card.DrawFiligree = $true

$lblCardTitle = New-Object Windows.Forms.Label
$lblCardTitle.Text = '启动器'
$lblCardTitle.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10)
$lblCardTitle.ForeColor = $C_Title
$lblCardTitle.AutoSize = $true
$lblCardTitle.BackColor = [Drawing.Color]::Transparent
$lblCardTitle.Location = New-Object Drawing.Point(26, 20)

$pathBox = New-Object PclPatchUi.RoundTextBox
$pathBox.Location = New-Object Drawing.Point(26, 46)
$pathBox.Size = New-Object Drawing.Size(660, 40)
$pathBox.CornerRadius = 8
$pathBox.Anchor = 'Top,Left,Right'

$txtPath = $pathBox.Inner
$txtPath.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9.5)
$txtPath.ForeColor = $C_Muted
$script:pathPlaceholder = $true
$txtPath.Text = '把 Plain Craft Launcher 2.exe 拖到这里，或点右侧浏览'

$btnBrowse = New-Object Windows.Forms.LinkLabel
$btnBrowse.Text = '浏览…'
$btnBrowse.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9.5)
$btnBrowse.LinkColor = $C_Link
$btnBrowse.ActiveLinkColor = $C_Primary
$btnBrowse.AutoSize = $true
$btnBrowse.BackColor = [Drawing.Color]::Transparent

$lblMode = New-Object Windows.Forms.Label
$lblMode.Text = '更新后如何自动恢复补丁'
$lblMode.ForeColor = [Drawing.ColorTranslator]::FromHtml('#5b6470')
$lblMode.AutoSize = $true
$lblMode.BackColor = [Drawing.Color]::Transparent
$lblMode.Location = New-Object Drawing.Point(26, 102)

$rdoWatch = New-Object Windows.Forms.RadioButton
$rdoWatch.Text = '常驻守护（推荐）   — 开机自启后台，打开启动器时检测、关闭后自动修复'
$rdoWatch.Location = New-Object Drawing.Point(26, 126)
$rdoWatch.Size = New-Object Drawing.Size(640, 22)
$rdoWatch.Checked = $true
$rdoWatch.ForeColor = $C_Text
$rdoWatch.BackColor = [Drawing.Color]::Transparent
$rdoWatch.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9.5)

$rdoShell = New-Object Windows.Forms.RadioButton
$rdoShell.Text = '启动壳检测   — 无后台；日常用「启动PCL.vbs」打开启动器'
$rdoShell.Location = New-Object Drawing.Point(26, 151)
$rdoShell.Size = New-Object Drawing.Size(640, 22)
$rdoShell.ForeColor = $C_Text
$rdoShell.BackColor = [Drawing.Color]::Transparent
$rdoShell.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9.5)

$rdoNone = New-Object Windows.Forms.RadioButton
$rdoNone.Text = '不自动修复   — 更新后把新 exe 再拖一次'
$rdoNone.Location = New-Object Drawing.Point(26, 176)
$rdoNone.Size = New-Object Drawing.Size(640, 22)
$rdoNone.ForeColor = $C_Text
$rdoNone.BackColor = [Drawing.Color]::Transparent
$rdoNone.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9.5)

$chkBackup = New-Object Windows.Forms.CheckBox
$chkBackup.Text = '打补丁前复制一份备份到同目录'
$chkBackup.Location = New-Object Drawing.Point(26, 204)
$chkBackup.Size = New-Object Drawing.Size(320, 22)
$chkBackup.ForeColor = [Drawing.ColorTranslator]::FromHtml('#6b7280')
$chkBackup.BackColor = [Drawing.Color]::Transparent
$chkBackup.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9)

$lblPristine = New-Object Windows.Forms.Label
$lblPristine.Text = '补丁会自动在包内保留原始 exe（约 6MB），用于「卸载补丁」完整还原 · '
$lblPristine.ForeColor = $C_Hint
$lblPristine.Font = $F_Small
$lblPristine.AutoSize = $true
$lblPristine.BackColor = [Drawing.Color]::Transparent
$lblPristine.Location = New-Object Drawing.Point(26, 232)

$lnkClean = New-Object Windows.Forms.LinkLabel
$lnkClean.Text = '清理原始备份'
$lnkClean.Font = $F_Small
$lnkClean.LinkColor = $C_Link
$lnkClean.AutoSize = $true
$lnkClean.BackColor = [Drawing.Color]::Transparent

$card.Controls.AddRange(@($lblCardTitle, $pathBox, $btnBrowse, $lblMode, $rdoWatch, $rdoShell, $rdoNone, $chkBackup, $lblPristine, $lnkClean))

# ============================ 按钮行 ============================
function New-RoundButton {
    param(
        [string]$Label,
        [Drawing.Color]$Back,
        [Drawing.Color]$Fore,
        [Drawing.Color]$Border,
        [int]$X, [int]$Y, [int]$W
    )
    $b = New-Object PclPatchUi.RoundButton
    $b.Text = $Label
    $b.Location = New-Object Drawing.Point($X, $Y)
    $b.Size = New-Object Drawing.Size($W, 38)
    $b.CornerRadius = 8
    $b.BackColor = $Back
    $b.ForeColor = $Fore
    $b.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9.5)
    $b.Cursor = [Windows.Forms.Cursors]::Hand
    if ($Border.A -gt 0) {
        $b.FlatAppearance.BorderSize = 1
        $b.FlatAppearance.BorderColor = $Border
    }
    return $b
}

$btnPatch = New-RoundButton -Label '开始打补丁' -Back $C_Primary -Fore ([Drawing.Color]::White) -Border ([Drawing.Color]::Transparent) -X 32 -Y 382 -W 132
$btnLaunch = New-RoundButton -Label '启动PCL' -Back $C_Card -Fore $C_Text -Border $C_Border -X 176 -Y 382 -W 116
$btnUninstall = New-RoundButton -Label '卸载补丁' -Back $C_DangerBg -Fore $C_Danger -Border ([Drawing.ColorTranslator]::FromHtml('#f0d9d7')) -X 304 -Y 382 -W 116
$btnUninstall.Anchor = 'Top,Left'

$lblStatus = New-Object Windows.Forms.Label
$lblStatus.Text = '就绪'
$lblStatus.ForeColor = $C_Muted
$lblStatus.AutoSize = $true
$lblStatus.BackColor = [Drawing.Color]::Transparent
$lblStatus.Anchor = 'Top,Right'

# ============================ 输出区 ============================
$outBox = New-Object PclPatchUi.RoundRichText
$outBox.Location = New-Object Drawing.Point(32, 434)
$outBox.Size = New-Object Drawing.Size(836, 176)
$outBox.Anchor = 'Top,Bottom,Left,Right'
$outBox.CornerRadius = 10

$txtOut = $outBox.Inner
$txtOut.Font = $F_Mono
$txtOut.ForeColor = [Drawing.ColorTranslator]::FromHtml('#6b7280')

$form.Controls.AddRange(@($logo, $lblTitle, $lblSub, $card, $btnPatch, $btnLaunch, $btnUninstall, $lblStatus, $outBox))

# ============================ 拖放与浏览 ============================
function Set-ExePath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $Path = $Path.Trim('"')
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ([IO.Path]::GetExtension($Path) -ne '.exe') { return }
    $script:pathPlaceholder = $false
    $txtPath.Text = $Path
    $txtPath.ForeColor = $C_Text
}

$dragEnter = { param($src, $e) if ($e.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = [Windows.Forms.DragDropEffects]::Copy } }
$dragDrop = {
    param($src, $e)
    try {
        $files = $e.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
        if ($files -and $files.Count -gt 0) { Set-ExePath -Path $files[0] }
    } catch {
        Write-Verbose ("拖放处理失败：" + $_.Exception.Message)
    }
}
foreach ($c in @($form, $card, $pathBox, $txtPath)) {
    $c.AllowDrop = $true
    $c.Add_DragEnter($dragEnter)
    $c.Add_DragDrop($dragDrop)
}

$txtPath.Add_Enter({
    if ($script:pathPlaceholder) {
        $txtPath.Text = ''
        $txtPath.ForeColor = $C_Text
        $script:pathPlaceholder = $false
    }
})
$txtPath.Add_Leave({
    if ([string]::IsNullOrWhiteSpace($txtPath.Text)) {
        $txtPath.ForeColor = $C_Muted
        $txtPath.Text = '把 Plain Craft Launcher 2.exe 拖到这里，或点右侧浏览'
        $script:pathPlaceholder = $true
    }
})

$btnBrowse.Add_LinkClicked({
    $dlg = New-Object Windows.Forms.OpenFileDialog
    $dlg.Filter = '启动器 (*.exe)|*.exe'
    $dlg.Title = '选择 Plain Craft Launcher 2.exe'
    if ($dlg.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) { Set-ExePath -Path $dlg.FileName }
})

# ============================ 输出辅助 ============================
function Add-OutputLine {
    param([string]$Text, [Nullable[Drawing.Color]]$Color)
    $txtOut.SelectionStart = $txtOut.TextLength
    $txtOut.SelectionLength = 0
    if ($null -ne $Color) { $txtOut.SelectionColor = $Color }
    else { $txtOut.SelectionColor = [Drawing.ColorTranslator]::FromHtml('#6b7280') }
    $txtOut.AppendText($Text + "`r`n")
    $txtOut.SelectionStart = $txtOut.TextLength
    $txtOut.ScrollToCaret()
    [Windows.Forms.Application]::DoEvents()
}

function Invoke-PatcherProcess {
    param([string]$ExtraArgs)
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:patcher + '" ' + $ExtraArgs
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $p = [Diagnostics.Process]::Start($psi)
    while (-not $p.HasExited) {
        $line = $p.StandardOutput.ReadLine()
        if ($null -ne $line) {
            if ($line -match '成功') { Add-OutputLine -Text $line -Color $C_Ok }
            elseif ($line -match '失败') { Add-OutputLine -Text $line -Color $C_Err }
            else { Add-OutputLine -Text $line -Color $null }
        } else { Start-Sleep -Milliseconds 50 }
    }
    while ($null -ne ($line = $p.StandardOutput.ReadLine())) {
        if ($line -match '成功') { Add-OutputLine -Text $line -Color $C_Ok }
        elseif ($line -match '失败') { Add-OutputLine -Text $line -Color $C_Err }
        else { Add-OutputLine -Text $line -Color $null }
    }
    $err = $p.StandardError.ReadToEnd()
    if ($err) { Add-OutputLine -Text $err -Color $C_Err }
    $p.Dispose()
    return $p.ExitCode
}

function Set-BusyState {
    param([bool]$On)
    $script:busy = $On
    foreach ($b in @($btnPatch, $btnLaunch, $btnUninstall)) { $b.Enabled = -not $On }
    $form.Cursor = if ($On) { [Windows.Forms.Cursors]::WaitCursor } else { [Windows.Forms.Cursors]::Default }
    [Windows.Forms.Application]::DoEvents()
}

function Update-UiState {
    try {
        $json = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:patcher -Status 2>$null
        $st = $json | ConvertFrom-Json
        if ($st.PristineAvailable) {
            $btnUninstall.Enabled = $true
            $btnUninstall.ForeColor = $C_Danger
            $btnUninstall.BackColor = $C_DangerBg
            $lnkClean.Visible = $true
        } else {
            $btnUninstall.Enabled = $false
            $btnUninstall.ForeColor = $C_Muted
            $btnUninstall.BackColor = $C_Card
            $lnkClean.Visible = $false
        }
    } catch {
        Write-Verbose ("状态查询失败：" + $_.Exception.Message)
    }
}

# ============================ 事件 ============================
$btnPatch.Add_Click({
    if ($script:busy) { return }
    if ($script:pathPlaceholder) {
        [Windows.Forms.MessageBox]::Show('请先选择 Plain Craft Launcher 2.exe。', 'PCL 下载补丁',
            [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }
    $exe = $txtPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($exe) -or -not (Test-Path -LiteralPath $exe)) {
        [Windows.Forms.MessageBox]::Show('找不到该文件，请重新选择启动器 exe。', 'PCL 下载补丁',
            [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }
    $af = if ($rdoShell.Checked) { 'shell' } elseif ($rdoNone.Checked) { 'none' } else { 'watch' }
    Set-BusyState -On $true
    $txtOut.Clear()
    $lblStatus.Text = '正在打补丁…'
    try {
        $patchArgs = '-ExePath "' + $exe + '" -AutoFix ' + $af
        if ($chkBackup.Checked) { $patchArgs = '-Backup ' + $patchArgs }
        $code = Invoke-PatcherProcess -ExtraArgs $patchArgs
        if ($code -eq 0) {
            $lblStatus.Text = '补丁完成'
            Add-OutputLine -Text '' -Color $null
            Add-OutputLine -Text '√ 补丁完成，可以启动启动器了。' -Color $C_Ok
        } else {
            $lblStatus.Text = '补丁失败'
            Add-OutputLine -Text '' -Color $null
            Add-OutputLine -Text '× 补丁失败，原文件未被改动。' -Color $C_Err
        }
    } finally {
        Set-BusyState -On $false
        Update-UiState
    }
})

$btnUninstall.Add_Click({
    if ($script:busy) { return }
    $ans = [Windows.Forms.MessageBox]::Show(
        "将把启动器还原到打补丁前的状态，并移除开机自启守护。`r`n`r`n确定要卸载补丁吗？",
        '卸载补丁', [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
    if ($ans -ne [Windows.Forms.DialogResult]::Yes) { return }
    Set-BusyState -On $true
    $txtOut.Clear()
    $lblStatus.Text = '正在卸载…'
    try {
        $exe = if ($script:pathPlaceholder) { '' } else { $txtPath.Text.Trim() }
        $unArgs = '-Uninstall'
        if (-not [string]::IsNullOrWhiteSpace($exe)) { $unArgs = '-ExePath "' + $exe + '" ' + $unArgs }
        $code = Invoke-PatcherProcess -ExtraArgs $unArgs
        if ($code -eq 0) {
            $lblStatus.Text = '已卸载'
            Add-OutputLine -Text '' -Color $null
            Add-OutputLine -Text '√ 卸载完成，启动器已还原。' -Color $C_Ok
        } elseif ($code -eq 2) {
            $lblStatus.Text = '无法卸载'
            [Windows.Forms.MessageBox]::Show(
                "未找到原始备份，无法自动卸载。`r`n`r`n请从官方渠道重新下载启动器覆盖。",
                '无法卸载', [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        } else {
            $lblStatus.Text = '卸载失败'
        }
    } finally {
        Set-BusyState -On $false
        Update-UiState
    }
})

$lnkClean.Add_LinkClicked({
    $ans = [Windows.Forms.MessageBox]::Show(
        "删除后「卸载补丁」将无法使用，只能从官方重新下载启动器覆盖。`r`n`r`n确定要清理原始备份吗？",
        '清理原始备份', [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
    if ($ans -ne [Windows.Forms.DialogResult]::Yes) { return }
    $dir = Join-Path $script:here '_原始备份'
    try {
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        Add-OutputLine -Text '已清理原始备份。' -Color $C_Muted
        Update-UiState
    } catch {
        [Windows.Forms.MessageBox]::Show("清理失败：$($_.Exception.Message)", '清理原始备份',
            [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
})

$btnLaunch.Add_Click({
    if ($script:busy) { return }
    $shellPs = Join-Path $script:here 'Watch-Shell.ps1'
    if (Test-Path -LiteralPath $shellPs) {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $shellPs + '"'
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        [Diagnostics.Process]::Start($psi) | Out-Null
    } else {
        if (-not $script:pathPlaceholder) {
            $exe = $txtPath.Text.Trim()
            if (Test-Path -LiteralPath $exe) { Start-Process -FilePath $exe }
        }
    }
})

function Update-Layout {
    $pad = 32
    $innerW = $form.ClientSize.Width - $pad * 2

    $card.Width = $innerW
    $pathBox.Width = $innerW - 26 - 90
    $btnBrowse.Location = New-Object Drawing.Point(($pathBox.Right + 12), 58)
    $lnkClean.Location = New-Object Drawing.Point(($lblPristine.Right), 232)

    $outBox.Width = $innerW
    $outBox.Top = 434
    $outBox.Height = [Math]::Max(120, $form.ClientSize.Height - 434 - $pad)

    $lblStatus.Location = New-Object Drawing.Point(($innerW + $pad - $lblStatus.Width), 392)
}

$form.Add_Shown({
    Update-Layout
    Update-UiState
    Add-OutputLine -Text '就绪。选择启动器 exe 后点「开始打补丁」。' -Color $C_Muted
})

$form.Add_Resize({
    try { Update-Layout } catch { Write-Verbose ("布局更新失败：" + $_.Exception.Message) }
})

$form.Add_FormClosing({
    param($src, $e)
    if ($script:busy) {
        $ans = [Windows.Forms.MessageBox]::Show('操作正在进行中，确定要退出吗？', 'PCL 下载补丁',
            [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
        if ($ans -ne [Windows.Forms.DialogResult]::Yes) { $e.Cancel = $true }
    }
})

[void]$form.ShowDialog()
$form.Dispose()
