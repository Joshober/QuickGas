#!/bin/bash
echo "Generating Firebase configuration files from .env..."
dart run scripts/generate_firebase_configs.dart
if [ $? -ne 0 ]; then
    echo ""
    echo "Error: Failed to generate config files."
    echo "Make sure you have:"
    echo "1. Created a .env file with your Firebase credentials"
    echo "2. Installed Dart SDK"
    echo "3. Run this from the quickgas directory"
    exit 1
fi
echo ""
echo "Done! Firebase config files have been generated."
