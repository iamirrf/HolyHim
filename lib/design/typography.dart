import 'package:flutter/material.dart';

class HolyTypography {
  HolyTypography._();
  static const display = TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: 40,
      height: 1.1,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2);
  static const title = TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: 28,
      height: 34 / 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -.5);
  static const verse = TextStyle(
      fontFamily: 'Lora',
      fontSize: 26,
      height: 38 / 26,
      fontWeight: FontWeight.w600,
      letterSpacing: -.35);
  static const reading = TextStyle(
      fontFamily: 'Lora',
      fontSize: 20,
      height: 31 / 20,
      fontWeight: FontWeight.w500);
  static const ui = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600);
  static const eyebrow = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2);
  static const accent = TextStyle(
      fontFamily: 'PlayfairDisplay', fontSize: 30, height: 1.2, fontWeight: FontWeight.w700);
  static const wordmark = TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: 38,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -.5);
}
