import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:uuid/uuid.dart';

import 'uploaded_file.dart';

const _uuid = Uuid();

/// Manages uploaded files: picking, copying to app storage, text extraction.
class FileStorageService {
  /// Directory where uploaded files are stored.
  Future<Directory> get _uploadDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'uploads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }  /// Pick a file using the platform file picker.
  /// Returns null if the user cancelled.
  Future<UploadedFile?> pickAndStoreFile() async {
    final typeGroup = XTypeGroup(
      label: 'Documents',
      extensions: [
        'txt', 'md', 'json', 'csv',
        'pdf', 'docx', 'doc',
      ],
    );

    final xFile = await openFile(acceptedTypeGroups: [typeGroup]);
    if (xFile == null) return null;

    final bytes = await xFile.readAsBytes();
    if (bytes.isEmpty) return null;

    final ext = p.extension(xFile.name).toLowerCase();
    final id = _uuid.v4();
    final storedName = '$id$ext';

    final dir = await _uploadDir;
    final file = File(p.join(dir.path, storedName));
    await file.writeAsBytes(bytes, flush: true);

    return UploadedFile(
      id: id,
      name: xFile.name,
      extension: ext,
      sizeBytes: bytes.length,
      createdAt: DateTime.now(),
    );
  }

  /// Read the raw bytes of a stored file.
  Future<List<int>> readBytes(UploadedFile file) async {
    final dir = await _uploadDir;
    final path = p.join(dir.path, '${file.id}${file.extension}');
    final f = File(path);
    if (!await f.exists()) return [];
    return f.readAsBytes();
  }

  /// Extract plain text content from an uploaded file.
  Future<String> extractText(UploadedFile file) async {
    final bytes = await readBytes(file);
    if (bytes.isEmpty) return '';

    final ext = file.extension.toLowerCase();
    return switch (ext) {
      '.txt' || '.md' => utf8.decode(bytes, allowMalformed: true),
      '.json' => _prettyPrintJson(utf8.decode(bytes, allowMalformed: true)),
      '.csv' => _formatCsv(utf8.decode(bytes, allowMalformed: true)),
      '.pdf' => _extractPdfText(bytes),
      '.docx' => _extractDocxText(bytes),
      '.doc' => _extractDocText(bytes),
      _ => utf8.decode(bytes, allowMalformed: true),
    };
  }

  /// Delete a stored file.
  Future<void> deleteFile(UploadedFile file) async {
    final dir = await _uploadDir;
    final path = p.join(dir.path, '${file.id}${file.extension}');
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  /// Get the local file path for a stored file.
  Future<String> filePath(UploadedFile file) async {
    final dir = await _uploadDir;
    return p.join(dir.path, '${file.id}${file.extension}');
  }

  // ── Format-specific text extraction ──────────────────────

  String _prettyPrintJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(obj);
    } catch (_) {
      Log.d('[FileStorageService] JSON pretty-print failed, returning raw');
      return raw;
    }
  }

  String _formatCsv(String raw) {
    // Return CSV as-is — the model can understand tabular text.
    return raw;
  }

  String _extractPdfText(List<int> bytes) {
    try {
      final document = syncfusion.PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      final buffer = StringBuffer();
      for (int i = 0; i < pageCount; i++) {
        final text = syncfusion.PdfTextExtractor(document)
            .extractText(startPageIndex: i, endPageIndex: i);
        buffer.writeln(text);
      }
      document.dispose();
      final result = buffer.toString().trim();
      if (result.isEmpty) return '[PDF: $pageCount pages, no extractable text]';
      return result;
    } catch (e) {
      Log.e('[FileStorageService] PDF extraction failed: $e');
      return '[PDF: extraction failed — $e]';
    }
  }

  String _extractDocxText(List<int> bytes) {
    try {
      // DOCX is a ZIP archive containing XML files.
      // The main text lives in word/document.xml.
      final archive = ZipDecoder().decodeBytes(bytes);
      final docXml = archive.findFile('word/document.xml');
      if (docXml == null) return '[DOCX: could not find document.xml]';

      final content = utf8.decode(docXml.content as List<int>, allowMalformed: true);

      // Strip XML tags to get plain text.
      final text = _stripXmlTags(content);
      if (text.trim().isEmpty) return '[DOCX: no extractable text]';
      return text;
    } catch (e) {
      Log.e('[FileStorageService] DOCX extraction failed: $e');
      return '[DOCX: extraction failed — $e]';
    }
  }

  String _extractDocText(List<int> bytes) {
    // Legacy .doc (OLE) format — attempt a best-effort extraction.
    // This is unreliable for complex documents but works for simple text.
    try {
      final raw = latin1.decode(bytes, allowInvalid: true);

      // Attempt to find readable text runs in the binary.
      // Simple heuristic: extract sequences of printable ASCII + common Unicode.
      final buffer = StringBuffer();
      final pattern = RegExp(r'[\x20-\x7E\u00A0-\u00FF\u2013\u2014\u2018\u2019\u201C\u201D]+');
      for (final match in pattern.allMatches(raw)) {
        final segment = match.group(0)!;
        if (segment.length >= 3) {
          // Filter out obvious binary junk (hex patterns, etc.)
          final alphaRatio = segment.runes.where((r) => r >= 0x41 && r <= 0x7A).length / segment.length;
          if (alphaRatio > 0.5) {
            buffer.writeln(segment);
          }
        }
      }

      final result = buffer.toString().trim();
      if (result.isEmpty) return '[DOC: legacy format — limited text extraction. Convert to .docx for better results]';
      return result;
    } catch (e) {
      Log.e('[FileStorageService] DOC extraction failed: $e');
      return '[DOC: extraction failed — $e]';
    }
  }

  /// Strip XML tags, keeping only the text content.
  String _stripXmlTags(String xml) {
    // Remove XML declarations and tags.
    final cleaned = xml
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&apos;'), "'")
        .replaceAll(RegExp(r'&#\d+;'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }
}
