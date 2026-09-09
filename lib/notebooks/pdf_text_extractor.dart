import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Extracts selectable PDF text silently for Notebook grounding.
/// The extracted text is stored as the source's textContent and is never
/// rendered as a raw-text screen for the student.
class PdfTextExtractorService {
  const PdfTextExtractorService();

  Future<String> extract(Uint8List bytes) async {
    if (bytes.isEmpty) return '';
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText().trim();
    } finally {
      document.dispose();
    }
  }
}
