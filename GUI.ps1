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

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:patcher = Join-Path $script:here 'Patcher.ps1'
$script:busy = $false

# ============================ 配色 ============================
$C_Bg       = [Drawing.ColorTranslator]::FromHtml('#f7f8fa')
$C_Card     = [Drawing.Color]::White
$C_Title    = [Drawing.ColorTranslator]::FromHtml('#262b33')
$C_Sub      = [Drawing.ColorTranslator]::FromHtml('#8791a0')
$C_Text     = [Drawing.ColorTranslator]::FromHtml('#3d444d')
$C_Muted    = [Drawing.ColorTranslator]::FromHtml('#9aa3af')
$C_Hint     = [Drawing.ColorTranslator]::FromHtml('#a8b0bb')
$C_Border   = [Drawing.ColorTranslator]::FromHtml('#e3e6ea')
$C_InputBg  = [Drawing.ColorTranslator]::FromHtml('#fbfbfc')
$C_Primary  = [Drawing.ColorTranslator]::FromHtml('#3b82f6')
$C_Link     = [Drawing.ColorTranslator]::FromHtml('#6f9ad4')
$C_Danger   = [Drawing.ColorTranslator]::FromHtml('#b0413a')
$C_DangerBg = [Drawing.ColorTranslator]::FromHtml('#fdf6f5')
$C_Ok       = [Drawing.ColorTranslator]::FromHtml('#16a34a')
$C_Err      = [Drawing.ColorTranslator]::FromHtml('#dc2626')
$C_Gold1    = [Drawing.ColorTranslator]::FromHtml('#b8894c')
$C_Gold2    = [Drawing.ColorTranslator]::FromHtml('#e3c68f')

# ============================ 窗体 ============================
$form = New-Object Windows.Forms.Form
$form.Text = 'PCL 下载补丁'
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Font
$form.ClientSize = New-Object Drawing.Size(900, 640)
$form.MinimumSize = New-Object Drawing.Size(820, 600)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $C_Bg
$form.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9)

$F_Title = New-Object Drawing.Font('Microsoft YaHei UI', 15)
$F_Mono = New-Object Drawing.Font('Consolas', 9)

# ============================ 头部 ============================
$logo = New-Object Windows.Forms.PictureBox
$logo.Location = New-Object Drawing.Point(32, 22)
$logo.Size = New-Object Drawing.Size(52, 52)
$logo.BackColor = [Drawing.Color]::Transparent
$logo.Add_Paint({
    param($src, $e)
    $g = $e.Graphics
    try {
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $pen = [Drawing.Pen]::new($C_Gold2, 2.6)
        $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
        $p = [Drawing.PointF[]]@(
            [Drawing.PointF]::new(6, 16), [Drawing.PointF]::new(26, 16),
            [Drawing.PointF]::new(40, 26), [Drawing.PointF]::new(26, 36),
            [Drawing.PointF]::new(6, 36)
        )
        $g.DrawPolygon($pen, $p)
        $pen.Dispose()
    } catch {
        Write-Verbose ("logo 绘制失败: " + $_.Exception.Message)
    }
})

$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = 'PCL 下载补丁'
$lblTitle.Font = $F_Title
$lblTitle.ForeColor = $C_Title
$lblTitle.AutoSize = $true
$lblTitle.BackColor = [Drawing.Color]::Transparent
$lblTitle.Location = New-Object Drawing.Point(98, 24)

$lblSub = New-Object Windows.Forms.Label
$lblSub.Text = '恢复新版 PCL 被关闭的下载功能'
$lblSub.ForeColor = $C_Sub
$lblSub.AutoSize = $true
$lblSub.BackColor = [Drawing.Color]::Transparent
$lblSub.Location = New-Object Drawing.Point(100, 54)

