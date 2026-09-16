import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/log_schema.dart';
import '../models/log_column.dart';
import '../services/schema_parser.dart';
import '../services/sheets_service.dart';
import '../services/google_auth.dart';
class RecordService {

  RecordService._();
 
  static final RecordService instance = RecordService._();
  static const recordsSheetName = "_record";

  // ============================================================
  // Records
  // ============================================================

  Future<void> synchronizeRecordsSheet(
    String spreadsheetId,
    List<LogColumn> oldColumns,
    List<LogColumn> newColumns,
  ) async {
    debugPrint('Synchronizing $recordsSheetName...');

    // ------------------------------------------------------------
    // Make sure _records exists
    // ------------------------------------------------------------

    if (!await SheetsService.instance.ensureSheetExists(spreadsheetId, recordsSheetName)){
      // Since there are no existing records, just create headers.
      await _writeRecordsSheet(
        spreadsheetId,
        newColumns,
        [],
      );

      return;
    }

    // ------------------------------------------------------------
    // Read existing records
    // ------------------------------------------------------------

    final existingRows = await _readRecordsSheet(
      spreadsheetId,
    );

    // No data at all.
    if (existingRows.isEmpty) {
      await _writeRecordsSheet(
        spreadsheetId,
        newColumns,
        [],
      );

      return;
    }

    final oldDataRows = existingRows.skip(1); // Skip headers

    final oldIndexById = {
      for (int i = 0; i < oldColumns.length; i++)
        oldColumns[i].id: i,
    };

    final newDataRows = oldDataRows.map((oldRow) {
      return newColumns.map((newColumn) {
        final oldIndex = oldIndexById[newColumn.id];

        if (oldIndex == null || oldIndex >= oldRow.length) {
          return '';
        }

        return oldRow[oldIndex];
      }).toList();
    }).toList();

    await _writeRecordsSheet(
      spreadsheetId,
      newColumns,
      newDataRows,
    );
  }


  Future<List<List<dynamic>>> _readRecordsSheet(
    String spreadsheetId,
  ) async {
    final accessToken = await SheetsService.instance.getAccessToken();
    final response = await http.get(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/${Uri.encodeComponent(recordsSheetName)}',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to read $recordsSheetName: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final rows = data['values'] as List<dynamic>? ?? [];

    return rows
        .map(
          (row) => List<dynamic>.from(row as List<dynamic>),
        )
        .toList();
  }

  Future<void> _writeRecordsSheet(
    String spreadsheetId,
    List<LogColumn> columns,
    List<List<dynamic>> dataRows,
  ) async {
    final accessToken = await SheetsService.instance.getAccessToken();

    // ------------------------------------------------------------
    // Clear existing records
    // ------------------------------------------------------------

    final clearRange = "'$recordsSheetName'!A:ZZ";

    final clearResponse = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/${Uri.encodeComponent(clearRange)}:clear',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    if (clearResponse.statusCode != 200) {
      throw Exception(
        'Failed to clear $recordsSheetName: '
        '${clearResponse.body}',
      );
    }

    // ------------------------------------------------------------
    // Build header
    // ------------------------------------------------------------

    final values = <List<dynamic>>[];

    values.add(
      columns.map((column) => column.name).toList(),
    );

    // ------------------------------------------------------------
    // Add existing data
    // ------------------------------------------------------------

    values.addAll(dataRows);

    // ------------------------------------------------------------
    // Nothing to write?
    // ------------------------------------------------------------

    if (values.isEmpty) {
      return;
    }

    // ------------------------------------------------------------
    // Calculate range
    // ------------------------------------------------------------

    final endColumn = SheetsService.instance.columnLetter(values.first.length);

    final endRow = values.length;

    final range =
        "'$recordsSheetName'!A1:$endColumn$endRow";

    // ------------------------------------------------------------
    // Write
    // ------------------------------------------------------------

    final response = await http.put(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/${Uri.encodeComponent(range)}'
        '?valueInputOption=RAW',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'range': range,
        'majorDimension': 'ROWS',
        'values': values,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to write $recordsSheetName: ${response.body}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadRecords(
    String spreadsheetId,
    LogSchema schema,
  ) async {
    final accessToken = await SheetsService.instance.getAccessToken();

    // ------------------------------------------------------------
    // Read _records
    // ------------------------------------------------------------

    final range = "'$recordsSheetName'!A:ZZ";

    final response = await http.get(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/'
        '${Uri.encodeComponent(range)}',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load $recordsSheetName: '
        '${response.body}',
      );
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    final rows =
        data['values'] as List<dynamic>? ?? [];

    // No header / no records.
    if (rows.isEmpty) {
      return [];
    }

    // ------------------------------------------------------------
    // First row = headers
    // ------------------------------------------------------------

    final headerRow =
        List<dynamic>.from(rows.first as List<dynamic>);

    // ------------------------------------------------------------
    // Build column indexes from schema
    //
    // The schema determines the meaning of each physical
    // position in _records.
    // ------------------------------------------------------------

    final records = <Map<String, dynamic>>[];

    // ------------------------------------------------------------
    // Read each record
    // ------------------------------------------------------------

    for (final rawRow in rows.skip(1)) {
      final row =
          List<dynamic>.from(rawRow as List<dynamic>);

      // Ignore completely empty rows.
      if (row.every(
        (value) => value.toString().trim().isEmpty,
      )) {
        continue;
      }

      final record = <String, dynamic>{};

      for (int i = 0; i < schema.columns.length; i++) {
        final column = schema.columns[i];

        if (i < row.length) {
          record[column.id] = row[i];
        } else {
          record[column.id] = '';
        }
      }

      records.add(record);
    }

    debugPrint(
      'Loaded ${records.length} records from $recordsSheetName',
    );

    return records;
  }

  Future<void> addLog(
    String spreadsheetId,
    LogSchema schema,
    Map<String, dynamic> values,
  ) async {
    final accessToken = await SheetsService.instance.getAccessToken();

    // Build the row according to the schema order.
    final row = schema.columns.map((column) {
      final value = values[column.id];

      if (value == null) {
        return '';
      }

      if (value is List<String>) {
        return value.join(', ');
      }

      if (value is DateTime) {
        return value.toIso8601String();
      }

      return value.toString();
    }).toList();

    final range = "'$recordsSheetName'!A:Z";

    final response = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/${Uri.encodeComponent(range)}:append'
        '?valueInputOption=USER_ENTERED'
        '&insertDataOption=INSERT_ROWS',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'majorDimension': 'ROWS',
        'values': [row],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to add log: ${response.body}',
      );
    }

    debugPrint('Log added to $recordsSheetName');
  }

