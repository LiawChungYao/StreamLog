import 'package:flutter/material.dart';

import 'log_column.dart';
import 'text_column.dart';
import 'number_column.dart';
import 'timestamp_column.dart';
import 'metadata_column.dart';

abstract class ColumnType {
  const ColumnType();

  /// Value persisted in the spreadsheet schema.
  String get name;

  /// Name displayed to the user.
  String get displayName;

  /// Validate a value entered for this column.
  ///
  /// Returns an error message if invalid, otherwise null.
  String? validate(dynamic value);

  /// Convert a value into the format expected by the column.
  dynamic convert(dynamic value);

  /// Build the configuration UI for this column.
  ///
  /// If the column has no configuration, return SizedBox.shrink().
  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<LogColumn> onChanged,
  });

  /// Build the input UI for adding/editing a record.
  Widget buildInput({
    required BuildContext context,
    required LogColumn column,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  });

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

class ColumnRegistry {
  static const List<ColumnType> all = [
    TextColumn(),
    MetadataColumn(),
    TimestampColumn(),
    NumberColumn(),
  ];

  static ColumnType fromName(String name) {
    switch (name) {
      case 'text':
        return const TextColumn();
      case 'metadata':
        return const MetadataColumn();
      case 'timestamp':
        return const TimestampColumn();
      case 'number':
        return const NumberColumn();
      default:
        throw ArgumentError('Unknown column type: $name');
    }
  }
}