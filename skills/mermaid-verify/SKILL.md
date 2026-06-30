---
name: mermaid-verify
description: |
  Verify Mermaid diagram syntax in Wiki markdown files for a given
  project. Primary trigger: user says "验证 project <name> 里面的 wiki
  的 mermaid", "验证 <name> 项目的 mermaid", "check mermaid in project
  <name>", "verify project <name> wiki", or similar — resolves `<name>`
  to `D:\code-wiki\projects\<name>\wiki_cache\` (the user's standard
  wiki project layout) and runs the bundled `verify.py` script on
  every `*.md` file there. Also supports direct file paths and explicit
  directory globs. Secondary triggers: "verify mermaid syntax",
  "检查 wiki 流程图", "验证 mermaid 语法", "mermaid 报错".
  Do NOT use for editing or generating Mermaid code (this skill only
  validates), or for general Wiki content quality vs. PL/SQL source code
  (use wiki-quality-difference-analysis).
---

# Mermaid Verify

## Inputs to collect

The model needs to know **what to verify**. The user's phrasing
determines the resolution path:

| User says… | Resolve to |
|---|---|
| `验证 project <name> 里面的 wiki 的 mermaid` | `D:\code-wiki\projects\<name>\wiki_cache\*.md` |
| `验证 <name> 项目的 mermaid` | `D:\code-wiki\projects\<name>\wiki_cache\*.md` |
| `<file>.SQL.md` (explicit filename) | that file directly |
| `整个 wiki_cache 跑一遍` / `批量验证` | glob `*.md` in the directory the user names (or current `wiki_cache/`) |
| "this file" with no path | ask before globbing — do not silently scan `C:\` |

If multiple files match, run each separately and aggregate results —
`verify.py` takes exactly one file per invocation.

## Procedure

1. **Identify the resolution mode** from the user's phrasing (table
   above). For project-name mode, extract `<name>` and assemble:
   ```powershell
   $WikiDir = Join-Path "D:\code-wiki\projects" "<name>\wiki_cache"
   if (-not (Test-Path $WikiDir)) {
       # Convention broken — ask the user where <name>'s wiki lives
       throw "Project '$name' not found at $WikiDir. Where is its wiki_cache directory?"
   }
   $MdFiles = Get-ChildItem -Path $WikiDir -Filter "*.md"
   ```

2. **Preflight — resolve every dependency in ONE PowerShell block**.
   Do not split this into multiple rounds. The shell that the model
   runs in often has a stripped PATH (no `C:\nvm4w\nodejs`, no npm
   global bin, etc.), so a naive `where mmdc` returns nothing even
   when Mermaid CLI is installed. This block refreshes PATH, finds
   `verify.py`, finds `mmdc` via multiple strategies, and sets UTF-8 —
   all in one shot:
   ```powershell
   # 1. Refresh PATH from registry (Bash-tool sessions have stripped PATH)
   $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

   # 2. Resolve bundled verify.py
   $SkillRoot = Join-Path $HOME ".mavis\agents\mavis\skills\mermaid-verify"
   $VerifyPy  = Join-Path $SkillRoot "scripts\verify.py"
   if (-not (Test-Path $VerifyPy)) {
       throw "verify.py not found at $VerifyPy. Ask the user where the skill is installed."
   }

   # 3. Resolve mmdc — try variants in order, then fall back to common install dirs
   $mmdcCmd = $null
   foreach ($name in @('mmdc.cmd', 'mmdc', 'mmdc.ps1')) {
       $found = Get-Command $name -ErrorAction SilentlyContinue
       if ($found) { $mmdcCmd = $found.Source; break }
   }
   if (-not $mmdcCmd) {
       $fallbacks = @(
           "C:\nvm4w\nodejs\mmdc.cmd",                          # nvm4w default
           (Join-Path $env:ProgramFiles "nodejs\mmdc.cmd"),     # standard Node
           (Join-Path $env:APPDATA "npm\mmdc.cmd"),             # npm global (user)
           "$HOME\.nvm\versions\node\*\mmdc.cmd"                # legacy nvm-windows
       )
       foreach ($c in $fallbacks) {
           $hit = Get-Item $c -ErrorAction SilentlyContinue
           if ($hit) { $mmdcCmd = $hit.FullName; break }
       }
   }
   if (-not $mmdcCmd) {
       throw "mmdc (Mermaid CLI) not found. Install: npm install -g @mermaid-js/mermaid-cli"
   }

   # 4. UTF-8 (Chinese Windows defaults to GBK; emoji and CJK get garbled otherwise)
   [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
   $env:PYTHONIOENCODING = "utf-8"
   $env:PYTHONUTF8 = "1"

   Write-Host "✅ verify.py: $VerifyPy"
   Write-Host "✅ mmdc:      $mmdcCmd"
   ```
   After this block, `$VerifyPy` and `$mmdcCmd` are bound for the rest
   of the session. **Do not run a second preflight** — if this block
   succeeded, trust it. Reason: doing it again wastes a round-trip and
   the user has already seen you flounder.

3. **Run verification**. For each target MD:
   ```powershell
   Set-Location (Split-Path $md.FullName -Parent)   # script writes temp files in CWD
   & python $VerifyPy $md.FullName
   $LASTEXITCODE   # 0 = all pass, 1 = at least one syntax error
   ```
   For project-name mode, loop over `$MdFiles` and collect per-file
   exit codes — see the Examples section.

4. **Parse each script run's output**. The script ends with exactly
   one of:
   - `未找到 mermaid 代码块` → nothing to verify in that file.
   - `所有 Mermaid 图表语法均正确` → all pass.
   - `存在语法错误` → at least one block failed. mmdc's `stderr`
     for the failing block has already been printed (it contains
     line / column hints inside the diagram source).

5. **Report**.
   - On success: file/chart count + "all green".
   - On failure: per-block ✅/❌ index, plus mmdc's `stderr` excerpt
     **verbatim**. Do not paraphrase the error — the exact text matters
     for fixing the syntax.
   - After reporting failures, offer: "要不要我帮你修第 N 个图的报错？"
     Do not auto-fix. Fixing requires reading and editing the MD, which
     is a separate decision the user should make.

## Output contract

A user-facing chat message, NOT a written file. Contains:

- Total files run + total chart count across the run(s).
- Per-file summary: filename, chart count, pass/fail.
- For each failure: mmdc's stderr excerpt verbatim.

Do not dump full mmdc output on success.

## Failure handling

| Symptom | Cause | Action |
|---|---|---|
| Preflight throws `mmdc (Mermaid CLI) not found` | Not installed, or in a path not on the fallback list | Tell user the `npm install -g @mermaid-js/mermaid-cli` command. Stop. |
| Preflight throws `verify.py not found at ...` | Skill install layout differs from default | Ask the user where the skill is installed. |
| Preflight `Project '<name>' not found at ...` | Project name typo, or non-standard layout | Ask the user for the actual wiki path. Don't guess. |
| `python ... verify.py ...` says `❌ 文件不存在` | Wrong MD path | Surface the message, ask for the corrected path. |
| mmdc prints a syntax error | Bad Mermaid in that block | Report stderr verbatim; offer to help fix; do not auto-edit. |
| Stale `_temp_verify_*.mmd` / `*.svg` left behind | Script crashed mid-loop | Safe to `mavis-trash` them; tell the user they were left over. |
| PowerShell output shows `��` instead of emoji | GBK console encoding | Preflight already sets UTF-8; if you still see this, the preflight didn't run. |

## Examples

> Each example below assumes **step 2 (preflight) has already run**
> in this session. `$VerifyPy` and `$mmdcCmd` are bound, UTF-8 is set,
> and PATH has been refreshed. Do not re-run preflight inside an example.

**Project name** — User says: "验证 project Aerr 里面的 wiki 的 mermaid"

```powershell
$WikiDir = Join-Path "D:\code-wiki\projects" "Aerr\wiki_cache"
if (-not (Test-Path $WikiDir)) {
    throw "Project 'Aerr' not found at $WikiDir. Where is its wiki_cache?"
}
$results = @()
Get-ChildItem -Path $WikiDir -Filter "*.md" | ForEach-Object {
    Write-Host "=== $($_.Name) ==="
    Set-Location $_.DirectoryName
    & python $VerifyPy $_.FullName
    $results += [pscustomobject]@{ File = $_.Name; ExitCode = $LASTEXITCODE }
    Write-Host ""
}
$results | Format-Table -AutoSize
```

**Single file** — User says: "帮我验证 ZLBSKCALMKAI.SQL.md 的 mermaid 语法"

```powershell
Set-Location D:\code-wiki\projects\Aerr\wiki_cache
& python $VerifyPy .\ZLBSKCALMKAI.SQL.md
```

**Explicit directory** — User says: "整个 wiki_cache 跑一遍 mermaid 验证"

```powershell
Set-Location D:\code-wiki\projects\Aerr\wiki_cache
Get-ChildItem -Filter "*.md" | ForEach-Object {
    Write-Host "=== $($_.Name) ==="
    & python $VerifyPy $_.FullName
    Write-Host ""
}
```

## Performance and timeouts

- `mmdc` spawns a headless Chrome via puppeteer for every diagram.
  Realistic throughput: **~1–3 seconds per chart** (cold Chrome start
  is slow, subsequent charts reuse the cached browser).
- For a project with N charts:
  | Charts | Expected wall time | Notes |
  |---|---|---|
  | < 30 | under 60s | Single shell command, no batching needed |
  | 30–100 | 1–3 min | Tight against the default 180s timeout |
  | > 100 | several minutes | **Split into batches** or extend the Bash tool timeout |
- If the verification command times out, split by file count or
  per-file (run one MD at a time). Don't blindly increase the
  timeout without first checking that mmdc is making progress.

## Windows (win32) platform notes

- Use `python` (not `python3`) — Windows defaults to `python`.
- `verify.py` auto-detects `os.name == 'nt'` and calls `mmdc.cmd`
  (the Windows shim). No extra path handling needed.
- Exit code from the script: `0` = all pass, `1` = at least one syntax
  error. Use this in CI / pipelines; for chat reporting, parse stdout.
- Always `Set-Location` to the MD's directory before invoking the
  script. The script writes its temp files in CWD, so this keeps them
  alongside the wiki MDs and avoids polluting other directories.
- Path resolution assumes the default install layout
  (`$HOME/.mavis/agents/mavis/skills/mermaid-verify/`). If the user has
  a custom `dataDir`, ask them where the skill lives.
- **UTF-8 + PATH refresh are inside the preflight block** (step 2).
  Don't repeat them per-example. If you see `��` instead of emoji in
  the output, the preflight didn't run — go back and run it before
  iterating further.
- **Project path convention**: `D:\code-wiki\projects\<name>\wiki_cache\`.
  If the user has a different convention, ask — don't guess.