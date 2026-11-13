import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HolyDialogs {
  HolyDialogs._();
  /// The system alert, so confirmation looks and reads like iOS.
  static Future<bool> confirm(BuildContext context,
      {required String title,
      required String message,
      String confirm = 'Continue',
      String cancel = 'Cancel',
      bool destructive = false}) async {
    final accepted = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
                title: Text(title),
                content: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(message)),
                actions: [
                  CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(cancel)),
                  CupertinoDialogAction(
                      isDefaultAction: !destructive,
                      isDestructiveAction: destructive,
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirm)),
                ]));
    return accepted ?? false;
  }

  static Future<void> alert(BuildContext context,
          {required String title,
          required String message,
          String action = 'OK'}) =>
      showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
                  title: Text(title),
                  content: Text(message),
                  actions: [
                    CupertinoDialogAction(
                        isDefaultAction: true,
                        onPressed: () => Navigator.pop(context),
                        child: Text(action)),
                  ]));
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
