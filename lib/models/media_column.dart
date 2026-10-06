import 'package:flutter/material.dart';
import 'column_type.dart';
import 'log_column.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '/services/sheets_service.dart';

class MediaColumn extends ColumnType {
  const MediaColumn();

  @override
  String get name => 'media';

  @override
  String get displayName => 'Media';

  @override
  String? validate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is! List) {
      return 'Invalid media value';
    }

    return null;
  }

  @override
  MediaColumn fromSchemaValues(Map<String, dynamic> values) {
    return const MediaColumn();
  }

  @override
  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<ColumnType> onChanged,
  }) {
    return const SizedBox.shrink();
  }

  @override
  Widget buildInput({
    required BuildContext context,
    required LogColumn column,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  }) {
    final files = value is List
        ? List<PendingFile>.from(value)
        : <PendingFile>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (files.isEmpty)
          const Text('No files attached')
        else
          ...files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: buildPreview(file),
                ),
              ),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  final updated = List<PendingFile>.from(files);
                  updated.removeAt(index);
                  onChanged(updated);
                },
              ),
            );
          }),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          onPressed: () async {
            // We'll implement this next.
            final result = await _showAddFileDialog(context);

            if (result != null) {
              onChanged([
                ...files,
                result,
              ]);
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Add file'),
        ),
      ],
    );
  }

  Future<PendingFile?> _showAddFileDialog(
    BuildContext context,
  ) async {
    return showDialog<PendingFile>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add attachment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Add link'),
                onTap: () async {
                  Navigator.pop(
                    dialogContext,
                    await _showAddLinkDialog(context),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Upload file'),
                onTap: () async {
                  final file = await _pickFile();

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, file);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<PendingFile?> _showAddLinkDialog(
    BuildContext context,
  ) async {
    final controller = TextEditingController();

    try {
      return await showDialog<PendingFile>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add link'),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/file.pdf',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final text = controller.text.trim();
                  final uri = Uri.tryParse(text);

                  if (uri == null ||
                      !{'http', 'https'}.contains(uri.scheme) ||
                      uri.host.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid URL.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(
                    dialogContext,
                    PendingFile.link(
                      name: text,
                      link: text,
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    } finally {
    }
  }

  Future<PendingFile?> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.single;
      final path = pickedFile.path;

      if (path == null) {
        throw Exception('Could not access the selected file.');
      }

      return PendingFile.file(
        name: pickedFile.name,
        file: File(path),
      );
    } catch (e) {
      debugPrint('File selection failed: $e');
      rethrow;
    }
  }

  Future<List<String>> processValues(
    List<PendingFile> files,
  ) async {
    final urls = <String>[];

    for (final pendingFile in files) {
      if (pendingFile.isLink) {
        urls.add(pendingFile.link!);
      } else if (pendingFile.file != null) {
        final url = await SheetsService.instance.uploadFileToDrive(
          pendingFile.file!,
        );
        urls.add(url);
      }
    }

    return urls;
  }

  Widget buildPreview(PendingFile pendingFile) {
    if (!pendingFile.isLink && pendingFile.file != null) {
      return Image.file(
        pendingFile.file!,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }

    if (pendingFile.isLink && pendingFile.link != null) {
      return Image.network(
        pendingFile.link!,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }

    return const Icon(Icons.insert_drive_file, size: 48);
  }
}

class PendingFile {
  final String name;
  final File? file;
  final String? link;

  const PendingFile._({
    required this.name,
    this.file,
    this.link,
  });

  const PendingFile.file({
    required String name,
    required File file,
  }) : this._(name: name, file: file);

  const PendingFile.link({
    required String name,
    required String link,
  }) : this._(name: name, link: link);

  bool get isLink => link != null;

  @override
  String toString() {
    if (isLink) {
      return 'PendingFile.link($link)';
    }

    return 'PendingFile.file(${file?.path})';
  }
}