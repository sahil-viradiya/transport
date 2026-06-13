import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';
import 'package:transport/app/modules/dashboard/controllers/dashboard_controller.dart';
import '../../../data/services/firebase_service.dart';

class ProfileController extends GetxController {
  // Tab control: 0 = Profile Details, 1 = Documents
  final RxInt activeSubTab = 0.obs;

  // Driver Information matching Rajesh Kumar (Right Screen)
  final RxString licenseNo = 'DL-IND-8829310'.obs;
  final RxString licenseClass = 'Heavy Transport (HTV)'.obs;
  final RxString licenseExpires = 'Oct 2028'.obs;
  final RxString safetyRating = '4.9'.obs;
  final RxString kmDriven = '12k+'.obs;
  final RxString employer = 'Northway Logistics Ltd.'.obs;
  final RxString fleetHub = 'Gurgaon-Sector 45'.obs;
  final RxString appVersion = 'v4.2.0 (Build 902)'.obs;

  // Emergency Contact Details (Mutable)
  final RxString emergencyContactName = 'Sunita Kumar'.obs;
  final RxString emergencyRelation = 'Wife'.obs;
  final RxString emergencyPhone = '+91 98765 43210'.obs;

  // Document management list (Left Screen)
  final RxList<DriverDocumentModel> documents = <DriverDocumentModel>[
    DriverDocumentModel(
      title: 'Driving License',
      subtitle: 'HCV Class Authority',
      expiryDate: '12 Oct 2026',
      status: 'Valid',
      statusMsg: '842 Days Left',
      icon: Icons.badge_outlined,
    ),
    DriverDocumentModel(
      title: 'National ID Card',
      subtitle: 'Aadhar Card / PAN',
      expiryDate: '01 Jan 2024',
      status: 'Expired',
      statusMsg: 'Expired',
      icon: Icons.contact_mail_outlined,
    ),
    DriverDocumentModel(
      title: 'Company ID',
      subtitle: 'Logistics Corp ID: 9012',
      expiryDate: 'Indefinite',
      status: 'Active',
      statusMsg: 'Authorized',
      icon: Icons.business_center_outlined,
    ),
  ].obs;

  @override
  void onInit() {
    super.onInit();
    loadProfileFromFirebase();
  }

  Future<void> loadProfileFromFirebase() async {
    try {
      final firebaseService = Get.find<FirebaseService>();
      final profile = await firebaseService.getDriverProfile();
      if (profile.isNotEmpty) {
        emergencyContactName.value = profile['name'] ?? 'Sunita Kumar';
        emergencyRelation.value = profile['relation'] ?? 'Wife';
        emergencyPhone.value = profile['phone'] ?? '+91 98765 43210';
        licenseNo.value = profile['licenseNo'] ?? 'DL-IND-8829310';
        licenseClass.value = profile['licenseClass'] ?? 'Heavy Transport (HTV)';
        licenseExpires.value = profile['licenseExpires'] ?? 'Oct 2028';
        safetyRating.value = profile['safetyRating'] ?? '4.9';
        kmDriven.value = profile['kmDriven'] ?? '12k+';
        employer.value = profile['employer'] ?? 'Northway Logistics Ltd.';
        fleetHub.value = profile['fleetHub'] ?? 'Gurgaon-Sector 45';
        
        final docsList = profile['documents'] as List?;
        if (docsList != null) {
          final list = docsList.map((d) {
            IconData icon = Icons.assignment_outlined;
            if (d['icon'] == 'badge') icon = Icons.badge_outlined;
            if (d['icon'] == 'contact_mail') icon = Icons.contact_mail_outlined;
            if (d['icon'] == 'business') icon = Icons.business_center_outlined;
            return DriverDocumentModel(
              title: d['title'] ?? '',
              subtitle: d['subtitle'] ?? '',
              expiryDate: d['expiryDate'] ?? '',
              status: d['status'] ?? '',
              statusMsg: d['statusMsg'] ?? '',
              icon: icon,
            );
          }).toList();
          documents.assignAll(list);
        }
      }
    } catch (_) {}
  }

  // Toggle switch tabs
  void selectSubTab(int index) {
    activeSubTab.value = index;
  }

