import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/log_schema.dart';
import '../models/log_column.dart';
import '../services/schema_parser.dart';
import '../services/sheets_service.dart';
import '../services/record_service.dart';
import '../services/google_auth.dart';
class SchemaService {

  SchemaService._();
  static final SchemaService instance = SchemaService._();
  static const int version = 1;
  static const defaultSchema = LogSchema(
        version: version,
        logSheetName: schemaSheetName,
        columns: [],
      );
  static const String schemaSheetName = '_schema';
  static const schemaHeaders = [
    'column_id',
    'name',
    'type',
    'required',
    'metadata_mode',
    'options',
  ];


  // ============================================================
  // SCHEMA
  // ============================================================

  Future<LogSchema> loadSchema(
    String spreadsheetId,
  ) async {
    
    // await ensureSheet(spreadsheetId, recordsSheetName);

    if (!await SheetsService.instance.sheetExists(spreadsheetId, schemaSheetName)){
      await SheetsService.instance.createSheet(spreadsheetId, schemaSheetName);
      return defaultSchema;
    }
      

    // Read Schema
    final accessToken = await SheetsService.instance.getAccessToken();
    const range = schemaSheetName;

    final response = await http.get(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/${Uri.encodeComponent(range)}',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load _schema: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = data['values'] as List<dynamic>? ?? [];

    // If schema is empty, send default
    if (rows.isEmpty) {
      return defaultSchema;
    }
    final columns = SchemaParser.parse(rows);

    return LogSchema(
      version: version,
      logSheetName: schemaSheetName,
      columns: columns,
    );
  }



  Future<void> saveSchema(
    String spreadsheetId,
    LogSchema oldSchema,
    LogSchema newSchema,
  ) async {

    // ------------------------------------------------------------
    // Prepare _schema
    // ------------------------------------------------------------

    await SheetsService.instance.ensureSheetExists(spreadsheetId, schemaSheetName);
    await clearSchema(spreadsheetId);

    // ------------------------------------------------------------
    // Make sure _records exists and synchronize it
    // ------------------------------------------------------------

    await RecordService.instance.synchronizeRecordsSheet(
      spreadsheetId,
      oldSchema.columns,
      newSchema.columns,
    );

    // ------------------------------------------------------------
    // Save the new schema
    // ------------------------------------------------------------
    final accessToken = await SheetsService.instance.getAccessToken();
    final values = <List<dynamic>>[
      schemaHeaders,
    ];


    for (final column in newSchema.columns) {
      final data = column.toSchemaValues();

      values.add(
        schemaHeaders
            .map((header) => data[header] ?? '')
            .toList(),
      );
    }

    final lastColumn = SheetsService.instance.columnLetter(schemaHeaders.length);
    final range =
        "'$schemaSheetName'!A1:$lastColumn${values.length}";

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
        'Failed to save _schema: ${response.body}',
      );
    }
  }

  Future<void> clearSchema(
    String spreadsheetId,
  ) async {


    final accessToken = await SheetsService.instance.getAccessToken();

    final range = "'$schemaSheetName'!A:Z";

    final response = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId/values/${Uri.encodeComponent(range)}:clear',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to clear _schema: ${response.body}',
      );
    }
  }
}