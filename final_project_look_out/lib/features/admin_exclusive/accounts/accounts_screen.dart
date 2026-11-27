import 'package:final_project_look_out/widgets/confirmation_dialog.dart';
import 'package:final_project_look_out/widgets/loader.dart';
import 'package:final_project_look_out/widgets/popup_notif.dart';

import '../../../services/admin_account_service.dart';
import '../../../services/admin_log_service.dart';
import '../../../widgets/lookout_app_bar.dart';
import 'create_account_form.dart';
import 'update_account_form.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class AccountsScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const AccountsScreen({super.key, this.onMenuPressed});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _AccountSort _sort = _AccountSort.nameAscending;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final usersStream = FirebaseFirestore.instance
        .collection('users')
        .snapshots();

    return Scaffold(
      appBar: LookOutAppBar(
        title: 'User Accounts',
        onMenuPressed: widget.onMenuPressed,
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
                    'Account Management',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage and monitor registered LookOut accounts.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Registered users',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _createAccount(context),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Create'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                            hintText:
                                'Search name, email, phone, role, or plate',
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
                      PopupMenuButton<_AccountSort>(
                        tooltip: 'Sort accounts',
                        initialValue: _sort,
                        onSelected: (sort) => setState(() => _sort = sort),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _AccountSort.nameAscending,
                            child: Text('Name A-Z'),
                          ),
                          PopupMenuItem(
                            value: _AccountSort.nameDescending,
                            child: Text('Name Z-A'),
                          ),
                          PopupMenuItem(
                            value: _AccountSort.newestFirst,
                            child: Text('Newest first'),
                          ),
                          PopupMenuItem(
                            value: _AccountSort.oldestFirst,
                            child: Text('Oldest first'),
                          ),
                        ],
                        icon: const Icon(Icons.sort),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: usersStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Unable to load accounts: ${snapshot.error}',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Loader.circular();
                      }

                      final accounts = snapshot.data!.docs.toList()
                        ..sort((a, b) => _compareAccounts(a, b, _sort));
                      final filteredAccounts = accounts
                          .where(_matchesSearch)
                          .toList();
                      final drivers = accounts
                          .where(
                            (account) => account.data()['role'] == 'driver',
                          )
                          .length;
                      final commuters = accounts
                          .where(
                            (account) => account.data()['role'] == 'commuter',
                          )
                          .length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _AccountMetric(
                                label: 'Total accounts',
                                value: '${accounts.length}',
                                icon: Icons.people_outline,
                              ),
                              _AccountMetric(
                                label: 'Drivers',
                                value: '$drivers',
                                icon: Icons.drive_eta_outlined,
                              ),
                              _AccountMetric(
                                label: 'Commuters',
                                value: '$commuters',
                                icon: Icons.person_outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${filteredAccounts.length} shown',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (accounts.isEmpty)
                            const Text('No user accounts found.')
                          else if (filteredAccounts.isEmpty)
                            const Text('No accounts match your search.')
                          else
                            for (final account in filteredAccounts)
                              _AccountCard(
                                account: account,
                                onAction: (action) => _handleAccountAction(
                                  context,
                                  account,
                                  action,
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

  bool _matchesSearch(QueryDocumentSnapshot<Map<String, dynamic>> account) {
    if (_searchQuery.isEmpty) return true;
    final data = account.data();
    final searchable = [
      account.id,
      data['fullName'],
      data['email'],
      data['phone'],
      data['role'],
      data['activePlate'],
      if (data['plates'] is Iterable) ...(data['plates'] as Iterable),
    ].whereType<Object>().join(' ').toLowerCase();
    return searchable.contains(_searchQuery);
  }
}

enum _AccountSort { nameAscending, nameDescending, newestFirst, oldestFirst }

enum _AccountAction { update, showMore, delete }

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onAction});

  final QueryDocumentSnapshot<Map<String, dynamic>> account;
  final ValueChanged<_AccountAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = account.data();
    final name = data['fullName'] as String? ?? 'Unnamed user';
    final email = data['email'] as String? ?? '';
    final role = data['role'] as String? ?? 'commuter';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(initials.isEmpty ? '?' : initials),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _AccountTag(label: _displayRole(role)),
                      if ((data['phone'] as String? ?? '').isNotEmpty)
                        _AccountTag(label: data['phone'] as String),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<_AccountAction>(
              tooltip: 'Account actions',
              onSelected: onAction,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _AccountAction.update,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Update account'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _AccountAction.showMore,
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined),
                      SizedBox(width: 12),
                      Text('Show more details'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _AccountAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 12),
                      Text('Delete account'),
                    ],
                  ),
                ),
              ],
              child: Icon(Icons.more_vert, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTag extends StatelessWidget {
  const _AccountTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tagColor = colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: tagColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _displayRole(String role) =>
    role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}';

int _compareAccounts(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
  _AccountSort sort,
) {
  if (sort == _AccountSort.nameAscending ||
      sort == _AccountSort.nameDescending) {
    final nameA = (a.data()['fullName'] as String? ?? '').toLowerCase();
    final nameB = (b.data()['fullName'] as String? ?? '').toLowerCase();
    final comparison = nameA.compareTo(nameB);
    return sort == _AccountSort.nameAscending ? comparison : -comparison;
  }

  final createdAtA = a.data()['createdAt'];
  final createdAtB = b.data()['createdAt'];
  final timeA = createdAtA is Timestamp ? createdAtA.millisecondsSinceEpoch : 0;
  final timeB = createdAtB is Timestamp ? createdAtB.millisecondsSinceEpoch : 0;
  final comparison = timeA.compareTo(timeB);
  return sort == _AccountSort.newestFirst ? -comparison : comparison;
}

Future<void> _handleAccountAction(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> account,
  _AccountAction action,
) async {
  switch (action) {
    case _AccountAction.update:
      await _updateAccount(context, account);
    case _AccountAction.showMore:
      await _showAccountDetails(context, account);
    case _AccountAction.delete:
      await _deleteAccount(context, account);
  }
}

Future<void> _createAccount(BuildContext context) async {
  final values = await showCreateAccountForm(context);
  if (values == null || !context.mounted) return;

  try {
    await AdminAccountService.createAccount(
      fullName: values.fullName,
      email: values.email,
      password: values.password,
      role: values.role,
    );
    if (context.mounted) {
      PopupNotif(
        message: 'Account Created.',
        title: 'Success',
        type: NotifType.success,
      ).show(context);
    }
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      PopupNotif(
        message:
            'Unable to create account (${error.code}): '
            '${error.message ?? 'No details provided.'}',
        title: 'Error',
        type: NotifType.error,
      ).show(context);
    }
  } on FirebaseException catch (error) {
    if (context.mounted) {
      PopupNotif(
        message: 'Unable to create account: ${error.message}',
        title: 'Error',
        type: NotifType.error,
      ).show(context);
    }
  }
}

