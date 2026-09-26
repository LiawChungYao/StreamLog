import 'package:flutter/material.dart';

import 'column_type.dart';
import 'log_column.dart';

class TimestampColumn extends ColumnType {
  const TimestampColumn();

  @override
  String get name => 'timestamp';

  @override
  String get displayName => 'Timestamp';

  @override
  String? validate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return null;
    }

    if (DateTime.tryParse(value.toString()) == null) {
      return 'Value must be a valid timestamp';
    }

    return null;
  }

  dynamic convert(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  @override
  TimestampColumn fromSchemaValues(Map<String, dynamic> values) {
    return const TimestampColumn();
  }

  @override
  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<ColumnType> onChanged,
  }) {
    return const SizedBox.shrink();
  }

  @override
  Widget buildInput({
    required BuildContext context,
    required LogColumn column,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  }) {
    final currentValue = convert(value) as DateTime?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            final initial = currentValue ?? DateTime.now();

            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );

            if (date == null || !context.mounted) {
              return;
            }

            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
            );

            if (time == null) {
              return;
            }

            onChanged(
              DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              ),
            );
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: column.name,
              border: const OutlineInputBorder(),
            ),
            child: Text(
              currentValue == null
                  ? 'Select date and time'
                  : _format(currentValue),
            ),
          ),
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          onPressed: () {
            onChanged(DateTime.now());
          },
          icon: const Icon(Icons.access_time),
          label: const Text('Now'),
        ),
      ],
    );
  }

  String _format(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}