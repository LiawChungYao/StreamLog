import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/column_type.dart';
import '../models/log_column.dart';
import '../util/ui_helper.dart';

class ConfigureColumnsPage extends StatefulWidget {
  final List<LogColumn> initialColumns;

  const ConfigureColumnsPage({
    super.key,
    this.initialColumns = const [],
  });

  @override
  State<ConfigureColumnsPage> createState() =>
      _ConfigureColumnsPageState();
}

class _ConfigureColumnsPageState extends State<ConfigureColumnsPage> {
  late List<LogColumn> columns;
  late List<LogColumn> originalColumns;

  @override
  void initState() {
    super.initState();

    columns = List.from(widget.initialColumns);
    originalColumns = List.from(widget.initialColumns);
  }

  bool get _hasChanges {
    return !listEquals(columns, originalColumns);
  }

  Future<bool> _confirmExit() async {
    if (!_hasChanges) {
      return true;
    }

    return UIHelper.showConfirmation(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes. Are you sure you want to leave?',
    );
  }

  void _addColumn() {
    setState(() {
      columns.add(
        LogColumn(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'New Column',
          type: ColumnRegistry.all[0],
          required: false,
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

    if (!confirmed) {
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }

        final shouldPop = await _confirmExit();

        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  100,
                ),
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
                  final column = columns[index];

                  return _ColumnCard(
                    key: ValueKey(column.id),
                    index: index,
                    column: column,
                    onChanged: (column) {
                      _updateColumn(index, column);
                    },
                    onDelete: () {
                      _removeColumn(index);
                    },
                  );
                },
              ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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

            // Column name
            TextFormField(
              initialValue: column.name,
              decoration: const InputDecoration(
                labelText: 'Column name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                onChanged(
                  column.copyWith(
                    name: value,
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Column type
            DropdownButtonFormField<String>(
              value: column.type.name,
              decoration: const InputDecoration(
                labelText: 'Column type',
                border: OutlineInputBorder(),
              ),
              items: ColumnRegistry.all.map((type) {
                return DropdownMenuItem<String>(
                  value: type.name,
                  child: Text(type.displayName),
                );
              }).toList(),
              onChanged: (typeName) {
                if (typeName == null) {
                  return;
                }

                final type = ColumnRegistry.fromName(typeName);

                if (type == null) {
                  return;
                }

                onChanged(
                  column.copyWith(type: type),
                );
              },
            ),

            const SizedBox(height: 8),

            // Required
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              subtitle: const Text(
                'Users must provide a value for this column',
              ),
              value: column.required,
              onChanged: (value) {
                onChanged(
                  column.copyWith(
                    required: value,
                  ),
                );
              },
            ),

            const Divider(),

            const SizedBox(height: 8),

            // Type-specific configuration
            column.type.buildConfiguration(
              context: context,
              column: column,
              onChanged: (type) {
                onChanged(
                  column.copyWith(
                    type: type,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}