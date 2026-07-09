import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/firebase_service.dart';
import '../../../data/services/session_service.dart';
import '../../../../widgets/dialogs/app_snackbar.dart';
import '../../../../widgets/dialogs/app_popup.dart';

/// Full detail of a single expense claim. Admins can approve/reject it right
/// here (only while it's still Pending); drivers see it read-only.
class ExpenseDetailController extends GetxController {
  final _fb = Get.find<FirebaseService>();
  final _session = Get.find<SessionService>();

  String expenseId = '';
  final RxBool isLoading = true.obs;
  final RxBool isActing = false.obs;
  final Rxn<Map<String, dynamic>> expense = Rxn<Map<String, dynamic>>();

  bool get isAdmin => _session.isAdmin;
  String get status => (expense.value?['status'] ?? 'Pending').toString();

  /// Admin + still pending = actionable.
  bool get canAct => isAdmin && status == 'Pending';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    expenseId = (args is Map ? args['id']?.toString() : args?.toString()) ?? '';
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      if (expenseId.isNotEmpty) {
        expense.value = await _fb.getExpense(expenseId);
      }
    } catch (_) {}
    isLoading.value = false;
  }

  Future<void> approve() async {
    if (!canAct || isActing.value) return;
    isActing.value = true;
    AppPopup.showLoading(message: 'Approving expense...');
    try {
      await _fb.approveExpenseById(expenseId, adminName: _session.name.value);
      await load();
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Expense Approved ✅',
          message: 'The driver has been notified.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    } finally {
      isActing.value = false;
    }
  }

  void promptReject() {
    if (!canAct) return;
    final reasonCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Expense?',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Get.back();
              _reject(reasonCtrl.text.trim());
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _reject(String reason) async {
    if (!canAct || isActing.value) return;
    isActing.value = true;
    AppPopup.showLoading(message: 'Rejecting expense...');
    try {
      await _fb.rejectExpenseById(expenseId,
          reason: reason, adminName: _session.name.value);
      await load();
      AppPopup.hideLoading();
      AppSnackBar.showInfo(
          title: 'Expense Rejected', message: 'The driver has been notified.');
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Error', message: e.toString());
    } finally {
      isActing.value = false;
    }
  }
}
