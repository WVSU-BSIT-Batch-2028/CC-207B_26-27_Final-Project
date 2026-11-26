// F4 Messages: the user's chats, newest first. It uses a Firestore stream,
// so a new message moves its chat to the top right away. Chats the other
// person wrote last and I haven't opened yet show a green dot and bold
// text. Search, "Unread only" and page numbers work together.

import 'package:flutter/material.dart';

import '../models/chat.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../utils/format.dart';
import '../utils/paging.dart';
import '../utils/strings.dart';
import '../utils/theme.dart';
import '../widgets/list_page.dart';
import '../widgets/list_tools.dart';
import '../widgets/page_header.dart';
import 'chat_screen.dart';

/// Inbox tab for farmers and buyers.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _myId = AuthService.currentUser!.id;
  final _scroll = ScrollController();
  late Stream<List<Chat>> _chats;
  String _search = '';
  bool _onlyUnread = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _chats = MessageService().watchChats(_myId);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Starts listening again (the Try again button and pull to refresh).
  Future<void> _retry() async {
    setState(() => _chats = MessageService().watchChats(_myId));
  }

  @override
  Widget build(BuildContext context) {
    final isFarmer = AuthService.currentUser!.isFarmer;
    return StreamBuilder<List<Chat>>(
      stream: _chats,
      builder: (context, snapshot) {
        final chats = snapshot.data ?? [];
        final unread = chats.where((c) => c.isUnreadFor(_myId)).length;
        final visible = chats.where((chat) {
          if (_onlyUnread && !chat.isUnreadFor(_myId)) return false;
          return matchesSearch(_search, [
            chat.otherUserName(_myId),
            chat.lastMessage,
          ]);
        }).toList();
        final slice = pageOf(visible, _page, pageSize: 15);
        return ListPage(
          controller: _scroll,
          onRefresh: _retry,
          header: PageHeader(
            eyebrow: 'Inbox',
            title: 'Messages',
            help: const [
              'A green dot means the other person wrote and you have not opened it yet.',
              'Use "Unread only" to see just the new ones.',
              'Start a chat from a crop ("Message farmer") or a request ("Message buyer").',
            ],
            lead: unread == 0
                ? (isFarmer
                      ? 'Chats with buyers about your crops.'
                      : 'Chats with farmers about their crops.')
                : 'You have $unread unread conversation'
                      '${unread == 1 ? '' : 's'}.',
          ),
          toolbar: ListToolbar(
            search: SearchBox(
              hint: 'Search names and messages…',
              onChanged: (text) => setState(() {
                _search = text;
                _page = 1;
              }),
            ),
            filters: [
              FilterChip(
                label: Text('Unread only ($unread)'),
                selected: _onlyUnread,
                showCheckmark: false,
                onSelected: (value) => setState(() {
                  _onlyUnread = value;
                  _page = 1;
                }),
              ),
            ],
          ),
          isLoading: snapshot.connectionState == ConnectionState.waiting,
          errorMessage: snapshot.hasError ? AppStrings.networkError : null,
          onRetry: _retry,
          isEmpty: visible.isEmpty,
          emptyMessage: _search.isNotEmpty || _onlyUnread
              ? 'No conversations match. Clear the search or the Unread '
                    'filter.'
              : isFarmer
              ? 'No messages yet.\nBuyers who message you show up here.'
              : 'No messages yet.\nOpen a crop in the Market and tap '
                    '"Message farmer".',
          // One white box with lines between the chats.
          sliverBuilder: (context, width) => SliverToBoxAdapter(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < slice.items.length; i++) ...[
                    if (i > 0) const Divider(),
                    _buildRow(slice.items[i]),
                  ],
                ],
              ),
            ),
          ),
          pagination: PaginationBar(
            slice: slice,
            onPage: (page) {
              setState(() => _page = page);
              if (_scroll.hasClients) _scroll.jumpTo(0);
            },
          ),
        );
      },
    );
  }

  /// One chat: avatar, name, last message and date, and an unread dot.
  Widget _buildRow(Chat chat) {
    final otherName = chat.otherUserName(_myId);
    final unread = chat.isUnreadFor(_myId);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: CircleAvatar(
        radius: 23,
        backgroundColor: AppColors.primaryLight,
        child: Text(
          otherName[0].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
      ),
      title: Text(
        otherName,
        style: TextStyle(
          fontSize: 15,
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread ? AppColors.text : AppColors.textMuted,
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatDate(chat.lastMessageAt), style: AppTextStyles.meta),
          if (unread) ...[
            const SizedBox(height: 6),
            // The dot has a text label for screen readers.
            Semantics(
              label: 'Unread',
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chat.id, otherName: otherName),
        ),
      ),
    );
  }
}
