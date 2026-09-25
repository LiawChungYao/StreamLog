import 'package:flutter/material.dart';

import 'column_type.dart';
import 'column_config.dart';
import 'log_column.dart';

class MetadataColumn extends ColumnType {
  const MetadataColumn();

  @override   
  String get name => 'metadata';

  @override
  String get displayName => 'Metadata';

  MetadataConfig getConfig(LogColumn column) {
    final config = column.config;

    if (config is MetadataConfig) {
      return config;
    }

    return const MetadataConfig(
      mode: MetadataMode.freeText,
    );
  }

  @override
  String? validate(dynamic value) {
    return null;
  }

  String? validateValue(
    LogColumn column,
    dynamic value,
  ) {
    final config = getConfig(column);

    if (value == null) {
      return null;
    }

    switch (config.mode) {
      case MetadataMode.freeText:
        return null;

      case MetadataMode.singleSelect:
        if (!config.options.contains(value.toString())) {
          return 'Value must be one of the available options';
        }
        return null;

      case MetadataMode.multiSelect:
        if (value is! List) {
          return 'Value must be a list';
        }

        for (final item in value) {
          if (!config.options.contains(item.toString())) {
            return 'Value contains an invalid option';
          }
        }

        return null;
    }
  }

  @override
  dynamic convert(dynamic value) {
    return value;
  }

  @override
  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<LogColumn> onChanged,
  }) {
    // We can move the existing metadata configuration
    // widget here once we refactor ConfigureColumnsPage.
    return const SizedBox.shrink();
  }

  @override
  Widget buildInput({
    required BuildContext context,
    required LogColumn column,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  }) {
    final config = getConfig(column);

    switch (config.mode) {
      case MetadataMode.freeText:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: column.name,
            border: const OutlineInputBorder(),
          ),
        );

      case MetadataMode.singleSelect:
        return DropdownButtonFormField<String>(
          value: value?.toString(),
          decoration: InputDecoration(
            labelText: column.name,
            border: const OutlineInputBorder(),
          ),
          items: config.options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
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
              final isSelected = selectedValues.contains(option);

              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  final values = List<String>.from(selectedValues);

                  if (selected) {
                    values.add(option);
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
}

