import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'notebook_models.dart';

class NoteExportService {
  static Future<void> export({required NotebookNote note, required String format}) async {
    final safeTitle = note.title.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim();
    final title = safeTitle.isEmpty ? 'Inspiro Note' : safeTitle;
    final dir = await getTemporaryDirectory();
    late final File file;

    switch (format) {
      case 'pdf':
        file = File('${dir.path}/$title.pdf');
        await file.writeAsBytes(await _pdf(note));
        break;
      case 'docx':
        file = File('${dir.path}/$title.docx');
        await file.writeAsBytes(_docx(note));
        break;
      case 'pptx':
        file = File('${dir.path}/$title.pptx');
        await file.writeAsBytes(_pptx(note));
        break;
      case 'png':
        file = File('${dir.path}/$title.png');
        await file.writeAsBytes(await _png(note));
        break;
      default:
        throw ArgumentError('Unsupported export format.');
    }

    await Share.shareXFiles([XFile(file.path)], text: note.title);
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
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Uint8List _pptx(NotebookNote note) {
    final archive = Archive();
    _add(archive, '[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/></Types>');
    _add(archive, '_rels/.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>');
    _add(archive, 'ppt/presentation.xml', '<?xml version="1.0" encoding="UTF-8"?><p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>');
    _add(archive, 'ppt/_rels/presentation.xml.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>');
    _add(archive, 'ppt/slides/slide1.xml', '<?xml version="1.0" encoding="UTF-8"?><p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/><p:sp><p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr b="1" sz="2800"/><a:t>${_xml(note.title)}</a:t></a:r></a:p></p:txBody></p:sp><p:sp><p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/>${note.content.split(RegExp(r'\n+')).map((p) => '<a:p><a:r><a:rPr sz="1600"/><a:t>${_xml(p)}</a:t></a:r></a:p>').join()}</p:txBody></p:sp></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>');
    _add(archive, 'ppt/slides/_rels/slide1.xml.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>');
    _add(archive, 'ppt/slideLayouts/slideLayout1.xml', '<?xml version="1.0" encoding="UTF-8"?><p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank"><p:cSld name="Blank"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>');
    _add(archive, 'ppt/slideLayouts/_rels/slideLayout1.xml.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>');
    _add(archive, 'ppt/slideMasters/slideMaster1.xml', '<?xml version="1.0" encoding="UTF-8"?><p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld name="Master"><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld><p:sldLayoutIdLst><p:sldLayoutId id="1" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles/><p:clrMap accent1="000000" accent2="000000" accent3="000000" accent4="000000" accent5="000000" accent6="000000" bg1="FFFFFF" bg2="FFFFFF" folHlink="0000FF" hlink="0000FF" tx1="000000" tx2="000000"/></p:sldMaster>');
    _add(archive, 'ppt/slideMasters/_rels/slideMaster1.xml.rels', '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>');
    _add(archive, 'ppt/theme/theme1.xml', '<?xml version="1.0" encoding="UTF-8"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Inspiro"><a:themeElements><a:clrScheme name="Inspiro"><a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="000000"/></a:dk2><a:lt2><a:srgbClr val="FFFFFF"/></a:lt2><a:accent1><a:srgbClr val="32C5FF"/></a:accent1><a:accent2><a:srgbClr val="7C5CFF"/></a:accent2><a:accent3><a:srgbClr val="00A0FF"/></a:accent3><a:accent4><a:srgbClr val="FFFFFF"/></a:accent4><a:accent5><a:srgbClr val="000000"/></a:accent5><a:accent6><a:srgbClr val="888888"/></a:accent6><a:hlink><a:srgbClr val="0000FF"/></a:hlink><a:folHlink><a:srgbClr val="800080"/></a:folHlink></a:clrScheme><a:fontScheme name="Inspiro"><a:majorFont/><a:minorFont/></a:fontScheme><a:fmtScheme name="Inspiro"><a:fillStyleLst/><a:lnStyleLst/><a:effectStyleLst/><a:bgFillStyleLst/></a:fmtScheme></a:themeElements></a:theme>');
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static Future<Uint8List> _png(NotebookNote note) async {
    const width = 1200.0;
    const height = 1800.0;
    const padding = 70.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, width, height), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    final titlePainter = ui.TextPainter(text: ui.TextSpan(text: note.title, style: const ui.TextStyle(fontSize: 42, fontWeight: ui.FontWeight.bold, color: ui.Color(0xFF15171A))), textDirection: ui.TextDirection.ltr, maxLines: 2)..layout(maxWidth: width - padding * 2);
    titlePainter.paint(canvas, const ui.Offset(padding, padding));
    final bodyPainter = ui.TextPainter(text: ui.TextSpan(text: note.content, style: const ui.TextStyle(fontSize: 25, color: ui.Color(0xFF2F3337,))), textDirection: ui.TextDirection.ltr)..layout(maxWidth: width - padding * 2);
    bodyPainter.paint(canvas, ui.Offset(padding, padding + titlePainter.height + 45));
    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  static void _add(Archive archive, String path, String value) {
    final data = Uint8List.fromList(value.codeUnits);
    archive.addFile(ArchiveFile(path, data.length, data));
  }

  static String _xml(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
}
