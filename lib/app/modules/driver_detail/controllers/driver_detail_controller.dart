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
  final RxList<Map<String, dynamic>> expenses = <Map<String, dynamic>>[].obs;

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
        final prof = Map<String, dynamic>.from(await _fb.getDriverProfile(phone));
        final trips = await _fb.getTripsForOwner(phone);
        final active = trips.firstWhereOrNull((t) => t.isActive);
        if (active != null) {
          activeTrip.value = await _fb.getTripData(active.id);
          activeTrip.value?['id'] = active.id;
        }

        // Vehicle fallback chain: profile → active trip's truck → any truck
        // registered against this driver in the trucks collection.
        if ((prof['vehicleNo'] ?? '').toString().trim().isEmpty) {
          final fromTrip = (activeTrip.value?['truckNo'] ?? '').toString();
          if (fromTrip.isNotEmpty) {
            prof['vehicleNo'] = fromTrip;
          } else {
            final trucks = await _fb.getTrucksForOwner(phone);
            if (trucks.isNotEmpty) {
              prof['vehicleNo'] = (trucks.first['truckNo'] ?? '').toString();
              prof['vehicleModel'] =
                  prof['vehicleModel'] ?? trucks.first['model'];
            }
          }
        }
        profile.value = prof;

        // This driver's expense claims (admin can see amount + status).
        final exp = await _fb.getExpensesForDriver(phone);
        exp.sort((a, b) =>
            (b['id'] ?? '').toString().compareTo((a['id'] ?? '').toString()));
        expenses.assignAll(exp);
      }
    } catch (_) {}
    isLoading.value = false;
  }
}
