param(
    [string]$ExePath = '',
    [switch]$Backup,
    [string]$PatchSet = 'ABCD'
)
$ErrorActionPreference = 'Stop'
$script:here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Log($msg) { Write-Output $msg }
function Fail($msg) { Write-Output "[失败] $msg"; exit 1 }

if ([string]::IsNullOrEmpty($ExePath)) {
    Write-Log "==== PCL 下载功能补丁 ===="
    Write-Log "补丁作者：沐序  https://github.com/AldricXZ/PCL-Download-Patch"
    Write-Log ""
    Write-Log "用法：把启动器的 Plain Craft Launcher 2.exe 拖到「拖我上去.bat」图标上松手即可。"
    Write-Log "      想保留一份补丁前的备份文件，改用「拖我上去_备份版.bat」（建议）。"
    Write-Log ""
    Write-Log "谁需要打补丁（补丁器也会自动判断）："
    Write-Log "  - 快照版（赞助版）：需要。请先用你自己的赞助账号从爱发电下载快照版。"
    Write-Log "  - 新版正式版（官方已限制下载的构建）：需要。从官方渠道获取。"
    Write-Log "  - 旧版正式版（如 2.13.1.1）：没有限制，直接用，无需补丁。"
    Write-Log ""
    Write-Log "补丁只修改启动器文件本身，不动 .minecraft、设置和存档。"
    Write-Log "默认不生成备份文件；补丁失败时原文件不会被改动。"
    exit 0
}

if (-not (Test-Path $ExePath)) { Fail "找不到文件：$ExePath" }
if ((Get-Item $ExePath).Name -notlike '*.exe') { Fail "请拖入启动器的 exe 文件" }

# ---------- 加载 Cecil（按 PS 版本选 dll） ----------
$cecilSub = 'netstandard2.0'
if ($PSVersionTable.PSEdition -eq 'Desktop') { $cecilSub = 'net40' }
$cecilPath = Join-Path $here "cecil\$cecilSub\Mono.Cecil.dll"
if (-not (Test-Path $cecilPath)) { Fail "缺少 $cecilPath" }
Add-Type -Path $cecilPath

# ---------- 备份 ----------
$srcPath = $ExePath
$backupPath = $ExePath -replace '\.exe$', '_补丁前备份.exe'
Write-Log ("[模式] " + $(if ($Backup) { '保留补丁前备份（建议）' } else { '不生成备份文件' }))

