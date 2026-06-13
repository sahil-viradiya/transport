import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/connectivity_service.dart';
import 'package:transport/main.dart';

class MockConnectivityService extends ConnectivityService {
  @override
  Future<ConnectivityService> init() async {
    isConnected.value = true;
    return this;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Get.putAsync(() => StorageService().init());
    await Get.putAsync<ConnectivityService>(() => MockConnectivityService().init());
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('Splash Screen displays brand name', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('The Highway Authority'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
