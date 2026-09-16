import '../models/log_column.dart';

class SchemaParser {
  static List<LogColumn> parse(List<dynamic> rows) {
    if (rows.isEmpty) {
      return [];
    }

    // ------------------------------------------------------------
    // First row = headers
    // ------------------------------------------------------------

    final headers = (rows.first as List<dynamic>)
        .map((value) => value.toString().trim())
        .toList();

    int indexOf(String name) {
      return headers.indexOf(name);
    }

    // Find indexes
    final columnIdIndex = indexOf('column_id');
    final nameIndex = indexOf('name');
    final typeIndex = indexOf('type');
    final requiredIndex = indexOf('required');
    final metadataModeIndex = indexOf('metadata_mode');
    final optionsIndex = indexOf('options');

    // Validate required headers
    if (columnIdIndex == -1 ||
        nameIndex == -1 ||
        typeIndex == -1) {
      throw Exception(
        '_schema must contain column_id, name and type columns',
      );
    }

    // ------------------------------------------------------------
    // Read column definitions
    // ------------------------------------------------------------

    final columns = <LogColumn>[];

    for (final rawRow in rows.skip(1)) {
      final row = rawRow as List<dynamic>;

      String getValue(int index) {
        if (index == -1 || index >= row.length) {
          return '';
        }

        return row[index].toString().trim();
      }

      final columnId = getValue(columnIdIndex);
      final name = getValue(nameIndex);
      final typeString = getValue(typeIndex);

      // Ignore completely empty rows.
      if (columnId.isEmpty &&
          name.isEmpty &&
          typeString.isEmpty) {
        continue;
      }

      // Validate column ID
      if (columnId.isEmpty) {
        throw Exception(
          'Schema column is missing column_id',
        );
      }

      // Validate column name
      if (name.isEmpty) {
        throw Exception(
          'Schema column "$columnId" is missing name',
        );
      }

      // ----------------------------------------------------------
      // Convert type string → ColumnType
      // ----------------------------------------------------------

      final type = switch (typeString) {
        'name' => ColumnType.name,
        'metadata' => ColumnType.metadata,
        'timestamp' => ColumnType.timestamp,
        'number' => ColumnType.number,
        _ => throw Exception(
            'Unknown column type "$typeString" '
            'for column "$columnId"',
          ),
      };

      // ----------------------------------------------------------
      // Required
      // ----------------------------------------------------------

      final requiredString = getValue(requiredIndex);

      final required =
          requiredString.toLowerCase() == 'true';

      // ----------------------------------------------------------
      // Type-specific configuration
      // ----------------------------------------------------------

      ColumnConfig? config;

      if (type == ColumnType.metadata) {
        final metadataModeString =
            getValue(metadataModeIndex);

        final mode = switch (metadataModeString) {
          'freeText' => MetadataMode.freeText,
          'singleSelect' => MetadataMode.singleSelect,
          'multiSelect' => MetadataMode.multiSelect,
          '' => MetadataMode.freeText,
          _ => throw Exception(
              'Unknown metadata mode "$metadataModeString" '
              'for column "$columnId"',
            ),
        };

        final optionsString = getValue(optionsIndex);

        final options = optionsString.isNotEmpty
            ? optionsString
                .split('|')
                .map((option) => option.trim())
                .where((option) => option.isNotEmpty)
                .toList()
            : <String>[];

        config = MetadataConfig(
          mode: mode,
          options: options,
        );
      }

      // ----------------------------------------------------------
      // Create LogColumn
      // ----------------------------------------------------------

      columns.add(
        LogColumn(
          id: columnId,
          name: name,
          type: type,
          required: required,
          config: config,
        ),
      );
    }

    return columns;
  }
}