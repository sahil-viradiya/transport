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

  @override
  void onInit() {
    super.onInit();
    loadExpenses();
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
      final amtStr = (exp['amount'] as String).replaceAll(RegExp(r'[^\d]'), '');
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

  Future<void> submitExpense(Map<String, dynamic> expenseData) async {
    AppPopup.showLoading(message: 'Submitting Claim...');
    try {
      await _firebaseService.saveExpense(expenseData);
      AppPopup.hideLoading();
      AppSnackBar.showSuccess(title: 'Claim Submitted', message: 'Your expense claim has been logged.');
      await loadExpenses();
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(title: 'Submission Failed', message: e.toString());
    }
  }
}
