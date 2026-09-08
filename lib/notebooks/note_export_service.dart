import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'notebook_models.dart';

class NoteExportService {
  static const _nativeChannel = MethodChannel('lodha_inspiro/native');

  static Future<void> export({required NotebookNote note, required String format}) async {
    final safeTitle = note.title.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim();
    final title = safeTitle.isEmpty ? 'Inspiro Note' : safeTitle;
    final extension = _extensionFor(format);
    final mimeType = _mimeTypeFor(format);
    final bytes = await _bytesFor(note, format);
    final fileName = '$title.$extension';

    if (Platform.isAndroid) {
      final savedUri = await _nativeChannel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
      if (savedUri != null && savedUri.isNotEmpty) return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: note.title);
  }

  static Future<Uint8List> _bytesFor(NotebookNote note, String format) {
    switch (format) {
      case 'pdf':
        return _pdf(note);
      case 'docx':
        return Future.value(_docx(note));
      case 'pptx':
        return Future.value(_pptx(note));
      case 'png':
        return _png(note);
      default:
        throw ArgumentError('Unsupported export format.');
    }
  }

  static String _extensionFor(String format) => format == 'docx' ? 'docx' : format;

  static String _mimeTypeFor(String format) {
    switch (format) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'png':
        return 'image/png';
      default:
        throw ArgumentError('Unsupported export format.');
    }
  }

  static Future<Uint8List> _pdf(NotebookNote note) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(note.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 18),
        ...note.content.split(RegExp(r'\n+')).map((p) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(p, style: const pw.TextStyle(fontSize: 12, lineSpacing: 4)),
        )),
      ],
    ));
    return doc.save();
  }

  static Uint8List _docx(NotebookNote note) {
    final archive = Archive();
    _add(archive, '[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>');
    _add(archive, '_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
    final body = '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>${_xml(note.title)}</w:t></w:r></w:p>${note.content.split(RegExp(r'\n+')).map((p) => '<w:p><w:r><w:t xml:space="preserve">${_xml(p)}</w:t></w:r></w:p>').join()}';
    _add(archive, 'word/document.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>');
    return Uint8List.fromList(ZipEncoder().encode(archive) ?? <int>[]);
  }

  static Uint8List _pptx(NotebookNote note) {
    final archive = Archive();
    _add(archive, '[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/></Types>');
    _add(archive, '_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>');
    _add(archive, 'ppt/presentation.xml', '<?xml version="1.0" encoding="UTF-8"?><p:presentation xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/></p:presentation>');
    _add(archive, 'ppt/_rels/presentation.xml.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>');
    _add(archive, 'ppt/slides/slide1.xml', '<?xml version="1.0" encoding="UTF-8"?><p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/><p:sp><p:nvSpPr><p:cNvPr id="2" name="Content"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr b="1" sz="2800"/><a:t>${_xml(note.title)}</a:t></a:r></a:p>${note.content.split(RegExp(r'\n+')).map((p) => '<a:p><a:r><a:rPr sz="1600"/><a:t>${_xml(p)}</a:t></a:r></a:p>').join()}</p:txBody></p:sp></p:spTree></p:cSld></p:sld>');
    return Uint8List.fromList(ZipEncoder().encode(archive) ?? <int>[]);
  }

  static Future<Uint8List> _png(NotebookNote note) async {
    const width = 1200.0;
    const height = 1800.0;
    const padding = 70.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, width, height), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    final titlePainter = TextPainter(
      text: TextSpan(text: note.title, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF15171A))),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: width - padding * 2);
    titlePainter.paint(canvas, const ui.Offset(padding, padding));
    final bodyPainter = TextPainter(
      text: TextSpan(text: note.content, style: const TextStyle(fontSize: 25, color: Color(0xFF2F3337))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - padding * 2);
    bodyPainter.paint(canvas, ui.Offset(padding, padding + titlePainter.height + 45));
    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List() ?? Uint8List(0);
  }

  static void _add(Archive archive, String path, String value) {
    final data = Uint8List.fromList(value.codeUnits);
    archive.addFile(ArchiveFile(path, data.length, data));
  }

  static String _xml(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
}
