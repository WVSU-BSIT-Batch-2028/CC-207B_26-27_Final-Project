// F3 AI Listing Assistant: the box at the top of the crop form. The farmer
// types a quick note, taps "Fill in for me", and the AI's suggestion is sent
// back to the form through [onSuggestion]. If the AI fails, we say so and
// the farmer simply fills in the form by hand (the fallback).

import 'package:flutter/material.dart';

import '../models/ai_listing_suggestion.dart';
import '../services/ai_service.dart';
import '../utils/app_exception.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import 'notice_box.dart';

/// Note field + button that asks the AI to fill in the crop form.
class AiAssistantBox extends StatefulWidget {
  const AiAssistantBox({super.key, required this.onSuggestion});

  /// Called with the AI's suggestion so the form can fill its fields.
  final ValueChanged<AiListingSuggestion> onSuggestion;

  @override
  State<AiAssistantBox> createState() => _AiAssistantBoxState();
}

class _AiAssistantBoxState extends State<AiAssistantBox> {
  final _noteController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _askAi() async {
    final note = _noteController.text.trim();
    if (note.length < 5) {
      setState(
        () => _error = 'Type a short note first, like "50 kilos kamatis".',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final suggestion = await AiService().suggestListing(note);
      if (!mounted) return;
      widget.onSuggestion(suggestion);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyMessage(e));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusCard)),
        side: BorderSide(color: Color(0x334A7F2C)), // brand green, 20%
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primaryDark),
                SizedBox(width: AppSizes.small),
                Text(
                  'AI Listing Assistant',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.labelGap),
            const Text(
              'Describe your crop in your own words (English, Hiligaynon or '
              'Filipino). The AI fills in the form, and you can change anything.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSizes.small),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                    'e.g. 50 kilos kamatis, 45 pesos per kilo, '
                    'bag-o lang ginpupo',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.small),
              NoticeBox(message: _error!, kind: NoticeKind.error),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _askAi,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isLoading ? 'Reading your note…' : 'Fill in for me',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "AI-generated" label shown next to anything the AI filled in.
class AiGeneratedChip extends StatelessWidget {
  const AiGeneratedChip({super.key});

  @override
  Widget build(BuildContext context) {
    // A blue pill, so AI content stands out from the green app colors.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: AppColors.info),
          SizedBox(width: 5),
          Text(
            AppStrings.aiGenerated,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}
