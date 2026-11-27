import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/admin_log_service.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/loader.dart';
import '../../widgets/lookout_app_bar.dart';
import '../../widgets/popup_notif.dart';

class AnnouncementsScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const AnnouncementsScreen({
    super.key,
    this.onMenuPressed,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

enum _AnnouncementSort { newestFirst, oldestFirst }

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const String _allFilter = 'All';
  static const List<String> _categories = [
    'Service update',
    'Route alert',
    'Schedule',
    'Maintenance',
    'App notice',
  ];
  static const List<({String value, String label})> _audiences = [
    (value: 'all', label: 'Everyone'),
    (value: 'commuter', label: 'Commuters'),
    (value: 'driver', label: 'Drivers'),
  ];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = _allFilter;
  String _selectedAudience = _allFilter;
  _AnnouncementSort _sort = _AnnouncementSort.newestFirst;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != _allFilter ||
      _selectedAudience != _allFilter;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = _allFilter;
      _selectedAudience = _allFilter;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> _userProfileStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> _openEditor({
    required String authorName,
    required bool isAdmin,
    required bool isDriver,
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    if (!isAdmin && !isDriver) return;

    final data = existing?.data();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (existing != null && !_canManageAnnouncement(
      data: data ?? const {},
      currentUid: currentUid,
      isAdmin: isAdmin,
      isDriver: isDriver,
    )) {
      return;
    }

    final initialTargetRole = isAdmin
        ? _normalizeAudience(data?['targetRole'] as String?)
        : 'driver';

    final result = await showDialog<_AnnouncementDraft>(
      context: context,
      builder: (context) => _AnnouncementEditorDialog(
        initialTitle: data?['title'] as String? ?? '',
        initialMessage: data?['message'] as String? ?? '',
        initialCategory: _normalizeCategory(data?['category'] as String?),
        initialTargetRole: initialTargetRole,
        isEditing: existing != null,
        canSelectAudience: isAdmin,
        categories: _categories,
        audiences: _audiences,
      ),
    );
    if (result == null || !mounted) return;

    final targetRole = isAdmin ? result.targetRole : 'driver';
    final docRef =
        existing?.reference ?? _firestore.collection('announcements').doc();
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    if (existing == null) {
      batch.set(docRef, {
        'title': result.title,
        'message': result.message,
        'category': result.category,
        'targetRole': targetRole,
        'authorName': authorName,
        'authorRole': isAdmin ? 'admin' : 'driver',
        'authorUid': currentUid,
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      batch.update(docRef, {
        'title': result.title,
        'message': result.message,
        'category': result.category,
        'targetRole': targetRole,
        'updatedAt': now,
      });
    }

    if (isAdmin) {
      batch.set(
        _firestore.collection('logs').doc(),
        adminLogData(
          title: existing == null
              ? 'Announcement posted'
              : 'Announcement updated',
          description: result.title,
          type: 'Announcement',
        ),
      );
    }

    try {
      await batch.commit();
      if (!mounted) return;
      PopupNotif(
        title: 'Success',
        message: existing == null
            ? 'Announcement published.'
            : 'Announcement updated.',
        type: NotifType.success,
      ).show(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      PopupNotif(
        title: 'Error',
        message: 'Unable to save announcement: ${error.message ?? error.code}',
        type: NotifType.error,
      ).show(context);
    }
  }

  Future<void> _deleteAnnouncement(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isAdmin,
    required bool isDriver,
  }) async {
    final data = doc.data();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (!_canManageAnnouncement(
      data: data,
      currentUid: currentUid,
      isAdmin: isAdmin,
      isDriver: isDriver,
    )) {
      return;
    }

    final title = data['title'] as String? ?? 'this announcement';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Delete Announcement?',
        content: 'Delete "$title"? This cannot be undone.',
        confirmText: 'Delete',
      ),
    );
    if (confirmed != true || !mounted) return;

    final batch = _firestore.batch();
    batch.delete(doc.reference);
    if (isAdmin) {
      batch.set(
        _firestore.collection('logs').doc(),
        adminLogData(
          title: 'Announcement deleted',
          description: title,
          type: 'Announcement',
        ),
      );
    }

    try {
      await batch.commit();
      if (!mounted) return;
      PopupNotif(
        title: 'Deleted',
        message: 'Announcement removed.',
        type: NotifType.info,
      ).show(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      PopupNotif(
        title: 'Error',
        message:
            'Unable to delete announcement: ${error.message ?? error.code}',
        type: NotifType.error,
      ).show(context);
    }
  }

  static bool _canManageAnnouncement({
    required Map<String, dynamic> data,
    required String? currentUid,
    required bool isAdmin,
    required bool isDriver,
  }) {
    if (isAdmin) return true;
    if (!isDriver || currentUid == null) return false;
    final targetRole = _normalizeAudience(data['targetRole'] as String?);
    return targetRole == 'driver' && data['authorUid'] == currentUid;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterAndSort(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String userRole,
    required bool isAdmin,
    required bool isDriver,
  }) {
    final filtered = docs.where((doc) {
      final data = doc.data();
      final targetRole = _normalizeAudience(data['targetRole'] as String?);
      if (!isAdmin && targetRole != 'all' && targetRole != userRole) {
        return false;
      }

      if (isAdmin &&
          _selectedAudience != _allFilter &&
          targetRole != _selectedAudience) {
        return false;
      }

      if (isDriver &&
          _selectedAudience != _allFilter &&
          targetRole != _selectedAudience) {
        return false;
      }

      final category = _normalizeCategory(data['category'] as String?);
      if (_selectedCategory != _allFilter && category != _selectedCategory) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final haystack = [
          data['title'] as String? ?? '',
          data['message'] as String? ?? '',
          category,
          data['authorName'] as String? ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final timeA = _timestampMillis(a.data()['createdAt']);
      final timeB = _timestampMillis(b.data()['createdAt']);
      return _sort == _AnnouncementSort.newestFirst
          ? timeB.compareTo(timeA)
          : timeA.compareTo(timeB);
    });

    return filtered;
  }

  static int _timestampMillis(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  static String _normalizeCategory(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return _categories.contains(trimmed) ? trimmed : _categories.first;
  }

  static String _normalizeAudience(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? 'all';
    return _audiences.any((item) => item.value == normalized)
        ? normalized
        : 'all';
  }

  static IconData _iconForCategory(String category) => switch (category) {
    'Service update' => Icons.directions_bus_outlined,
    'Route alert' => Icons.alt_route,
    'Schedule' => Icons.schedule,
    'Maintenance' => Icons.build_outlined,
    'App notice' => Icons.tips_and_updates_outlined,
    _ => Icons.campaign_outlined,
  };

  static String _audienceLabel(String value) {
    for (final audience in _audiences) {
      if (audience.value == value) return audience.label;
    }
    return 'Everyone';
  }

  static String _formatTimestamp(Object? value) {
    if (value is! Timestamp) return 'Just now';
    final date = value.toDate().toLocal();
    const months = [
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
    ];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final announcementsStream = _firestore
        .collection('announcements')
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      stream: _userProfileStream(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data?.data();
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final userRole =
            (profile?['role'] as String?)?.trim().toLowerCase() ?? 'commuter';
        final isAdmin = userRole == 'admin';
        final isDriver = userRole == 'driver';
        final canPost = isAdmin || isDriver;
        final fullName = (profile?['fullName'] as String?)?.trim() ?? '';
        final authorName = fullName.isNotEmpty
            ? fullName
            : (FirebaseAuth.instance.currentUser?.email ??
                (isAdmin ? 'LookOut! Admin' : 'LookOut! Driver'));
        final availableAudiences = isAdmin
            ? _audiences
            : _audiences
                  .where((audience) => audience.value != 'commuter')
                  .toList();

        return Scaffold(
          appBar: LookOutAppBar(
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: 'Announcements',
            onMenuPressed: widget.onMenuPressed,
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: announcementsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Unable to load announcements: ${snapshot.error}',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Loader.circular();
              }

              final allDocs = snapshot.data!.docs;
              final visibleDocs = _filterAndSort(
                allDocs,
                userRole: userRole,
                isAdmin: isAdmin,
                isDriver: isDriver,
              );

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
                              'Updates from LookOut!',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAdmin
                                  ? 'Post and manage live service announcements.'
                                  : isDriver
                                      ? 'View updates and share advisories with fellow drivers.'
                                      : 'Live project news and service advisories.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canPost) ...[
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _openEditor(
                            authorName: authorName,
                            isAdmin: isAdmin,
                            isDriver: isDriver,
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Post'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(
                            () => _searchQuery = value.trim().toLowerCase(),
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search announcements...',
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<_AnnouncementSort>(
                        tooltip: 'Sort announcements',
                        initialValue: _sort,
                        onSelected: (sort) => setState(() => _sort = sort),
                        icon: const Icon(Icons.sort),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _AnnouncementSort.newestFirst,
                            child: Text('Newest first'),
                          ),
                          PopupMenuItem(
                            value: _AnnouncementSort.oldestFirst,
                            child: Text('Oldest first'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final category in [_allFilter, ..._categories])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected: (_) => setState(
                                () => _selectedCategory = category,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isAdmin || isDriver) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('All audiences'),
                              selected: _selectedAudience == _allFilter,
                              onSelected: (_) => setState(
                                () => _selectedAudience = _allFilter,
                              ),
                            ),
                          ),
                          for (final audience in availableAudiences)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(audience.label),
                                selected: _selectedAudience == audience.value,
                                onSelected: (_) => setState(
                                  () => _selectedAudience = audience.value,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${visibleDocs.length} '
                        '${visibleDocs.length == 1 ? 'announcement' : 'announcements'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (_hasActiveFilters) ...[
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.filter_alt_off, size: 18),
                          label: const Text('Reset filters'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (visibleDocs.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 40,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _hasActiveFilters
                                  ? 'No announcements match your filters.'
                                  : 'No announcements posted yet.',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _hasActiveFilters
                                  ? 'Try clearing your search or selecting another category.'
                                  : canPost
                                      ? 'Tap Post to publish the first update.'
                                      : 'Check back soon for route and service updates.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _clearFilters,
                                child: const Text('Clear filters'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    for (final doc in visibleDocs)
                      _AnnouncementCard(
                        doc: doc,
                        category: _normalizeCategory(
                          doc.data()['category'] as String?,
                        ),
                        audienceLabel: _audienceLabel(
                          _normalizeAudience(
                            doc.data()['targetRole'] as String?,
                          ),
                        ),
                        showAudience: isAdmin || isDriver,
                        icon: _iconForCategory(
                          _normalizeCategory(doc.data()['category'] as String?),
                        ),
                        dateLabel: _formatTimestamp(doc.data()['createdAt']),
                        canManage: _canManageAnnouncement(
                          data: doc.data(),
                          currentUid: currentUid,
                          isAdmin: isAdmin,
                          isDriver: isDriver,
                        ),
                        onEdit: () => _openEditor(
                          authorName: authorName,
                          isAdmin: isAdmin,
                          isDriver: isDriver,
                          existing: doc,
                        ),
                        onDelete: () => _deleteAnnouncement(
                          doc,
                          isAdmin: isAdmin,
                          isDriver: isDriver,
                        ),
                      ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.doc,
    required this.category,
    required this.audienceLabel,
    required this.showAudience,
    required this.icon,
    required this.dateLabel,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String category;
  final String audienceLabel;
  final bool showAudience;
  final IconData icon;
  final String dateLabel;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = doc.data();
    final title = data['title'] as String? ?? 'Announcement';
    final message = data['message'] as String? ?? '';
    final authorName = data['authorName'] as String? ?? 'LookOut! team';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (showAudience)
                        Text(
                          'Audience: $audienceLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: 'Announcement actions',
                    onSelected: (action) {
                      if (action == 'edit') onEdit();
                      if (action == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            Text(
              '$authorName · $dateLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementDraft {
  const _AnnouncementDraft({
    required this.title,
    required this.message,
    required this.category,
    required this.targetRole,
  });

  final String title;
  final String message;
  final String category;
  final String targetRole;
}

class _AnnouncementEditorDialog extends StatefulWidget {
  const _AnnouncementEditorDialog({
    required this.initialTitle,
    required this.initialMessage,
    required this.initialCategory,
    required this.initialTargetRole,
    required this.isEditing,
    required this.canSelectAudience,
    required this.categories,
    required this.audiences,
  });

  final String initialTitle;
  final String initialMessage;
  final String initialCategory;
  final String initialTargetRole;
  final bool isEditing;
  final bool canSelectAudience;
  final List<String> categories;
  final List<({String value, String label})> audiences;

  @override
  State<_AnnouncementEditorDialog> createState() =>
      _AnnouncementEditorDialogState();
}

class _AnnouncementEditorDialogState extends State<_AnnouncementEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  late String _category;
  late String _targetRole;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _messageController = TextEditingController(text: widget.initialMessage);
    _category = widget.initialCategory;
    _targetRole = widget.initialTargetRole;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _AnnouncementDraft(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        category: _category,
        targetRole: widget.canSelectAudience ? _targetRole : 'driver',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Announcement' : 'New Announcement'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (widget.canSelectAudience)
                DropdownButtonFormField<String>(
                  initialValue: _targetRole,
                  decoration: const InputDecoration(labelText: 'Audience'),
                  items: widget.audiences
                      .map(
                        (audience) => DropdownMenuItem(
                          value: audience.value,
                          child: Text(audience.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _targetRole = value);
                  },
                )
              else
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Audience'),
                  child: Text(
                    'Drivers only',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 3,
                maxLines: 6,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a message.'
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
          child: Text(widget.isEditing ? 'Save' : 'Publish'),
        ),
      ],
    );
  }
}
