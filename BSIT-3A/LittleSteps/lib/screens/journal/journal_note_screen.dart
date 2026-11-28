import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/journal_entry.dart';
import '../../models/journal_validators.dart';
import '../../services/api_client.dart';
import '../../services/journal_service.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/auth_scope.dart';
import '../../widgets/state_views.dart';
import 'widgets/journal_widgets.dart';

/// Displays a form for creating, editing, or deleting a private journal note.
///
/// Presents the privacy boundary above the note field, enforces the
/// 2,000-character limit and non-future date check, and preserves the draft
/// in place if saving fails while offline.
class JournalNoteScreen extends StatefulWidget {
  /// Creates a [JournalNoteScreen].
  ///
  /// Pass [entry] to edit an existing note, and [journalService] in tests to
  /// override the signed-in API client.
  const JournalNoteScreen({super.key, this.entry, this.journalService});

  /// Existing note being edited, or `null` when creating a new note.
  final JournalEntry? entry;

  /// Service used to save or delete notes, or `null` to use the signed-in client.
  final JournalService? journalService;

  @override
  State<JournalNoteScreen> createState() => _JournalNoteScreenState();
}

class _JournalNoteScreenState extends State<JournalNoteScreen> {
  static const _formFields = {'content', 'entryDate'};

  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _offline = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _unavailable = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) {
      return;
    }
    _contentController.text = entry.content;
    _date = DateTime.tryParse(entry.entryDate) ?? _date;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickJournalDate(
      context,
      initialDate: _date,
      helpText: 'When did you notice it?',
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _fieldErrors = Map.of(_fieldErrors)..remove('entryDate');
      });
    }
  }

  // Validates and saves the note as typed (preserving line breaks).
  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }
    final dateError = validateEntryDate(_date, now: DateTime.now());
    if (dateError != null) {
      setState(() => _errorMessage = dateError);
      return;
    }

    // Read everything that needs `context` before the first `await`.
    final child = AuthScope.of(context).activeChild;
    final navigator = Navigator.of(context);
    final service =
        widget.journalService ??
        JournalService(apiClient: AuthScope.apiClientOf(context));
    if (child == null) {
      setState(() => _errorMessage = 'Choose a child before writing a note.');
      return;
    }

    // ApiClient refuses every save while it is marked offline, until some
    // later request succeeds. Tapping Save asks to try again, so let this
    // save really try the connection.
    if (service.apiClient.isOffline) {
      service.apiClient.isOffline = false;
    }

    setState(() {
      _saving = true;
      _offline = false;
      _errorMessage = null;
      _fieldErrors = const {};
    });

    try {
      final entryDate = DateFormat('yyyy-MM-dd').format(_date);
      final editing = widget.entry;
      if (editing == null) {
        await service.createJournalEntry(
          childId: child.id,
          entryDate: entryDate,
          content: _contentController.text,
        );
      } else {
        await service.updateJournalEntry(
          childId: child.id,
          entryId: editing.id,
          content: _contentController.text,
          entryDate: entryDate,
        );
      }
      if (!mounted) {
        return;
      }
      navigator.pop(true);
    } on NotFoundApiException {
      // The note was deleted elsewhere, or is not this caregiver's.
      if (mounted) {
        setState(() => _unavailable = true);
      }
    } on NoConnectionApiException {
      // The typed note stays in the box, so it can be saved once online.
      if (mounted) {
        setState(() => _offline = true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showServerErrors(error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    final child = AuthScope.of(context).activeChild;
    if (_saving || entry == null || child == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text("This can't be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    // Cancel, or tapping outside the dialog (null), keeps the note.
    if (confirmed != true || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final service =
        widget.journalService ??
        JournalService(apiClient: AuthScope.apiClientOf(context));
    if (service.apiClient.isOffline) {
      service.apiClient.isOffline = false;
    }

    setState(() {
      _saving = true;
      _offline = false;
      _errorMessage = null;
    });

    try {
      await service.deleteJournalEntry(childId: child.id, entryId: entry.id);
      if (!mounted) {
        return;
      }
      navigator.pop(true);
    } on NotFoundApiException {
      if (mounted) {
        setState(() => _unavailable = true);
      }
    } on NoConnectionApiException {
      if (mounted) {
        setState(() => _offline = true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showServerErrors(ApiException error) {
    final fieldErrors = <String, String>{};
    String? otherError;
    for (final detail in error.details) {
      final field = detail['field'];
      final issue = detail['issue'];
      if (field is! String || issue is! String) {
        continue;
      }
      if (_formFields.contains(field)) {
        fieldErrors[field] = issue;
      } else {
        otherError ??= issue;
      }
    }
    setState(() {
      _fieldErrors = fieldErrors;
      _errorMessage = fieldErrors.isEmpty
          ? (otherError ?? error.message)
          : otherError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit note' : 'New note'),
        actions: [
          if (_isEditing && !_unavailable)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete note',
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      // Reveal nothing about a missing or unauthorized note and drop form content.
      body: _unavailable
          ? const EmptyStateView(
              title: "This note isn't available",
              message:
                  'It may have been removed, or it belongs to another account.',
              icon: Icons.lock_outline,
            )
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final dateError = _fieldErrors['entryDate'];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          // Place the privacy boundary notice above the text input.
          const JournalPrivacyNotice(),
          const SizedBox(height: AppSpacing.space16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(DateFormat.yMMMd().format(_date)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.touchTarget),
              ),
            ),
          ),
          if (dateError != null) ...[
            const SizedBox(height: AppSpacing.space4),
            Text(
              dateError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textError,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.space16),
          TextFormField(
            controller: _contentController,
            keyboardType: TextInputType.multiline,
            minLines: 4,
            maxLines: 8,
            // Shows the "123/2000" counter without cutting pasted text, so
            // the validator can explain the limit instead.
            maxLength: maxJournalLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            decoration: InputDecoration(
              labelText: 'What did you notice?',
              alignLabelWithHint: true,
              errorText: _fieldErrors['content'],
            ),
            validator: validateJournalContent,
            onChanged: (_) {
              if (_fieldErrors.containsKey('content')) {
                setState(() {
                  _fieldErrors = Map.of(_fieldErrors)..remove('content');
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.space16),
          if (_offline) ...[
            const OfflineStatusCard(
              message: 'Reconnect to save changes. Your note is kept here.',
              trailing: JournalPrivateBadge(filled: false),
            ),
            const SizedBox(height: AppSpacing.space16),
          ],
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textError,
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
          ],
          SizedBox(
            height: AppSizes.touchTarget,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.surfaceCard,
                      ),
                    )
                  : const Text('Save note'),
            ),
          ),
        ],
      ),
    );
  }
}
