import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:transport/app/core/theme/app_colors.dart';
import 'package:transport/widgets/app_text.dart';

/// Displays the selected proof-of-delivery document and exposes only the
/// deletion interaction required by its parent screen.
class ProofOfDeliveryPreview extends StatelessWidget {
  const ProofOfDeliveryPreview({
    super.key,
    required this.bytes,
    required this.isDark,
    required this.onDelete,
  });

  final Uint8List bytes;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  AppText('Document Preview',
                      style: AppTextStyle.bodyLarge,
                      fontWeight: FontWeight.bold),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE380).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AppText('Draft',
                    style: AppTextStyle.labelMedium,
                    color: Color(0xFFBF2600),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 200,
              color: Colors.grey.shade100,
              child: Stack(
                children: [
                  Image.memory(bytes,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText('proof_of_delivery.jpg',
                                    style: AppTextStyle.bodyMedium,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    overflow: TextOverflow.ellipsis),
                                AppText('Uploaded today, 14:22 PM',
                                    style: AppTextStyle.labelMedium,
                                    color: Colors.white70),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
