import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lazily-initialized [SharedPreferencesWithCache] shared across the app.
/// Provides in-memory caching (like legacy SharedPreferences) with the modern
/// async API.
SharedPreferencesWithCache? _cache;

Future<SharedPreferencesWithCache> prefsCache() async {
  _cache ??= await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );
  return _cache!;
}

/// Inject a pre-created [SharedPreferencesWithCache] for testing.
/// Call [resetPrefsCache] in tearDown to clean up.
@visibleForTesting
void setMockPrefsCache(SharedPreferencesWithCache mock) {
  _cache = mock;
}

/// Reset the cached instance. Useful for hot-restart and testing.
@visibleForTesting
void resetPrefsCache() {
  _cache = null;
}
