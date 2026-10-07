import 'package:flutter/material.dart';

import 'column_type.dart';
import 'log_column.dart';
import '../util/ui_helper.dart';

class MetadataColumn extends ColumnType {
  final MetadataConfig config;

  const MetadataColumn({
    this.config = const MetadataConfig(
      mode: MetadataMode.freeText,
    ),
  });

  @override
  String get name => 'metadata';

  @override
  String get displayName => 'Metadata';

  @override
  Map<String, dynamic> toSchemaValues() {
    return config.toSchemaValues();
  }

  @override
  String? validate(dynamic value) {
    if (value == null) {
      return null;
    }

    switch (config.mode) {
      case MetadataMode.freeText:
        return null;

      case MetadataMode.singleSelect:
        if (!config.options.contains(value.toString()) && value != null) {
          return 'Value must be one of the available options';
        }

        return null;

      case MetadataMode.multiSelect:
        if (value is! List && value != null) {
          return 'Value must be a list';
        }

        for (final item in value) {
          if (!config.options.contains(item.toString()) && value != null) {
            return 'Value contains an invalid option';
          }
        }

        return null;
    }
  }

  @override
  MetadataColumn fromSchemaValues(Map<String, dynamic> values) {
    final modeString = values['mode']?.toString() ?? '';

    final mode = switch (modeString) {
      'freeText' => MetadataMode.freeText,
      'singleSelect' => MetadataMode.singleSelect,
      'multiSelect' => MetadataMode.multiSelect,
      '' => MetadataMode.freeText,
      _ => throw Exception(
          'Unknown metadata mode "$modeString"',
        ),
    };

    final options = values['options'] is List
        ? List<String>.from(values['options'])
        : <String>[];

    return MetadataColumn(
      config: MetadataConfig(
        mode: mode,
        options: options,
      ),
    );
  }

  @override
  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<ColumnType> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MetadataMode>(
          value: config.mode,
          decoration: const InputDecoration(
            labelText: 'Mode',
            border: OutlineInputBorder(),
          ),
          items: MetadataMode.values.map((mode) {
            return DropdownMenuItem<MetadataMode>(
              value: mode,
              child: Text(_displayMode(mode)),
            );
          }).toList(),
          onChanged: (mode) {
            if (mode == null) {
              return;
            }

            onChanged(
              MetadataColumn(
                config: config.copyWith(
                  mode: mode,
                ),
              ),
            );
          },
        ),

        if (config.mode != MetadataMode.freeText) ...[
          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Options',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final value = await UIHelper.showTextInput(
                    context,
                    title: 'Add option',
                    labelText: 'Option',
                    hintText: 'Enter a value',
                  );

                  if (value == null) {
                    return;
                  }

                  final option = value.trim();

                  if (option.isEmpty) {
                    return;
                  }

                  if (config.options.contains(option)) {
                    UIHelper.showSnackBar(
                      context,
                      'Option already exists',
                    );
                    return;
                  }

                  final options = List<String>.from(config.options)
                    ..add(option);

                  onChanged(
                    MetadataColumn(
                      config: config.copyWith(
                        options: options,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),

          if (config.options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No options added.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),

          ...List.generate(
            config.options.length,
            (index) {
              final option = config.options[index];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text(
                    '${index + 1}',
                  ),
                ),
                title: Text(option),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    final confirmed =
                        await UIHelper.showConfirmation(
                      context,
                      title: 'Remove option?',
                      message:
                          'Are you sure you want to remove "$option"?',
                    );

                    if (!confirmed) {
                      return;
                    }

                    final options = List<String>.from(
                      config.options,
                    )..removeAt(index);

                    onChanged(
                      MetadataColumn(
                        config: config.copyWith(
                          options: options,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget buildInput({
    required BuildContext context,
    required LogColumn column,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  }) {
    switch (config.mode) {
      case MetadataMode.freeText:
        return TextFormField(
          initialValue: value?.toString(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: column.name,
            border: const OutlineInputBorder(),
          ),
        );

        case MetadataMode.singleSelect:
          final selectedValue =
              value is String && value.isNotEmpty ? value : null;

          return DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: InputDecoration(
              labelText: column.name,
              border: const OutlineInputBorder(),
            ),
            items: config.options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          );

      case MetadataMode.multiSelect:
        final selectedValues = value is List
            ? List<String>.from(value)
            : <String>[];

        return InputDecorator(
          decoration: InputDecoration(
            labelText: column.name,
            border: const OutlineInputBorder(),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: config.options.map((option) {
              final isSelected =
                  selectedValues.contains(option);

              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  final values =
                      List<String>.from(selectedValues);

                  if (selected) {
                    if (!values.contains(option)) {
                      values.add(option);
                    }
                  } else {
                    values.remove(option);
                  }

                  onChanged(values);
                },
              );
            }).toList(),
          ),
        );
    }
  }

  String _displayMode(MetadataMode mode) {
    switch (mode) {
      case MetadataMode.freeText:
        return 'Free Text';

      case MetadataMode.singleSelect:
        return 'Single Select';

      case MetadataMode.multiSelect:
        return 'Multi Select';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is MetadataColumn &&
        other.config == config;
  }

  @override
  int get hashCode => config.hashCode;
}

enum MetadataMode {
  freeText,
  singleSelect,
  multiSelect,
}

class MetadataConfig {
  final MetadataMode mode;
  final List<String> options;

  const MetadataConfig({
    required this.mode,
    this.options = const [],
  });

  Map<String, dynamic> toSchemaValues() {
    return {
      'mode': mode.name,
      'options': options,
    };
  }

  MetadataConfig copyWith({
    MetadataMode? mode,
    List<String>? options,
  }) {
    return MetadataConfig(
      mode: mode ?? this.mode,
      options: options ?? this.options,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! MetadataConfig) {
      return false;
    }

    return mode == other.mode &&
        _listEquals(options, other.options);
  }

  @override
  int get hashCode {
    return Object.hash(
      mode,
      Object.hashAll(options),
    );
  }

  static bool _listEquals(
    List<String> a,
    List<String> b,
  ) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }
}