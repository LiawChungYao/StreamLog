enum ColumnType {
  name,
  metadata,
  timestamp,
  number;

  String get displayName {
    switch (this) {
      case ColumnType.name:
        return 'Text';
      case ColumnType.metadata:
        return 'Metadata';
      case ColumnType.timestamp:
        return 'Timestamp';
      case ColumnType.number:
        return 'Number';
    }
  }
}

enum MetadataMode {
  freeText,
  singleSelect,
  multiSelect;

  String get displayName {
    switch (this) {
      case MetadataMode.freeText:
        return 'Free text';
      case MetadataMode.singleSelect:
        return 'Single select';
      case MetadataMode.multiSelect:
        return 'Multi select';
    }
  }
}

enum ConfigPropertyType {
  text,
  number,
  dropdown,
  checkbox,
  multiSelect,
  list,
}

class ConfigProperty {
  final String key;
  final String label;
  final ConfigPropertyType type;
  final dynamic value;
  final List<dynamic> options;

  const ConfigProperty({
    required this.key,
    required this.label,
    required this.type,
    this.value,
    this.options = const [],
  });
}

abstract class ColumnConfig {
  const ColumnConfig();

  List<ConfigProperty> get properties;

  ColumnConfig updateProperty(
    String key,
    dynamic value,
  );
  String? validate(String value);
  Map<String, dynamic> toSchemaValues();
}

class MetadataConfig extends ColumnConfig {
  final MetadataMode mode;
  final List<String> options;

  const MetadataConfig({
    required this.mode,
    this.options = const [],
  });


  @override
  String? validate(String value) {
    if (mode == MetadataMode.singleSelect &&
        !options.contains(value)) {
      return 'Value must be one of the available options';
    }

    if (mode == MetadataMode.multiSelect &&
      !options.contains(value)) {
    }

    return null;
  }

  @override
  Map<String, dynamic> toSchemaValues() {
    return {
      'metadata_mode': mode.name,
      'options': options.join('|'),
    };
  }


  @override
  List<ConfigProperty> get properties {
    return [
      ConfigProperty(
        key: 'mode',
        label: 'Input mode',
        type: ConfigPropertyType.dropdown,
        value: mode,
        options: MetadataMode.values,
      ),

      if (mode != MetadataMode.freeText)
        ConfigProperty(
          key: 'options',
          label: 'Options',
          type: ConfigPropertyType.list,
          value: options,
        ),
    ];
  }

  @override
  ColumnConfig updateProperty(
    String key,
    dynamic value,
  ) {
    switch (key) {
      case 'mode':
        return MetadataConfig(
          mode: value as MetadataMode,
          options: value == MetadataMode.freeText
              ? const []
              : options,
        );

      case 'options':
        return MetadataConfig(
          mode: mode,
          options: List<String>.from(value),
        );

      default:
        throw ArgumentError('Unknown property: $key');
    }
  }
}

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
    this.required = false,
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
}