import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpreadsheetStorage {
  SpreadsheetStorage._();

  static final SpreadsheetStorage instance =
      SpreadsheetStorage._();

  static const String _storageKey = 'spreadsheets';

  /// Returns all locally saved spreadsheets.
  ///
  /// Each spreadsheet has:
  /// {
  ///   "id": "...",
  ///   "title": "..."
  /// }
  Future<List<Map<String, dynamic>>> getSpreadsheets() async {
    final prefs = await SharedPreferences.getInstance();

    final saved =
        prefs.getStringList(_storageKey) ?? [];

    final spreadsheets = <Map<String, dynamic>>[];

    for (final item in saved) {
      try {
        final data =
            jsonDecode(item) as Map<String, dynamic>;

        if (data['id'] == null) {
          continue;
        }

        spreadsheets.add({
          'id': data['id'],
          'title': data['title'] ?? 'Untitled spreadsheet',
        });
      } catch (e) {
        debugPrint(
          'Failed to parse saved spreadsheet: $e',
        );
      }
    }

    debugPrint(
      'GET SPREADSHEETS: $spreadsheets',
    );

    return spreadsheets;
  }

  /// Saves a spreadsheet locally.
  ///
  /// If the spreadsheet already exists, its title is updated.
  Future<void> saveSpreadsheet(
    String id,
    String title,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final spreadsheets =
        prefs.getStringList(_storageKey) ?? [];

    final data = jsonEncode({
      'id': id,
      'title': title,
    });

    bool updated = false;

    for (int i = 0; i < spreadsheets.length; i++) {
      try {
        final existing =
            jsonDecode(spreadsheets[i])
                as Map<String, dynamic>;

        if (existing['id'] == id) {
          spreadsheets[i] = data;
          updated = true;
          break;
        }
      } catch (e) {
        debugPrint(
          'Failed to parse existing spreadsheet: $e',
        );
      }
    }

    if (!updated) {
      spreadsheets.add(data);
    }

    await prefs.setStringList(
      _storageKey,
      spreadsheets,
    );

    debugPrint(
      'SAVE SPREADSHEET: $id - $title',
    );
  }

  /// Removes a spreadsheet from local storage.
  ///
  /// This does NOT delete the actual Google Spreadsheet.
  Future<void> removeSpreadsheet(String id) async {
    final prefs = await SharedPreferences.getInstance();

    final spreadsheets =
        prefs.getStringList(_storageKey) ?? [];

    spreadsheets.removeWhere((item) {
      try {
        final data =
            jsonDecode(item)
                as Map<String, dynamic>;

        return data['id'] == id;
      } catch (e) {
        // Keep malformed entries.
        return false;
      }
    });

    await prefs.setStringList(
      _storageKey,
      spreadsheets,
    );

    debugPrint(
      'REMOVED SPREADSHEET: $id',
    );
  }

  /// Replaces all locally stored spreadsheets.
  Future<void> setSpreadsheets(
    List<Map<String, dynamic>> spreadsheets,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final data = spreadsheets.map((spreadsheet) {
      return jsonEncode({
        'id': spreadsheet['id'],
        'title':
            spreadsheet['title'] ?? 'Untitled spreadsheet',
      });
    }).toList();

    await prefs.setStringList(
      _storageKey,
      data,
    );

    debugPrint(
      'SET SPREADSHEETS: $spreadsheets',
    );
  }


  Future<void> removeSpreadsheetFromPreferences(
    String spreadsheetId,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final existing =
        prefs.getStringList('spreadsheets') ?? [];

    final updated = existing.where((item) {
      try {
        final data =
            jsonDecode(item) as Map<String, dynamic>;

        return data['id'] != spreadsheetId;
      } catch (e) {
        // Keep malformed entries rather than deleting them.
        return true;
      }
    }).toList();

    await prefs.setStringList(
      'spreadsheets',
      updated,
    );

    debugPrint(
      'Removed spreadsheet $spreadsheetId from SharedPreferences',
    );
  }

    Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}