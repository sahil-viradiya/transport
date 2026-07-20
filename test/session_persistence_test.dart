import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('session survives an app restart (persisted to storage)', () async {
    SharedPreferences.setMockInitialValues({});

    // --- first launch: user logs in ---
    final storage1 = await StorageService().init();
    final session1 = SessionService(storage: storage1);
    await session1.init();
    expect(session1.isLoggedIn, isFalse, reason: 'fresh install = logged out');

    await session1.setSession(
        phone: '+91 98765 43210', name: 'Yash', role: 'admin');
    expect(session1.isLoggedIn, isTrue);
    expect(session1.ownerKey, '919876543210');

    // --- app restarted: brand new service instances, same storage ---
    final storage2 = await StorageService().init();
    final session2 = SessionService(storage: storage2);
    await session2.init();

    expect(session2.isLoggedIn, isTrue,
        reason: 'user must NOT have to log in again after a restart');
    expect(session2.ownerKey, '919876543210');
    expect(session2.isAdmin, isTrue, reason: 'role must persist too');
  });

  test('logout clears the session', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService().init();
    final session = SessionService(storage: storage);
    await session.init();
    await session.setSession(phone: '+919876543210', role: 'driver');
    expect(session.isLoggedIn, isTrue);

    await session.clear();
    expect(session.isLoggedIn, isFalse);
  });
}