Future<void> _updateAccount(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> account,
) async {
  final previousData = account.data();
  final values = await showUpdateAccountForm(
    context,
    fullName: previousData['fullName'] as String? ?? '',
    role: previousData['role'] as String? ?? 'commuter',
  );
  if (values == null || !context.mounted) return;

  final changes = <String>[];
  if (previousData['fullName'] != values.fullName) {
    changes.add('name updated');
  }
  if (previousData['role'] != values.role) {
    changes.add(
      'role changed from '
      '${_displayRole(previousData['role'] as String? ?? '')} to '
      '${_displayRole(values.role)}',
    );
  }

  final db = FirebaseFirestore.instance;
  final batch = db.batch();
  batch.update(account.reference, {
    'fullName': values.fullName,
    'role': values.role,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  batch.set(
    db.collection('logs').doc(),
    adminLogData(
      title: 'Account updated',
      description:
          '${previousData['fullName'] ?? account.id}: '
          '${changes.isEmpty ? 'details saved' : changes.join(', ')}',
      type: 'Account',
    ),
  );

  try {
    await batch.commit();
    if (context.mounted) {
      PopupNotif(
        message: 'Account updated.',
        title: 'Success',
        type: NotifType.success,
      ).show(context);
    }
  } on FirebaseException catch (error) {
    if (context.mounted) {
      PopupNotif(
        message: 'Unable to update account: ${error.message}',
        title: 'Error',
        type: NotifType.error,
      ).show(context);
    }
  }
}

Future<void> _showAccountDetails(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> account,
) async {
  final data = account.data();
  final createdAt = data['createdAt'];
  final updatedAt = data['updatedAt'];
  final details = <String, String>{
    'UID': account.id,
    'Full name': data['fullName'] as String? ?? '—',
    'Email': data['email'] as String? ?? '—',
    'Phone': data['phone'] as String? ?? '—',
    'Role': _displayRole(data['role'] as String? ?? '—'),
    'Active plate': data['activePlate'] as String? ?? '—',
    'Plates': data['plates'] is Iterable
        ? (data['plates'] as Iterable).join(', ')
        : '—',
    'Login tab': data['loginTab'] as String? ?? '—',
    'Created at': createdAt is Timestamp
        ? createdAt.toDate().toLocal().toString()
        : '—',
    'Updated at': updatedAt is Timestamp
        ? updatedAt.toDate().toLocal().toString()
        : '—',
  };

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Show More Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in details.entries) ...[
              Text(entry.key, style: Theme.of(context).textTheme.labelMedium),
              SelectableText(entry.value),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _deleteAccount(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> account,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ConfirmationDialog(
      title: 'Delete account?',
      content:
          'Delete the Firestore profile for '
          '${account.data()['fullName'] ?? account.id}? '
          'The Firebase Authentication account may remain and could still sign in.',
      confirmText: 'Delete',
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await AdminAccountService.deleteAccount(
      uid: account.id,
      fullName: account.data()['fullName'] as String? ?? 'Unnamed user',
      email: account.data()['email'] as String? ?? '',
    );
    if (context.mounted) {
      PopupNotif(
        message: 'Firestore profile deleted. The Auth account may remain.',
        title: 'Info',
        type: NotifType.info,
      ).show(context);
    }
  } on FirebaseException catch (error) {
    if (context.mounted) {
      PopupNotif(
        message: 'Unable to delete account: ${error.message}',
        title: 'Error',
        type: NotifType.error,
      ).show(context);
    }
  }
}
