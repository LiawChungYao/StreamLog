import 'package:flutter/material.dart';
import 'package:sheets_manager/services/spreadsheet_storage.dart';

import '../services/sheets_service.dart';
import '../services/schema_service.dart';
import '../services/record_service.dart';
import '../screens/configure_columns.dart';
import '../screens/add_log.dart';
import '../models/log_schema.dart';
import '../models/log_column.dart';
import '../util/ui_helper.dart';


// ============================================================
// INDEXED RECORD
// ============================================================
//
// Keeps the record together with its original position in the
// records list / physical _record sheet.
//
// This is important when filtering.
//
// Example:
//
// records:
//   0 -> Alice
//   1 -> Bob
//   2 -> Charlie
//
// Search "Charlie":
//
// filteredRecords:
//   originalIndex = 2
//
// So deleting it still deletes physical row 3 in the sheet
// (row 1 is the header).
//

class IndexedRecord {
  final int originalIndex;
  final Map<String, dynamic> record;

  const IndexedRecord({
    required this.originalIndex,
    required this.record,
  });
}


// ============================================================
// SHEET MAIN SCREEN
// ============================================================

class SheetMainScreen extends StatefulWidget {
  final String spreadsheetId;

  const SheetMainScreen({
    super.key,
    required this.spreadsheetId,
  });

  @override
  State<SheetMainScreen> createState() => _SheetMainScreenState();
}


// ============================================================
// STATE
// ============================================================

class _SheetMainScreenState extends State<SheetMainScreen> {
  LogSchema? schema;

  bool loading = true;
  bool savingSchema = false;
  bool loadingRecords = false;

  // ============================================================
  // RECORDS
  // ============================================================

  List<Map<String, dynamic>> records = [];

