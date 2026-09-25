import 'package:flutter/material.dart';

import 'column_type.dart';
import 'log_column.dart';

class NumberColumn extends ColumnType {
  const NumberColumn();

  @override
  String get name => 'number';

  @override
  String get displayName => 'Number';

  @override
  String? validate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    if (value is num) {
      return null;
    }

    if (num.tryParse(value.toString()) == null) {
      return 'Value must be a number';
    }

    return null;
  }

  @override
  dynamic convert(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    if (value is num) {
      return value;
    }

    return num.tryParse(value.toString());
  }

  @override
  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<LogColumn> onChanged,
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
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      onChanged: (text) {
        if (text.isEmpty) {
          onChanged(null);
          return;
        }

        final number = num.tryParse(text);

        if (number != null) {
          onChanged(number);
        }
      },
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
      ),
    );
  }
}