import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '/services/sheets_service.dart';
import '/util/ui_helper.dart';
import 'column_type.dart';
import 'log_column.dart';

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

    // Values from the input screen are List<PendingFile>.
    // Values loaded from Sheets are stored as a String.
    if (value is List || value is String) {
      return null;
    }

    return 'Invalid media value';
  }

  @override
  Map<String, dynamic> toSchemaValues() {
    return config.toSchemaValues();
  }

  @override
  MediaColumn fromSchemaValues(Map<String, dynamic> values) {
    return MediaColumn(
      config: MediaConfig(
        automaticDisplay:
            values['automaticDisplay'] as bool? ?? true,
      ),
    );
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
    final files = _parseFiles(value);

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
              leading: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        child: buildPreview(file),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: buildPreview(file),
                  ),
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

  List<PendingFile> _parseFiles(dynamic value) {
    if (value is List<PendingFile>) {
      return List<PendingFile>.from(value);
    }

    if (value is String) {
      return value
          .split(',')
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty)
          .map(
            (url) => PendingFile.link(
              name: url,
              link: url,
            ),
          )
          .toList();
    }

    return [];
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
                  final file = await _showAddLinkDialog(context);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, file);
                  }
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

  // ---------------------------------------------------------------------------
  // Input preview
  // ---------------------------------------------------------------------------

  Widget buildPreview(PendingFile pendingFile) {

    if (!pendingFile.isLink && pendingFile.file != null) {
      return Image.file(
        pendingFile.file!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return const Icon(Icons.broken_image);
        },
      );
    }

    if (pendingFile.isLink && pendingFile.link != null) {
      final url = pendingFile.link!;
      final fileId = _extractDriveFileId(url);

      if (fileId == null) {
        return Image.network(
          url,
        fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return const SizedBox(
              width: 100,
              height: 100,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            return const SizedBox(
              width: 100,
              height: 100,
              child: Icon(Icons.broken_image),
            );
          },
        );
      }

      return FutureBuilder<Uint8List>(
        future: _downloadFile(fileId),
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
            fit: BoxFit.contain,
          );
        },
      );
    }

    return const Icon(
      Icons.insert_drive_file,
      size: 48,
    );
  }

  // ---------------------------------------------------------------------------
  // Record display
  // ---------------------------------------------------------------------------

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
      return _buildImages(
        context,
        urls,
      );
    }

    return _buildLinksWithLoadButton(
      context,
      urls,
    );
  }

  List<String> _extractUrls(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((url) => url.trim())
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

  Widget _buildImages(
    BuildContext context,
    List<String> urls,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls.map(
        (url) => _buildImage(
          context,
          url,
        ),
      ).toList(),
    );
  }

  Widget _buildImage(
    BuildContext context,
    String url,
  ) {
    final fileId = _extractDriveFileId(url);

    final image = fileId != null
        ? _buildDriveImage(fileId)
        : _buildNetworkImage(url);

    return GestureDetector(
      onTap: () {
        _showFullImage(
          context,
          url,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: image,
      ),
    );
  }

  Widget _buildDriveImage(String fileId) {
    return FutureBuilder<Uint8List>(
      future: _downloadFile(fileId),
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

        return Image.memory(
          snapshot.data!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return const SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      errorBuilder: (_, __, ___) {
        return const SizedBox(
          width: 80,
          height: 80,
          child: Icon(Icons.broken_image),
        );
      },
    );
  }

  Future<void> _showFullImage(
    BuildContext context,
    String url,
  ) async {
    final fileId = _extractDriveFileId(url);

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: fileId != null
                ? _buildFullDriveImage(fileId)
                : _buildFullNetworkImage(url),
          ),
        );
      },
    );
  }

  Widget _buildFullDriveImage(String fileId) {
    return FutureBuilder<Uint8List>(
      future: _downloadFile(fileId),
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
          return const Icon(
            Icons.broken_image,
            size: 64,
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildFullNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return const Icon(
          Icons.broken_image,
          size: 64,
        );
      },
    );
  }

  Widget _buildLinksWithLoadButton(
    BuildContext context,
    List<String> urls,
  ) {
    var showImages = false;

    return StatefulBuilder(
      builder: (context, setState) {
        if (showImages) {
          return _buildImages(
            context,
            urls,
          );
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

  // ---------------------------------------------------------------------------
  // Google Drive
  // ---------------------------------------------------------------------------

  Future<Uint8List> _downloadFile(String fileId) async {
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
        'Failed to download file: ${response.statusCode}',
      );
    }

    return response.bodyBytes;
  }

  String? _extractDriveFileId(String url) {
    final match = RegExp(
      r'/file/d/([^/]+)',
    ).firstMatch(url);

    return match?.group(1);
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
  }) : this._(
          name: name,
          file: file,
        );

  const PendingFile.link({
    required String name,
    required String link,
  }) : this._(
          name: name,
          link: link,
        );

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
      'automaticDisplay': automaticDisplay,
    };
  }

  MediaConfig copyWith({
    bool? automaticDisplay,
  }) {
    return MediaConfig(
      automaticDisplay:
          automaticDisplay ?? this.automaticDisplay,
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
