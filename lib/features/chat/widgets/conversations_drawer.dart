// Step 1: Inventory
// This file DEFINES: ConversationsDrawer StatefulWidget with:
//   - State variables: _conversations (List<Conversation>), _groupedItems (List<dynamic>), _activeConversationId (String?)
//   - Methods: _buildGroupedItems(), _buildDateHeader(), _buildConversationTile(), _buildEmptyDrawer(),
//              _showContextMenu(), _showRenameDialog(), _exportConversation(), _timeAgo(), _getPreview()
//   - Widget props: onNewConversation (VoidCallback), onConversationSelected (Function(String)), activeConversationId (String?)
//
// This file USES from other files:
//   - ConversationProvider (from conversation_provider.dart):
//     - .conversations (getter) -> List<Conversation>
//     - .isLoading (getter) -> bool
//     - .deleteConversation(String id) -> Future<void>
//     - .undoDelete() -> Future<void>
//     - .renameConversation(String id, String newTitle) -> Future<void>
//     - .getConversationText(String id) -> Future<String>
//   - Conversation (from conversation.dart):
//     - Fields: id, title, modelName, updatedAt, messageCount
//   - share_plus for Share.share()
//   - Provider package for context.read<>() / context.watch<>()
//
// Step 2: Connections
// - MainShell creates ConversationsDrawer passing onNewConversation and onConversationSelected callbacks
// - Drawer listens to ConversationProvider via context.watch<ConversationProvider>()
// - On conversation tap: calls widget.onConversationSelected(id) + Navigator.pop(context)
// - On new chat: calls widget.onNewConversation() + Navigator.pop(context)
// - Dismissible: calls ConversationProvider.deleteConversation() + shows SnackBar with Undo
// - Long-press: shows bottom sheet with Rename/Export/Delete options
//
// Step 3: User Journey Trace
// User opens drawer -> sees grouped conversation list (Today/Yesterday/This Week/Older)
// User taps conversation -> onConversationSelected called, drawer closes
// User swipes left -> conversation deleted, SnackBar shown with Undo button
// User long-presses -> bottom sheet shows Rename/Export/Delete
//   - Rename -> AlertDialog with TextField -> ConversationProvider.renameConversation()
//   - Export -> ConversationProvider.getConversationText() -> Share.share()
//   - Delete -> AlertDialog confirm -> ConversationProvider.deleteConversation()
// User taps edit icon -> onNewConversation called, drawer closes
//
// Step 4: Layout Sanity
// Drawer > SafeArea > Column([Header Row, Divider, Expanded(ListView)])
// ListView contains mixed items: String headers and Conversation tiles
// Dismissible wraps each conversation tile
// No unbounded ListView inside Column - properly wrapped in Expanded
// TextEditingController for rename dialog declared as local in dialog method (disposed inline)
// ConversationProvider watched in build() via context.watch<>()

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pocketai/core/models/conversation.dart';
import 'package:pocketai/core/providers/conversation_provider.dart';

class ConversationsDrawer extends StatefulWidget {
  final VoidCallback onNewConversation;
  final Function(String) onConversationSelected;
  final String? activeConversationId;

  const ConversationsDrawer({
    super.key,
    required this.onNewConversation,
    required this.onConversationSelected,
    this.activeConversationId,
  });

  @override
  State<ConversationsDrawer> createState() => _ConversationsDrawerState();
}

