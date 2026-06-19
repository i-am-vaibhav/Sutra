/// A file uploaded by the user for inclusion in chat prompts.
///
/// Persists metadata to SharedPreferences and file content to disk.
class UploadedFile {
  final String id;
  final String name;
  final String extension;
  final int sizeBytes;
  final DateTime createdAt;

  const UploadedFile({
    required this.id,
    required this.name,
    required this.extension,
    required this.sizeBytes,
    required this.createdAt,
  });

  /// The MIME-friendly label shown in chips, e.g. "notes.txt" or "report.pdf".
  String get displayName => name;

  /// Short size label, e.g. "1.2 KB" or "3.4 MB".
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// File-type icon hint for the UI.
  String get fileTypeLabel {
    final ext = extension.toLowerCase();
    return switch (ext) {
      '.txt' || '.md' => 'Text',
      '.json' => 'JSON',
      '.csv' => 'CSV',
      '.pdf' => 'PDF',
      '.docx' || '.doc' => 'Word',
      _ => 'File',
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'extension': extension,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory UploadedFile.fromJson(Map<String, dynamic> json) => UploadedFile(
        id: json['id'] as String,
        name: json['name'] as String,
        extension: json['extension'] as String,
        sizeBytes: json['sizeBytes'] as int,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      );
}
