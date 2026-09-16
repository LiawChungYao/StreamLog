import 'package:flutter/material.dart';

import '../models/log_column.dart';
import '../util/ui_helper.dart';

class ConfigureColumnsPage extends StatefulWidget {
  final List<LogColumn> initialColumns;

  const ConfigureColumnsPage({
    super.key,
    this.initialColumns = const [],
  });

  @override
  State<ConfigureColumnsPage> createState() => _ConfigureColumnsPageState();
}

class _ConfigureColumnsPageState extends State<ConfigureColumnsPage> {
  late List<LogColumn> columns;

  @override
  void initState() {
    super.initState();

    columns = List.from(widget.initialColumns);
  }

  // ------------------------------------------------------------
  // Column management
  // ------------------------------------------------------------

  void _addColumn() {
    setState(() {
      columns.add(
        LogColumn(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'New Column',
          type: ColumnType.metadata,
          required: false,
          config: const MetadataConfig(
            mode: MetadataMode.freeText,
            options: [],
          ),
        ),
      );
    });
  }

  Future<void> _removeColumn(int index) async {
    final column = columns[index];

    final confirmed = await UIHelper.showConfirmation(
      context,
      title: 'Remove column?',
      message: 'Are you sure you want to remove "${column.name}"?',
    );

    if (!confirmed) return;

    setState(() {
      columns.removeAt(index);
    });
  }

  void _updateColumn(int index, LogColumn column) {
    setState(() {
      columns[index] = column;
    });
  }

  void _save() {
    Navigator.pop(context, columns);
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Schema'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addColumn,
        icon: const Icon(Icons.add),
        label: const Text('Add Column'),
      ),

