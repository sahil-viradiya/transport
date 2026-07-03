import 'package:get/get.dart';
import '../../../data/services/firebase_service.dart';

/// Loads a single driver's full details (profile, availability, current trip)
/// by phone, for the admin's driver detail screen.
class DriverDetailController extends GetxController {
  final _fb = Get.find<FirebaseService>();

  String phone = '';
  final RxBool isLoading = true.obs;
  final Rxn<Map<String, dynamic>> user = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> profile = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> activeTrip = Rxn<Map<String, dynamic>>();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    phone = (args is Map ? args['phone']?.toString() : args?.toString()) ?? '';
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      if (phone.isNotEmpty) {
        user.value = await _fb.getUserData(phone);
        profile.value = await _fb.getDriverProfile(phone);
        final trips = await _fb.getTripsForOwner(phone);
        final active = trips.firstWhereOrNull((t) => t.isActive);
        if (active != null) {
          activeTrip.value = await _fb.getTripData(active.id);
          activeTrip.value?['id'] = active.id;
        }
      }
    } catch (_) {}
    isLoading.value = false;
  }
}
