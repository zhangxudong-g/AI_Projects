# setup_antlr.ps1 - 环境检查脚本
# 注意：此项目使用纯 Python 实现，不需要 ANTLR 或 Java！

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PL/SQL Wiki Demo - 环境检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 检查 Python
Write-Host "[1/3] 检查 Python 安装..." -ForegroundColor Yellow
try {
    $pythonVersion = & python --version 2>&1 | Out-String
    if ($pythonVersion -match "Python") {
        Write-Host "  ✅ Python found: $pythonVersion" -ForegroundColor Green
    }
    else {
        throw "Python not found"
    }
}
catch {
    Write-Host "  ❌ ERROR: Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Please install Python 3.8+ from: https://www.python.org/downloads/" -ForegroundColor Yellow
    exit 1
}

# Step 2: 安装依赖
Write-Host "[2/3] 检查 Python 依赖..." -ForegroundColor Yellow
try {
    # Check if packages are already installed
    $hasOpenai = & pip show openai 2>&1 | Out-String
    if ($hasOpenai -match "Name: openai") {
        Write-Host "  ✅ openai package found" -ForegroundColor Green
    } else {
        Write-Host "  Installing openai..." -ForegroundColor Yellow
        & pip install openai 2>&1 | Out-Null
    }
    Write-Host "  ✅ Dependencies ready" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️ Warning: Could not verify dependencies" -ForegroundColor Yellow
}

# Step 3: 验证提取器
Write-Host "[3/3] 验证 PL/SQL 提取器..." -ForegroundColor Yellow
try {
    & python -c "from plsql_extractor import parse_plsql_file; print('OK')" 2>&1 | Out-String
    Write-Host "  ✅ PL/SQL extractor loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ ERROR: Failed to load extractor" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ 环境检查完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "  运行 Demo: python main.py" -ForegroundColor White
Write-Host ""
