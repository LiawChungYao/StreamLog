import 'column_type.dart';
import 'dart:convert';
class LogColumn {
  final String id;
  final String name;
  final ColumnType type;
  final bool required;

  const LogColumn({
    required this.id,
    required this.name,
    required this.type,
    required this.required,
  });

  Map<String, dynamic> toSchemaValues() {
    return {
      'column_id': id,
      'name': name,
      'type': type.name,
      'required': required,
      'config': jsonEncode(type.toSchemaValues()),
    };
  }

  LogColumn copyWith({
    String? id,
    String? name,
    ColumnType? type,
    bool? required,
  }) {
    return LogColumn(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! LogColumn) {
      return false;
    }

    return id == other.id &&
        name == other.name &&
        type == other.type &&
        required == other.required;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      type,
      required,
    );
  }
}