# ============================ 主卡片 ============================
$card = New-Object Windows.Forms.Panel
$card.Location = New-Object Drawing.Point(32, 92)
$card.Size = New-Object Drawing.Size(836, 268)
$card.BackColor = $C_Bg
$card.Add_Paint({
    param($src, $e)    $g = $e.Graphics
    try {
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $w = [single]$src.Width
        $h = [single]$src.Height
        $r = [single]14

        # 圆角边框
        $path = [Drawing.Drawing2D.GraphicsPath]::new()
        $d = [single]($r * 2)
        $path.AddArc([single]0, [single]0, $d, $d, [single]180, [single]90)
        $path.AddArc([single]($w - $d - 1), [single]0, $d, $d, [single]270, [single]90)
        $path.AddArc([single]($w - $d - 1), [single]($h - $d - 1), $d, $d, [single]0, [single]90)
        $path.AddArc([single]0, [single]($h - $d - 1), $d, $d, [single]90, [single]90)
        $path.CloseFigure()

        $bg = [Drawing.SolidBrush]::new($C_Card)
        $g.FillPath($bg, $path)
        $penB = [Drawing.Pen]::new($C_Border, 1)
        $g.DrawPath($penB, $path)
        $bg.Dispose(); $penB.Dispose()

        # ---- 右下角淡金卷草纹（线 10% / 叶 7.5% / 花 8.5%）----
        # 图案坐标范围约 200x170；缩放 0.60 后约 120x102，贴右下角
        $gs = $g.Save()
        $g.SetClip($path, [Drawing.Drawing2D.CombineMode]::Intersect)
        $scale = [single]0.60
        $g.TranslateTransform([single]($w - 132), [single]($h - 122))
        $g.ScaleTransform($scale, $scale)

        $grad = [Drawing.Drawing2D.LinearGradientBrush]::new(
            [Drawing.Point]::new(0, 200), [Drawing.Point]::new(200, 0),
            $C_Gold1, $C_Gold2)

        $penL = [Drawing.Pen]::new($grad, [single]2.2)
        $penL.StartCap = [Drawing.Drawing2D.LineCap]::Round
        $penL.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $penL.LineJoin = [Drawing.Drawing2D.LineJoin]::Round

        # 逐段三次贝塞尔（GDI+ 的 DrawCurve 是样条插值，与 SVG 的 C 语义不同）
        $g.DrawBezier($penL, [Drawing.PointF]::new(26,168), [Drawing.PointF]::new(8,150), [Drawing.PointF]::new(10,118), [Drawing.PointF]::new(34,106))
        $g.DrawBezier($penL, [Drawing.PointF]::new(34,106), [Drawing.PointF]::new(62,86), [Drawing.PointF]::new(92,72), [Drawing.PointF]::new(110,64))
        $g.DrawBezier($penL, [Drawing.PointF]::new(110,64), [Drawing.PointF]::new(132,50), [Drawing.PointF]::new(156,38), [Drawing.PointF]::new(172,22))
        $g.DrawBezier($penL, [Drawing.PointF]::new(172,22), [Drawing.PointF]::new(182,8), [Drawing.PointF]::new(197,12), [Drawing.PointF]::new(198,25))
        $g.DrawBezier($penL, [Drawing.PointF]::new(198,25), [Drawing.PointF]::new(199,36), [Drawing.PointF]::new(188,42), [Drawing.PointF]::new(181,36))
        $g.DrawBezier($penL, [Drawing.PointF]::new(110,64), [Drawing.PointF]::new(108,82), [Drawing.PointF]::new(112,100), [Drawing.PointF]::new(124,110))
        $g.DrawBezier($penL, [Drawing.PointF]::new(124,110), [Drawing.PointF]::new(136,121), [Drawing.PointF]::new(154,119), [Drawing.PointF]::new(156,108))
        $g.DrawBezier($penL, [Drawing.PointF]::new(92,72), [Drawing.PointF]::new(86,56), [Drawing.PointF]::new(90,40), [Drawing.PointF]::new(102,28))
        $g.DrawBezier($penL, [Drawing.PointF]::new(62,86), [Drawing.PointF]::new(52,70), [Drawing.PointF]::new(50,54), [Drawing.PointF]::new(58,42))
        $penL.Dispose()

        # 叶片（实心）
        $leafBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(19, $C_Gold1))
        $leafSets = @(
            [Drawing.PointF[]]@([Drawing.PointF]::new(102,28), [Drawing.PointF]::new(106,14), [Drawing.PointF]::new(118,6), [Drawing.PointF]::new(128,8), [Drawing.PointF]::new(124,22), [Drawing.PointF]::new(114,30)),
            [Drawing.PointF[]]@([Drawing.PointF]::new(58,42), [Drawing.PointF]::new(52,28), [Drawing.PointF]::new(56,14), [Drawing.PointF]::new(66,10), [Drawing.PointF]::new(70,24), [Drawing.PointF]::new(66,38)),
            [Drawing.PointF[]]@([Drawing.PointF]::new(144,48), [Drawing.PointF]::new(152,34), [Drawing.PointF]::new(166,28), [Drawing.PointF]::new(176,32), [Drawing.PointF]::new(168,46), [Drawing.PointF]::new(156,52)),
            [Drawing.PointF[]]@([Drawing.PointF]::new(80,124), [Drawing.PointF]::new(68,118), [Drawing.PointF]::new(62,106), [Drawing.PointF]::new(66,96), [Drawing.PointF]::new(78,102), [Drawing.PointF]::new(84,114)),
            [Drawing.PointF[]]@([Drawing.PointF]::new(132,114), [Drawing.PointF]::new(142,122), [Drawing.PointF]::new(146,134), [Drawing.PointF]::new(141,143), [Drawing.PointF]::new(130,136), [Drawing.PointF]::new(126,124))
        )
        foreach ($lf in $leafSets) {
            $gp = [Drawing.Drawing2D.GraphicsPath]::new()
            $gp.AddClosedCurve($lf, [single]0.4)
            $g.FillPath($leafBrush, $gp)
            $gp.Dispose()
        }
        $leafBrush.Dispose()

        # 三瓣小花
        $fb = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(22, $C_Gold1))
        foreach ($f in @(@(66, 10, 0.62), @(181, 36, 0.5))) {
            $gs2 = $g.Save()
            $g.TranslateTransform([single]$f[0], [single]$f[1])
            $g.ScaleTransform([single]$f[2], [single]$f[2])
            for ($i = 0; $i -lt 3; $i++) {
                $gs3 = $g.Save()
                $g.RotateTransform([single]($i * 120))
                $g.FillEllipse($fb, [single]-9, [single]-26, [single]18, [single]26)
                $g.Restore($gs3)
            }
            $g.Restore($gs2)
        }
        $fb.Dispose()

        $g.Restore($gs)
        $g.ResetClip()
        $grad.Dispose()
        $path.Dispose()
    } catch {
        Write-Verbose ("卡片绘制失败: " + $_.Exception.Message)
        try { ("[卡片绘制失败] " + $_.Exception.ToString()) | Out-File (Join-Path $env:TEMP 'pcl-gui-paint.log') -Append -Encoding utf8 } catch { Write-Verbose "日志写入失败" }
    }
})

