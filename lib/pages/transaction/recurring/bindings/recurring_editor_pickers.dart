import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../custom_ui/widgets/origin_date_picker.dart';

/// Same draft-until-confirm contract as the old wheel, with a wrapping heading.
Future<T?> showRecurringEditorWheel<T>(
  BuildContext context, {
  required T initial,
  required List<T> items,
  required String Function(T) labelBuilder,
  required String title,
}) {
  var selected = initial;
  final l = AppLocalizations.of(context);
  return showBeeSheet<T>(context,
      title: title,
      child: StatefulBuilder(
          builder: (context, setState) => BeeWheel<T>(
              values: items,
              value: selected,
              label: labelBuilder,
              onChanged: (value) => setState(() => selected = value))),
      footer: Row(children: [
        Expanded(
            child: BeeButton(
                label: l.commonCancel,
                kind: BeeButtonKind.secondary,
                onPressed: () => Navigator.pop(context))),
        const SizedBox(width: 8),
        Expanded(
            child: BeeButton(
                label: l.commonOk,
                onPressed: () => Navigator.pop(context, selected))),
      ]));
}

Future<DateTime?> showRecurringEditorDatePicker(
  BuildContext context, {
  required DateTime initial,
  required DateTime minDate,
  required DateTime maxDate,
}) =>
    showOriginDatePicker(
      context,
      initial: initial,
      minDate: minDate,
      maxDate: maxDate,
    );
