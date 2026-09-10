import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session tokens in platform-encrypted storage.
///
/// Tokens are credentials, so they go to the Keychain / EncryptedSharedPreferences
/// rather than `SharedPreferences`. Only the tokens are stored — the account
/// itself is re-fetched from `/auth/me` on launch, so a role or status changed
/// on the server takes effect the next time the app opens rather than being
/// pinned to whatever was cached at sign-in.
class TokenStorage {
  const TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'foodloop.auth.access_token';
  static const _refreshKey = 'foodloop.auth.refresh_token';

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

final _secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Lives in `core/` rather than the auth feature because the networking layer
/// needs it too: the interceptor that attaches the bearer token cannot depend
/// on a feature without creating an import cycle.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(_secureStorageProvider)),
);
