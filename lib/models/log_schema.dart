import 'log_column.dart';

class LogSchema {
  final int version;
  final String logSheetName;
  final List<LogColumn> columns;

  const LogSchema({
    required this.version,
    required this.logSheetName,
    required this.columns,
  });
}
