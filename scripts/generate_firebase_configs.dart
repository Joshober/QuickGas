import 'dart:io';

void main() async {
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print('Error: .env file not found');
    exit(1);
  }

  final envContent = await envFile.readAsString();
  final envMap = <String, String>{};
  
  for (final line in envContent.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      envMap[key] = value;
    }
  }

  _generateAndroidConfig(envMap);
  _generateIOSConfig(envMap);
  print('Firebase configuration files generated successfully!');
}

void _generateAndroidConfig(Map<String, String> env) {
  final apiKey = env['FIREBASE_ANDROID_API_KEY'] ?? '';
  final projectNumber = env['FIREBASE_PROJECT_NUMBER'] ?? '';
  final projectId = env['FIREBASE_PROJECT_ID'] ?? '';
  final packageName = env['FIREBASE_ANDROID_PACKAGE_NAME'] ?? '';
  final appId = env['FIREBASE_ANDROID_APP_ID'] ?? '';

  if (apiKey.isEmpty || projectNumber.isEmpty || projectId.isEmpty || 
      packageName.isEmpty || appId.isEmpty) {
    print('Warning: Missing required Android Firebase env variables');
    print('Required: FIREBASE_ANDROID_API_KEY, FIREBASE_PROJECT_NUMBER, FIREBASE_PROJECT_ID, FIREBASE_ANDROID_PACKAGE_NAME, FIREBASE_ANDROID_APP_ID');
    return;
  }

  final storageBucket = env['FIREBASE_STORAGE_BUCKET'] ?? '$projectId.firebasestorage.app';
  final databaseUrl = env['FIREBASE_DATABASE_URL'] ?? 'https://$projectId-default-rtdb.firebaseio.com';
  
  final jsonContent = '''
{
  "project_info": {
    "project_number": "$projectNumber",
    "firebase_url": "$databaseUrl",
    "project_id": "$projectId",
    "storage_bucket": "$storageBucket"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "$appId",
        "android_client_info": {
          "package_name": "$packageName"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "$apiKey"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
''';

  final outputFile = File('android/app/google-services.json');
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(jsonContent);
  print('Generated: android/app/google-services.json');
}

void _generateIOSConfig(Map<String, String> env) {
  final apiKey = env['FIREBASE_IOS_API_KEY'] ?? '';
  final projectNumber = env['FIREBASE_PROJECT_NUMBER'] ?? '';
  final projectId = env['FIREBASE_PROJECT_ID'] ?? '';
  final bundleId = env['FIREBASE_IOS_BUNDLE_ID'] ?? '';
  final appId = env['FIREBASE_IOS_APP_ID'] ?? '';
  final databaseUrl = env['FIREBASE_DATABASE_URL'] ?? '';
  final storageBucket = env['FIREBASE_STORAGE_BUCKET'] ?? '';

  if (apiKey.isEmpty || projectNumber.isEmpty || projectId.isEmpty || 
      bundleId.isEmpty || appId.isEmpty) {
    print('Warning: Missing required iOS Firebase env variables');
    print('Required: FIREBASE_IOS_API_KEY, FIREBASE_PROJECT_NUMBER, FIREBASE_PROJECT_ID, FIREBASE_IOS_BUNDLE_ID, FIREBASE_IOS_APP_ID');
    return;
  }

  final dbUrl = databaseUrl.isNotEmpty 
      ? databaseUrl 
      : 'https://$projectId-default-rtdb.firebaseio.com';
  final storage = storageBucket.isNotEmpty 
      ? storageBucket 
      : '$projectId.firebasestorage.app';

  final plistContent = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>$apiKey</string>
	<key>GCM_SENDER_ID</key>
	<string>$projectNumber</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>$bundleId</string>
	<key>PROJECT_ID</key>
	<string>$projectId</string>
	<key>STORAGE_BUCKET</key>
	<string>$storage</string>
	<key>IS_ADS_ENABLED</key>
	<false></false>
	<key>IS_ANALYTICS_ENABLED</key>
	<false></false>
	<key>IS_APPINVITE_ENABLED</key>
	<true></true>
	<key>IS_GCM_ENABLED</key>
	<true></true>
	<key>IS_SIGNIN_ENABLED</key>
	<true></true>
	<key>GOOGLE_APP_ID</key>
	<string>$appId</string>
	<key>DATABASE_URL</key>
	<string>$dbUrl</string>
</dict>
</plist>
''';

  final outputFile = File('ios/Runner/GoogleService-Info.plist');
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(plistContent);
  print('Generated: ios/Runner/GoogleService-Info.plist');
}
