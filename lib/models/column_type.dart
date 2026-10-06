import 'package:flutter/material.dart';

import 'log_column.dart';
import 'text_column.dart';
import 'number_column.dart';
import 'timestamp_column.dart';
import 'metadata_column.dart';
import 'media_column.dart';

abstract class ColumnType {
  const ColumnType();

  String get name;
  String get displayName;

  Map<String, dynamic> toSchemaValues(){
    return {};
  }

  ColumnType fromSchemaValues(
    Map<String, dynamic> values,
  );

  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<ColumnType> onChanged,
  });

  Widget buildInput({
    required BuildContext context,
    required LogColumn column,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  });

  String? validate(dynamic value);


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
    MediaColumn(),
  ];

  

  static ColumnType? fromName(String name) {
    switch (name) {
      case 'text':
        return const TextColumn();
      case 'metadata':
        return const MetadataColumn();
      case 'timestamp':
        return const TimestampColumn();
      case 'number':
        return const NumberColumn();
      case 'media':
        return const MediaColumn();
      default:
        return null;
    }
  }
}