$lblCardTitle = New-Object Windows.Forms.Label
$lblCardTitle.Text = '启动器'
$lblCardTitle.Font = New-Object Drawing.Font('Microsoft YaHei UI', 10)
$lblCardTitle.ForeColor = $C_Title
$lblCardTitle.AutoSize = $true
$lblCardTitle.BackColor = [Drawing.Color]::Transparent
$lblCardTitle.Location = New-Object Drawing.Point(26, 20)

$txtPath = New-Object Windows.Forms.TextBox
$txtPath.Location = New-Object Drawing.Point(26, 48)
$txtPath.Size = New-Object Drawing.Size(660, 26)
$txtPath.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$txtPath.BackColor = $C_InputBg
$txtPath.Font = $script:form.Font
$txtPath.ForeColor = $C_Muted
$txtPath.Text = '把 Plain Craft Launcher 2.exe 拖到这里，或点右侧浏览'
$script:pathPlaceholder = $true

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

$btnBrowse = New-Object Windows.Forms.LinkLabel
$btnBrowse.Text = '浏览…'
$btnBrowse.LinkColor = $C_Link
$btnBrowse.ActiveLinkColor = $C_Primary
$btnBrowse.AutoSize = $true
$btnBrowse.BackColor = [Drawing.Color]::Transparent
$btnBrowse.Location = New-Object Drawing.Point(700, 53)

