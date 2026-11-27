import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/loader.dart';
import '../../widgets/lookout_app_bar.dart';
import '../../widgets/popup_notif.dart';

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  static const List<String> _feedbackCategories = [
    'General',
    'PUV Tracking',
    'ETA & Routes',
    'Poke System',
    'Bug Report',
    'Suggestion',
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _openFeedbackDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      PopupNotif(
        title: 'Sign in required',
        message: 'Sign in to submit feedback.',
        type: NotifType.warning,
      ).show(context);
      return;
    }

    final draft = await showDialog<_FeedbackDraft>(
      context: context,
      builder: (context) => const _FeedbackDialog(
        categories: _feedbackCategories,
      ),
    );
    if (draft == null || !mounted) return;

    try {
      final userSnapshot =
          await _firestore.collection('users').doc(user.uid).get();
      final fullName = (userSnapshot.data()?['fullName'] as String?)?.trim() ?? '';
      final senderName = fullName.isNotEmpty
          ? fullName
          : (user.email ?? 'LookOut! user');
      final now = FieldValue.serverTimestamp();

      await _firestore.collection('feedback_faqs').add({
        'type': 'feedback',
        'name': senderName,
        'fromName': senderName,
        'fromUid': user.uid,
        'category': draft.category,
        'rating': draft.rating,
        'message': draft.message,
        'status': 'open',
        'createdAt': now,
        'updatedAt': now,
      });

      if (!mounted) return;
      PopupNotif(
        title: 'Thank you!',
        message: 'Your feedback was submitted.',
        type: NotifType.success,
      ).show(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      PopupNotif(
        title: 'Error',
        message: 'Unable to submit feedback: ${error.message ?? error.code}',
        type: NotifType.error,
      ).show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final faqsStream = _firestore
        .collection('feedback_faqs')
        .where('type', isEqualTo: 'faq')
        .snapshots();

    return Scaffold(
      appBar: const LookOutAppBar(title: 'FAQs'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: faqsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to load FAQs: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) return const Loader.circular();

          final allFaqs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final questionA = a.data()['question']?.toString() ?? '';
              final questionB = b.data()['question']?.toString() ?? '';
              return questionA.toLowerCase().compareTo(questionB.toLowerCase());
            });

          final faqs = _searchQuery.isEmpty
              ? allFaqs
              : allFaqs.where((doc) {
                  final data = doc.data();
                  final question =
                      data['question']?.toString().toLowerCase() ?? '';
                  final answer = data['answer']?.toString().toLowerCase() ?? '';
                  return question.contains(_searchQuery) ||
                      answer.contains(_searchQuery);
                }).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frequently Asked Questions',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Find quick answers or send us feedback.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _openFeedbackDialog,
                    icon: const Icon(Icons.feedback_outlined),
                    label: const Text('Feedback'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(
                  () => _searchQuery = value.trim().toLowerCase(),
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search FAQs...',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${faqs.length} ${faqs.length == 1 ? 'article' : 'articles'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Reset search'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (faqs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 40,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No FAQs match your search.'
                              : 'No FAQs available yet.',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Try a different keyword or clear the search.'
                              : 'Check back soon or send feedback with your question.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _clearSearch,
                            child: const Text('Clear search'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                for (final faq in faqs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: Icon(Icons.help_outline, color: colors.primary),
                      title: Text(
                        faq.data()['question']?.toString() ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        16,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            faq.data()['answer']?.toString() ?? '',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedbackDraft {
  const _FeedbackDraft({
    required this.category,
    required this.rating,
    required this.message,
  });

  final String category;
  final int rating;
  final String message;
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({required this.categories});

  final List<String> categories;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  late String _category;
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.first;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _FeedbackDraft(
        category: _category,
        rating: _rating,
        message: _messageController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Send Feedback'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rating', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                      onPressed: () => setState(() => _rating = star),
                      icon: Icon(
                        star <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Share an issue, suggestion, or question...',
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 5,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your feedback message.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
