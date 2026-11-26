// The "Photo" part of the Add / Edit crop form. The farmer can add their
// own photo, change it or remove it, and sees a preview. Without a photo,
// the preview shows the sample photo of the chosen crop that buyers will
// see instead. The photo is optional.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_exception.dart';
import '../utils/photo_compress.dart';
import '../utils/theme.dart';
import 'crop_image.dart';
import 'notice_box.dart';

/// Preview plus "Add a photo" / "Change photo" / "Remove photo" buttons.
class PhotoPickerField extends StatefulWidget {
  const PhotoPickerField({
    super.key,
    required this.crop,
    required this.photo,
    required this.onChanged,
  });

  /// The chosen crop (for the sample photo), or null before choosing.
  final String? crop;

  /// The farmer's photo (already shrunk), or null for none.
  final Uint8List? photo;

  /// Called with the new photo, or null when the farmer removes it.
  final ValueChanged<Uint8List?> onChanged;

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  bool _isWorking = false;
  String? _error;

  /// Opens the phone's gallery (or the computer's file picker), then
  /// shrinks the photo so it can be saved.
  Future<void> _pick() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });
    try {
      // The picker already makes very big photos smaller, which makes our
      // own shrinking (in compressPhoto) much faster.
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file == null) return; // the farmer closed the picker
      final jpeg = compressPhoto(await file.readAsBytes());
      widget.onChanged(jpeg);
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not open that photo. Try another one.');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final crop = widget.crop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusCard),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: photo != null
                  ? FarmerPhoto(bytes: photo)
                  : crop != null
                  // Changes as soon as the farmer picks another crop.
                  ? CropImage(
                      key: ValueKey(crop),
                      crop: crop,
                      size: CropImageSize.card,
                    )
                  : const ColoredBox(
                      color: AppColors.primaryLight,
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.link,
                        size: 40,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.small),
        Wrap(
          spacing: AppSizes.small,
          runSpacing: AppSizes.small,
          children: [
            OutlinedButton.icon(
              onPressed: _isWorking ? null : _pick,
              icon: _isWorking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      photo == null
                          ? Icons.add_a_photo_outlined
                          : Icons.photo_library_outlined,
                      size: 18,
                    ),
              label: Text(
                _isWorking
                    ? 'Preparing photo…'
                    : photo == null
                    ? 'Add a photo'
                    : 'Change photo',
              ),
            ),
            if (photo != null)
              TextButton.icon(
                onPressed: _isWorking ? null : () => widget.onChanged(null),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove photo'),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSizes.small),
          NoticeBox(message: _error!, kind: NoticeKind.error),
        ],
      ],
    );
  }
}
