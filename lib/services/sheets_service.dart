import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../services/google_auth.dart';
import 'package:http_parser/http_parser.dart';

class SheetsService {
  SheetsService._();
  static final SheetsService instance = SheetsService._();
  final GoogleAuthService auth = GoogleAuthService.instance;

  // ============================================================
  // SPREADSHEET
  // ============================================================

  Future<String> createSpreadsheet() async {
    final accessToken = await getAccessToken();

    final response = await http.post(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'properties': {
          'title': 'My New Spreadsheet',
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create spreadsheet: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    return data['spreadsheetId'] as String;
  }

  Future<String> getAccessToken() async {
    final authentication = await auth.getAuthentication();
    final accessToken = authentication.accessToken;

    if (accessToken == null) {
      throw Exception('Failed to obtain Google access token');
    }

    return accessToken;
  }

  Future<String> getSpreadsheet(String id) async {
    final accessToken = await getAccessToken();

    final response = await http.get(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$id',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    }

    throw Exception(
      'Unable to retrieve spreadsheet: ${response.body}',
    );
  }

  Future<void> renameSpreadsheet(
    String spreadsheetId,
    String newName,
  ) async {
    final accessToken = await getAccessToken();

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
            'updateSpreadsheetProperties': {
              'properties': {
                'title': newName,
              },
              'fields': 'title',
            },
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to rename spreadsheet: ${response.body}',
      );
    }
  }

  Future<bool> isSpreadsheetTrashed(
    String spreadsheetId,
  ) async {
    final authentication =
        await auth.getAuthentication();

    final accessToken = authentication.accessToken;

    final response = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files/'
        '$spreadsheetId?fields=id,name,trashed',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      return data['trashed'] == true;
    }

    if (response.statusCode == 404) {
      // Treat a missing/inaccessible spreadsheet as unavailable.
      return true;
    }

    throw Exception(
      'Failed to check spreadsheet: ${response.body}',
    );
  }

  String columnLetter(int columnNumber) {
    var result = '';

    while (columnNumber > 0) {
      columnNumber--;
      result = String.fromCharCode(65 + (columnNumber % 26)) + result;
      columnNumber ~/= 26;
    }

    return result;
  }
  // ============================================================
  // SHEETS
  // ============================================================

  Future<void> renameSheet(
    String spreadsheetId,
    int sheetId,
    String newName,
  ) async {
    final accessToken = await getAccessToken();

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
            'updateSheetProperties': {
              'properties': {
                'sheetId': sheetId,
                'title': newName,
              },
              'fields': 'title',
            },
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to rename sheet: ${response.body}',
      );
    }
  }

  Future<int> createSheet(
    String spreadsheetId,
    String sheetName,
  ) async {
    debugPrint('Creating New Sheet: $sheetName');

    final accessToken = await getAccessToken();

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
            'addSheet': {
              'properties': {
                'title': sheetName,
              },
            },
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create sheet "$sheetName": ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final replies = data['replies'] as List<dynamic>? ?? [];

    if (replies.isEmpty) {
      throw Exception(
        'Sheet "$sheetName" was created but no reply was returned.',
      );
    }

    final properties =
        replies[0]['addSheet']['properties'] as Map<String, dynamic>;

    return properties['sheetId'] as int;
  }

  Future<bool> sheetExists(
    String spreadsheetId,
    String sheetName,
  ) async {
    final accessToken = await getAccessToken();

    final response = await http.get(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId?fields=sheets.properties',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to check spreadsheet sheets: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final sheets = data['sheets'] as List<dynamic>? ?? [];

    return sheets.any((sheet) {
      final properties =
          sheet['properties'] as Map<String, dynamic>;

      return properties['title'] == sheetName;
    });
  }

  Future<bool> ensureSheetExists(
    String spreadsheetId,
    String sheetName,
  ) async {
    final exists = await sheetExists(
      spreadsheetId,
      sheetName,
    );

    if (exists) {
      debugPrint('$sheetName already exists');
      return exists;
    }

    debugPrint(
      '$sheetName does not exist. Creating it...',
    );

    await createSheet(
      spreadsheetId,
      sheetName,
    );

    debugPrint(
      '$sheetName created successfully',
    );

    return exists;
  }

  Future<int?> getSheetId(
    String spreadsheetId,
    String sheetName,
  ) async {
    final accessToken = await getAccessToken();

    final response = await http.get(
      Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/'
        '$spreadsheetId'
        '?fields=sheets(properties(sheetId,title))',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to get sheet ID: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final sheets = data['sheets'] as List<dynamic>? ?? [];

    for (final sheet in sheets) {
      final properties =
          sheet['properties'] as Map<String, dynamic>;

      final title = properties['title'] as String?;

      if (title == sheetName) {
        return properties['sheetId'] as int?;
      }
    }

    return null;
  }

  Future<String> uploadFileToDrive(File file) async {
    final accessToken = await getAccessToken();

    final fileName = file.path.split(Platform.pathSeparator).last;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files'
        '?uploadType=multipart',
      ),
    );

    request.headers['Authorization'] = 'Bearer $accessToken';

    request.files.add(
      http.MultipartFile.fromString(
        'metadata',
        jsonEncode({
          'name': fileName,
        }),
        contentType: MediaType(
          'application',
          'json',
        ),
      ),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to upload file: $responseBody',
      );
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    final fileId = data['id'] as String?;

    if (fileId == null) {
      throw Exception(
        'File uploaded but no file ID was returned.',
      );
    }

    return 'https://drive.google.com/file/d/$fileId/view';
  }

}
