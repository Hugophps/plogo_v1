import 'package:flutter/material.dart';

class EnodeChargerModel {
  const EnodeChargerModel({
    required this.vendor,
    required this.brandLabel,
    required this.model,
    required this.brandColor,
  });

  final String vendor;
  final String brandLabel;
  final String model;
  final Color brandColor;

  String get optionId => '$vendor::$model';
}

const enodeChargerCatalog = <EnodeChargerModel>[
  EnodeChargerModel(
    vendor: 'WALLBOX',
    brandLabel: 'Wallbox',
    model: 'Pulsar Plus',
    brandColor: Color(0xFFF3F4FF),
  ),
  EnodeChargerModel(
    vendor: 'WALLBOX',
    brandLabel: 'Wallbox',
    model: 'Copper SB',
    brandColor: Color(0xFFF3F4FF),
  ),
  EnodeChargerModel(
    vendor: 'TESLA',
    brandLabel: 'Tesla',
    model: 'Wall Connector (Gen 3)',
    brandColor: Color(0xFFE5F6FF),
  ),
  EnodeChargerModel(
    vendor: 'ZAPTEC',
    brandLabel: 'Zaptec',
    model: 'Go',
    brandColor: Color(0xFFE8FFF2),
  ),
  EnodeChargerModel(
    vendor: 'SCHNEIDER',
    brandLabel: 'Schneider Electric',
    model: 'EVlink Pro AC',
    brandColor: Color(0xFFEFF8FF),
  ),
];
