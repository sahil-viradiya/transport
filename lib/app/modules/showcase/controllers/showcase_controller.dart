import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/data/providers/api_provider.dart';
import 'package:transport/app/data/services/storage_service.dart';
import 'package:transport/app/data/services/connectivity_service.dart';
import 'package:transport/app/core/utils/image_picker_helper.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';

class ShowcaseController extends GetxController {
  // Services
  final _storage = Get.find<StorageService>();
  final _connectivity = Get.find<ConnectivityService>();
  final _apiProvider = ApiProvider();

  // API states
  final RxString apiResponse = 'Tap "Test Successful API" or "Test Error API"'.obs;
  final RxBool isApiLoading = false.obs;

  // Button loader states
  final RxBool isBtnLoading = false.obs;

  // Input states
  final textController = TextEditingController();
  final searchController = TextEditingController();
  final otpController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  // Image states
  final RxString pickedImagePath = ''.obs;

  // Local storage states
  final RxString savedValue = 'No saved value'.obs;

  // Connectivity
  RxBool get isOnline => _connectivity.isConnected;

  @override
  void onInit() {
    super.onInit();
    // Load previously saved preference value if it exists
    final saved = _storage.read<String>('user_input_key');
    if (saved != null) {
      savedValue.value = saved;
    }
  }

  // Pick Image Helper
  Future<void> pickImage(bool fromCamera) async {
    final path = fromCamera 
        ? await ImagePickerHelper.captureImageFromCamera()
        : await ImagePickerHelper.pickImageFromGallery();
    if (path != null) {
      pickedImagePath.value = path;
      AppSnackBar.showSuccess(title: 'Success', message: 'Image loaded successfully!');
    }
  }

  // SharedPreferences Demo
  void saveToStorage() {
    if (textController.text.isNotEmpty) {
      _storage.write('user_input_key', textController.text);
      savedValue.value = textController.text;
      AppSnackBar.showSuccess(title: 'Saved', message: 'Value saved to local storage!');
    } else {
      AppSnackBar.showWarning(title: 'Validation', message: 'Please type something first.');
    }
  }

  // SharedPreferences Clear Demo
  void clearStorage() {
    _storage.remove('user_input_key');
    savedValue.value = 'No saved value';
    AppSnackBar.showInfo(title: 'Cleared', message: 'Local storage value cleared.');
  }

  // Dio API Success Request
  Future<void> fetchSuccessPost() async {
    isApiLoading.value = true;
    apiResponse.value = 'Fetching...';
    try {
      final response = await _apiProvider.get('/posts/1');
      apiResponse.value = 'Title: ${response.data['title']}\n\nBody: ${response.data['body']}';
    } catch (e) {
      apiResponse.value = 'Failed to load post. Interceptor should have popped snackbar.';
    } finally {
      isApiLoading.value = false;
    }
  }

  // Dio API Error Trigger Request
  Future<void> fetchErrorPost() async {
    isApiLoading.value = true;
    apiResponse.value = 'Triggering 404...';
    try {
      // Endpoint that doesn't exist to trigger 404 error
      await _apiProvider.get('/non-existent-endpoint');
    } catch (e) {
      apiResponse.value = 'API error occurred. Custom Error Interceptor triggered AppSnackBar.';
    } finally {
      isApiLoading.value = false;
    }
  }

  // Simulate Button loading
  void startLoadingButton() {
    isBtnLoading.value = true;
    Future.delayed(const Duration(seconds: 3), () {
      isBtnLoading.value = false;
      AppSnackBar.showInfo(title: 'Loading Finished', message: 'Demo loader completed.');
    });
  }

  @override
  void onClose() {
    textController.dispose();
    searchController.dispose();
    otpController.dispose();
    super.onClose();
  }
}
