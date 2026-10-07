import 'dart:convert';

import '../models/column_type.dart';
import '../models/log_column.dart';

class SchemaParser {
  static List<LogColumn> parse(List<dynamic> rows) {
    if (rows.isEmpty) {
      return [];
    }

    final headers = (rows.first as List<dynamic>)
        .map((value) => value.toString().trim())
        .toList();

    int indexOf(String name) {
      return headers.indexOf(name);
    }

    final columnIdIndex = indexOf('column_id');
    final nameIndex = indexOf('name');
    final typeIndex = indexOf('type');

    if (columnIdIndex == -1 ||
        nameIndex == -1 ||
        typeIndex == -1) {
      throw Exception(
        '_schema must contain column_id, name and type columns',
      );
    }

    final columns = <LogColumn>[];

    for (final rawRow in rows.skip(1)) {
      final row = rawRow as List<dynamic>;

      String getValue(String header) {
        final index = indexOf(header);

        if (index == -1 || index >= row.length) {
          return '';
        }

        return row[index].toString().trim();
      }

      final columnId = getValue('column_id');
      final name = getValue('name');
      final typeName = getValue('type');

      // Ignore completely empty rows.
      if (columnId.isEmpty &&
          name.isEmpty &&
          typeName.isEmpty) {
        continue;
      }

      if (columnId.isEmpty) {
        throw Exception(
          'Schema column is missing column_id',
        );
      }

      if (name.isEmpty) {
        throw Exception(
          'Schema column "$columnId" is missing name',
        );
      }

      final type = _parseColumnType(
        typeName,
        row,
        headers,
        columnId,
      );

      final required =
          getValue('required').toLowerCase() == 'true';

      columns.add(
        LogColumn(
          id: columnId,
          name: name,
          type: type,
          required: required,
        ),
      );
    }

    return columns;
  }

  static ColumnType _parseColumnType(
    String typeName,
    List<dynamic> row,
    List<String> headers,
    String columnId,
  ) {
    final type = ColumnRegistry.fromName(typeName);

    if (type == null) {
      throw Exception(
        'Unknown column type "$typeName" '
        'for column "$columnId"',
      );
    }

    final config = _getConfig(row, headers, columnId);

    return type.fromSchemaValues(config);
  }

  static Map<String, dynamic> _getConfig(
    List<dynamic> row,
    List<String> headers,
    String columnId,
  ) {
    final configIndex = headers.indexOf('config');

    if (configIndex == -1 ||
        configIndex >= row.length ||
        row[configIndex].toString().trim().isEmpty) {
      return {};
    }

    final rawConfig = row[configIndex].toString().trim();

    try {
      final decoded = jsonDecode(rawConfig);

      if (decoded is! Map) {
        throw const FormatException(
          'Config must be a JSON object',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } on FormatException catch (e) {
      throw Exception(
        'Invalid config for column "$columnId": ${e.message}',
      );
    }
  }
}