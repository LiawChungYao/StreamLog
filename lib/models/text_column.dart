import 'package:flutter/material.dart';

import 'column_type.dart';
import 'log_column.dart';

class TextColumn extends ColumnType {
  const TextColumn();

  @override
  String get name => 'text';

  @override
  String get displayName => 'Text';

  @override
  String? validate(dynamic value) {
    return null;
  }

  @override
  dynamic convert(dynamic value) {
    return value?.toString() ?? '';
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
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
      ),
    );
  }
}