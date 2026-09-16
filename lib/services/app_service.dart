import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sheets_manager/util/ui_helper.dart';

import 'sheets_service.dart';
import 'schema_service.dart';
import 'record_service.dart';
import 'spreadsheet_storage.dart';

class AppService {
  AppService._();

  static final AppService instance = AppService._();

  final SheetsService sheets = SheetsService.instance;
  final SchemaService schemaService = SchemaService.instance;
  final RecordService recordService = RecordService.instance;
  final SpreadsheetStorage storage =
      SpreadsheetStorage.instance;

  /// Loads all spreadsheets saved locally.
  ///
  /// Invalid/deleted/trashed spreadsheets are removed
  /// from local storage.
  Future<List<Map<String, dynamic>>> loadSpreadsheets() async {
    return storage.getSpreadsheets();
  }

  /// Creates a new spreadsheet and saves its ID locally.
  Future<String> createSpreadsheet() async {
    final id = await sheets.createSpreadsheet();
    
    await storage.saveSpreadsheet(id, 'My New Spreadsheet');
    return id;
  }

  Future<String?> addSpreadsheet(String id, context) async {
  try {
    final response = await sheets.getSpreadsheet(id);
    final data = jsonDecode(response) as Map<String, dynamic>;

    final properties = data['properties'] as Map<String, dynamic>?;

    final title = properties?['title'] as String? ?? 'Untitled spreadsheet';

    await storage.saveSpreadsheet(id, title);

    UIHelper.showSnackBar(context, "Added Spreadsheet");
    return id;
  } catch (e) {
    debugPrint('Failed to add spreadsheet: $id $e');
    UIHelper.showSnackBar(context, "Failed to add spreadsheet: $id");
  }
}

  /// Removes a spreadsheet ID from local storage.
  ///
  /// This does NOT delete the actual Google Spreadsheet.
  Future<void> removeSpreadsheet(String spreadsheetId) async {
    await storage.removeSpreadsheet(spreadsheetId);
  }

  Future<List<Map<String, dynamic>>> refreshSpreadsheets() async {
    final cached = await storage.getSpreadsheets();

    final List<Map<String, dynamic>> spreadsheets = [];

    for (final spreadsheet in cached) {
      final id = spreadsheet['id'] as String;

      try {        
        final isTrashed =
          await SheetsService.instance.isSpreadsheetTrashed(id);

        if (isTrashed){
          continue;
        }

        final response = await sheets.getSpreadsheet(id);

        final data =
            jsonDecode(response) as Map<String, dynamic>;

        spreadsheets.add({
          'id': data['spreadsheetId'],
          'title':
              data['properties']?['title']
                  ?? 'Untitled spreadsheet',
        });
      } catch (e) {
        debugPrint(
          'Spreadsheet $id is no longer accessible: $e',
        );
      }
    }

    await storage.setSpreadsheets(spreadsheets);

    return spreadsheets;
  }

  /// Loads a spreadsheet's schema.
  Future<dynamic> loadSchema(String spreadsheetId) async {
    return schemaService.loadSchema(spreadsheetId);
  }

  /// Saves a new schema.
  Future<void> saveSchema(
    String spreadsheetId,
    dynamic oldSchema,
    dynamic newSchema,
  ) async {
    await schemaService.saveSchema(
      spreadsheetId,
      oldSchema,
      newSchema,
    );
  }

  /// Adds a log entry.
  Future<void> addLog(
    String spreadsheetId,
    dynamic schema,
    Map<String, dynamic> values,
  ) async {
    await recordService.addLog(
      spreadsheetId,
      schema,
      values,
    );
  }

  String extractSpreadsheetId(String input) {
    input = input.trim();

    // If it's already just an ID, return it
    if (!input.contains('/')) {
      return input;
    }

    try {
      final uri = Uri.parse(input);
      final segments = uri.pathSegments;

      final dIndex = segments.indexOf('d');

      if (dIndex != -1 && dIndex + 1 < segments.length) {
        return segments[dIndex + 1];
      }
    } catch (_) {
      // Invalid URL — fall through
    }

    // Return original input if it couldn't be parsed
    return input;
  }
}