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
  TextColumn fromSchemaValues(Map<String, dynamic> values) {
    return const TextColumn();
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
    return TextFormField(
      key: ValueKey(column.id),
      initialValue: value?.toString() ?? '',
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
      ),
    );
  }
}