$lblModeTitle = New-Object Windows.Forms.Label
$lblModeTitle.Text = '更新后如何自动恢复补丁'
$lblModeTitle.ForeColor = [Drawing.ColorTranslator]::FromHtml('#5b6470')
$lblModeTitle.AutoSize = $true
$lblModeTitle.BackColor = [Drawing.Color]::Transparent
$lblModeTitle.Location = New-Object Drawing.Point(26, 90)

$rdoWatch = New-Object Windows.Forms.RadioButton
$rdoWatch.Text = '常驻守护（推荐）   — 开机自启后台，打开启动器时检测、关闭后自动修复'
$rdoWatch.Location = New-Object Drawing.Point(26, 114)
$rdoWatch.Size = New-Object Drawing.Size(620, 22)
$rdoWatch.Checked = $true
$rdoWatch.ForeColor = $C_Text
$rdoWatch.BackColor = [Drawing.Color]::Transparent

$rdoShell = New-Object Windows.Forms.RadioButton
$rdoShell.Text = '启动壳检测   — 无后台；日常用「启动PCL.vbs」打开启动器'
$rdoShell.Location = New-Object Drawing.Point(26, 138)
$rdoShell.Size = New-Object Drawing.Size(620, 22)
$rdoShell.ForeColor = $C_Text
$rdoShell.BackColor = [Drawing.Color]::Transparent

$rdoNone = New-Object Windows.Forms.RadioButton
$rdoNone.Text = '不自动修复   — 更新后把新 exe 再拖一次'
$rdoNone.Location = New-Object Drawing.Point(26, 162)
$rdoNone.Size = New-Object Drawing.Size(620, 22)
$rdoNone.ForeColor = $C_Text
$rdoNone.BackColor = [Drawing.Color]::Transparent

$chkBackup = New-Object Windows.Forms.CheckBox
$chkBackup.Text = '打补丁前复制一份备份到同目录'
$chkBackup.Location = New-Object Drawing.Point(26, 192)
$chkBackup.Size = New-Object Drawing.Size(320, 22)
$chkBackup.ForeColor = [Drawing.ColorTranslator]::FromHtml('#6b7280')
$chkBackup.BackColor = [Drawing.Color]::Transparent

$lblPristine = New-Object Windows.Forms.Label
$lblPristine.Text = '补丁会自动在包内保留原始 exe（约 6MB），用于「卸载补丁」完整还原'
$lblPristine.ForeColor = $C_Hint
$lblPristine.Font = New-Object Drawing.Font('Microsoft YaHei UI', 8)
$lblPristine.AutoSize = $true
$lblPristine.BackColor = [Drawing.Color]::Transparent
$lblPristine.Location = New-Object Drawing.Point(26, 222)

$lnkClean = New-Object Windows.Forms.LinkLabel
$lnkClean.Text = '清理原始备份'
$lnkClean.Font = New-Object Drawing.Font('Microsoft YaHei UI', 8)
$lnkClean.LinkColor = $C_Link
$lnkClean.AutoSize = $true
$lnkClean.BackColor = [Drawing.Color]::Transparent
$lnkClean.Location = New-Object Drawing.Point(470, 222)

$card.Controls.AddRange(@(
    $lblCardTitle, $txtPath, $btnBrowse, $lblModeTitle,
    $rdoWatch, $rdoShell, $rdoNone, $chkBackup, $lblPristine, $lnkClean
))

# ============================ 按钮行 ============================
function New-FlatButton {
    param(
        [string]$Text, [Drawing.Color]$Back, [Drawing.Color]$Fore,
        [Nullable[Drawing.Color]]$BorderColor,
        [int]$X, [int]$Y, [int]$W
    )
    $b = New-Object Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object Drawing.Point($X, $Y)
    $b.Size = New-Object Drawing.Size($W, 38)
    $b.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    if ($null -ne $BorderColor) {
        $b.FlatAppearance.BorderSize = 1
        $b.FlatAppearance.BorderColor = $BorderColor
    } else {
        $b.FlatAppearance.BorderSize = 0
    }
    $b.BackColor = $Back
    $b.ForeColor = $Fore
    $b.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9.5)
    $b.Cursor = [Windows.Forms.Cursors]::Hand
    return $b
}

