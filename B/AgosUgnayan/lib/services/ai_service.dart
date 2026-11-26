// The AI Listing Assistant. (1) A farmer types a quick note like
// "50 kilos kamatis, 45 per kilo, harvest sa Biyernes" and Gemini turns it
// into form values. We call Gemini through Firebase AI Logic, so there is no
// API key in the app.
// (2) "Generate crop description": a short description of the chosen crop
// for buyers, from the crop name only (no personal data is sent).

import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

import '../models/ai_listing_suggestion.dart';
import '../utils/app_exception.dart';
import '../utils/ai_text.dart';
import '../utils/app_logger.dart';
import '../utils/constants.dart';
import '../utils/privacy_filter.dart';

/// Asks Gemini to read a farmer's note and suggest listing details.
class AiService {
  /// The Gemini model for ALL our AI features (farmer assistant, crop
  /// descriptions, buyer assistant). If Google retires it, change only
  /// this line. We use Lite: on the free tier gemini-3.5-flash allows only
  /// 20 requests a day for the whole project, and its "thinking" made
  /// answers slow and cut off. Lite answered in about 2 seconds in our
  /// tests (tool/assistant_stress_test.dart).
  static const String modelName = 'gemini-3.5-flash-lite';

  /// Little "thinking": enough for our short tasks, and fast.
  static final ThinkingConfig thinking = ThinkingConfig.withThinkingLevel(
    ThinkingLevel.minimal,
  );

  /// How long we wait before giving up and letting the farmer type manually.
  static const Duration timeout = Duration(seconds: 20);

  /// Returns the suggestion, or throws [AppException] with a friendly message
  /// so the screen can show the manual form (our fallback).
  Future<AiListingSuggestion> suggestListing(String note) async {
    // Privacy: send only the crop details, never phone numbers or emails.
    final safeNote = removeContactDetails(note);

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: modelName,
        // Ask for JSON so we can read the answer reliably.
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0, // same note -> same answer
          thinkingConfig: thinking,
        ),
      );
      final response = await model
          .generateContent([Content.text(listingPrompt(safeNote))])
          .timeout(timeout);

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw const AppException(_fallbackMessage);
      }
      final suggestion = AiListingSuggestion.fromJsonText(text);
      if (suggestion.isEmpty) {
        throw const AppException(
          'The AI could not find crop details in your note. '
          'Try adding the crop and amount, or fill in the form yourself.',
        );
      }
      return suggestion;
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(_fallbackMessage);
    } catch (e, stack) {
      // Bad JSON, no internet, AI not enabled in Firebase, and so on.
      AppLogger.error('AI suggestion failed', e, stack);
      throw const AppException(_fallbackMessage);
    }
  }

  /// A short, plain description of [crop] for buyers (2-4 sentences, at
  /// most 300 characters). Only the crop name and its category are sent.
  /// Throws [AppException] with a friendly message if it fails, so the
  /// farmer can simply write their own.
  Future<String> describeCrop(String crop) async {
    final category = cropInfo(crop)?.category.label ?? 'crop';
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: modelName,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          thinkingConfig: thinking,
        ),
      );
      final response = await model
          .generateContent([Content.text(describePrompt(crop, category))])
          .timeout(timeout);
      final text = cleanCropDescription(response.text);
      if (text == null) throw const AppException(_describeFallback);
      return text;
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException(_describeFallback);
    } catch (e, stack) {
      AppLogger.error('AI crop description failed', e, stack);
      throw const AppException(_describeFallback);
    }
  }

  static const _describeFallback =
      'The AI could not write a description right now. '
      'You can write your own, or try again later.';

  /// Instructions for the crop description. The rules keep it short,
  /// simple and honest (no prices, no health claims, nothing about the farm).
  static String describePrompt(String crop, String category) =>
      '''
Write a short description of the crop "$crop" ($category) for a farmer's
listing in an online market in Iloilo, Philippines. Buyers will read it.
In 2 to 4 short, simple English sentences (at most 280 characters in total):
what the crop is, how it looks, how it is commonly cooked or used in the
Philippines, and one useful tip for buyers (for example how to store it).
Rules: plain text only, no title, no lists, no prices, no health or medical
claims, and nothing about this farmer's farm, harvest or quality.
''';

  static const _fallbackMessage =
      'The AI assistant is not available right now. '
      'You can fill in the form yourself.';

  /// The instructions we give Gemini. The rules stop it from guessing:
  /// anything not in the note must be null.
  static String listingPrompt(String note) {
    final localNames = kLocalCropNames.entries
        .map((e) => '${e.key} = ${e.value}')
        .join(', ');
    return '''
You help farmers in Iloilo, Philippines list crops for sale.
Read the farmer's note (English, Hiligaynon or Filipino) and return JSON with:
- "crop": one of ${kCrops.join(', ')}. Local names: $localNames.
- "quantity": a number.
- "unit": one of ${kUnits.join(', ')} ("kilo" or "kilos" means kg, "sako" means sack).
- "price": the asking price per unit in pesos, a number.
- "description": one short English sentence for buyers about quality or harvest, ONLY if the note says something about it (for example "fresh", "bag-o lang ginpupo", "harvested yesterday"); otherwise null.
Return one JSON object (not a list).
Rules: use null for anything the note does not say. Never invent a price, quantity or freshness.
Farmer's note: """$note"""
''';
  }
}
