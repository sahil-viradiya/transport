import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/session_service.dart';
import '../../../../widgets/dialogs/app_snackbar.dart';
import '../../../../widgets/dialogs/app_popup.dart';

/// Renders a single notification's context (trip or expense) and lets the user
/// perform the SAME approve/reject action that's available on the bell tile —
/// so every notification is actionable both inline and on its detail page.
class NotificationDetailController extends GetxController {
  final _fb = Get.find<FirebaseService>();
  final _session = Get.find<SessionService>();

  Map<String, dynamic> note = {};
  final RxBool isLoading = true.obs;
  final RxBool isActing = false.obs;
  final Rxn<Map<String, dynamic>> trip = Rxn<Map<String, dynamic>>();
  final Rxn<Map<String, dynamic>> expense = Rxn<Map<String, dynamic>>();

  String get type => note['type']?.toString() ?? 'info';
  String get tripId => note['tripId']?.toString() ?? '';
  String get refId => note['refId']?.toString() ?? '';
  String get title => note['title']?.toString() ?? 'Notification';
  String get body => note['body']?.toString() ?? '';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    note = (args is Map) ? Map<String, dynamic>.from(args) : {};
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      if (tripId.isNotEmpty) trip.value = await _fb.getTripData(tripId);
      if (refId.isNotEmpty && type.startsWith('expense')) {
        expense.value = await _fb.getExpense(refId);
      }
    } catch (_) {}
    isLoading.value = false;
  }

  /// '' = no action; otherwise 'load' | 'delivery' | 'expense' | 'assign'.
  String get availableAction {
    if (note['actioned'] == true) return ''; // already handled once
    switch (type) {
      case 'load_request':
        return trip.value?['status'] == 'LOAD_REQUESTED' ? 'load' : '';
      case 'delivery_request':
        return trip.value?['status'] == 'DELIVERY_REQUESTED' ? 'delivery' : '';
      case 'expense_submitted':
        return expense.value?['status'] == 'Pending' ? 'expense' : '';
      case 'trip_assigned':
        return trip.value?['status'] == 'PENDING' ? 'assign' : '';
      default:
        return '';
    }
  }

  Future<void> approve() async {
    final action = availableAction;
    if (action.isEmpty || isActing.value) return;
    isActing.value = true;
    AppPopup.showLoading(message: 'Approving...');
    final name = _session.name.value;
    try {
      switch (action) {
        case 'load':
          await _fb.approveLoad(tripId, adminName: name);
          break;
        case 'delivery':
          await _fb.approveDelivery(tripId, adminName: name);
          break;
        case 'expense':
          await _fb.approveExpenseById(refId, adminName: name);
          break;
        case 'assign':
          await _fb.acceptTrip(tripId, driverName: name);
          break;
      }
      await _markRead();
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Approved ✅', message: 'Action completed successfully.');
      Get.back();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    } finally {
      isActing.value = false;
    }
  }

  void promptReject() {
    final action = availableAction;
    if (action.isEmpty) return;
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Get.back();
              reject(reasonCtrl.text.trim());
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> reject(String reason) async {
    final action = availableAction;
    if (action.isEmpty || isActing.value) return;
    isActing.value = true;
    AppPopup.showLoading(message: 'Rejecting...');
    final name = _session.name.value;
    try {
      switch (action) {
        case 'load':
          await _fb.rejectLoad(tripId, reason: reason, adminName: name);
          break;
        case 'delivery':
          await _fb.rejectDelivery(tripId, reason: reason, adminName: name);
          break;
        case 'expense':
          await _fb.rejectExpenseById(refId, reason: reason, adminName: name);
          break;
        case 'assign':
          await _fb.rejectTrip(tripId, reason: reason, driverName: name);
          break;
      }
      await _markRead();
      AppPopup.hideLoading();
      AppSnackBar.showInfo(title: 'Rejected', message: 'The other party is notified.');
      Get.back();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    } finally {
      isActing.value = false;
    }
  }

  Future<void> _markRead() async {
    final id = note['id']?.toString() ?? '';
    if (id.isNotEmpty) await _fb.markNotificationActioned(id);
    note['actioned'] = true;
  }
}
