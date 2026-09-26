import 'package:flutter/material.dart';

import '../models/log_column.dart';
import '../models/log_schema.dart';
import '../services/record_service.dart';
import '../util/ui_helper.dart';
import '../util/utils.dart';

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

  Map<String, dynamic> values = {};

  late Map<String, dynamic> originalValues;

  bool get isEditing => widget.originalIndex != null;

  LogColumn get currentColumn {
    return widget.schema.columns[currentIndex];
  }

  bool get isLastColumn {
    return currentIndex == widget.schema.columns.length - 1;
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _initializeValues();

    // Keep a snapshot of the values when editing started.
    originalValues = ValueUtils.deepCopyMap(values);
  }

  void _initializeValues() {
    if (widget.initialValues == null) {
      return;
    }

    values = ValueUtils.deepCopyMap(
      widget.initialValues!,
    );
  }

  // ---------------------------------------------------------------------------
  // Change detection
  // ---------------------------------------------------------------------------

  bool get _hasChanges {
    if (!isEditing) {
      return false;
    }

    return !ValueUtils.equals(
      values,
      originalValues,
    );
  }

  Future<bool> _confirmExit() async {
    if (!_hasChanges) {
      return true;
    }

    return await UIHelper.showConfirmation(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes. Are you sure you want to leave?',
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void next() {
    if (!_validateCurrentColumn()) {
      return;
    }

    if (isLastColumn) {
      showReview();
      return;
    }

    setState(() {
      currentIndex++;
    });
  }

  Future<void> previous() async {
    if (currentIndex == 0) {
      final shouldPop = await _confirmExit();

      if (shouldPop && mounted) {
        Navigator.pop(context);
      }

      return;
    }

    setState(() {
      currentIndex--;
    });
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  bool _validateCurrentColumn() {
    final column = currentColumn;
    final value = values[column.id];

    // Required validation.
    if (column.required && _isEmpty(value)) {
      UIHelper.showSnackBar(
        context,
        '${column.name} is required.',
      );

      return false;
    }

    // Column-specific validation.
    final error = column.type.validate(value);

    if (error != null) {
      UIHelper.showSnackBar(
        context,
        error,
      );

      return false;
    }

    return true;
  }

  bool _isEmpty(dynamic value) {
    if (value == null) {
      return true;
    }

    if (value is String) {
      return value.trim().isEmpty;
    }

    if (value is List) {
      return value.isEmpty;
    }

    return false;
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
            isEditing ? 'Review Changes' : 'Review Log',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.schema.columns.map(
                (column) {
                  final value = values[column.id];

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: Text(
                      '${column.name}: ${_displayValue(value)}',
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
                isEditing ? 'Save Changes' : 'Save',
              ),
            ),
          ],
        );
      },
    );
  }

  String _displayValue(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .join(', ');
    }

    return value?.toString() ?? '';
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> saveLog() async {
    try {
      if (isEditing) {
        await RecordService.instance.updateRecord(
          widget.spreadsheetId,
          widget.schema,
          widget.originalIndex!,
          values,
        );
      } else {
        await RecordService.instance.addLog(
          widget.spreadsheetId,
          widget.schema,
          values,
        );
      }

      if (!mounted) {
        return;
      }

      UIHelper.showSnackBar(
        context,
        isEditing ? 'Changes saved' : 'Log saved',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

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

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }

        final shouldPop = await _confirmExit();

        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Column Input
  // ---------------------------------------------------------------------------

  Widget _buildColumnInput(LogColumn column) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: column.type.buildInput(
        context: context,
        column: column,
        value: values[column.id],
        onChanged: (value) {
          setState(() {
            values[column.id] = value;
          });
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation UI
  // ---------------------------------------------------------------------------

  Widget _buildNavigation() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (currentIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: previous,
                child: const Text('Back'),
              ),
            ),
          if (currentIndex > 0)
            const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: next,
              child: Text(
                isLastColumn ? 'Review' : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

