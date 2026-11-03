import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Portable reading and interface fonts are bundled under their open licenses.
/// The method channel also supports isolated native preview capture.
abstract final class HolyTypography {
  static const family = 'Manrope';
  static const channel = MethodChannel('holyher/typography');
  static Map<String, dynamic>? nativeResolution;
  static Future<void> initialize() async {
    nativeResolution = {
      'source': 'Bundled open fonts',
      'reading': 'Source Serif 4',
      'interface': 'Manrope',
      'portable': true
    };
  }

  static const display = TextStyle(
      fontFamily: 'SourceSerif4',
      fontSize: 34,
      height: 39 / 34,
      fontWeight: FontWeight.w600,
      letterSpacing: -.7);
  static const heading = TextStyle(
      fontFamily: 'SourceSerif4',
      fontSize: 28,
      height: 33 / 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -.4);
  static const section = TextStyle(
      fontFamily: 'SourceSerif4',
      fontSize: 22,
      height: 27 / 22,
      fontWeight: FontWeight.w600);
  static const scripture = TextStyle(
      fontFamily: 'SourceSerif4',
      fontSize: 22,
      height: 32 / 22,
      fontWeight: FontWeight.w400);
  static const reading = TextStyle(
      fontFamily: family,
      fontSize: 20,
      height: 1.5,
      fontWeight: FontWeight.w400);
  static const body = TextStyle(
      fontFamily: family,
      fontSize: 17,
      height: 25 / 17,
      fontWeight: FontWeight.w400);
  static const action = TextStyle(
      fontFamily: family,
      fontSize: 17,
      height: 22 / 17,
      fontWeight: FontWeight.w600);
  static const supporting = TextStyle(
      fontFamily: family,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400);
  static const label = TextStyle(
      fontFamily: family,
      fontSize: 12,
      height: 16 / 12,
      fontFeatures: [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600);
}