  // Edit Emergency Contact dialog
  void showEditEmergencyContactDialog() {
    final nameEditController = TextEditingController(text: emergencyContactName.value);
    final relationEditController = TextEditingController(text: emergencyRelation.value);
    final phoneEditController = TextEditingController(text: emergencyPhone.value);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Emergency Contact', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameEditController,
                decoration: const InputDecoration(labelText: 'Contact Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationEditController,
                decoration: const InputDecoration(labelText: 'Relation'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneEditController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameEditController.text.isNotEmpty && phoneEditController.text.isNotEmpty) {
                emergencyContactName.value = nameEditController.text;
                emergencyRelation.value = relationEditController.text;
                emergencyPhone.value = phoneEditController.text;
                try {
                  final firebaseService = Get.find<FirebaseService>();
                  await firebaseService.updateEmergencyContact(
                    nameEditController.text,
                    relationEditController.text,
                    phoneEditController.text,
                  );
                } catch (_) {}
                Get.back();
                AppSnackBar.showSuccess(
                  title: 'Contact Updated',
                  message: 'Emergency contact updated successfully.',
                );
              } else {
                AppSnackBar.showWarning(
                  title: 'Incomplete Details',
                  message: 'Please fill name and phone number fields.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Simulate Document Renew flow
  void renewDocument(String docTitle) {
    AppPopup.showConfirmation(
      title: 'RENEW DOCUMENT',
      description: 'Would you like to initiate the renewal request for "$docTitle" on the Ministry portal?',
      confirmText: 'Renew Now',
      cancelText: 'Cancel',
      onConfirm: () {
        AppSnackBar.showSuccess(
          title: 'Renewal Initiated',
          message: 'Your request for "$docTitle" has been submitted for verification.',
        );
      },
    );
  }

  // Simulate Preview PDF/ID Card
  void previewDocument(String docTitle) {
    AppSnackBar.showInfo(
      title: 'Loading Preview',
      message: 'Fetching digital copy of your "$docTitle"...',
    );
  }

  // Simulate Digital ID Card download
  void downloadDigitalId() {
    AppSnackBar.showSuccess(
      title: 'Digital ID Ready',
      message: 'Logistics Digital ID download completed successfully.',
    );
  }

  // Upload/Add new document
  void showAddNewDocumentDialog() {
    final titleEditController = TextEditingController();
    final subtitleEditController = TextEditingController();
    final expiryEditController = TextEditingController();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Upload New Document', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleEditController,
                decoration: const InputDecoration(labelText: 'Document Name (e.g. Permit, RC)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleEditController,
                decoration: const InputDecoration(labelText: 'Subtitle/Authority'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryEditController,
                decoration: const InputDecoration(labelText: 'Expiry Date (e.g. 12 Oct 2027)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleEditController.text.isNotEmpty) {
                final newDoc = DriverDocumentModel(
                  title: titleEditController.text,
                  subtitle: subtitleEditController.text.isNotEmpty ? subtitleEditController.text : 'Uploaded Scans',
                  expiryDate: expiryEditController.text.isNotEmpty ? expiryEditController.text : 'Indefinite',
                  status: 'Valid',
                  statusMsg: 'Under Review',
                  icon: Icons.assignment_turned_in_outlined,
                );
                documents.add(newDoc);
                
                try {
                  final firebaseService = Get.find<FirebaseService>();
                  final listMap = documents.map((d) {
                    String iconKey = 'assignment';
                    if (d.icon == Icons.badge_outlined) iconKey = 'badge';
                    if (d.icon == Icons.contact_mail_outlined) iconKey = 'contact_mail';
                    if (d.icon == Icons.business_center_outlined) iconKey = 'business';
                    return {
                      'title': d.title,
                      'subtitle': d.subtitle,
                      'expiryDate': d.expiryDate,
                      'status': d.status,
                      'statusMsg': d.statusMsg,
                      'icon': iconKey,
                    };
                  }).toList();
                  await firebaseService.updateDriverDocuments(listMap);
                } catch (_) {}
                
                Get.back();
                AppSnackBar.showSuccess(
                  title: 'Document Uploaded',
                  message: 'Document "${titleEditController.text}" uploaded successfully and is under review.',
                );
              } else {
                AppSnackBar.showWarning(
                  title: 'Incomplete Details',
                  message: 'Please fill out the document name.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  // Upload/Change driver profile avatar picture
  Future<void> changeAvatar() async {
    final List<String> presetAvatars = [
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop',
    ];

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Profile Picture', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Choose from predefined avatars:', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presetAvatars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () async {
                      Get.back();
                      await _saveAvatarUrl(presetAvatars[index]);
                      AppSnackBar.showSuccess(
                        title: 'Avatar Updated',
                        message: 'Profile picture has been updated successfully.',
                      );
                    },
                    child: CircleAvatar(
                      radius: 32,
                      backgroundImage: NetworkImage(presetAvatars[index]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
              onPressed: () async {
                Get.back();
                await _pickAvatarFromPicker(ImageSource.gallery);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Take Photo'),
              onPressed: () async {
                Get.back();
                await _pickAvatarFromPicker(ImageSource.camera);
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatarFromPicker(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        AppPopup.showLoading(message: 'Uploading photo...');
        final firebaseService = Get.find<FirebaseService>();
        final downloadUrl = await firebaseService.uploadDriverAvatar(pickedFile.path);
        await _saveAvatarUrl(downloadUrl);
        AppPopup.hideLoading();
        
        if (downloadUrl.startsWith('http')) {
          AppSnackBar.showSuccess(
            title: 'Avatar Updated',
            message: 'Profile picture has been uploaded successfully.',
          );
        } else {
          AppSnackBar.showWarning(
            title: 'Avatar Updated (Local Fallback)',
            message: 'Firebase Storage bucket not initialized. Picture saved locally on device.',
          );
        }
      }
    } catch (e) {
      AppPopup.hideLoading();
      AppSnackBar.showError(
        title: 'Upload Failed',
        message: 'Could not upload profile picture. Try again.',
      );
    }
  }

  Future<void> _saveAvatarUrl(String url) async {
    try {
      final firebaseService = Get.find<FirebaseService>();
      await firebaseService.updateDriverProfile({
        'avatarUrl': url,
      });

      // Sync with dashboard and profile loaders
      final dashboardController = Get.find<DashboardController>();
      dashboardController.avatarUrl.value = url;
    } catch (_) {}
  }

  // Dialog allowing updates to Driver Name, Phone, Vehicle Number, and Vehicle Model.
  void showEditProfileDialog() {
    final dashboardController = Get.find<DashboardController>();
    final nameEditController = TextEditingController(text: dashboardController.driverName.value);
    final phoneEditController = TextEditingController(text: dashboardController.driverPhone.value);
    final vehicleNoEditController = TextEditingController(text: dashboardController.vehicleNo.value);
    final vehicleModelEditController = TextEditingController(text: dashboardController.vehicleModel.value);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Driver Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameEditController,
                decoration: const InputDecoration(labelText: 'Driver Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneEditController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleNoEditController,
                decoration: const InputDecoration(labelText: 'Vehicle Number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: vehicleModelEditController,
                decoration: const InputDecoration(labelText: 'Vehicle Model'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameEditController.text.isNotEmpty &&
                  phoneEditController.text.isNotEmpty &&
                  vehicleNoEditController.text.isNotEmpty &&
                  vehicleModelEditController.text.isNotEmpty) {
                
                AppPopup.showLoading(message: 'Saving changes...');
                try {
                  final firebaseService = Get.find<FirebaseService>();
                  await firebaseService.updateDriverProfile({
                    'driverName': nameEditController.text,
                    'driverPhone': phoneEditController.text,
                    'vehicleNo': vehicleNoEditController.text,
                    'vehicleModel': vehicleModelEditController.text,
                  });

                  // Sync to controllers
                  dashboardController.driverName.value = nameEditController.text;
                  dashboardController.driverPhone.value = phoneEditController.text;
                  dashboardController.vehicleNo.value = vehicleNoEditController.text;
                  dashboardController.vehicleModel.value = vehicleModelEditController.text;
                  
                  AppPopup.hideLoading();
                  Get.back();
                  AppSnackBar.showSuccess(
                    title: 'Profile Updated',
                    message: 'Driver profile details updated successfully.',
                  );
                } catch (_) {
                  AppPopup.hideLoading();
                  AppSnackBar.showError(
                    title: 'Save Failed',
                    message: 'An error occurred while saving profile details.',
                  );
                }
              } else {
                AppSnackBar.showWarning(
                  title: 'Incomplete Details',
                  message: 'Please fill all profile fields.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class DriverDocumentModel {
  final String title;
  final String subtitle;
  final String expiryDate;
  final String status; // 'Valid', 'Expired', 'Active'
  final String statusMsg;
  final IconData icon;

  DriverDocumentModel({
    required this.title,
    required this.subtitle,
    required this.expiryDate,
    required this.status,
    required this.statusMsg,
    required this.icon,
  });
}
