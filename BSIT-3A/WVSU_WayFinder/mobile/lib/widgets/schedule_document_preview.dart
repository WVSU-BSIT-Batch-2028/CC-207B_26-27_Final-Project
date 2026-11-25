import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/schedule_documents.dart';
import '../data/browser_schedule.dart';

class ScheduleDocumentPreview extends StatelessWidget {
  const ScheduleDocumentPreview({super.key, required this.document});
  final ScheduleDocument document;
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('schedule-document-preview'),
    height: 240,
    width: double.infinity,
    child: kIsWeb
        ? _BrowserPreview(
            key: ValueKey(document.storagePath),
            document: document,
          )
        : document.isPdf
        ? PdfViewer.file(
            document.path,
            params: PdfViewerParams(
              errorBannerBuilder: (context, error, stackTrace, documentRef) =>
                  const Center(
                    child: Text(
                      'The PDF preview could not be opened. Choose the file again.',
                    ),
                  ),
            ),
          )
        : Image.file(
            File(document.path),
            fit: BoxFit.contain,
            cacheWidth: 1400,
            semanticLabel: 'Uploaded schedule preview',
            errorBuilder: (_, __, ___) => const Center(
              child: Text(
                'The saved image could not be opened. Choose the file again.',
              ),
            ),
          ),
  );
}

class _BrowserPreview extends StatefulWidget {
  const _BrowserPreview({super.key, required this.document});
  final ScheduleDocument document;
  @override
  State<_BrowserPreview> createState() => _BrowserPreviewState();
}

class _BrowserPreviewState extends State<_BrowserPreview> {
  late final _bytes = getBrowserFile(widget.document.storagePath);

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('Choose the original file again to preview it.'),
        );
      }
      final bytes = snapshot.data;
      if (bytes == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.document.isPdf) {
        return PdfViewer.data(bytes, sourceName: widget.document.storagePath);
      }
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        semanticLabel: 'Uploaded schedule preview',
        errorBuilder: (_, __, ___) =>
            const Center(child: Text('This image could not be opened.')),
      );
    },
  );
}
