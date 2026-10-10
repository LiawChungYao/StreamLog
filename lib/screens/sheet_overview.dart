import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/sheets_service.dart';
import '../util/ui_helper.dart';

class SheetOverviewScreen extends StatefulWidget {
  final String spreadsheetId;

  const SheetOverviewScreen({
    super.key,
    required this.spreadsheetId,
  });

  @override
  State<SheetOverviewScreen> createState() =>
      _SheetOverviewScreenState();
}

class _SheetOverviewScreenState extends State<SheetOverviewScreen> {
  final SheetsService sheets = SheetsService.instance;

  Map<String, dynamic>? spreadsheet;
  bool isLoading = true;
  bool isRenaming = false;

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
        isLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD SPREADSHEET ERROR: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load spreadsheet.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (spreadsheet == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Spreadsheet Settings'),
        ),
        body: const Center(
          child: Text('Unable to load spreadsheet.'),
        ),
      );
    }

    final properties =
        spreadsheet!['properties'] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spreadsheet Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Spreadsheet Name',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              properties['title'] as String? ?? '',
              style: const TextStyle(fontSize: 18),
            ),
            trailing: IconButton(
              tooltip: 'Rename spreadsheet',
              icon: const Icon(Icons.edit),
              onPressed: isRenaming ? null : _renameSpreadsheet,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSpreadsheet() async {
    final properties =
        spreadsheet!['properties'] as Map<String, dynamic>;

    final newName = await UIHelper.showTextInput(
      context,
      title: 'Rename spreadsheet',
      labelText: 'Spreadsheet name',
      hintText: 'Enter spreadsheet name',
    );

    if (!mounted || newName == null || newName.trim().isEmpty) {
      return;
    }

    final trimmedName = newName.trim();

    setState(() {
      isRenaming = true;
    });

    try {
      await sheets.renameSpreadsheet(
        widget.spreadsheetId,
        trimmedName,
      );

      if (!mounted) return;

      setState(() {
        properties['title'] = trimmedName;
      });

      UIHelper.showSnackBar(
        context,
        'Spreadsheet renamed successfully.',
      );
    } catch (e) {
      debugPrint('RENAME SPREADSHEET ERROR: $e');

      if (!mounted) return;

      UIHelper.showSnackBar(
        context,
        'Failed to rename spreadsheet.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isRenaming = false;
        });
      }
    }
  }
}