  String? filterColumnId;
  String filterText = '';

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadSchema();
  }

  // ============================================================
  // LOAD SCHEMA
  // ============================================================

  Future<void> loadSchema() async {
    try {
      // ----------------------------------------------------------
      // Check whether spreadsheet is trashed
      // ----------------------------------------------------------

      final isTrashed =
          await SheetsService.instance.isSpreadsheetTrashed(
        widget.spreadsheetId,
      );

      if (isTrashed) {
        debugPrint(
          'Spreadsheet ${widget.spreadsheetId} is trashed.',
        );

        await SpreadsheetStorage.instance
            .removeSpreadsheetFromPreferences(
          widget.spreadsheetId,
        );

        if (!mounted) return;

        Navigator.pop(context);
        return;
      }

      // ----------------------------------------------------------
      // Load schema
      // ----------------------------------------------------------

      final loadedSchema =
          await SchemaService.instance.loadSchema(
        widget.spreadsheetId,
      );

      if (!mounted) return;

      setState(() {
        schema = loadedSchema;
        loading = false;
      });

      // ----------------------------------------------------------
      // Load records
      // ----------------------------------------------------------

      await loadRecords();
    } catch (e) {
      debugPrint(
        'Failed to load spreadsheet: $e',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load spreadsheet: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // LOAD RECORDS
  // ============================================================

  Future<void> loadRecords() async {
    if (schema == null) return;

    if (mounted) {
      setState(() {
        loadingRecords = true;
      });
    }

    try {
      final loadedRecords =
          await RecordService.instance.loadRecords(
        widget.spreadsheetId,
        schema!,
      );

      if (!mounted) return;

      setState(() {
        records = loadedRecords;
        loadingRecords = false;
      });
    } catch (e) {
      debugPrint(
        'Failed to load records: $e',
      );

      if (!mounted) return;

      setState(() {
        loadingRecords = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load records: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE RECORD
  // ============================================================

  Future<void> _deleteRecord(
    IndexedRecord indexedRecord,
  ) async {
    final confirmed = await UIHelper.showConfirmation(
      context,
      title: 'Delete record?',
      message: 'Are you sure you want to delete this record?',
    );

    if (!confirmed) return;

    final originalIndex = indexedRecord.originalIndex;

    try {
      await RecordService.instance.deleteRecord(
        widget.spreadsheetId,
        originalIndex,
      );

      if (!mounted) return;

      // ----------------------------------------------------------
      // Remove from local list
      // ----------------------------------------------------------
      //
      // We can remove it immediately instead of waiting for
      // another network request.
      //

      setState(() {
        records.removeAt(originalIndex);
      });

      UIHelper.showSnackBar(
        context,
        'Record deleted',
      );
    } catch (e) {
      if (!mounted) return;

      UIHelper.showSnackBar(
        context,
        'Failed to delete record: $e',
      );
    }
  }

  // ============================================================
  // EDIT RECORD
  // ============================================================

  Future<void> _editRecord(
    IndexedRecord indexedRecord,
  ) async {
    if (schema == null) return;

    // ----------------------------------------------------------
    // Keep the original position.
    // ----------------------------------------------------------

    final originalIndex = indexedRecord.originalIndex;

    // ----------------------------------------------------------
    // Open AddLogPage with existing values.
    // ----------------------------------------------------------
    //
    // AddLogPage will use these values to initialize its
    // TextEditingControllers / input widgets.
    //
    // When the user finishes editing, AddLogPage should update
    // the existing row instead of creating a new row.
    //

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLogPage(
          schema: schema!,
          spreadsheetId: widget.spreadsheetId,

          // Existing record values.
          initialValues: indexedRecord.record,

          // Tell AddLogPage this is an edit.
          originalIndex: originalIndex,
        ),
      ),
    );

    // ----------------------------------------------------------
    // Refresh after returning from AddLogPage.
    // ----------------------------------------------------------

    if (updated == true) {
      await loadRecords();
    }
  }

  // ============================================================
  // FILTERED RECORDS
  // ============================================================

  List<IndexedRecord> get filteredRecords {
    final query = filterText.trim().toLowerCase();

    // ----------------------------------------------------------
    // No filter
    // ----------------------------------------------------------

    if (query.isEmpty) {
      return records
          .asMap()
          .entries
          .map(
            (entry) => IndexedRecord(
              originalIndex: entry.key,
              record: entry.value,
            ),
          )
          .toList();
    }

    // ----------------------------------------------------------
    // Apply filter
    // ----------------------------------------------------------

    return records
        .asMap()
        .entries
        .where((entry) {
          final record = entry.value;

          // ----------------------------------------------------
          // Search all columns
          // ----------------------------------------------------

          if (filterColumnId == null) {
            return record.values.any(
              (value) => value
                  .toString()
                  .toLowerCase()
                  .contains(query),
            );
          }

          // ----------------------------------------------------
          // Search selected column
          // ----------------------------------------------------

          final value = record[filterColumnId];

          return value
              .toString()
              .toLowerCase()
              .contains(query);
        })
        .map(
          (entry) => IndexedRecord(
            originalIndex: entry.key,
            record: entry.value,
          ),
        )
        .toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spreadsheet'),
      ),

      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [
                // ==================================================
                // ADD LOG
                // ==================================================

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: schema == null
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddLogPage(
                                  schema: schema!,
                                  spreadsheetId:
                                      widget.spreadsheetId,
                                ),
                              ),
                            );

                            // Refresh records after returning.
                            await loadRecords();
                          },

                    child: const Text('Add Log'),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // CONFIGURE COLUMNS
                // ==================================================

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed:
                        savingSchema || schema == null
                            ? null
                            : () async {
                                final columns =
                                    await Navigator.push<
                                        List<LogColumn>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ConfigureColumnsPage(
                                      initialColumns:
                                          schema!.columns,
                                    ),
                                  ),
                                );

                                if (columns == null) return;

                                final updatedSchema =
                                    LogSchema(
                                  version:
                                      schema!.version,
                                  logSheetName:
                                      schema!.logSheetName,
                                  columns: columns,
                                );

                                setState(() {
                                  savingSchema = true;
                                });

                                try {
                                  await SchemaService
                                      .instance
                                      .saveSchema(
                                    widget.spreadsheetId,
                                    schema!,
                                    updatedSchema,
                                  );

                                  if (!mounted) return;

                                  setState(() {
                                    schema =
                                        updatedSchema;
                                    savingSchema = false;
                                  });

                                  // Column order / structure
                                  // may have changed.
                                  await loadRecords();

                                  if (!mounted) return;

                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Schema saved',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;

                                  setState(() {
                                    savingSchema = false;
                                  });

                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to save schema: $e',
                                      ),
                                    ),
                                  );
                                }
                              },

                    child: const Text(
                      'Configure Columns',
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // SPREADSHEET SETTINGS
                // ==================================================

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton(
                    onPressed: savingSchema
                        ? null
                        : () {
                            // Spreadsheet Settings
                          },

                    child: const Text(
                      'Spreadsheet Settings',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // RECORDS HEADER
                // ==================================================

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Records',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    Text(
                      '${filteredRecords.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ==================================================
                // FILTER
                // ==================================================

                _buildRecordFilter(),

                const SizedBox(height: 12),

                // ==================================================
                // RECORD LIST
                // ==================================================

                Expanded(
                  child: _buildRecordsList(),
                ),
              ],
            ),
          ),

          // ========================================================
          // SAVING OVERLAY
          // ========================================================

          if (savingSchema)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black54,

                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),

                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,

                          children: [
                            CircularProgressIndicator(),

                            SizedBox(height: 16),

                            Text(
                              'Saving schema...',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // RECORD FILTER
  // ============================================================

  Widget _buildRecordFilter() {
    return Row(
      children: [
        // --------------------------------------------------------
        // COLUMN FILTER
        // --------------------------------------------------------

        Expanded(
          flex: 2,

          child: DropdownButtonFormField<String?>(
            value: filterColumnId,

            decoration: const InputDecoration(
              labelText: 'Filter by',
              border: OutlineInputBorder(),

              contentPadding:
                  EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),

            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Columns'),
              ),

              ...schema!.columns.map(
                (column) {
                  return DropdownMenuItem<String?>(
                    value: column.id,

                    child: Text(
                      column.name,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ],

            onChanged: (value) {
              setState(() {
                filterColumnId = value;
              });
            },
          ),
        ),

        const SizedBox(width: 12),

        // --------------------------------------------------------
        // SEARCH
        // --------------------------------------------------------

        Expanded(
          flex: 3,

          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search',
              prefixIcon:
                  Icon(Icons.search),
              border: OutlineInputBorder(),

              contentPadding:
                  EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),

            onChanged: (value) {
              setState(() {
                filterText = value;
              });
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECORD LIST
  // ============================================================

  Widget _buildRecordsList() {
    if (loadingRecords) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final visibleRecords = filteredRecords;

    if (visibleRecords.isEmpty) {
      return const Center(
        child: Text(
          'No records found',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: visibleRecords.length,

      itemBuilder: (context, index) {
        final indexedRecord =
            visibleRecords[index];

        final record =
            indexedRecord.record;

        final originalIndex =
            indexedRecord.originalIndex;

        return Card(
          margin: const EdgeInsets.only(
            bottom: 8,
          ),

          child: Padding(
            padding: const EdgeInsets.all(12),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // ------------------------------------------------
                // Record header
                // ------------------------------------------------

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        // Use originalIndex here so the number
                        // remains stable while filtering.
                        'Record ${originalIndex + 1}',

                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    // ------------------------------------------------
                    // Edit
                    // ------------------------------------------------

                    IconButton(
                      tooltip: 'Edit record',

                      icon: const Icon(
                        Icons.edit_outlined,
                      ),

                      onPressed: () {
                        _editRecord(
                          indexedRecord,
                        );
                      },
                    ),

                    // ------------------------------------------------
                    // Delete
                    // ------------------------------------------------

                    IconButton(
                      tooltip: 'Delete record',

                      icon: const Icon(
                        Icons.delete_outline,
                      ),

                      onPressed: () {
                        _deleteRecord(
                          indexedRecord,
                        );
                      },
                    ),
                  ],
                ),

                const Divider(),

                // ------------------------------------------------
                // Record fields
                // ------------------------------------------------

                ...schema!.columns.map(
                  (column) {
                    final value =
                        record[column.id];

                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 4,
                      ),

                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          SizedBox(
                            width: 110,

                            child: Text(
                              column.name,

                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),

                          Expanded(
                            child: Text(
                              value?.toString() ??
                                  '',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}