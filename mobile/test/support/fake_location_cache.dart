import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodloop/core/location/location_cache.dart';
import 'package:foodloop/core/location/location_providers.dart';

/// An in-memory stand-in for [LocationCache].
///
/// The real one talks to the Keychain / EncryptedSharedPreferences through a
/// platform channel, and under a test binding that channel never answers. The
/// bounded reads and writes in [LocationCache] then sit waiting on timers that
/// are still pending when the test ends — which is the binding telling the
/// truth: nothing had answered.
///
/// Every method is overridden, so the storage handed to `super` is never
/// touched.
///
/// Test-only. Production always uses the real encrypted store.
class FakeLocationCache extends LocationCache {
  FakeLocationCache({this.stored}) : super(const FlutterSecureStorage());

  /// What a previous launch supposedly remembered. Null is the cold-start
  /// case, which is what most tests are written for.
  DeviceLocation? stored;

  /// Counts writes, so a test can prove a real fix is remembered — and that a
  /// fix read back out of the cache is not written straight back in.
  int writes = 0;

  @override
  Future<DeviceLocation?> read() async => stored;

  @override
  Future<void> write(DeviceLocation location) async {
    writes++;
    stored = location;
  }

  @override
  Future<void> clear() async => stored = null;
}
