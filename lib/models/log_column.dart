import '../util/utils.dart';
import 'column_type.dart';

class LogColumn {
  final String id;
  final String name;
  final ColumnType type;
  final bool required;
  final ColumnConfig? config;

  const LogColumn({
    required this.id,
    required this.name,
    required this.type,
    required this.required,
    this.config,
  });

  Map<String, dynamic> toSchemaValues() {
    return {
      'column_id': id,
      'name': name,
      'type': type.name,
      'required': required,
      ...?config?.toSchemaValues(),
    };
  }

  LogColumn copyWith({
    String? id,
    String? name,
    ColumnType? type,
    bool? required,
    ColumnConfig? config,
  }) {
    return LogColumn(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
      config: config ?? this.config,
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
        required == other.required &&
        config == other.config;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      type,
      required,
      config,
    );
  }
}