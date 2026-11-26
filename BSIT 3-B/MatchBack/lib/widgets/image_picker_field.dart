import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/report_image_storage.dart';
import '../theme/paper_theme.dart';

class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    required this.image,
    required this.onChanged,
    this.enabled = true,
    this.label = 'Photo (optional)',
    super.key,
  });

  final ReportImageData? image;
  final ValueChanged<ReportImageData?> onChanged;
  final bool enabled;
  final String label;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  static const _maxBytes = 600 * 1024;

  final _picker = ImagePicker();
  bool _busy = false;
  String? _error;

  /// Checks the real file contents, not just the file name.
  String? _detectMime(List<int> b) {
    if (b.length < 12) return null;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'image/png';
    }
    if (b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (file == null) return; // The person cancelled.

      final bytes = await file.readAsBytes();
      final mime = _detectMime(bytes);

      if (mime == null) {
        setState(() {
          _error = 'Unsupported file. Please choose a JPG, PNG, or WebP image.';
        });
        return;
      }

      if (bytes.length > _maxBytes) {
        setState(() {
          _error =
              'That photo is too large (${(bytes.length / 1024).round()} KB). '
              'Please choose a smaller one (under 600 KB).';
        });
        return;
      }

      widget.onChanged(ReportImageData(bytes, mime));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load that photo. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _remove() {
    setState(() {
      _error = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final canTap = widget.enabled && !_busy;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Paper.ink, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'JPG, PNG, or WebP. Do not show names, ID numbers, or faces.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Image.memory(image.bytes, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Loading photo...'),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: canTap ? () => _pick(ImageSource.gallery) : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(image == null ? 'Choose photo' : 'Replace photo'),
                ),
                OutlinedButton.icon(
                  onPressed: canTap ? () => _pick(ImageSource.camera) : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take a photo'),
                ),
                if (image != null)
                  TextButton.icon(
                    onPressed: widget.enabled ? _remove : null,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
        ],
      ),
    );
  }
}
