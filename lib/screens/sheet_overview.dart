import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/sheets_service.dart';

class SheetOverviewScreen extends StatefulWidget {
  final String spreadsheetId;
  const SheetOverviewScreen({
    super.key,
    required this.spreadsheetId,
  });

  @override
  State<SheetOverviewScreen> createState() => _SheetOverviewScreenState();
}

class _SheetOverviewScreenState extends State<SheetOverviewScreen> {
  final SheetsService sheets = SheetsService.instance;

  Map<String, dynamic>? spreadsheet;

  @override
  void initState() {
    super.initState();
    _loadSpreadsheet(); 
  }

  Future<void> _loadSpreadsheet() async {
    try {
      final response = await sheets.getSpreadsheet(
        widget.spreadsheetId,
      );

      final data = jsonDecode(response) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        spreadsheet = data;
      });
    } catch (e) {
      print('LOAD SPREADSHEET ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (spreadsheet == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final properties = spreadsheet!['properties'];
    final sheetList = spreadsheet!['sheets'] as List<dynamic>;
    return Scaffold(
      appBar: AppBar(
        title: Text(properties['title']),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSpreadsheetName(properties),
          const SizedBox(height: 24),

          _buildSheets(sheetList),
          const SizedBox(height: 24),

          // _buildAppearance(),
          // const SizedBox(height: 24),

          // _buildFormatting(),
        ],
      ),
    );
  }

Future<String?> _showRenameDialog({
  required String title,
  required String currentName,
  required String hintText,
}) async {
  final controller = TextEditingController(text: currentName);

  final newName = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hintText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                controller.text.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  return newName;
}

Widget _buildSpreadsheetName(Map<String, dynamic> properties) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Spreadsheet',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 12),

      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          properties['title'],
          style: const TextStyle(
            fontSize: 18,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: (){ _renameSpreadsheet();},
        ),
      ),
    ],
  );
}

Future<void> _renameSpreadsheet() async {
  final newName = await _showRenameDialog(
    title: 'Rename spreadsheet',
    currentName: spreadsheet!['properties']['title'],
    hintText: 'Spreadsheet name',
  );

  if (newName == null || newName.isEmpty) {
    return;
  }

  await sheets.renameSpreadsheet(
    widget.spreadsheetId,
    newName,
  );

  setState(() {
    spreadsheet!['properties']['title'] = newName;
  });
}

Widget _buildSheets(List<dynamic> sheetList) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Sheets',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 8),

      ...sheetList.map((sheet) {
        final properties = sheet['properties'];

        return ListTile(
          leading: const Icon(Icons.drag_handle),
          title: Text(properties['title']),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _renameSheet(
                properties['sheetId'],
                properties['title'],
              );
            },
          ),
        );
      }),

      
      ElevatedButton(
        onPressed: () async {sheets.createSheet(widget.spreadsheetId, _getNewSheetName(sheetList));}, 
        child: const Text("+ New Sheet"),
      )  
    ],
  );
}

String _getNewSheetName(List<dynamic> sheetList) {
  const baseName = 'New Sheet';

  final existingNames = sheetList
      .map((sheet) => sheet['properties']['title'] as String)
      .toSet();

  if (!existingNames.contains(baseName)) {
    return baseName;
  }

  int number = 2;

  while (existingNames.contains('$baseName $number')) {
    number++;
  }

  return '$baseName $number';
}

Future<void> _renameSheet(
  int sheetId,
  String currentName,
) async {
  final newName = await _showRenameDialog(
    title: 'Rename sheet',
    currentName: currentName,
    hintText: 'Sheet name',
  );

  if (newName == null || newName.isEmpty) {
    return;
  }

  await sheets.renameSheet(
    widget.spreadsheetId,
    sheetId,
    newName,
  );
}

Widget _buildAppearance() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Appearance',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      ListTile(
        title: const Text('Theme'),
        trailing: const Text('Default'),
        onTap: () {
          // Show theme selector
        },
      ),

      ListTile(
        title: const Text('Default font'),
        trailing: const Text('Arial'),
        onTap: () {
          // Show font selector
        },
      ),

      ListTile(
        title: const Text('Default size'),
        trailing: const Text('12'),
        onTap: () {
          // Show font size selector
        },
      ),
    ],
  );
}

Widget _buildFormatting() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Formatting',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      ListTile(
        title: const Text('Text color'),
        trailing: const Icon(Icons.palette),
        onTap: () {
          // Color picker
        },
      ),

      ListTile(
        title: const Text('Background color'),
        trailing: const Icon(Icons.palette),
        onTap: () {
          // Color picker
        },
      ),

      ListTile(
        title: const Text('Alignment'),
        trailing: const Text('Center'),
        onTap: () {
          // Alignment selector
        },
      ),

      ListTile(
        title: const Text('Vertical alignment'),
        trailing: const Text('Middle'),
        onTap: () {
          // Vertical alignment selector
        },
      ),

      ListTile(
        title: const Text('Text wrapping'),
        trailing: const Text('Wrap'),
        onTap: () {
          // Wrapping selector
        },
      ),
    ],
  );
}

}