# PowerShell script to set Railway backend environment variables from .env file
# Usage: .\scripts\setup-railway-backend.ps1

Write-Host "Setting up Railway backend environment variables from .env file..." -ForegroundColor Green

# Navigate to project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "Error: .env file not found in project root" -ForegroundColor Red
    exit 1
}

# Link to backend service
Write-Host "`nLinking to backend service..." -ForegroundColor Yellow
railway link --project vocal-ship --service backend | Out-Null

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
        # Continuation of multi-line value (like JSON)
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

# Backend-specific variables to set
$backendVars = @{
    "STRIPE_SECRET_KEY" = $variables["STRIPE_SECRET_KEY"]
    "FIREBASE_SERVICE_ACCOUNT" = $variables["FIREBASE_SERVICE_ACCOUNT"]
    "FIREBASE_ENABLED" = if ($variables["FIREBASE_SERVICE_ACCOUNT"]) { "true" } else { "false" }
    "OPENROUTESERVICE_API_KEY" = $variables["OPENROUTESERVICE_API_KEY"]
}

# Clean up Firebase JSON (remove newlines, extra spaces)
if ($backendVars["FIREBASE_SERVICE_ACCOUNT"]) {
    $firebaseJson = $backendVars["FIREBASE_SERVICE_ACCOUNT"]
    # Remove newlines and extra whitespace, but preserve JSON structure
    $firebaseJson = $firebaseJson -replace "`n", "" -replace "`r", "" -replace "\s+", " "
    $backendVars["FIREBASE_SERVICE_ACCOUNT"] = $firebaseJson
}

# Set variables in Railway
Write-Host "`nSetting environment variables in Railway..." -ForegroundColor Yellow
foreach ($key in $backendVars.Keys) {
    if ($backendVars[$key]) {
        Write-Host "  Setting $key..." -ForegroundColor Cyan
        $value = $backendVars[$key]
        # Escape special characters for PowerShell
        $value = $value -replace '"', '\"'
        railway variables --set "$key=$value" | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ $key set successfully" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Failed to set $key" -ForegroundColor Red
        }
    } else {
        Write-Host "  Skipping $key (not found in .env)" -ForegroundColor Gray
    }
}

# Database connection (using internal Railway networking)
Write-Host "`nSetting up database connection (internal networking)..." -ForegroundColor Yellow
railway variables --service Postgres | Out-Null
$dbVars = railway variables --service Postgres --json | ConvertFrom-Json

if ($dbVars) {
    $dbHost = $dbVars.PGHOST
    $dbPort = $dbVars.PGPORT
    $dbName = $dbVars.PGDATABASE
    $dbUser = $dbVars.PGUSER
    $dbPassword = $dbVars.PGPASSWORD
    
    if ($dbHost -and $dbPort -and $dbName) {
        $jdbcUrl = "jdbc:postgresql://${dbHost}:${dbPort}/${dbName}"
        Write-Host "  Setting DATABASE_URL..." -ForegroundColor Cyan
        railway variables --set "DATABASE_URL=$jdbcUrl" | Out-Null
        railway variables --set "DATABASE_USERNAME=$dbUser" | Out-Null
        railway variables --set "DATABASE_PASSWORD=$dbPassword" | Out-Null
        Write-Host "    ✓ Database connection configured (internal: $dbHost)" -ForegroundColor Green
    }
}

# CORS and Server URL (if not already set)
Write-Host "`nSetting CORS and server configuration..." -ForegroundColor Yellow
$frontendUrl = railway variables --service frontend --json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty RAILWAY_PUBLIC_DOMAIN
if ($frontendUrl) {
    $frontendUrl = "https://$frontendUrl"
    railway variables --set "CORS_ALLOWED_ORIGINS=$frontendUrl" | Out-Null
    Write-Host "  ✓ CORS set to: $frontendUrl" -ForegroundColor Green
}

$backendUrl = railway variables --json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty RAILWAY_PUBLIC_DOMAIN
if ($backendUrl) {
    $backendUrl = "https://$backendUrl"
    railway variables --set "SERVER_BASE_URL=$backendUrl" | Out-Null
    Write-Host "  ✓ Server base URL set to: $backendUrl" -ForegroundColor Green
}

Write-Host "`n✓ Backend environment variables configured successfully!" -ForegroundColor Green
Write-Host "`nYou can verify with: railway variables" -ForegroundColor Cyan