$btnPatch = New-FlatButton -Text '开始打补丁' -Back $C_Primary -Fore ([Drawing.Color]::White) -BorderColor $null -X 32 -Y 378 -W 132
$btnLaunch = New-FlatButton -Text '启动PCL' -Back $C_Card -Fore $C_Text -BorderColor $C_Border -X 178 -Y 378 -W 116
$btnUninstall = New-FlatButton -Text '卸载补丁' -Back $C_DangerBg -Fore $C_Danger -BorderColor ([Drawing.ColorTranslator]::FromHtml('#f0d9d7')) -X 308 -Y 378 -W 116

$lblStatus = New-Object Windows.Forms.Label
$lblStatus.Text = '就绪'
$lblStatus.ForeColor = $C_Muted
$lblStatus.AutoSize = $true
$lblStatus.BackColor = [Drawing.Color]::Transparent
$lblStatus.Location = New-Object Drawing.Point(820, 390)

# ============================ 输出区 ============================
$txtOut = New-Object Windows.Forms.RichTextBox
$txtOut.Location = New-Object Drawing.Point(32, 430)
$txtOut.Size = New-Object Drawing.Size(836, 180)
$txtOut.ReadOnly = $true
$txtOut.ScrollBars = [Windows.Forms.RichTextBoxScrollBars]::Vertical
$txtOut.BackColor = $C_Card
$txtOut.ForeColor = [Drawing.ColorTranslator]::FromHtml('#6b7280')
$txtOut.Font = $F_Mono
$txtOut.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$txtOut.WordWrap = $false

$form.Controls.AddRange(@($logo, $lblTitle, $lblSub, $card, $btnPatch, $btnLaunch, $btnUninstall, $lblStatus, $txtOut))

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
        Write-Verbose ("拖放处理失败: " + $_.Exception.Message)
    }
}
foreach ($c in @($form, $card, $txtPath)) {
    $c.AllowDrop = $true
    $c.Add_DragEnter($dragEnter)
    $c.Add_DragDrop($dragDrop)
}

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
    if ($null -ne $Color) { $txtOut.SelectionColor = $Color } else { $txtOut.SelectionColor = [Drawing.ColorTranslator]::FromHtml('#6b7280') }
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
        } else {
            Start-Sleep -Milliseconds 50
        }
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
    if ($On) { $form.Cursor = [Windows.Forms.Cursors]::WaitCursor } else { $form.Cursor = [Windows.Forms.Cursors]::Default }
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
        if ($st.KnownExeExists -and $script:pathPlaceholder) {
            $script:pathPlaceholder = $false
            $txtPath.Text = $st.KnownExe
            $txtPath.ForeColor = $C_Text
        }
    } catch {
        Write-Verbose ("状态查询失败: " + $_.Exception.Message)
    }
}

# ============================ 事件 ============================
$btnPatch.Add_Click({
    if ($script:busy) { return }
    $exe = $txtPath.Text.Trim()
    if ($script:pathPlaceholder -or [string]::IsNullOrWhiteSpace($exe) -or -not (Test-Path -LiteralPath $exe)) {
        [Windows.Forms.MessageBox]::Show('请先选择 Plain Craft Launcher 2.exe。', 'PCL 下载补丁',
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
        $exe = $txtPath.Text.Trim()
        if (-not $script:pathPlaceholder -and (Test-Path -LiteralPath $exe)) { Start-Process -FilePath $exe }
    }
})

$form.Add_Shown({
    Update-UiState
    $lblStatus.Location = New-Object Drawing.Point(($form.ClientSize.Width - $lblStatus.Width - 32), 390)
    Add-OutputLine -Text '就绪。选择启动器 exe 后点「开始打补丁」。' -Color $C_Muted
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