class _ConversationsDrawerState extends State<ConversationsDrawer> {
  List<Conversation> _conversations = [];
  List<dynamic> _groupedItems = [];
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.activeConversationId;
  }

  @override
  void didUpdateWidget(ConversationsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeConversationId != widget.activeConversationId) {
      setState(() {
        _activeConversationId = widget.activeConversationId;
      });
    }
  }

  void _buildGroupedItems(List<Conversation> conversations) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayConvs = <Conversation>[];
    final yesterdayConvs = <Conversation>[];
    final thisWeekConvs = <Conversation>[];
    final olderConvs = <Conversation>[];

    for (final conv in conversations) {
      final convDay = DateTime(
        conv.updatedAt.year,
        conv.updatedAt.month,
        conv.updatedAt.day,
      );
      if (!convDay.isBefore(today)) {
        todayConvs.add(conv);
      } else if (!convDay.isBefore(yesterday)) {
        yesterdayConvs.add(conv);
      } else if (!convDay.isBefore(weekAgo)) {
        thisWeekConvs.add(conv);
      } else {
        olderConvs.add(conv);
      }
    }

    final items = <dynamic>[];
    if (todayConvs.isNotEmpty) {
      items.add('Today');
      items.addAll(todayConvs);
    }
    if (yesterdayConvs.isNotEmpty) {
      items.add('Yesterday');
      items.addAll(yesterdayConvs);
    }
    if (thisWeekConvs.isNotEmpty) {
      items.add('This Week');
      items.addAll(thisWeekConvs);
    }
    if (olderConvs.isNotEmpty) {
      items.add('Older');
      items.addAll(olderConvs);
    }

    _conversations = conversations;
    _groupedItems = items;
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _getPreview(Conversation conv) {
    if (conv.messageCount == 0) return 'No messages yet';
    return '${conv.messageCount} message${conv.messageCount == 1 ? '' : 's'}';
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF64748B),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final isActive = conversation.id == _activeConversationId;
    return Dismissible(
      key: Key('conv_${conversation.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: const BoxDecoration(
          color: Colors.red,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text(
              'Delete Conversation',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this conversation?',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) async {
        await context.read<ConversationProvider>().deleteConversation(conversation.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Conversation deleted'),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFF1E293B),
              action: SnackBarAction(
                label: 'Undo',
                textColor: const Color(0xFF3B82F6),
                onPressed: () {
                  context.read<ConversationProvider>().undoDelete();
                },
              ),
            ),
          );
        }
      },
      child: GestureDetector(
        onLongPress: () => _showContextMenu(conversation),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          tileColor: isActive ? const Color(0xFF1E293B) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: Color(0xFF3B82F6),
            ),
          ),
          title: Text(
            conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  conversation.modelName.isNotEmpty
                      ? conversation.modelName
                      : 'No Model',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _getPreview(conversation),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          trailing: Text(
            _timeAgo(conversation.updatedAt),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
            ),
          ),
          onTap: () {
            setState(() {
              _activeConversationId = conversation.id;
            });
            widget.onConversationSelected(conversation.id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showContextMenu(Conversation conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                conversation.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(color: Color(0xFF334155), height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6)),
              title: const Text(
                'Rename',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Color(0xFF3B82F6)),
              title: const Text(
                'Export',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _exportConversation(conversation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(conversation);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Conversation conversation) {
    final controller = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Rename Conversation',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new title',
            hintStyle: TextStyle(color: Color(0xFF64748B)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF3B82F6)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              controller.dispose();
              Navigator.pop(ctx);
              if (newTitle.isNotEmpty) {
                await context
                    .read<ConversationProvider>()
                    .renameConversation(conversation.id, newTitle);
              }
            },
            child: const Text(
              'Rename',
              style: TextStyle(color: Color(0xFF3B82F6)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Conversation conversation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Delete Conversation',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This conversation will be permanently deleted.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context
                  .read<ConversationProvider>()
                  .deleteConversation(conversation.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Conversation deleted'),
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xFF1E293B),
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: const Color(0xFF3B82F6),
                      onPressed: () {
                        context.read<ConversationProvider>().undoDelete();
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportConversation(Conversation conversation) async {
    try {
      final text = await context
          .read<ConversationProvider>()
          .getConversationText(conversation.id);
      if (text.isNotEmpty) {
        await Share.share(text, subject: 'MyTinyAI Conversation');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No content to export'),
              backgroundColor: Color(0xFF1E293B),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export conversation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEmptyDrawer() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.history,
            size: 48,
            color: Color(0xFF334155),
          ),
          SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start a new chat to begin',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversationProvider>();
    final conversations = provider.conversations.toList();
    _buildGroupedItems(conversations);

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    color: Color(0xFF3B82F6),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'MyTinyAI',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF64748B),
                    ),
                    tooltip: 'New Chat',
                    onPressed: () {
                      widget.onNewConversation();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B), height: 1),
            if (provider.isLoading)
              const LinearProgressIndicator(
                color: Color(0xFF3B82F6),
                backgroundColor: Color(0xFF1E293B),
              ),
            Expanded(
              child: _conversations.isEmpty && !provider.isLoading
                  ? _buildEmptyDrawer()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      itemCount: _groupedItems.length,
                      itemBuilder: (ctx, i) {
                        final item = _groupedItems[i];
                        if (item is String) {
                          return _buildDateHeader(item);
                        }
                        return _buildConversationTile(item as Conversation);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}