      body: columns.isEmpty
          ? _buildEmptyState()
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: columns.length,

              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }

                  final column = columns.removeAt(oldIndex);
                  columns.insert(newIndex, column);
                });
              },

              itemBuilder: (context, index) {
                return _ColumnCard(
                  key: ValueKey(columns[index].id),
                  index: index,
                  column: columns[index],

                  onChanged: (column) {
                    _updateColumn(index, column);
                  },

                  onDelete: () {
                    _removeColumn(index);
                  },
                );
              },
            ),
    );
  }

  // ------------------------------------------------------------
  // Empty state
  // ------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.view_column_outlined,
            size: 64,
          ),

          const SizedBox(height: 16),

          const Text(
            'No columns configured',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Add a column to start configuring your log.',
          ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _addColumn,
            icon: const Icon(Icons.add),
            label: const Text('Add Column'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Column Card
// ============================================================================

class _ColumnCard extends StatelessWidget {
  final int index;
  final LogColumn column;
  final ValueChanged<LogColumn> onChanged;
  final VoidCallback onDelete;

  const _ColumnCard({
    super.key,
    required this.index,
    required this.column,
    required this.onChanged,
    required this.onDelete,
  });

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------

  LogColumn _copyColumn({
    String? name,
    ColumnType? type,
    bool? required,
    Object? config = _unchanged,
  }) {
    return LogColumn(
      id: column.id,
      name: name ?? column.name,
      type: type ?? column.type,
      required: required ?? column.required,
      config: identical(config, _unchanged)
          ? column.config
          : config as ColumnConfig?,
    );
  }

  static const Object _unchanged = Object();

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // ----------------------------------------------------
            // Header
            // ----------------------------------------------------

            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,

                  child: const Icon(
                    Icons.drag_indicator,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    column.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Remove column',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),

            const Divider(),

            // ----------------------------------------------------
            // Column name
            // ----------------------------------------------------

            TextFormField(
              initialValue: column.name,

              decoration: const InputDecoration(
                labelText: 'Column name',
                border: OutlineInputBorder(),
              ),

              onChanged: (value) {
                onChanged(
                  _copyColumn(
                    name: value,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------
            // Column type
            // ----------------------------------------------------

            DropdownButtonFormField<ColumnType>(
              value: column.type,

              decoration: const InputDecoration(
                labelText: 'Column type',
                border: OutlineInputBorder(),
              ),

              items: ColumnType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                );
              }).toList(),

              onChanged: (type) {
                if (type == null) return;

                ColumnConfig? config;

                if (type == ColumnType.metadata) {
                  config = const MetadataConfig(
                    mode: MetadataMode.freeText,
                    options: [],
                  );
                }

                onChanged(
                  _copyColumn(
                    type: type,
                    config: config,
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // ----------------------------------------------------
            // Required
            // ----------------------------------------------------

            SwitchListTile(
              contentPadding: EdgeInsets.zero,

              title: const Text('Required'),

              subtitle: const Text(
                'Users must provide a value for this column',
              ),

              value: column.required,

              onChanged: (value) {
                onChanged(
                  _copyColumn(
                    required: value,
                  ),
                );
              },
            ),

            // ----------------------------------------------------
            // Configuration
            // ----------------------------------------------------

            if (column.config != null) ...[
              const Divider(),

              const SizedBox(height: 8),

              const Text(
                'Configuration',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              _ConfigEditor(
                config: column.config!,
                onChanged: (config) {
                  onChanged(
                    _copyColumn(
                      config: config,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Generic Config Editor
// ============================================================================

class _ConfigEditor extends StatelessWidget {
  final ColumnConfig config;
  final ValueChanged<ColumnConfig> onChanged;

  const _ConfigEditor({
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final properties = config.properties;

    if (properties.isEmpty) {
      return const Text(
        'No additional configuration.',
        style: TextStyle(
          color: Colors.grey,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        ...List.generate(
          properties.length,
          (index) {
            final property = properties[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == properties.length - 1 ? 0 : 16,
              ),

              child: _ConfigPropertyEditor(
                property: property,

                onChanged: (value) {
                  final updatedConfig = config.updateProperty(
                    property.key,
                    value,
                  );

                  onChanged(updatedConfig);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// Generic Config Property Editor
// ============================================================================

class _ConfigPropertyEditor extends StatelessWidget {
  final ConfigProperty property;
  final ValueChanged<dynamic> onChanged;

  const _ConfigPropertyEditor({
    required this.property,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (property.type) {
      case ConfigPropertyType.text:
        return _buildTextField();

      case ConfigPropertyType.number:
        return _buildNumberField();

      case ConfigPropertyType.dropdown:
        return _buildDropdown();

      case ConfigPropertyType.checkbox:
        return _buildCheckbox();

      case ConfigPropertyType.multiSelect:
        return _buildMultiSelect();

      case ConfigPropertyType.list:
        return _buildList();
    }
  }

  // ------------------------------------------------------------
  // Text
  // ------------------------------------------------------------

  Widget _buildTextField() {
    return TextFormField(
      initialValue: property.value?.toString() ?? '',

      decoration: InputDecoration(
        labelText: property.label,
        border: const OutlineInputBorder(),
      ),

      onChanged: onChanged,
    );
  }

  // ------------------------------------------------------------
  // Number
  // ------------------------------------------------------------

  Widget _buildNumberField() {
    return TextFormField(
      initialValue: property.value?.toString() ?? '',

      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
      ),

      decoration: InputDecoration(
        labelText: property.label,
        border: const OutlineInputBorder(),
      ),

      onChanged: (value) {
        if (value.isEmpty) {
          onChanged(null);
          return;
        }

        final number = num.tryParse(value);

        if (number != null) {
          onChanged(number);
        }
      },
    );
  }

  // ------------------------------------------------------------
  // Dropdown
  // ------------------------------------------------------------

  Widget _buildDropdown() {
    final options = property.options;

    return DropdownButtonFormField<dynamic>(
      value: property.value,

      decoration: InputDecoration(
        labelText: property.label,
        border: const OutlineInputBorder(),
      ),

      items: options.map((option) {
        return DropdownMenuItem<dynamic>(
          value: option,
          child: Text(_displayValue(option)),
        );
      }).toList(),

      onChanged: onChanged,
    );
  }

  // ------------------------------------------------------------
  // Checkbox
  // ------------------------------------------------------------

  Widget _buildCheckbox() {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,

      title: Text(property.label),

      value: property.value == true,

      onChanged: (value) {
        onChanged(value ?? false);
      },
    );
  }

  // ------------------------------------------------------------
  // Multi-select
  // ------------------------------------------------------------

  Widget _buildMultiSelect() {
    final selected = List<dynamic>.from(
      property.value ?? const [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          property.label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,

          children: property.options.map((option) {
            final isSelected = selected.contains(option);

            return FilterChip(
              label: Text(
                _displayValue(option),
              ),

              selected: isSelected,

              onSelected: (value) {
                final updated = List<dynamic>.from(selected);

                if (value) {
                  if (!updated.contains(option)) {
                    updated.add(option);
                  }
                } else {
                  updated.remove(option);
                }

                onChanged(updated);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // List
  // ------------------------------------------------------------

  Widget _buildList() {
    final values = List<String>.from(
      property.value ?? const [],
    );

    return _ListPropertyEditor(
      label: property.label,
      values: values,

      onChanged: (updatedValues) {
        onChanged(updatedValues);
      },
    );
  }

  // ------------------------------------------------------------
  // Display value
  // ------------------------------------------------------------

  String _displayValue(dynamic value) {
    if (value is Enum) {
      return value.name;
    }

    return value.toString();
  }
}

// ============================================================================
// List Property Editor
// ============================================================================

class _ListPropertyEditor extends StatefulWidget {
  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const _ListPropertyEditor({
    required this.label,
    required this.values,
    required this.onChanged,
  });

  @override
  State<_ListPropertyEditor> createState() => _ListPropertyEditorState();
}

class _ListPropertyEditorState extends State<_ListPropertyEditor> {
  late List<String> values;

  @override
  void initState() {
    super.initState();

    values = List.from(widget.values);
  }

  @override
  void didUpdateWidget(
    covariant _ListPropertyEditor oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.values != widget.values) {
      values = List.from(widget.values);
    }
  }

  // ------------------------------------------------------------
  // Add
  // ------------------------------------------------------------

  Future<void> _addItem() async {
    final value = await UIHelper.showTextInput(
      context,
      title: 'Add ${widget.label.toLowerCase().singularize()}',
      labelText: widget.label,
      hintText: 'Enter a value',
    );

    if (value == null) return;

    final trimmedValue = value.trim();

    if (trimmedValue.isEmpty) return;

    if (values.contains(trimmedValue)) {
      UIHelper.showSnackBar(
        context,
        'Value already exists',
      );

      return;
    }

    setState(() {
      values.add(trimmedValue);
    });

    widget.onChanged(
      List.from(values),
    );
  }

  // ------------------------------------------------------------
  // Remove
  // ------------------------------------------------------------

  Future<void> _removeItem(int index) async {
    final value = values[index];

    final confirmed = await UIHelper.showConfirmation(
      context,
      title: 'Remove item?',
      message: 'Are you sure you want to remove "$value"?',
    );

    if (!confirmed) return;

    setState(() {
      values.removeAt(index);
    });

    widget.onChanged(
      List.from(values),
    );
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),

        if (values.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),

            child: Text(
              'No items added.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),

        ...List.generate(
          values.length,
          (index) {
            return ListTile(
              contentPadding: EdgeInsets.zero,

              leading: CircleAvatar(
                radius: 14,
                child: Text(
                  '${index + 1}',
                ),
              ),

              title: Text(
                values[index],
              ),

              trailing: IconButton(
                icon: const Icon(Icons.close),

                onPressed: () {
                  _removeItem(index);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// Small String helper
// ============================================================================

extension _StringExtensions on String {
  String singularize() {
    if (endsWith('s') && length > 1) {
      return substring(0, length - 1);
    }

    return this;
  }
}
