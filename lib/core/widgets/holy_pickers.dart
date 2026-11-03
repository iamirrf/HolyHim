import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<TimeOfDay?> showHolyTimePicker(BuildContext context,
    {required TimeOfDay initialTime}) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return showTimePicker(context: context, initialTime: initialTime);
  }
  var selected = initialTime;
  return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (context) => Container(
          height: 330,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
              top: false,
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      CupertinoButton(
                          onPressed: () => Navigator.pop(context, selected),
                          child: const Text('Done'))
                    ]),
                Expanded(
                    child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: DateTime(
                            2000, 1, 1, initialTime.hour, initialTime.minute),
                        use24hFormat:
                            MediaQuery.alwaysUse24HourFormatOf(context),
                        onDateTimeChanged: (value) =>
                            selected = TimeOfDay.fromDateTime(value))),
              ]))));
}
