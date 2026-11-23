import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Opens the image picker and returns file name + bytes, or null if cancelled.
Future<({String fileName, Uint8List bytes})?> pickProfileImageBytes(
  BuildContext context,
) async {
  final picked = await FilePicker.pickFiles(type: FileType.image);
  if (picked.isEmpty) return null;
  final file = picked.single;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  return (fileName: file.name, bytes: bytes);
}