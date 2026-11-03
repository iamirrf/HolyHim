import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:holyher/core/widgets/holy_ui.dart';
import 'package:holyher/data/units.dart';
import 'package:holyher/data/lessons.dart';

/// Sends real Flutter pointer events through the rendered route's hit testing.
/// Used by the isolated QA entry point; unavailable in the production app.
abstract final class PreviewAutomation {
  static final List<String> events = [];
  static Future<void> pause([int milliseconds = 500]) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));
  static Element? find(bool Function(Widget) predicate) {
    Element? found;
    void visit(Element element) {
      if (predicate(element.widget)) {
        final r = element.findRenderObject();
        if (r is RenderBox && r.hasSize && r.size.width > 0) found = element;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return found;
  }

  static bool hasText(String text) =>
      find((w) => w is Text && w.data == text) != null;
  static Future<void> tap(String text) async {
    final element = find((w) =>
        w is Text && w.data == text ||
        w is HolyPressable && w.label == text ||
        w is IconButton && w.tooltip == text ||
        w is PopupMenuButton<String> && w.tooltip == text);
    if (element == null) throw StateError('Preview action missing: $text');
    await Scrollable.ensureVisible(element,
        alignment: .5, duration: const Duration(milliseconds: 160));
    await pause(120);
    final box = element.findRenderObject() as RenderBox,
        point = box.localToGlobal(box.size.center(Offset.zero));
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
        pointer: 1, position: point, kind: PointerDeviceKind.touch));
    await pause(90);
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
        pointer: 1, position: point, kind: PointerDeviceKind.touch));
    events.add('tap:$text');
    await pause(750);
  }

  static Future<void> drag(Offset from, Offset to, {int duration = 600}) async {
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
        pointer: 2, position: from, kind: PointerDeviceKind.touch));
    final n = (duration / 16).ceil();
    for (var i = 1; i <= n; i++) {
      await pause(16);
      final p = Offset.lerp(from, to, i / n)!;
      final previous = Offset.lerp(from, to, (i - 1) / n)!;
      GestureBinding.instance.handlePointerEvent(PointerMoveEvent(
          pointer: 2,
          position: p,
          delta: p - previous,
          kind: PointerDeviceKind.touch,
          timeStamp: Duration(milliseconds: i * 16)));
    }
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
        pointer: 2,
        position: to,
        kind: PointerDeviceKind.touch,
        timeStamp: Duration(milliseconds: duration + 16)));
    events.add('drag:${from.dx},${from.dy}->${to.dx},${to.dy}:$duration');
    await pause(700);
  }

  static Future<void> fill(String label, String value,
      {bool keyboard = false}) async {
    final element = find((w) =>
        w is TextField &&
        (w.decoration?.labelText == label || w.decoration?.hintText == label));
    if (element == null) throw StateError('Preview field missing: $label');
    final field = element.widget as TextField;
    EditableText? editable;
    void visit(Element child) {
      if (child.widget is EditableText) editable = child.widget as EditableText;
      child.visitChildren(visit);
    }

    element.visitChildren(visit);
    final controller = field.controller ?? editable?.controller;
    controller?.text = value;
    field.onChanged?.call(value);
    if (keyboard) editable?.focusNode.requestFocus();
    await pause(700);
  }

  static Future<void> next() async {
    while (hasText('Next part')) {
      await tap('Next part');
    }
    await tap('Next');
  }

  static Future<void> run(String route, Size size,
      {VoidCallback? failWrites}) async {
    await pause(800);
    if (route.startsWith('contact:')) {
      await fill('Your email', 'reader@example.com');
      await fill(
          'Your message', 'Please help me find a saved lesson on my iPad.');
      await tap('Send message');
    }
    if (route == 'lesson:pause') await tap('Close reading');
    if (route == 'learn:future') {
      await tap('Search');
      await fill('Find a lesson', lessons[8].title);
      await tap(lessons[8].title);
    }
    if (route == 'learn:unit') await tap(unitTitles.first);
    if (route == 'learn:list') await tap('List');
    if (route == 'learn:search' || route == 'learn:search-empty') {
      await tap('Search');
      await fill('Find a lesson',
          route.endsWith('empty') ? 'no matching words' : 'peace');
    }
    if (route == 'welcome:1') await tap('Show continuity preview');
    if (route == 'welcome:2') await tap('Show saved Scripture preview');
    if (route == 'reset:sent') {
      await tap('Send reset link');
    }
    if (route == 'auth:invalid') {
      await tap('Sign in');
    }
    if (route == 'auth:visible') {
      await fill('Email', 'reader@example.com');
      await fill('Password', 'a-reading-moment');
      await tap('Show password');
    }
    if (route == 'auth:keyboard') {
      await fill('Email', 'reader@example.com', keyboard: true);
    }
    if (route == 'saved:removed' ||
        route == 'saved:undo' ||
        route == 'saved:undo-failure') {
      await tap('Verse actions');
      await tap('Remove from Saved');
      if (route == 'saved:undo-failure') failWrites?.call();
      if (route == 'saved:undo' || route == 'saved:undo-failure') {
        await tap('Undo');
      }
    }
    if (route == 'saved:search-empty') {
      await fill('Search saved lessons', 'no matching words');
    }
    if (route == 'motion:welcome') {
      await pause(4000);
      await drag(Offset(size.width * .5, size.height * .72),
          Offset(size.width * .5, size.height * .45),
          duration: 1000);
      await drag(Offset(size.width * .5, size.height * .4),
          Offset(size.width * .5, size.height * .7),
          duration: 1000);
    }
    if (route == 'motion:tabs') {
      await drag(Offset(size.width * .8, size.height * .5),
          Offset(size.width * .15, size.height * .5));
      await pause();
      await tap('Profile');
      await tap('Walk');
      await drag(Offset(size.width * .5, size.height * .72),
          Offset(size.width * .5, size.height * .35),
          duration: 900);
      await drag(Offset(size.width * .5, size.height * .35),
          Offset(size.width * .5, size.height * .65),
          duration: 700);
      await tap('Walk');
    }
    if (route == 'motion:onboarding') {
      await tap('Skip');
      await tap('Peace');
      await tap('Continue');
      await tap('Not now');
      await tap('Begin my walk');
      await pause(1500);
    }
    if (route == 'motion:lesson') {
      await drag(Offset(size.width * .7, size.height * .5),
          Offset(size.width * .55, size.height * .5),
          duration: 1000);
      await drag(Offset(size.width * .8, size.height * .5),
          Offset(size.width * .15, size.height * .5),
          duration: 180);
      await tap('Continue');
      await tap('Previous card');
      await tap('Continue');
      await tap('Continue');
      await tap('Continue');
      await tap('Finish my reading');
      await pause(3000);
    }
  }
}
