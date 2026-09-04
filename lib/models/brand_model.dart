import 'package:flutter/material.dart';

class BrandModel {
  final String name;
  final String discountText;
  final String logoText;
  final Color themeColor;

  BrandModel({
    required this.name,
    required this.discountText,
    required this.logoText,
    required this.themeColor,
  });
}

// TODO: Replace this mock catalog with a backend/API response model.
// This is intentionally static while the app flow is being stabilized.
final List<BrandModel> brandData = [
  BrandModel(
    name: 'Samsung',
    discountText: 'Up to 30% off',
    logoText: 'SAMSUNG',
    themeColor: const Color(0xFF1D4ED8),
  ),
  BrandModel(
    name: 'Motorola',
    discountText: 'Up to 40% off',
    logoText: 'M motorola',
    themeColor: const Color(0xFF334155),
  ),
  BrandModel(
    name: 'Oppo',
    discountText: 'Up to 35% off',
    logoText: 'oppo',
    themeColor: const Color(0xFF15803D),
  ),
  BrandModel(
    name: 'Apple',
    discountText: 'Up to 50% off',
    logoText: 'Apple',
    themeColor: const Color(0xFF111827),
  ),
];
