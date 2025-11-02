class BackendConstants {
  static const String backendUrl = 'YOUR_BACKEND_URL_HERE';

  static String getBackendUrl() {
    const envUrl = String.fromEnvironment('BACKEND_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return backendUrl;
  }
}
