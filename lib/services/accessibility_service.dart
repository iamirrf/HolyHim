import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransparencyPreference extends Notifier<bool> {
  static const _channel = MethodChannel('holyher/accessibility');
  bool _active = true;
  @override
  bool build() {
    _active = true;
    _channel.setMethodCallHandler((call) async {
      if (_active && call.method == 'transparencyChanged') {
        state = call.arguments == true;
      }
    });
    Future.microtask(() async {
      try {
        final value = await _channel.invokeMethod<bool>('reduceTransparency');
        if (_active) state = value ?? true;
      } catch (_) {
        if (_active) state = false;
      }
    });
    ref.onDispose(() {
      _active = false;
      _channel.setMethodCallHandler(null);
    });
    return true;
  }
}

final reduceTransparencyProvider =
    NotifierProvider<TransparencyPreference, bool>(TransparencyPreference.new);
