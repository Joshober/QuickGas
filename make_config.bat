@echo off
echo Generating Firebase configuration files from .env...
dart run scripts/generate_firebase_configs.dart
if %errorlevel% neq 0 (
    echo.
    echo Error: Failed to generate config files.
    echo Make sure you have:
    echo 1. Created a .env file with your Firebase credentials
    echo 2. Installed Dart SDK
    echo 3. Run this from the quickgas directory
    exit /b 1
)
echo.
echo Done! Firebase config files have been generated.
pause
