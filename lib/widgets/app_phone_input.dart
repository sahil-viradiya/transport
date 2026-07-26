import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:transport/app/core/theme/app_colors.dart';
import 'package:transport/widgets/app_text.dart';

class CountryInfo {
  final String flag;
  final String dialCode;
  final String name;
  final int minLength;
  final int maxLength;

  const CountryInfo({
    required this.flag,
    required this.dialCode,
    required this.name,
    this.minLength = 7,
    this.maxLength = 11,
  });
}

class AppPhoneInput extends StatelessWidget {
  static const List<CountryInfo> supportedCountries = [
    CountryInfo(flag: '🇮🇳', dialCode: '+91', name: 'India', minLength: 10, maxLength: 10),
    CountryInfo(flag: '🇺🇸', dialCode: '+1', name: 'United States', minLength: 10, maxLength: 10),
    CountryInfo(flag: '🇬🇧', dialCode: '+44', name: 'United Kingdom', minLength: 10, maxLength: 11),
    CountryInfo(flag: '🇦🇪', dialCode: '+971', name: 'United Arab Emirates', minLength: 9, maxLength: 9),
    CountryInfo(flag: '🇪🇸', dialCode: '+34', name: 'Spain', minLength: 9, maxLength: 9),
    CountryInfo(flag: '🇲🇽', dialCode: '+52', name: 'Mexico', minLength: 10, maxLength: 10),
    CountryInfo(flag: '🇨🇦', dialCode: '+1', name: 'Canada', minLength: 10, maxLength: 10),
    CountryInfo(flag: '🇸🇦', dialCode: '+966', name: 'Saudi Arabia', minLength: 9, maxLength: 9),
    CountryInfo(flag: '🇩🇪', dialCode: '+49', name: 'Germany', minLength: 10, maxLength: 11),
  ];

  final TextEditingController controller;
  final String selectedDialCode;
  final ValueChanged<String> onCountryChanged;
  final String? Function(String?)? validator;

  const AppPhoneInput({
    super.key,
    required this.controller,
    required this.selectedDialCode,
    required this.onCountryChanged,
    this.validator,
  });

  CountryInfo get _selectedCountry =>
      supportedCountries.firstWhere(
        (c) => c.dialCode == selectedDialCode,
        orElse: () => supportedCountries.first,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppColors.border,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Country Selector Dropdown
          PopupMenuButton<CountryInfo>(
            onSelected: (country) => onCountryChanged(country.dialCode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedCountry.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 6),
                  AppText(
                    _selectedCountry.dialCode,
                    style: AppTextStyle.bodyMedium,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => supportedCountries
                .map(
                  (c) => PopupMenuItem<CountryInfo>(
                    value: c,
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        AppText(
                          c.name,
                          style: AppTextStyle.bodyMedium,
                          fontWeight: FontWeight.w600,
                        ),
                        const Spacer(),
                        AppText(
                          c.dialCode,
                          style: AppTextStyle.labelMedium,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: isDark ? Colors.white24 : AppColors.border,
          ),

          const SizedBox(width: 12),

          // Phone Number Input Field
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'phone_hint'.tr,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : AppColors.textHint,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              validator: validator ??
                  (val) {
                    final digits = (val ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.isEmpty) {
                      return 'phone_required'.tr;
                    }
                    if (digits.length < _selectedCountry.minLength ||
                        digits.length > _selectedCountry.maxLength) {
                      return 'invalid_phone'.tr;
                    }
                    return null;
                  },
            ),
          ),
        ],
      ),
    );
  }
}