# ---------- 读取内嵌依赖（供 Cecil 解析引用） ----------
$depsDir = Join-Path $env:TEMP ("PCLPatchDeps_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $depsDir | Out-Null

$rp = New-Object Mono.Cecil.ReaderParameters
$rp.ReadSymbols = $false
$resolver = New-Object Mono.Cecil.DefaultAssemblyResolver
$resolver.AddSearchDirectory($depsDir)
$resolver.AddSearchDirectory((Split-Path -Parent $srcPath))
$rp.AssemblyResolver = $resolver

try {
    $asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($srcPath, $rp)
} catch {
    Fail ("无法读取启动器： " + $_.Exception.Message)
}
$mod = $asm.MainModule
$allTypes = $mod.GetTypes()
$OC = [Mono.Cecil.Cil.OpCodes]
Write-Log ("[识别] " + $asm.FullName)

# 从内嵌 .resources 里提取依赖 dll
$depCount = 0
foreach ($res in $mod.Resources) {
    if ($res.ResourceType.ToString() -ne 'Embedded') { continue }
    if (-not $res.Name.EndsWith('.resources')) { continue }
    try {
        $raw = $res.GetResourceData()
        $tmpRes = Join-Path $depsDir ($res.Name -replace '[\\/:*?"<>|]', '_')
        [IO.File]::WriteAllBytes($tmpRes, $raw)
        $rr = New-Object System.Resources.ResourceReader($tmpRes)
        foreach ($e in $rr) {
            if ($e.Value -is [byte[]] -and $e.Value.Length -gt 5000) {
                $head = [Text.Encoding]::ASCII.GetString($e.Value, 0, 2)
                if ($head -eq 'MZ') {
                    $out = Join-Path $depsDir (($e.Key -replace '[\\/:*?"<>|]', '_') + '.dll')
                    [IO.File]::WriteAllBytes($out, $e.Value)
                    $depCount++
                }
            }
        }
        $rr.Close()
    } catch { }
}
Write-Log ("[依赖] 从启动器内嵌资源提取了 $depCount 个依赖程序集")
if ($depCount -eq 0) { $resolver.AddSearchDirectory($depsDir) | Out-Null }

# ---------- 已打补丁 / 无限制 检测 ----------
$hasQwq = $false
$hasFakeLoader = $false
$hasRealLoader = $false
$loaderInit = $null
$pd = $allTypes | Where-Object { $_.Name -eq 'PageDownloadInstall' } | Select-Object -First 1
if ($pd) {
    $loaderInit = $pd.Methods | Where-Object { $_.Name -eq 'LoaderInit' } | Select-Object -First 1
}
if ($loaderInit -and $loaderInit.HasBody) {
    foreach ($x in $loaderInit.Body.Instructions) {
        if ($x.OpCode.Name -eq 'ldsfld' -and $x.Operand.Name -eq 'DlClientListLoader') { $hasRealLoader = $true }
        if ($x.OpCode.Name -eq 'ldstr' -and [string]$x.Operand -eq '关闭下载') { $hasFakeLoader = $true }
    }
}
foreach ($t in $allTypes) {
    foreach ($m in $t.Methods) {
        if (-not $m.HasBody) { continue }
        foreach ($x in $m.Body.Instructions) {
            if ($x.OpCode.Name -eq 'ldstr' -and ([string]$x.Operand).Contains('为遵守相关法律法规')) { $hasQwq = $true; break }
        }
        if ($hasQwq) { break }
    }
    if ($hasQwq) { break }
}
$alreadyPatched = $false
if (-not $hasFakeLoader) {
    if (-not $hasQwq) { Fail "这个启动器没有下载限制（如官方旧版正式版），无需打补丁，直接使用即可。" }
    if ($hasRealLoader) {
        $alreadyPatched = $true
        Write-Log "[状态] 检测到旧版补丁痕迹，将逐项检查，并自动修复已知缺陷（整合包安装）。"
    } else {
        Write-Log "[警告] 未找到假加载器结构，本补丁器可能不适配此版本，将尝试其余补丁。"
    }
}

$results = New-Object System.Collections.ArrayList

# ---------- 补丁 A：下载页假加载器 → 真加载器 ----------
$doneA = $false
if ($PatchSet.Contains("A")) {
if ($loaderInit -and $loaderInit.HasBody) {
    $md = $allTypes | Where-Object { $_.Name -eq 'ModDownload' } | Select-Object -First 1
    $dlField = if ($md) { $md.Fields | Where-Object { $_.Name -eq 'DlClientListLoader' } | Select-Object -First 1 } else { $null }
    $ins1 = @($loaderInit.Body.Instructions)
    $idxA = -1; $idxB = -1
    for ($i = 0; $i -lt $ins1.Count; $i++) {
        if ($ins1[$i].OpCode.Name -eq 'ldstr' -and [string]$ins1[$i].Operand -eq '关闭下载') { $idxA = $i }
        if ($idxA -ge 0 -and $ins1[$i].OpCode.Name -eq 'newobj' -and $ins1[$i].Operand.DeclaringType.Name -eq 'LoaderTask`2') { $idxB = $i; break }
    }
    if ($dlField -and $idxA -ge 0 -and $idxB -gt $idxA -and $ins1[$idxB + 1].OpCode.Name -eq 'ldarg.0' -and @($loaderInit.Body.ExceptionHandlers).Count -eq 0) {
        $il1 = $loaderInit.Body.GetILProcessor()
        $il1.Replace($ins1[$idxA], $il1.Create($OC::Ldsfld, $dlField))
        for ($i = $idxA + 1; $i -le $idxB; $i++) { $il1.Replace($ins1[$i], $il1.Create($OC::Nop)) }
        $doneA = $true
    }
}
$results.Add("MC版本下载恢复(假加载器替换): " + $(if ($doneA) { '成功' } elseif ($alreadyPatched) { '已是完成状态' } elseif (-not $PatchSet.Contains('A')) { '按要求跳过' } else { '未适配，跳过' })) | Out-Null
}

# ---------- 补丁 B：版本修改页 MC 卡片可见 ----------
$doneB = 0
foreach ($t in $allTypes) {
    foreach ($m in $t.Methods) {
        if (-not $m.HasBody) { continue }
        $b2 = @($m.Body.Instructions)
        for ($i = 0; $i -lt $b2.Count - 2; $i++) {
            if ($b2[$i].OpCode.Name -eq 'callvirt' -and $b2[$i].Operand.Name -eq 'get_CardMinecraft' -and
                $b2[$i+1].OpCode.Name -eq 'ldc.i4.2' -and
                $b2[$i+2].OpCode.Name -eq 'callvirt' -and $b2[$i+2].Operand.Name -eq 'set_Visibility') {
                $m.Body.GetILProcessor().Replace($b2[$i+1], $m.Body.GetILProcessor().Create($OC::Ldc_I4_0))
                $doneB++
            }
        }
    }
}
$results.Add("版本修改页MC卡片恢复: " + $(if ($doneB -ge 1) { "成功($doneB 处)" } elseif ($alreadyPatched) { '已是完成状态' } elseif ($doneB -eq 0 -and -not ($allTypes | Where-Object { $_.Name -eq 'PageDownloadModify' })) { '此版本没有该页面，跳过' } else { '未适配，跳过' })) | Out-Null

# ---------- 补丁 C：整合包安装分发重建 ----------
$mm = $allTypes | Where-Object { $_.Name -eq 'ModModpack' } | Select-Object -First 1
$doneC = $false
$skipC = '未适配，跳过'
if (-not $PatchSet.Contains('C')) { $skipC = '按要求跳过' }
$m3 = $null
if ($PatchSet.Contains('C')) {
if ($mm) { $m3 = $mm.Methods | Where-Object { $_.Name -eq 'ModpackInstall' -and $_.Parameters.Count -eq 3 } | Select-Object -First 1 }
if (-not $m3) {
    $skipC = '此版本没有整合包安装方法，跳过'
}
if ($m3 -and $m3.HasBody) {
    $m3ins = @($m3.Body.Instructions)
    $t0 = $null; $t1 = $null; $t2 = $null
    for ($i = 0; $i -lt $m3ins.Count - 2; $i++) {
        if ($m3ins[$i].OpCode.Name -eq 'ldstr' -and ([string]$m3ins[$i].Operand).Contains('为遵守相关法律法规') -and
            $m3ins[$i+1].OpCode.Name -eq 'newobj' -and $m3ins[$i+1].Operand.FullName -eq 'System.Void System.Exception::.ctor(System.String)' -and
            $m3ins[$i+2].OpCode.Name -eq 'throw') {
            $t0 = $m3ins[$i]; $t1 = $m3ins[$i+1]; $t2 = $m3ins[$i+2]; break
        }
    }
    $catchOk = $false
    foreach ($h in $m3.Body.ExceptionHandlers) { if ($h.HandlerType.ToString() -eq 'Catch' -and $h.HandlerEnd -eq $t0) { $catchOk = $true } }
    $v1ok = $false; $v2ok = $false; $v4ok = $false
    foreach ($v in $m3.Body.Variables) {
        if ($v.Index -eq 1 -and $v.VariableType.Name -eq 'ZipArchive') { $v1ok = $true }
        if ($v.Index -eq 2 -and $v.VariableType.Name -eq 'String') { $v2ok = $true }
        if ($v.Index -eq 4 -and $v.VariableType.Name -eq 'Int32') { $v4ok = $true }
    }
    $needPacks = @('InstallPackCurseForge','InstallPackHMCL','InstallPackMMC','InstallPackMCBBS','InstallPackModrinth','InstallPackLauncherPack','InstallPackCompress')
    $packsOk = $true
    $installRefs = @{}
    foreach ($n in $needPacks) {
        $x = $mm.Methods | Where-Object { $_.Name -eq $n } | Select-Object -First 1
        if (-not $x) { $packsOk = $false } else { $installRefs[$n] = $x }
    }
    # Logger.Info(String, LogBehavior, String) 引用与源码路径字符串
    $logInfoRef = $null; $pathStr = $null
    for ($i = 0; $i -lt $m3ins.Count - 2; $i++) {
        if ($m3ins[$i].OpCode.Name -eq 'ldc.i4.0' -and $m3ins[$i+1].OpCode.Name -eq 'ldstr' -and
            ([string]$m3ins[$i+1].Operand).EndsWith('.vb') -and $m3ins[$i+2].OpCode.Name -eq 'call' -and
            $m3ins[$i+2].Operand.FullName.Contains('Logger::Info')) {
            $logInfoRef = $m3ins[$i+2].Operand; $pathStr = [string]$m3ins[$i+1].Operand; break
        }
    }
    if ($t0 -and $catchOk -and $v1ok -and $v2ok -and $v4ok -and $packsOk -and $logInfoRef) {
        $il3 = $m3.Body.GetILProcessor()
        $retLocal = New-Object Mono.Cecil.Cil.VariableDefinition($m3.ReturnType)
        $m3.Body.Variables.Add($retLocal)
        $packLocal = $null
        foreach ($v in $m3.Body.Variables) { if ($v.Index -eq 4) { $packLocal = $v } }
        $branchPend = @{}
        $caseTargets = @{}
        $disp = New-Object System.Collections.ArrayList
        foreach ($c in @(0, 1, 2, 3, 4, 9)) {
            $disp.Add($il3.Create($OC::Ldloc_S, $packLocal)) | Out-Null
            $disp.Add($il3.Create($OC::Ldc_I4, $c)) | Out-Null
            $bx = $il3.Create($OC::Beq, [Mono.Cecil.Cil.Instruction]::Create($OC::Nop))
            if (-not $branchPend.ContainsKey("C$c")) { $branchPend["C$c"] = New-Object System.Collections.ArrayList }
            $branchPend["C$c"].Add($bx) | Out-Null
            $disp.Add($bx) | Out-Null
        }
        $disp.Add($il3.Create($OC::Ldstr, '整合包种类：未能识别，假定为压缩包')) | Out-Null
        $disp.Add($il3.Create($OC::Ldc_I4_0)) | Out-Null
        $disp.Add($il3.Create($OC::Ldstr, $pathStr)) | Out-Null
        $disp.Add($il3.Create($OC::Call, $logInfoRef)) | Out-Null
        $disp.Add($il3.Create($OC::Ldarg_0)) | Out-Null
        $disp.Add($il3.Create($OC::Ldloc_1)) | Out-Null
        $disp.Add($il3.Create($OC::Call, $installRefs['InstallPackCompress'])) | Out-Null
        $disp.Add($il3.Create($OC::Stloc_S, $retLocal)) | Out-Null
        $lf0 = $il3.Create($OC::Leave, [Mono.Cecil.Cil.Instruction]::Create($OC::Nop))
        if (-not $branchPend.ContainsKey('FINAL')) { $branchPend['FINAL'] = New-Object System.Collections.ArrayList }
        $branchPend['FINAL'].Add($lf0) | Out-Null
        $disp.Add($lf0) | Out-Null
        $cases = @(
            @{ k = 'C0'; n = 'CurseForge'; m = 'InstallPackCurseForge';    a = @('F','A','B','I','L') },
            @{ k = 'C1'; n = 'HMCL';       m = 'InstallPackHMCL';          a = @('F','A','B') },
            @{ k = 'C2'; n = 'MMC';        m = 'InstallPackMMC';           a = @('F','A','B') },
            @{ k = 'C3'; n = 'MCBBS';      m = 'InstallPackMCBBS';         a = @('F','A','B','I') },
            @{ k = 'C4'; n = 'Modrinth';   m = 'InstallPackModrinth';      a = @('F','A','B','I','L') },
            @{ k = 'C9'; n = '带启动器的压缩包'; m = 'InstallPackLauncherPack'; a = @('F','A','B') }
        )
        foreach ($cs in $cases) {
            $tgt = $il3.Create($OC::Ldstr, ('整合包种类：' + $cs.n))
            $caseTargets[$cs.k] = $tgt
            $disp.Add($tgt) | Out-Null
            $disp.Add($il3.Create($OC::Ldc_I4_0)) | Out-Null
            $disp.Add($il3.Create($OC::Ldstr, $pathStr)) | Out-Null
            $disp.Add($il3.Create($OC::Call, $logInfoRef)) | Out-Null
            foreach ($a in $cs.a) {
                switch ($a) {
                    'F' { $disp.Add($il3.Create($OC::Ldarg_0)) | Out-Null }
                    'A' { $disp.Add($il3.Create($OC::Ldloc_1)) | Out-Null }
                    'B' { $disp.Add($il3.Create($OC::Ldloc_2)) | Out-Null }
                    'I' { $disp.Add($il3.Create($OC::Ldarg_1)) | Out-Null }
                    'L' { $disp.Add($il3.Create($OC::Ldarg_2)) | Out-Null }
                }
            }
            $disp.Add($il3.Create($OC::Call, $installRefs[$cs.m])) | Out-Null
            $disp.Add($il3.Create($OC::Stloc_S, $retLocal)) | Out-Null
            $lf = $il3.Create($OC::Leave, [Mono.Cecil.Cil.Instruction]::Create($OC::Nop))
            $branchPend['FINAL'].Add($lf) | Out-Null
            $disp.Add($lf) | Out-Null
        }
        foreach ($d in $disp) { $il3.InsertBefore($t0, $d) }
        foreach ($x in $m3.Body.Instructions) {
            if ($x.Operand -is [Mono.Cecil.Cil.Instruction] -and $x.Operand -eq $t0) { $x.Operand = $disp[0] }
        }
        foreach ($k in $branchPend.Keys) {
            if ($caseTargets.ContainsKey($k)) { foreach ($br in $branchPend[$k]) { $br.Operand = $caseTargets[$k] } }
        }
        $il3.Remove($t0); $il3.Remove($t1); $il3.Remove($t2)
        foreach ($h in $m3.Body.ExceptionHandlers) {
            if ($h.HandlerEnd -eq $t0 -or $h.HandlerEnd -eq $t1 -or $h.HandlerEnd -eq $t2) { $h.HandlerEnd = $disp[0] }
            if ($h.TryEnd -eq $t0 -or $h.TryEnd -eq $t1 -or $h.TryEnd -eq $t2) { $h.TryEnd = $disp[0] }
        }
        $finalIns = $il3.Create($OC::Ldloc_S, $retLocal)
        $il3.Append($finalIns)
        $il3.Append($il3.Create($OC::Ret))
        foreach ($br in $branchPend['FINAL']) { $br.Operand = $finalIns }
        # 关键：把外层 finally 的结束边界收缩到结尾代码之前，否则 ldloc/ret 落入 finally 块内，leave 目标非法
        foreach ($h in $m3.Body.ExceptionHandlers) {
            if ($h.HandlerType.ToString() -eq 'Finally' -and $null -eq $h.HandlerEnd) { $h.HandlerEnd = $finalIns }
        }
        $doneC = '成功'
    } elseif ($t0) {
        $skipC = '结构不匹配（可能是其他版本），跳过'
    } else {
        # 已打补丁（无 qwq throw）→ 检查分发比较链是否为有缺陷的旧版并修复
        $catchH = $m3.Body.ExceptionHandlers | Where-Object { $_.HandlerType.ToString() -eq 'Catch' } | Select-Object -First 1
        if ($catchH -and $catchH.HandlerEnd -and $catchH.HandlerEnd.OpCode.Name -eq 'ldloc.s' -and $catchH.HandlerEnd.Operand.VariableType.Name -eq 'Int32') {
            $packLocal = $catchH.HandlerEnd.Operand
            $chainStart = $catchH.HandlerEnd
            $len = 0; $beqs = 0; $cur = $chainStart
            while ($null -ne $cur -and $cur.OpCode.Name -in @('ldloc.s','ldc.i4','ldc.i4.s','beq')) {
                $len++
                if ($cur.OpCode.Name -eq 'beq') { $beqs++ }
                $cur = $cur.Next
            }
            if ($beqs -ge 5 -and $len -eq (1 + 2 * $beqs)) {
                # 有缺陷的旧版链：每组比较缺少 ldloc 压栈 → 补齐
                $il3 = $m3.Body.GetILProcessor()
                $cur = $chainStart.Next
                $inserted = 0
                while ($null -ne $cur -and $cur.OpCode.Name -in @('ldc.i4','ldc.i4.s')) {
                    $beq = $cur.Next
                    if ($null -eq $beq -or $beq.OpCode.Name -ne 'beq') { break }
                    $after = $beq.Next
                    if ($null -ne $after -and $after.OpCode.Name -in @('ldc.i4','ldc.i4.s')) {
                        $il3.InsertBefore($after, $il3.Create($OC::Ldloc_S, $packLocal))
                        $inserted++
                    }
                    $cur = $after
                }
                # 旧版缺陷二：结尾代码落在 finally 块内 → 收缩边界
                $insAll = @($m3.Body.Instructions)
                $fixedH = 0
                if ($insAll[-1].OpCode.Name -eq 'ret' -and $insAll[-2].OpCode.Name -eq 'ldloc.s') {
                    foreach ($h in $m3.Body.ExceptionHandlers) {
                        if ($h.HandlerType.ToString() -eq 'Finally' -and $null -eq $h.HandlerEnd) { $h.HandlerEnd = $insAll[-2]; $fixedH++ }
                    }
                }
                if ($inserted -eq 5 -and $fixedH -ge 1) { $doneC = '成功(已修复旧版缺陷)' }
                else { $skipC = "旧版缺陷修复不完整（补 $inserted 处压栈，边界 $fixedH）" }
            } elseif ($len -eq (3 * $beqs) -and $beqs -ge 5) {
                $skipC = '已是修复后的补丁，无需处理'
            } else {
                $skipC = '未识别的分发结构，跳过'
            }
        } else {
            $skipC = '此版本整合包安装未被限制，无需处理'
        }
    }
}
$results.Add("整合包安装恢复(分发重建): " + $(if ($doneC) { $doneC } else { $skipC })) | Out-Null
}

# ---------- 补丁 D：本地安装入口重建 ----------
$doneD = $false
$skipD = '未适配，跳过'
if (-not $PatchSet.Contains('D')) { $skipD = '按要求跳过' }
$m0 = $null
if ($PatchSet.Contains('D')) {
if ($mm) { $m0 = $mm.Methods | Where-Object { $_.Name -eq 'ModpackInstall' -and $_.Parameters.Count -eq 0 } | Select-Object -First 1 }
if ($m0 -and $m0.HasBody) {
    $m0ins = @($m0.Body.Instructions)
    $guardOk = $m0ins.Count -ge 5 -and $m0ins[-1].OpCode.Name -eq 'ret' -and $m0ins[-2].OpCode.Name -eq 'call' -and $m0ins[-2].Operand.FullName.Contains('Hint')
    $lambda = $null; $cl = $null
    foreach ($t in $allTypes) {
        if ($t.FullName.StartsWith('PCL.ModModpack/_Closure$__0-0')) { $cl = $t }
    }
    if ($cl) {
        $lambda = $cl.Methods | Where-Object { $_.Name -eq '_Lambda$__0' } | Select-Object -First 1
    }
    $fl = if ($cl) { $cl.Fields | Where-Object { $_.Name -eq '$VB$Local_File' } | Select-Object -First 1 } else { $null }
    $ct0 = if ($cl) { $cl.Methods | Where-Object { $_.Name -eq '.ctor' } | Select-Object -First 1 } else { $null }
    $mb = $allTypes | Where-Object { $_.Name -eq 'ModBase' } | Select-Object -First 1
    $runInThread = if ($mb) { $mb.Methods | Where-Object { $_.Name -eq 'RunInThread' } | Select-Object -First 1 } else { $null }
    # SelectFile(4参, OneOf 元组筛选) / FirstOrDefault / Nullable ctor —— 任意调用点采集
    $sfRef = $null; $fodRef = $null; $nubCtor = $null
    foreach ($t in $allTypes) {
        foreach ($m in $t.Methods) {
            if (-not $m.HasBody) { continue }
            $mi = @($m.Body.Instructions)
            for ($i = 0; $i -lt $mi.Count; $i++) {
                $op = $mi[$i].Operand
                if ($null -eq $op) { continue }
                $tn = $op.GetType().Name
                if ($tn -in @('MethodReference','MethodSpecification','GenericInstanceMethod')) {
                    if (-not $sfRef -and $op.Name -eq 'SelectFile' -and $op.Parameters.Count -eq 4 -and $op.Parameters[3].ParameterType.FullName.Contains('OneOf')) { $sfRef = $op }
                    if (-not $fodRef -and $op.Name -eq 'FirstOrDefault' -and $op.DeclaringType.FullName.StartsWith('System.Linq.Enumerable')) { $fodRef = $op }
                    if (-not $nubCtor -and $op.Name -eq '.ctor' -and $op.DeclaringType.FullName.StartsWith('System.Nullable`1<MeloongCore.OneOf')) { $nubCtor = $op }
                }
            }
        }
    }
    if ($guardOk -and $lambda -and $fl -and $ct0 -and $runInThread -and $sfRef -and $fodRef -and $nubCtor) {
        $oneOfGI = $nubCtor.DeclaringType.GenericArguments[0]
        try { $oneOfDef = $oneOfGI.Resolve() } catch { $oneOfDef = $null }
        $opA = $null
        if ($oneOfDef) {
            foreach ($cm in $oneOfDef.Methods) {
                if ($cm.Name -eq 'op_Implicit' -and $cm.Parameters.Count -eq 1 -and
                    $cm.Parameters[0].ParameterType -is [Mono.Cecil.GenericParameter] -and $cm.Parameters[0].ParameterType.Position -eq 0) { $opA = $cm }
            }
        }
        $sni = $null
        foreach ($cm in $mod.TypeSystem.String.Resolve().Methods) { if ($cm.Name -eq 'IsNullOrEmpty' -and $cm.Parameters.Count -eq 1) { $sni = $cm; break } }
        $actionCtor = $null
        foreach ($t in $allTypes) {
            foreach ($m in $t.Methods) {
                if (-not $m.HasBody) { continue }
                foreach ($ix in $m.Body.Instructions) {
                    if ($ix.OpCode.Name -eq 'newobj' -and $ix.Operand.FullName -eq 'System.Void System.Action::.ctor(System.Object,System.IntPtr)') { $actionCtor = $ix.Operand; break }
                }
                if ($actionCtor) { break }
            }
            if ($actionCtor) { break }
        }
        if ($opA -and $sni -and $actionCtor) {
            $aSide = $oneOfGI.GenericArguments[0]
            if ($aSide.FullName.StartsWith('System.Collections.Generic.IEnumerable')) {
                $vtType = $aSide.GenericArguments[0]
                $b4 = $m0.Body
                $il4 = $b4.GetILProcessor()
                while ($b4.Instructions.Count -gt 0) { $il4.Remove($b4.Instructions[0]) }
                while ($b4.ExceptionHandlers.Count -gt 0) { $b4.ExceptionHandlers.RemoveAt(0) }
                while ($b4.Variables.Count -gt 0) { $b4.Variables.RemoveAt(0) }
                $varFile = New-Object Mono.Cecil.Cil.VariableDefinition($mod.TypeSystem.String)
                $b4.Variables.Add($varFile)
                $varClosure = New-Object Mono.Cecil.Cil.VariableDefinition($cl)
                $b4.Variables.Add($varClosure)
                $b4.MaxStackSize = 16
                $il4.Append($il4.Create($OC::Ldc_I4_1))
                $il4.Append($il4.Create($OC::Newarr, $vtType))
                $il4.Append($il4.Create($OC::Dup))
                $il4.Append($il4.Create($OC::Ldc_I4_0))
                $il4.Append($il4.Create($OC::Ldc_I4_3))
                $il4.Append($il4.Create($OC::Newarr, $mod.TypeSystem.String))
                $il4.Append($il4.Create($OC::Dup))
                $il4.Append($il4.Create($OC::Ldc_I4_0))
                $il4.Append($il4.Create($OC::Ldstr, 'rar'))
                $il4.Append($il4.Create($OC::Stelem_Ref))
                $il4.Append($il4.Create($OC::Dup))
                $il4.Append($il4.Create($OC::Ldc_I4_1))
                $il4.Append($il4.Create($OC::Ldstr, 'zip'))
                $il4.Append($il4.Create($OC::Stelem_Ref))
                $il4.Append($il4.Create($OC::Dup))
                $il4.Append($il4.Create($OC::Ldc_I4_2))
                $il4.Append($il4.Create($OC::Ldstr, 'mrpack'))
                $il4.Append($il4.Create($OC::Stelem_Ref))
                $il4.Append($il4.Create($OC::Ldstr, '整合包文件'))
                $vtCtorRef = New-Object Mono.Cecil.MethodReference('.ctor', $mod.TypeSystem.Void, $vtType)
                $vtCtorRef.HasThis = $true
                $vtCtorRef.Parameters.Add((New-Object Mono.Cecil.ParameterDefinition((New-Object Mono.Cecil.ArrayType($mod.TypeSystem.String)))))
                $vtCtorRef.Parameters.Add((New-Object Mono.Cecil.ParameterDefinition($mod.TypeSystem.String)))
                $il4.Append($il4.Create($OC::Newobj, $vtCtorRef))
                $il4.Append($il4.Create($OC::Stelem_Any, $vtType))
                $il4.Append($il4.Create($OC::Call, $mod.ImportReference($opA)))
                $il4.Append($il4.Create($OC::Newobj, $nubCtor))
                $il4.Append($il4.Create($OC::Ldstr, '选择整合包压缩文件'))
                $il4.Append($il4.Create($OC::Ldc_I4_0))
                $il4.Append($il4.Create($OC::Ldnull))
                $il4.Append($il4.Create($OC::Call, $sfRef))
                $il4.Append($il4.Create($OC::Call, $fodRef))
                $il4.Append($il4.Create($OC::Stloc_S, $varFile))
                $contIns = $il4.Create($OC::Ldloc_S, $varFile)
                $il4.Append($il4.Create($OC::Ldloc_S, $varFile))
                $il4.Append($il4.Create($OC::Call, $mod.ImportReference($sni)))
                $il4.Append($il4.Create($OC::Brfalse_S, $contIns))
                $il4.Append($il4.Create($OC::Ret))
                $il4.Append($contIns)
                $il4.Append($il4.Create($OC::Newobj, $ct0))
                $il4.Append($il4.Create($OC::Stloc_S, $varClosure))
                $il4.Append($il4.Create($OC::Ldloc_S, $varClosure))
                $il4.Append($il4.Create($OC::Ldloc_S, $varFile))
                $il4.Append($il4.Create($OC::Stfld, $fl))
                $il4.Append($il4.Create($OC::Ldloc_S, $varClosure))
                $il4.Append($il4.Create($OC::Ldftn, $lambda))
                $il4.Append($il4.Create($OC::Newobj, $actionCtor))
                $il4.Append($il4.Create($OC::Call, $runInThread))
                $il4.Append($il4.Create($OC::Ret))
                $doneD = $true
            }
        }
    } elseif ($m0ins.Count -gt 3 -and $m0ins[0].OpCode.Name -eq 'ldc.i4.1' -and $m0ins[1].OpCode.Name -eq 'newarr') {
        $skipD = '已是修复后的补丁，无需处理'
    } elseif ($m0ins.Count -gt 3) {
        $skipD = '结构不匹配（可能是其他版本），跳过'
    } else {
        $skipD = '此版本入口未被限制，无需处理'
    }
}
$results.Add("本地安装整合包入口恢复: " + $(if ($doneD) { '成功' } else { $skipD })) | Out-Null
}

# ---------- 写出 ----------
$tmpOut = Join-Path $env:TEMP ("PCLPatched_" + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.exe')
try {
    $asm.Write($tmpOut)
    $asm.Dispose()
} catch {
    Fail ("写出失败，原文件未改动： " + $_.Exception.Message)
}
# 复核
try {
    $rp2 = New-Object Mono.Cecil.ReaderParameters
    $rp2.ReadSymbols = $false
    $asm2 = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($tmpOut, $rp2)
    $asm2.Dispose()
} catch {
    Remove-Item $tmpOut -Force
    Fail ("补丁后文件自检失败，原文件未改动： " + $_.Exception.Message)
}
if ($Backup) {
    Copy-Item $srcPath $backupPath -Force
    Write-Log "已生成补丁前备份：$backupPath"
}
Copy-Item $tmpOut $srcPath -Force
Remove-Item $tmpOut -Force
Write-Log "==================== 补丁结果 ===================="
foreach ($r in $results) { Write-Log ("  " + $r) }
Write-Log "=================================================="
Write-Log "已写回：$srcPath"
if (-not $Backup) { Write-Log "（本次未创建备份；如需备份，使用「拖我上去_备份版.bat」重新处理）" }
Write-Log "完成！重新启动启动器即可生效。"
