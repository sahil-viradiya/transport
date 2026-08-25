import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService().init();
  });

  test('starts logged out with an empty owner key', () async {
    final s = await SessionService(storage: storage).init();
    expect(s.isLoggedIn, false);
    expect(s.ownerKey, '');
  });

  test('setSession persists identity and normalises the phone', () async {
    final s = await SessionService(storage: storage).init();
    await s.setSession(phone: '+91 98765 43210', name: 'Ramesh', role: 'owner');

    expect(s.ownerKey, '+919876543210');
    expect(s.isLoggedIn, true);
    expect(s.isAdmin, false);
  });

  test('a fresh instance restores the session from storage', () async {
    final first = await SessionService(storage: storage).init();
    await first.setSession(phone: '+919876543210', name: 'Ramesh');

    final restored = await SessionService(storage: storage).init();
    expect(restored.ownerKey, '+919876543210');
    expect(restored.name.value, 'Ramesh');
    expect(restored.isLoggedIn, true);
  });

  test('admin role is detected', () async {
    final s = await SessionService(storage: storage).init();
    await s.setSession(phone: '+919999999999', role: 'admin');
    expect(s.isAdmin, true);
  });

  test('clear() fully logs the user out', () async {
    final s = await SessionService(storage: storage).init();
    await s.setSession(phone: '+919876543210', name: 'Ramesh');

    await s.clear();
    expect(s.isLoggedIn, false);
    expect(s.ownerKey, '');
    expect(s.name.value, '');
  });
}
