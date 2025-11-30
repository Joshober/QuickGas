# PowerShell script to set Railway frontend environment variables from .env file
# Usage: .\scripts\setup-railway-frontend.ps1

Write-Host "Setting up Railway frontend environment variables from .env file..." -ForegroundColor Green

# Navigate to project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "Error: .env file not found in project root" -ForegroundColor Red
    exit 1
}

# Link to frontend service
Write-Host "`nLinking to frontend service..." -ForegroundColor Yellow
railway link --project vocal-ship --service frontend | Out-Null

# Read .env file
Write-Host "Reading .env file..." -ForegroundColor Yellow
$envContent = Get-Content ".env" -Raw

# Parse environment variables
$variables = @{}

# Split by lines and process
$lines = $envContent -split "`r?`n"
$currentKey = $null
$currentValue = @()
$inMultiLine = $false

foreach ($line in $lines) {
    $originalLine = $line
    $line = $line.Trim()
    
    # Skip empty lines
    if ([string]::IsNullOrWhiteSpace($line)) {
        if ($inMultiLine) {
            $currentValue += ""
        }
        continue
    }
    
    # Skip comments (unless we're in a multi-line value)
    if ($line.StartsWith("#") -and -not $inMultiLine) {
        continue
    }
    
    # Check if line contains = (key-value pair)
    if ($line -match "^([^=]+)=(.*)$" -and -not $inMultiLine) {
        # Save previous key-value if exists
        if ($null -ne $currentKey) {
            $variables[$currentKey] = ($currentValue -join "`n").Trim()
        }
        
        $currentKey = $matches[1].Trim()
        $valuePart = $matches[2].Trim()
        
        # Check if value starts with { (likely JSON)
        if ($valuePart.StartsWith("{")) {
            $currentValue = @($valuePart)
            $inMultiLine = $true
        } else {
            $currentValue = @($valuePart)
            $inMultiLine = $false
        }
    } else {
        # Continuation of multi-line value
        if ($null -ne $currentKey) {
            $currentValue += $originalLine
            # Check if we've closed the JSON
            if ($line -match "^\s*\}\s*$" -or ($line.Contains("}") -and $line.Trim().EndsWith("}"))) {
                $inMultiLine = $false
            } else {
                $inMultiLine = $true
            }
        }
    }
}

# Save last key-value
if ($null -ne $currentKey) {
    $variables[$currentKey] = ($currentValue -join "`n").Trim()
}

# Frontend-specific variables to set
$frontendVars = @{
    "GOOGLE_MAPS_API_KEY" = $variables["GOOGLE_MAPS_API_KEY"]
    "STRIPE_PUBLISHABLE_KEY" = $variables["STRIPE_PUBLISHABLE_KEY"]
    "BACKEND_URL" = $null  # Will be set from Railway service URL
}

# Get backend URL from Railway
Write-Host "`nGetting backend URL..." -ForegroundColor Yellow
railway link --service backend | Out-Null
$backendUrl = railway variables --json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty RAILWAY_PUBLIC_DOMAIN
if ($backendUrl) {
    $frontendVars["BACKEND_URL"] = "https://$backendUrl"
    Write-Host "  Found backend URL: $($frontendVars['BACKEND_URL'])" -ForegroundColor Cyan
}

# Link back to frontend
railway link --service frontend | Out-Null

# Set variables in Railway
Write-Host "`nSetting environment variables in Railway..." -ForegroundColor Yellow
foreach ($key in $frontendVars.Keys) {
    if ($frontendVars[$key]) {
        Write-Host "  Setting $key..." -ForegroundColor Cyan
        $value = $frontendVars[$key]
        # Escape special characters for PowerShell
        $value = $value -replace '"', '\"'
        railway variables --set "$key=$value" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ $key set successfully" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Failed to set $key" -ForegroundColor Red
        }
    } else {
        Write-Host "  Skipping $key (not found in .env or Railway)" -ForegroundColor Gray
    }
}

Write-Host "`n✓ Frontend environment variables configured successfully!" -ForegroundColor Green
Write-Host "`nYou can verify with: railway variables" -ForegroundColor Cyan

