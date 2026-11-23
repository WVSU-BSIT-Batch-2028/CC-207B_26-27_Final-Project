import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/schedule_documents.dart';

class ScheduleDocumentPreview extends StatelessWidget {
  const ScheduleDocumentPreview({super.key, required this.document});
  final ScheduleDocument document;
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('schedule-document-preview'),
    height: 240,
    width: double.infinity,
    child: document.isPdf
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
