import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HolyDialogs {
  HolyDialogs._();
  static Future<bool> confirm(BuildContext context,
      {required String title,
      required String message,
      String confirm = 'Continue',
      String cancel = 'Cancel',
      bool destructive = false}) async {
    var accepted = false;
    await AdaptiveAlertDialog.show(
        context: context,
        title: title,
        message: message,
        actions: [
          AlertAction(
              title: cancel, style: AlertActionStyle.cancel, onPressed: () {}),
          AlertAction(
              title: confirm,
              style: destructive
                  ? AlertActionStyle.destructive
                  : AlertActionStyle.primary,
              onPressed: () => accepted = true)
        ]);
    return accepted;
  }

  static Future<void> alert(BuildContext context,
          {required String title,
          required String message,
          String action = 'OK'}) =>
      AdaptiveAlertDialog.show(
          context: context,
          title: title,
          message: message,
          actions: [
            AlertAction(
                title: action,
                style: AlertActionStyle.primary,
                onPressed: () {})
          ]);
  static Future<TimeOfDay?> time(BuildContext context,
          {required TimeOfDay initialTime}) =>
      AdaptiveTimePicker.show(context: context, initialTime: initialTime);
  static Future<T?> sheet<T>(BuildContext context,
          {required WidgetBuilder builder, bool scrollControlled = true}) =>
      showModalBottomSheet<T>(
          context: context,
          showDragHandle: true,
          isScrollControlled: scrollControlled,
          useSafeArea: true,
          builder: builder);
  static Future<String?> actions(BuildContext context,
      {String? title, required Map<String, VoidCallback> choices}) async {
    return showCupertinoModalPopup<String>(
        context: context,
        builder: (context) => CupertinoActionSheet(
            title: title == null ? null : Text(title),
            actions: choices.entries
                .map((e) => CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(context).pop(e.key);
                      e.value();
                    },
                    child: Text(e.key)))
                .toList(),
            cancelButton: CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'))));
  }
}
