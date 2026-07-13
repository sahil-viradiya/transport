import 'dart:async';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:transport/app/data/services/session_service.dart';
import 'package:transport/app/data/services/firebase_service.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';

class ExpensesController extends GetxController {
  final _firebaseService = Get.find<FirebaseService>();
  final _session = Get.find<SessionService>();

  final RxList<Map<String, dynamic>> expenses = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;

  final RxString totalExpenses = '₹0'.obs;
  final RxString approvedExpenses = '₹0'.obs;
  final RxString pendingExpenses = '₹0'.obs;

  StreamSubscription? _expensesSub;

  @override
  void onInit() {
    super.onInit();
    _bind();
    // Re-subscribe if the signed-in user changes.
    ever(_session.phone, (_) => _bind());
  }

  /// Live expenses for this driver, so an admin's approve/reject shows up
  /// immediately instead of waiting for a manual refresh.
  void _bind() {
    _expensesSub?.cancel();
    final phone = _session.ownerKey;
    if (phone.isEmpty) {
      expenses.clear();
      _calculateStats();
      return;
    }
    isLoading.value = true;
    _expensesSub =
        _firebaseService.watchExpensesForDriver(phone).listen((list) {
      expenses.assignAll(list);
      _calculateStats();
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);
  }

  Future<void> loadExpenses() async {
    isLoading.value = true;
    try {
      final phone = _session.ownerKey;
      if (phone.isEmpty) return;
      final fetchedExpenses = await _firebaseService.getExpensesForDriver(phone);
      expenses.assignAll(fetchedExpenses);
      _calculateStats();
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  void _calculateStats() {
    double total = 0;
    double approved = 0;
    double pending = 0;

    for (var exp in expenses) {
      // `amount` may be stored as a String ("₹1,200") or a raw number — don't
      // assume, or a numeric amount blows up the whole stats calculation.
      final amtStr =
          (exp['amount'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
      final amt = double.tryParse(amtStr) ?? 0;
      total += amt;
      if (exp['status'] == 'Approved') {
        approved += amt;
      } else {
        pending += amt;
      }
    }

    final format = (double val) {
      if (val == 0) return '₹0';
      return '₹${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    };

    totalExpenses.value = format(total);
    approvedExpenses.value = format(approved);
    pendingExpenses.value = format(pending);
  }

  /// Driver files an expense with a receipt proof. If [receiptBytes] are given
  /// they're uploaded first; then the claim is saved as Pending and every admin
  /// is notified to approve/reject.
  Future<void> submitExpense(Map<String, dynamic> expenseData,
      {Uint8List? receiptBytes}) async {
    AppPopup.showLoading(message: 'Submitting Claim...');
    try {
      final id =
          expenseData['id'] ?? 'EXP-${DateTime.now().millisecondsSinceEpoch}';
      expenseData['id'] = id;
      if (receiptBytes != null && receiptBytes.isNotEmpty) {
        expenseData['receiptUrl'] =
            await _firebaseService.uploadExpenseReceipt(id, receiptBytes);
      }
      await _firebaseService.submitTripExpense(expenseData,
          driverName: _session.name.value);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(
          title: 'Claim Submitted',
          message: 'Expense sent to admin for approval.');
      // The live stream picks the new claim up on its own.
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Submission Failed', message: e.toString());
    }
  }

  @override
  void onClose() {
    _expensesSub?.cancel();
    super.onClose();
  }
}
