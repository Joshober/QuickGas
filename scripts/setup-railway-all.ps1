# PowerShell script to set all Railway environment variables from .env file
# Usage: .\scripts\setup-railway-all.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Railway Environment Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run backend setup
Write-Host "Step 1: Setting up backend..." -ForegroundColor Yellow
& "$PSScriptRoot\setup-railway-backend.ps1"

Write-Host "`n" -NoNewline

# Run frontend setup
Write-Host "Step 2: Setting up frontend..." -ForegroundColor Yellow
& "$PSScriptRoot\setup-railway-frontend.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✓ All environment variables configured!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

