import 'package:flutter/material.dart';
import 'column_type.dart';
import 'log_column.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '/services/sheets_service.dart';
import '/util/ui_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
class MediaColumn extends ColumnType {
  final MediaConfig config;

  const MediaColumn({
    this.config = const MediaConfig(),
  });

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
    final automaticDisplay =
        values['media_automatic_display'] == null ||
        values['media_automatic_display'].toString().toLowerCase() == 'true';

    return MediaColumn(
      config: MediaConfig(
        automaticDisplay: automaticDisplay,
      ),
    );
  }

  @override
  Map<String, dynamic> toSchemaValues() {
    return config.toSchemaValues();
  }

  @override
  Widget buildConfiguration({
    required BuildContext context,
    required LogColumn column,
    required ValueChanged<ColumnType> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Automatically display images'),
      subtitle: const Text(
        'Load images automatically instead of showing their links.',
      ),
      value: config.automaticDisplay,
      onChanged: (value) {
        onChanged(
          MediaColumn(
            config: config.copyWith(
              automaticDisplay: value,
            ),
          ),
        );
      },
    );
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
    final text = await UIHelper.showTextInput(
      context,
      title: 'Add link',
      labelText: 'URL',
      hintText: 'https://example.com/file.jpg',
    );  

    if (!context.mounted || text == null) {
      return null;
    }

    final value = text.trim();
    final uri = Uri.tryParse(value);

    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      UIHelper.showSnackBar(
        context,
        'Please enter a valid URL.',
      );
      return null;
    }

    return PendingFile.link(
      name: value,
      link: value,
    );
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
      final fileId = _extractDriveFileId(pendingFile.link!);

      if (fileId == null) {
        return const Icon(Icons.broken_image);
      }

      return FutureBuilder<Uint8List>(
        future: _downloadThumbnail(fileId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 100,
              height: 100,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const SizedBox(
              width: 100,
              height: 100,
              child: Icon(Icons.broken_image),
            );
          }

          return Image.memory(
            snapshot.data!,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          );
        },
      );
    }

    return const Icon(Icons.insert_drive_file, size: 48);
  }

  Future<Uint8List> _downloadThumbnail(String fileId) async {
    final accessToken =
        await SheetsService.instance.getAccessToken();

    final response = await http.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files/$fileId'
        '?alt=media',
      ),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download image: ${response.statusCode}',
      );
    }

    return response.bodyBytes;
  }

  String? _extractDriveFileId(String url) {
    final match = RegExp(r'/file/d/([^/]+)').firstMatch(url);
    return match?.group(1);
  }

  @override
  Widget buildDisplay({
    required BuildContext context,
    required LogColumn column,
    required dynamic value,
  }) {
    final urls = _extractUrls(value);

    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    if (config.automaticDisplay) {
      return _buildImages(urls);
    }

    return _buildLinksWithLoadButton(urls);
  }

  List<String> _extractUrls(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .toList();
    }

    return [];
  }

  Widget _buildImages(List<String> urls) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls.map(_buildImage).toList(),
    );
  }

  Widget _buildImage(String url) {
    final fileId = _extractDriveFileId(url);

    if (fileId != null) {
      return FutureBuilder<Uint8List>(
        future: _downloadThumbnail(fileId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 80,
              height: 80,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const SizedBox(
              width: 80,
              height: 80,
              child: Icon(Icons.broken_image),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              snapshot.data!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const SizedBox(
            width: 80,
            height: 80,
            child: Icon(Icons.broken_image),
          );
        },
      ),
    );
  }

  Widget _buildLinksWithLoadButton(List<String> urls) {
    var showImages = false;

    return StatefulBuilder(
      builder: (context, setState) {
        if (showImages) {
          return _buildImages(urls);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...urls.map(
              (url) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  showImages = true;
                });
              },
              icon: const Icon(Icons.image),
              label: const Text('Show'),
            ),
          ],
        );
      },
    );
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


class MediaConfig {
  final bool automaticDisplay;

  const MediaConfig({
    this.automaticDisplay = true,
  });

  Map<String, dynamic> toSchemaValues() {
    return {
      'media_automatic_display': automaticDisplay.toString(),
    };
  }

  MediaConfig copyWith({
    bool? automaticDisplay,
  }) {
    return MediaConfig(
      automaticDisplay: automaticDisplay ?? this.automaticDisplay,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! MediaConfig) {
      return false;
    }

    return automaticDisplay == other.automaticDisplay;
  }

  @override
  int get hashCode => automaticDisplay.hashCode;
}