  Future<void> deleteRecord(
    String spreadsheetId,
    int rowIndex,
  ) async {
    final accessToken =
        await SheetsService.instance.getAccessToken();

    // Google Sheets rows are zero-based in batchUpdate.
    //
    // rowIndex is the index of the record in your records list.
    // Because row 0 is the header, the actual sheet row is:
    //
    // record index 0 -> sheet row 1 (zero-based)
    // record index 1 -> sheet row 2
    // record index 2 -> sheet row 3

    final sheetId = await SheetsService.instance.getSheetId(
      spreadsheetId,
      recordsSheetName,
    );

    if (sheetId == null) {
      throw Exception(
        'Sheet "$recordsSheetName" does not exist.',
      );
    }

    final response = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId:batchUpdate',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': sheetId,
                'dimension': 'ROWS',
                'startIndex': rowIndex + 1,
                'endIndex': rowIndex + 2,
              },
            },
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete record: ${response.body}',
      );
    }

    debugPrint(
      'Deleted record at index $rowIndex from $recordsSheetName',
    );
  }

  Future<void> updateRecord(
    String spreadsheetId,
    LogSchema schema,
    int originalIndex,
    Map<String, dynamic> values,
  ) async {
    final accessToken =
        await SheetsService.instance.getAccessToken();

    // Convert the record into the same column order
    // used by the schema.
    final row = schema.columns.map((column) {
      final value = values[column.id];

      if (value == null) {
        return '';
      }

      if (value is List<String>) {
        return value.join(', ');
      }

      if (value is DateTime) {
        return value.toIso8601String();
      }

      return value.toString();
    }).toList();

    // Google Sheets row 1 is the header.
    // originalIndex 0 = Sheet row 2.
    final sheetRow = originalIndex + 2;

    final endColumn =
        SheetsService.instance.columnLetter(row.length);

    final range =
        "'$recordsSheetName'!A$sheetRow:$endColumn$sheetRow";

    final response = await http.put(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/'
        '${Uri.encodeComponent(range)}'
        '?valueInputOption=USER_ENTERED',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'range': range,
        'majorDimension': 'ROWS',
        'values': [row],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update record: ${response.body}',
      );
    }

    debugPrint(
      'Record $originalIndex updated in $recordsSheetName',
    );
  }
}