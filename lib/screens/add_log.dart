import 'package:flutter/material.dart';

import '../models/log_column.dart';
import '../models/log_schema.dart';
import '../services/record_service.dart';
import '../util/ui_helper.dart';

class AddLogPage extends StatefulWidget {
  final LogSchema schema;
  final String spreadsheetId;

  // Existing values when editing.
  final Map<String, dynamic>? initialValues;

  // Original position in the records list / _record sheet.
  // null means we are adding a new record.
  final int? originalIndex;

  const AddLogPage({
    super.key,
    required this.schema,
    required this.spreadsheetId,
    this.initialValues,
    this.originalIndex,
  });

  @override
  State<AddLogPage> createState() => _AddLogPageState();
}

class _AddLogPageState extends State<AddLogPage> {
  int currentIndex = 0;

  bool get isEditing => widget.originalIndex != null;

  Map<String, dynamic> values = {};

  late TextEditingController textController;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    textController = TextEditingController();

    _initializeValues();

    _loadCurrentValue();
  }

  void _initializeValues() {
    if (widget.initialValues == null) {
      values = {};
      return;
    }

    values = {};

    for (final column in widget.schema.columns) {
      final value = widget.initialValues![column.id];

      if (value == null) {
        continue;
      }

      // ----------------------------------------------------------
      // Multi-select
      // ----------------------------------------------------------
      //
      // Records are stored in Google Sheets as:
      //
      // "Option A, Option B, Option C"
      //
      // Convert that back into a List<String> for the UI.
      //

      if (column.type == ColumnType.metadata &&
          _metadataMode(column) == MetadataMode.multiSelect) {
        if (value is List) {
          values[column.id] = List<String>.from(
            value.map((item) => item.toString()),
          );
        } else {
          final text = value.toString().trim();

          if (text.isEmpty) {
            values[column.id] = <String>[];
          } else {
            values[column.id] = text
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList();
          }
        }

        continue;
      }

      // ----------------------------------------------------------
      // Other values
      // ----------------------------------------------------------

      values[column.id] = value;
    }
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Current column
  // ---------------------------------------------------------------------------

  LogColumn get currentColumn {
    return widget.schema.columns[currentIndex];
  }

  bool get isLastColumn {
    return currentIndex ==
        widget.schema.columns.length - 1;
  }

  // ---------------------------------------------------------------------------
  // Metadata helpers
  // ---------------------------------------------------------------------------

  MetadataConfig? _metadataConfig(LogColumn column) {
    if (column.config is MetadataConfig) {
      return column.config as MetadataConfig;
    }

    return null;
  }

  MetadataMode? _metadataMode(LogColumn column) {
    return _metadataConfig(column)?.mode;
  }

  List<String> _metadataOptions(LogColumn column) {
    return _metadataConfig(column)?.options ?? [];
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void next() {
    saveCurrentValue();

    if (!_validateCurrentColumn()) {
      return;
    }

    if (isLastColumn) {
      showReview();
      return;
    }

    setState(() {
      currentIndex++;
      _loadCurrentValue();
    });
  }

  void previous() {
    if (currentIndex == 0) {
      Navigator.pop(context);
      return;
    }

    saveCurrentValue();

    setState(() {
      currentIndex--;
      _loadCurrentValue();
    });
  }

  // ---------------------------------------------------------------------------
  // Value handling
  // ---------------------------------------------------------------------------

  void _loadCurrentValue() {
    final column = currentColumn;
    final value = values[column.id];

    if (_usesTextController(column)) {
      textController.text = value?.toString() ?? '';

      textController.selection =
          TextSelection.fromPosition(
        TextPosition(
          offset: textController.text.length,
        ),
      );
    } else {
      textController.clear();
    }
  }

  bool _usesTextController(LogColumn column) {
    if (column.type == ColumnType.name) {
      return true;
    }

    if (column.type == ColumnType.metadata) {
      return _metadataMode(column) ==
          MetadataMode.freeText;
    }

    return false;
  }

  void saveCurrentValue() {
    final column = currentColumn;

    if (_usesTextController(column)) {
      values[column.id] = textController.text;
    }
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  bool _validateCurrentColumn() {
    final column = currentColumn;
    final value = values[column.id];

    // ----------------------------------------------------------
    // Required validation
    // ----------------------------------------------------------

    if (column.required) {
      if (value == null) {
        UIHelper.showSnackBar(
          context,
          '${column.name} is required.',
        );
        return false;
      }

      if (value is String && value.trim().isEmpty) {
        UIHelper.showSnackBar(
          context,
          '${column.name} is required.',
        );
        return false;
      }

      if (value is List && value.isEmpty) {
        UIHelper.showSnackBar(
          context,
          '${column.name} is required.',
        );
        return false;
      }
    }

    // ----------------------------------------------------------
    // Metadata configuration validation
    // ----------------------------------------------------------

    if (column.config != null && value != null) {
      String? error;

      if (column.config is MetadataConfig) {
        final config =
            column.config as MetadataConfig;

        // ------------------------------------------------------
        // Single select
        // ------------------------------------------------------

        if (config.mode == MetadataMode.singleSelect) {
          if (!config.options.contains(
            value.toString(),
          )) {
            error =
                'Please select one of the available options.';
          }
        }

        // ------------------------------------------------------
        // Multi select
        // ------------------------------------------------------

        if (config.mode == MetadataMode.multiSelect) {
          if (value is List) {
            final invalidValues = value.where(
              (item) =>
                  !config.options.contains(
                item.toString(),
              ),
            );

            if (invalidValues.isNotEmpty) {
              error =
                  'One or more selected values are invalid.';
            }
          }
        }
      }

      if (error != null) {
        UIHelper.showSnackBar(
          context,
          error,
        );
        return false;
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Review
  // ---------------------------------------------------------------------------

  void showReview() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            isEditing
                ? 'Review Changes'
                : 'Review Log',
          ),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children:
                  widget.schema.columns.map(
                (column) {
                  final value =
                      values[column.id];

                  String displayValue;

                  if (value is List) {
                    displayValue = value
                        .map(
                          (item) =>
                              item.toString(),
                        )
                        .join(', ');
                  } else if (value is DateTime) {
                    displayValue =
                        value.toString();
                  } else {
                    displayValue =
                        value?.toString() ?? '';
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),

                    child: Text(
                      '${column.name}: $displayValue',
                    ),
                  );
                },
              ).toList(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Back'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                saveLog();
              },

              child: Text(
                isEditing
                    ? 'Save Changes'
                    : 'Save',
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> saveLog() async {
    try {
      // ----------------------------------------------------------
      // Edit existing record
      // ----------------------------------------------------------

      if (isEditing) {
        await RecordService.instance.updateRecord(
          widget.spreadsheetId,
          widget.schema,
          widget.originalIndex!,
          values,
        );
      }

      // ----------------------------------------------------------
      // Add new record
      // ----------------------------------------------------------

      else {
        await RecordService.instance.addLog(
          widget.spreadsheetId,
          widget.schema,
          values,
        );
      }

      if (!mounted) return;

      UIHelper.showSnackBar(
        context,
        isEditing
            ? 'Changes saved'
            : 'Log saved',
      );

      // ----------------------------------------------------------
      // Tell SheetMainScreen that the record changed.
      // ----------------------------------------------------------

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      UIHelper.showSnackBar(
        context,
        isEditing
            ? 'Failed to update record: $e'
            : 'Failed to save log: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Main UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final column = currentColumn;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Log • ${currentIndex + 1} / '
                  '${widget.schema.columns.length}'
              : '${currentIndex + 1} / '
                  '${widget.schema.columns.length}',
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildColumnInput(column),
            ),

            _buildNavigation(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Column Input
  // ---------------------------------------------------------------------------

  Widget _buildColumnInput(LogColumn column) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildColumnContent(column),
    );
  }

  Widget _buildColumnContent(LogColumn column) {
    switch (column.type) {
      case ColumnType.name:
        return _buildNameInput(column);

      case ColumnType.timestamp:
        return _buildTimestampInput(column);

      case ColumnType.number:
        return _buildNumberInput(column);

      case ColumnType.metadata:
        return _buildMetadataInput(column);
    }
  }

  // ---------------------------------------------------------------------------
  // Name
  // ---------------------------------------------------------------------------

  Widget _buildNameInput(LogColumn column) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        const SizedBox(height: 80),

        Text(
          column.name,
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        TextField(
          controller: textController,
          autofocus: true,
          textAlign: TextAlign.center,

          style: const TextStyle(
            fontSize: 28,
          ),

          decoration: InputDecoration(
            hintText:
                'Enter ${column.name}',
            border:
                const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Timestamp
  // ---------------------------------------------------------------------------

  Widget _buildTimestampInput(
    LogColumn column,
  ) {
    final currentValue =
        values[column.id];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        const SizedBox(height: 60),

        Text(
          column.name,
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        ElevatedButton(
          onPressed: () {
            setState(() {
              values[column.id] =
                  DateTime.now();
            });
          },

          style:
              ElevatedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(
              vertical: 24,
            ),
          ),

          child: const Text(
            'Now',
            style: TextStyle(
              fontSize: 24,
            ),
          ),
        ),

        const SizedBox(height: 16),

        OutlinedButton(
          onPressed: () async {
            final date =
                await showDatePicker(
              context: context,
              firstDate:
                  DateTime(2000),
              lastDate:
                  DateTime(2100),

              initialDate:
                  DateTime.now(),
            );

            if (date == null ||
                !mounted) {
              return;
            }

            final time =
                await showTimePicker(
              context: context,
              initialTime:
                  TimeOfDay.now(),
            );

            if (time == null ||
                !mounted) {
              return;
            }

            setState(() {
              values[column.id] =
                  DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          },

          style:
              OutlinedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(
              vertical: 24,
            ),
          ),

          child: const Text(
            'Choose Date & Time',
            style: TextStyle(
              fontSize: 20,
            ),
          ),
        ),

        if (currentValue != null) ...[
          const SizedBox(height: 24),

          Text(
            currentValue.toString(),
            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 18,
            ),
          ),
        ],

        const SizedBox(height: 60),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Number
  // ---------------------------------------------------------------------------

  Widget _buildNumberInput(
    LogColumn column,
  ) {
    final value =
        values[column.id]?.toString() ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        const SizedBox(height: 20),

        Text(
          column.name,
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        Container(
          height: 60,
          width: double.infinity,

          alignment:
              Alignment.centerRight,

          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
          ),

          decoration:
              BoxDecoration(
            border: Border.all(
              color: Theme.of(context)
                  .dividerColor,
            ),

            borderRadius:
                BorderRadius.circular(8),
          ),

          child: Text(
            value.isEmpty
                ? '0'
                : value,

            style:
                const TextStyle(
              fontSize: 32,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 12),

        _buildNumberKeyboard(column),
      ],
    );
  }

  Widget _buildNumberKeyboard(
    LogColumn column,
  ) {
    final buttons = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '.',
      '0',
      '⌫',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),

      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),

      itemCount: buttons.length,

      itemBuilder: (_, index) {
        final button =
            buttons[index];

        return ElevatedButton(
          style:
              ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
          ),

          onPressed: () {
            setState(() {
              String current =
                  values[column.id]
                          ?.toString() ??
                      '';

              if (button == '⌫') {
                if (current.isNotEmpty) {
                  current =
                      current.substring(
                    0,
                    current.length - 1,
                  );
                }
              } else if (button == '.') {
                if (!current
                    .contains('.')) {
                  current += '.';
                }
              } else {
                current += button;
              }

              values[column.id] =
                  current;
            });
          },

          child: Text(
            button,

            style:
                const TextStyle(
              fontSize: 20,
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Metadata
  // ---------------------------------------------------------------------------

  Widget _buildMetadataInput(
    LogColumn column,
  ) {
    final mode =
        _metadataMode(column);

    switch (mode) {
      case MetadataMode.freeText:
        return _buildMetadataFreeText(
          column,
        );

      case MetadataMode.singleSelect:
        return _buildSingleSelect(
          column,
        );

      case MetadataMode.multiSelect:
        return _buildMultiSelect(
          column,
        );

      case null:
        return const Center(
          child: Text(
            'No metadata mode configured',
          ),
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Metadata - Free Text
  // ---------------------------------------------------------------------------

  Widget _buildMetadataFreeText(
    LogColumn column,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        const SizedBox(height: 80),

        Text(
          column.name,
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        TextField(
          controller: textController,
          autofocus: true,
          textAlign: TextAlign.center,

          style: const TextStyle(
            fontSize: 24,
          ),

          decoration: InputDecoration(
            hintText:
                'Enter ${column.name}',
            border:
                const OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Metadata - Single Select
  // ---------------------------------------------------------------------------

  Widget _buildSingleSelect(
    LogColumn column,
  ) {
    final selected =
        values[column.id];

    final options =
        _metadataOptions(column);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        const SizedBox(height: 40),

        Text(
          column.name,
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 30),

        ...options.map(
          (option) {
            final isSelected =
                selected == option;

            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),

              child: SizedBox(
                width: double.infinity,

                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      values[column.id] =
                          option;
                    });
                  },

                  style:
                      ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 20,
                    ),
                  ),

                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,

                          textAlign:
                              TextAlign.center,

                          style:
                              const TextStyle(
                            fontSize: 20,
                          ),
                        ),
                      ),

                      if (isSelected)
                        const Padding(
                          padding:
                              EdgeInsets.only(
                            right: 12,
                          ),

                          child: Icon(
                            Icons.check,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Metadata - Multi Select
  // ---------------------------------------------------------------------------

  Widget _buildMultiSelect(
    LogColumn column,
  ) {
    final selected =
        List<String>.from(
      values[column.id] ??
          <String>[],
    );

    final options =
        _metadataOptions(column);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        const SizedBox(height: 20),

        Text(
          column.name,
          style: Theme.of(context)
              .textTheme
              .headlineMedium,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 30),

        ...options.map(
          (option) {
            final isSelected =
                selected.contains(
              option,
            );

            return CheckboxListTile(
              contentPadding:
                  EdgeInsets.zero,

              title: Text(
                option,

                style:
                    const TextStyle(
                  fontSize: 20,
                ),
              ),

              value: isSelected,

              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    if (!selected
                        .contains(option)) {
                      selected.add(option);
                    }
                  } else {
                    selected.remove(
                      option,
                    );
                  }

                  values[column.id] =
                      selected;
                });
              },
            );
          },
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Widget _buildNavigation() {
    return Padding(
      padding:
          const EdgeInsets.all(16),

      child: Row(
        children: [
          if (currentIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: previous,
                child:
                    const Text('Back'),
              ),
            ),

          if (currentIndex > 0)
            const SizedBox(width: 12),

          Expanded(
            child: ElevatedButton(
              onPressed: next,

              child: Text(
                isLastColumn
                    ? 'Review'
                    : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }
}