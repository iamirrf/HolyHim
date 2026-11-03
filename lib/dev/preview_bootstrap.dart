import 'dart:io';
import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holyher/core/constants/app_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holyher/core/theme/app_theme.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/dev/preview_fixtures.dart';
import 'package:holyher/dev/preview_automation.dart';

Future<void> runPreview({String entrypoint = 'tool/preview_main.dart'}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await HolyTypography.initialize();
  await HolyMark.prepare();
  final args = await HolyTypography.channel
          .invokeListMethod<String>('previewArguments') ??
      [];
  String argument(String name, String fallback) =>
      args
          .where((v) => v.startsWith('--holyher-$name='))
          .firstOrNull
          ?.split('=')
          .last ??
      fallback;
  final route = argument('preview', 'A-welcome'),
      scale = double.tryParse(argument('scale', '1')) ?? 1,
      motion = argument('motion', 'true') == 'true';
  final session =
      argument('session', 'default').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  final readyName = session == 'default'
      ? 'preview-ready.json'
      : 'preview-ready-$session.json';
  final errorsName = session == 'default'
      ? 'preview-errors.txt'
      : 'preview-errors-$session.txt';
  final orientation = argument('orientation', 'portrait'),
      viewport = argument('viewport', 'full');
  await SystemChrome.setPreferredOrientations(orientation == 'landscape'
      ? [DeviceOrientation.landscapeLeft]
      : [DeviceOrientation.portraitUp]);
  await Future<void>.delayed(const Duration(milliseconds: 400));
  final specimen =
      await HolyTypography.channel.invokeMethod<dynamic>('specimen');
  if (specimen != null) {
    await File('${Directory.systemTemp.path}/native-rounded-specimen.png')
        .writeAsBytes(List<int>.from(specimen));
  }
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    File('${Directory.systemTemp.path}/$errorsName').writeAsStringSync(
        '$route: ${details.exceptionAsString()}\n',
        mode: FileMode.append);
  };
  final timings = <FrameTiming>[];
  SchedulerBinding.instance.addTimingsCallback((batch) {
    timings.addAll(batch);
    if (timings.length > 6000) timings.removeRange(0, timings.length - 6000);
  });
  final theme = argument('theme', 'pearl');
  final fixture = PreviewFixture(route, theme: theme), screen = fixture.build();
  runApp(ProviderScope(
      overrides: fixture.overrides,
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(theme: theme),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: !motion),
              child: BlushBackdrop(child: child!)),
          home: screen)));
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    if (viewport == 'split') {
      await HolyTypography.channel.invokeMethod<void>(
          'previewViewport', {'width': 375.0, 'height': 1000.0});
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    timings.clear();
    try {
      await PreviewAutomation.run(
          route, view.physicalSize / view.devicePixelRatio,
          failWrites: () => fixture.store.failWrites = true);
    } catch (error) {
      File('${Directory.systemTemp.path}/$errorsName')
          .writeAsStringSync('$route action: $error\n', mode: FileMode.append);
    }
    await File('${Directory.systemTemp.path}/$readyName')
        .writeAsString(jsonEncode({
      'route': route,
      'theme': theme,
      'session': session,
      'runtimeMode': kProfileMode
          ? 'profile'
          : kReleaseMode
              ? 'release'
              : 'debug',
      'platform': Platform.operatingSystemVersion,
      'frameTimings': summarizeTimings(timings),
      'logicalWidth': view.physicalSize.width / view.devicePixelRatio,
      'logicalHeight': view.physicalSize.height / view.devicePixelRatio,
      'pixelWidth': view.physicalSize.width,
      'pixelHeight': view.physicalSize.height,
      'devicePixelRatio': view.devicePixelRatio,
      'textScale': scale,
      'reduceMotion': !motion,
      'build':
          '${AppConstants.versionName} (${AppConstants.buildNumber}) local redesign preview',
      'orientation': orientation,
      'viewport': viewport == 'split'
          ? 'UIKit hosted narrow iPad viewport; system Split View requires manual verification'
          : 'full native window',
      'font': HolyTypography.nativeResolution,
      'entrypoint': entrypoint,
      'bootstrap': 'lib/dev/preview_bootstrap.dart',
      'fixture': 'lib/dev/preview_fixtures.dart',
      'events': PreviewAutomation.events
    }));
  });
}

Map<String, Object> summarizeTimings(List<FrameTiming> frames) {
  int percentile(List<int> values, double p) {
    if (values.isEmpty) return 0;
    values.sort();
    return values[((values.length - 1) * p).round()];
  }

  final build = frames.map((f) => f.buildDuration.inMicroseconds).toList(),
      raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList();
  return {
    'sampleCount': frames.length,
    'buildUsP50': percentile(build, .5),
    'buildUsP95': percentile(build, .95),
    'buildUsMax': percentile(build, 1),
    'rasterUsP50': percentile(raster, .5),
    'rasterUsP95': percentile(raster, .95),
    'rasterUsMax': percentile(raster, 1),
    'samplesOver16667Us': frames
        .where((f) =>
            f.buildDuration.inMicroseconds > 16667 ||
            f.rasterDuration.inMicroseconds > 16667)
        .length,
    'input':
        'QA-generated Flutter pointer events; manual touch feel remains a separate check',
    'samples': [
      for (final f in frames)
        [f.buildDuration.inMicroseconds, f.rasterDuration.inMicroseconds]
    ]
  };
}
