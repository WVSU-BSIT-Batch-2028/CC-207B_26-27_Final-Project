//updated to be functional - Joshua

import 'package:final_project_look_out/widgets/confirmation_dialog.dart';
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';

import '../../../services/admin_log_service.dart';
import '../../../widgets/lookout_app_bar.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeedbackFaqsScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;

  const FeedbackFaqsScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entriesStream = FirebaseFirestore.instance
        .collection('feedback_faqs')
        .snapshots();

    return Scaffold(
      appBar: LookOutAppBar(
        title: 'Feedback & FAQs',
        onMenuPressed: onMenuPressed,
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Feedback & FAQs',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review what users are saying and find answers to '
                    'common questions.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: entriesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Unable to load feedback and FAQs: ${snapshot.error}',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Loader.circular();
                      }

                      final entries = snapshot.data!.docs;
                      final feedback =
                          entries
                              .where(
                                (entry) => entry.data()['type'] == 'feedback',
                              )
                              .toList()
                            ..sort(_compareNewestFirst);
                      final faqs =
                          entries
                              .where((entry) => entry.data()['type'] == 'faq')
                              .toList()
                            ..sort((a, b) {
                              final questionA =
                                  a.data()['question'] as String? ?? '';
                              final questionB =
                                  b.data()['question'] as String? ?? '';
                              return questionA.compareTo(questionB);
                            });
                      final unresolvedCount = feedback
                          .where(
                            (entry) => entry.data()['status'] != 'resolved',
                          )
                          .length;
                      final ratings = feedback
                          .map((entry) => entry.data()['rating'])
                          .whereType<num>()
                          .toList();
                      final averageRating = ratings.isEmpty
                          ? '—'
                          : (ratings.reduce((a, b) => a + b) / ratings.length)
                                .toStringAsFixed(1);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _FeedbackMetric(
                                label: 'Feedback received',
                                value: '${feedback.length}',
                                icon: Icons.forum_outlined,
                              ),
                              _FeedbackMetric(
                                label: 'Needs a reply',
                                value: '$unresolvedCount',
                                icon: Icons.mark_email_unread_outlined,
                              ),
                              _FeedbackMetric(
                                label: 'Average rating',
                                value: averageRating,
                                icon: Icons.star_outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Recent feedback',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (feedback.isEmpty)
                            const Text('No feedback received yet.')
                          else
                            for (final entry in feedback)
                              _FeedbackCard(
                                feedback: entry,
                                onResolve: () => _setFeedbackStatus(
                                  context,
                                  entry,
                                  'resolved',
                                ),
                              ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Frequently asked questions',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _editFaq(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add FAQ'),
                              ),
                            ],
                          ),
                          Text(
                            '${faqs.length} articles',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (faqs.isEmpty)
                            const Text('No FAQs have been added.')
                          else
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < faqs.length;
                                    index++
                                  ) ...[
                                    if (index > 0) const Divider(height: 1),
                                    _FaqTile(
                                      faq: faqs[index],
                                      onEdit: () =>
                                          _editFaq(context, faqs[index]),
                                      onDelete: () =>
                                          _deleteFaq(context, faqs[index]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackMetric extends StatelessWidget {
  const _FeedbackMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 50) / 2,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback, required this.onResolve});

  final QueryDocumentSnapshot<Map<String, dynamic>> feedback;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = feedback.data();
    final name =
        data['name'] as String? ?? data['fromName'] as String? ?? 'User';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final status = data['status'] as String? ?? 'open';
    final statusColor = status == 'resolved' ? Colors.green : colors.tertiary;
    final timestamp = data['createdAt'];
    final date = timestamp is Timestamp
        ? _formatDateTime(timestamp.toDate())
        : 'Date unavailable';
    final rating = data['rating'] is num
        ? (data['rating'] as num).round().clamp(0, 5)
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  child: Text(initials.isEmpty ? '?' : initials),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _FeedbackStatus(
                  label: _displayStatus(status),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var star = 1; star <= 5; star++)
                  Icon(
                    star <= rating ? Icons.star : Icons.star_border,
                    size: 18,
                    color: Colors.amber.shade700,
                  ),
                const SizedBox(width: 8),
                Text(
                  data['category'] as String? ?? 'General',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data['message'] as String? ?? '',
              style: theme.textTheme.bodyMedium,
            ),
            if (status != 'resolved')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onResolve,
                  child: const Text('Mark resolved'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackStatus extends StatelessWidget {
  const _FeedbackStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.faq,
    required this.onEdit,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> faq;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = faq.data();
    final timestamp = data['updatedAt'];
    final updated = timestamp is Timestamp
        ? _formatDate(timestamp.toDate())
        : 'Not available';

    return ExpansionTile(
      leading: Icon(Icons.help_outline, color: colors.primary),
      title: Text(data['question'] as String? ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit FAQ',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete FAQ',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(56, 0, 20, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['answer'] as String? ?? '',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Updated $updated',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

int _compareNewestFirst(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final dateA = a.data()['createdAt'];
  final dateB = b.data()['createdAt'];
  final valueA = dateA is Timestamp ? dateA.millisecondsSinceEpoch : 0;
  final valueB = dateB is Timestamp ? dateB.millisecondsSinceEpoch : 0;
  return valueB.compareTo(valueA);
}

String _displayStatus(String status) => status.isEmpty
    ? status
    : '${status[0].toUpperCase()}${status.substring(1)}';

String _formatDate(DateTime date) =>
    '${_month(date.month)} ${date.day}, ${date.year}';

String _formatDateTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${_formatDate(date)} · $hour:$minute $period';
}

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

Future<void> _editFaq(
  BuildContext context, [
  QueryDocumentSnapshot<Map<String, dynamic>>? faq,
]) async {
  final values = await showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => _FaqEditorDialog(
      initialQuestion: faq?.data()['question'] as String? ?? '',
      initialAnswer: faq?.data()['answer'] as String? ?? '',
      isEditing: faq != null,
    ),
  );
  if (values == null || !context.mounted) return;

  final db = FirebaseFirestore.instance;
  final entry = faq?.reference ?? db.collection('feedback_faqs').doc();
  final batch = db.batch();
  final now = FieldValue.serverTimestamp();
  if (faq == null) {
    batch.set(entry, {
      'type': 'faq',
      'question': values.$1,
      'answer': values.$2,
      'createdAt': now,
      'updatedAt': now,
    });
  } else {
    batch.update(entry, {
      'question': values.$1,
      'answer': values.$2,
      'updatedAt': now,
    });
  }
  batch.set(
    db.collection('logs').doc(),
    adminLogData(
      title: faq == null ? 'FAQ created' : 'FAQ updated',
      description: values.$1,
      type: 'Content',
    ),
  );

  try {
    await batch.commit();
    if (context.mounted) {
      PopupNotif(message: faq == null ? 'FAQ added.' : 'FAQ updated.', title: 'Info', type: NotifType.info,).show(context);
    }
  } on FirebaseException catch (error) {
    if (context.mounted) {
      PopupNotif(message: 'Unable to save FAQ: ${error.message}', title: 'Error', type: NotifType.error,).show(context);
    }
  }
}

Future<void> _deleteFaq(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> faq,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ConfirmationDialog(
      title: 'Delete FAQ?',
      content:'Delete "${faq.data()['question'] ?? ''}"?',
      confirmText: 'Delete',
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final db = FirebaseFirestore.instance;
  final batch = db.batch();
  batch.delete(faq.reference);
  batch.set(
    db.collection('logs').doc(),
    adminLogData(
      title: 'FAQ deleted',
      description: faq.data()['question'] as String? ?? '',
      type: 'Content',
    ),
  );
  try {
    await batch.commit();
    if (context.mounted) {
      PopupNotif(
        message: 'FAQ deleted.',
        title: 'Info',
        type: NotifType.info,
      ).show(context);
    }
  } on FirebaseException catch (error) {
    if (context.mounted) {
      PopupNotif(message: 'Unable to delete FAQ: ${error.message}', title: 'Error', type: NotifType.error,).show(context);
    }
  }
}

Future<void> _setFeedbackStatus(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> feedback,
  String status,
) async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();
  batch.update(feedback.reference, {
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  batch.set(
    db.collection('logs').doc(),
    adminLogData(
      title: 'Feedback marked as resolved',
      description: feedback.data()['message'] as String? ?? feedback.id,
      type: 'Feedback',
    ),
  );
  try {
    await batch.commit();
    if (context.mounted) {
      PopupNotif(message: 'Feedback marked as resolved.', title: 'Info', type: NotifType.info,).show(context);
    }
  } on FirebaseException catch (error) {
    if (context.mounted) {
      PopupNotif(message: 'Unable to update feedback: ${error.message}', title: 'Error', type: NotifType.error,).show(context);
    }
  }
}

class _FaqEditorDialog extends StatefulWidget {
  const _FaqEditorDialog({
    required this.initialQuestion,
    required this.initialAnswer,
    required this.isEditing,
  });

  final String initialQuestion;
  final String initialAnswer;
  final bool isEditing;

  @override
  State<_FaqEditorDialog> createState() => _FaqEditorDialogState();
}

class _FaqEditorDialogState extends State<_FaqEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.initialQuestion);
    _answerController = TextEditingController(text: widget.initialAnswer);
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      _questionController.text.trim(),
      _answerController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit FAQ' : 'Add FAQ'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(labelText: 'Question'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a question.'
                  : null,
            ),
            TextFormField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Answer',
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 5,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an answer.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
