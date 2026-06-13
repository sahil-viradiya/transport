import 'package:get/get.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';
import 'package:transport/widgets/dialogs/app_popup.dart';

class TripDetailsController extends GetxController {
  // Static arguments or loaded details matching reference (Middle Screen: Trip Details)
  final String tripId = 'TRP-882910';
  final RxString remainingDistance = '142.5 KM'.obs;
  
  // Addresses
  final String pickupAddress = 'Reliance Industries Warehouse, Sector 4, Vashi, Navi Mumbai, Maharashtra 400703';
  final String pickupContact = 'Anand Mehta';
  final String dropoffAddress = 'Amazon Fulfilment Centre (BOM7), Chakan Industrial Area, Phase II, Pune 410501';
  final String dropoffContact = 'Suresh G.';
  
  // Material Logs
  final String materialType = 'Industrial Goods';
  final String materialSubtitle = 'Steel Coils & Heavy Parts';
  final String loadWeight = '10 Tons';
  
  // Status Milestones
  final RxList<MilestoneModel> milestones = <MilestoneModel>[
    MilestoneModel(title: 'Assigned', time: 'Oct 24, 08:00 AM', isCompleted: true),
    MilestoneModel(title: 'Accepted', time: 'Oct 24, 08:15 AM', isCompleted: true),
    MilestoneModel(title: 'Started', time: 'Oct 24, 11:00 AM', isCompleted: true),
    MilestoneModel(
      title: 'In Transit',
      time: 'Oct 24, 01:30 PM',
      isCompleted: true,
      description: 'Currently at Kolhapur Plaza',
    ),
    MilestoneModel(title: 'Delivered', time: 'Expected by 05:00 PM', isCompleted: false),
  ].obs;

  // Estimated values
  final RxString estimatedTime = '2h 45m'.obs;
  final RxInt fuelConsumed = 42.obs;

  // Update Status action
  void updateStatus() {
    // If last element is not completed, complete it
    final deliveredIndex = milestones.indexWhere((m) => m.title == 'Delivered');
    if (deliveredIndex != -1 && !milestones[deliveredIndex].isCompleted) {
      milestones[deliveredIndex] = MilestoneModel(
        title: 'Delivered',
        time: 'Oct 24, 04:15 PM',
        isCompleted: true,
        description: 'Delivered to Amazon BOM7 Dock 4',
      );
      remainingDistance.value = '0.0 KM';
      estimatedTime.value = '0m';
      AppSnackBar.showSuccess(title: 'Delivered', message: 'Trip status updated to Delivered!');
    } else {
      AppSnackBar.showInfo(title: 'No Updates', message: 'Cargo has already been marked as Delivered.');
    }
  }

  // SOS button trigger
  void triggerEmergencySos() {
    AppPopup.showConfirmation(
      title: 'ACTIVATE EMERGENCY SOS',
      description: 'Do you want to broadcast your emergency coordinates for trip TRP-882910?',
      confirmText: 'Broadcast',
      cancelText: 'Cancel',
      onConfirm: () {
        AppSnackBar.showError(
          title: 'SOS ACTIVE',
          message: 'Safety dispatch and highway assistance have been alerted.',
        );
      },
    );
  }
}

class MilestoneModel {
  final String title;
  final String time;
  final bool isCompleted;
  final String? description;

  MilestoneModel({
    required this.title,
    required this.time,
    required this.isCompleted,
    this.description,
  });
}
