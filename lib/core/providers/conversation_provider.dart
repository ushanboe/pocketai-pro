// Step 1: Inventory
// This file DEFINES: ConversationProvider class (ChangeNotifier) with:
//   Fields: _conversations (List<Conversation>), _isLoading (bool),
//           _lastDeleted (Conversation?), _lastDeletedMessages (List<Message>?)
//   Getters: conversations, isLoading
//   Methods: loadConversations(), createConversation(), addMessage(), getMessages(),
//            deleteConversation(), undoDelete(), renameConversation(), deleteMessage(),
//            getConversationText()
//
// This file USES from other files:
//   - DatabaseHelper (from lib/core/services/database_helper.dart)
//     Methods used: insertConversation, getAllConversations, updateConversation,
//                   deleteConversation, insertMessage, getMessagesForConversation, deleteMessage
//   - Conversation (from lib/core/models/conversation.dart)
//     Fields: id, title, modelId, modelName, systemPrompt, temperature, maxTokens,
//             createdAt, updatedAt, messageCount
//     Methods: copyWith, fromMap, toMap
//   - Message (from lib/core/models/message.dart)
//     Fields: id, conversationId, role, content, timestamp, tokenCount, generationTimeMs
//   - AppSettings (from lib/core/models/app_settings.dart)
//     Fields: temperature, maxTokens, systemPrompt, selectedModelId, selectedModelName
//
// External packages: uuid (for UUID generation), flutter/foundation (for ChangeNotifier)
//
// Step 2: Connections
// - main.dart creates instance and calls await conversationProvider.loadConversations()
// - ChatScreen calls createConversation(), addMessage(), getMessages(), deleteMessage(), getConversationText()
// - ConversationsDrawer calls deleteConversation(), undoDelete(), renameConversation(), getConversationText()
// - All DB calls delegate to DatabaseHelper.instance
//
// Step 3: User Journey Trace
// loadConversations: sets _isLoading=true, queries DB, sorts by updatedAt desc, notifyListeners
// createConversation: builds Conversation with UUID, snapshots settings, inserts to DB, prepends to list
// addMessage: inserts message, updates conversation updatedAt+messageCount, auto-titles if first user msg
// getMessages: queries DB for messages by conversationId ordered by timestamp ASC
// deleteConversation: saves to _lastDeleted/_lastDeletedMessages, deletes from DB, removes from list
// undoDelete: re-inserts conversation + messages to DB, re-adds to list, clears _lastDeleted
// renameConversation: updates DB title, updates in-memory list item
// deleteMessage: deletes from DB, decrements messageCount on conversation
// getConversationText: loads messages, formats as "Role: content\n" string
//
// Step 4: Layout Sanity
// No widgets — pure ChangeNotifier provider
// UUID package used for ID generation (uuid is in pubspec per spec)
// Auto-title: first 40 chars of first user message content
// All async methods use try/catch for error resilience
// notifyListeners() called after every state mutation

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:pocketai/core/models/conversation.dart';
import 'package:pocketai/core/models/message.dart';
import 'package:pocketai/core/models/app_settings.dart';
import 'package:pocketai/core/services/database_helper.dart';

class ConversationProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  Conversation? _lastDeleted;
  List<Message>? _lastDeletedMessages;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoading => _isLoading;
  Conversation? get lastDeleted => _lastDeleted;

  /// Loads all conversations from DB, sorted by updatedAt descending.
  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _db.getAllConversations();
      // getAllConversations already returns sorted by updatedAt DESC
      _conversations = rows;
    } catch (e) {
      debugPrint('ConversationProvider.loadConversations error: $e');
      _conversations = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new Conversation with a UUID, snapshots settings fields,
  /// inserts to DB, prepends to _conversations list, and notifies listeners.
  /// Returns the created Conversation.
  Future<Conversation> createConversation(
    AppSettings settings,
    String modelId,
    String modelName,
  ) async {
    final now = DateTime.now();
    final conversation = Conversation(
      id: _uuid.v4(),
      title: 'New Conversation',
      modelId: modelId.isNotEmpty ? modelId : settings.selectedModelId,
      modelName: modelName.isNotEmpty ? modelName : settings.selectedModelName,
      systemPrompt: settings.systemPrompt,
      temperature: settings.temperature,
      maxTokens: settings.maxTokens,
      createdAt: now,
      updatedAt: now,
      messageCount: 0,
    );

    try {
      await _db.insertConversation(conversation);
      _conversations.insert(0, conversation);
      notifyListeners();
    } catch (e) {
      debugPrint('ConversationProvider.createConversation error: $e');
    }

    return conversation;
  }

  /// Inserts a message to the messages table, updates the conversation's
  /// updatedAt and messageCount. If this is the first user message, auto-generates
  /// a title from the first 40 characters of the content.
  Future<void> addMessage(String conversationId, Message message) async {
    try {
      await _db.insertMessage(message);

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index == -1) return;

      final conversation = _conversations[index];
      final newCount = conversation.messageCount + 1;
      final now = DateTime.now();

      // Auto-generate title from first user message (messageCount was 0 before this)
      String newTitle = conversation.title;
      if (message.role == 'user' && conversation.messageCount == 0) {
        final raw = message.content.trim();
        newTitle = raw.length <= 40 ? raw : '${raw.substring(0, 40)}…';
        if (newTitle.isEmpty) newTitle = 'New Conversation';
      }

      final updated = conversation.copyWith(
        updatedAt: now,
        messageCount: newCount,
        title: newTitle,
      );

      await _db.updateConversation(updated);
      _conversations[index] = updated;

      // Re-sort so the most recently updated conversation floats to top
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      notifyListeners();
    } catch (e) {
      debugPrint('ConversationProvider.addMessage error: $e');
    }
  }

  /// Queries messages table WHERE conversationId=? ORDER BY timestamp ASC.
  /// Returns List<Message>.
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      return await _db.getMessagesForConversation(conversationId);
    } catch (e) {
      debugPrint('ConversationProvider.getMessages error: $e');
      return [];
    }
  }

  /// Stores conversation and its messages in _lastDeleted/_lastDeletedMessages,
  /// deletes from DB (cascade to messages), removes from _conversations list,
  /// and notifies listeners.
  Future<void> deleteConversation(String conversationId) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    try {
      // Save for potential undo
      final conversation = _conversations[index];
      final messages = await _db.getMessagesForConversation(conversationId);
      _lastDeleted = conversation;
      _lastDeletedMessages = messages;

      // Delete from DB (DatabaseHelper.deleteConversation deletes messages first)
      await _db.deleteConversation(conversationId);

      // Remove from in-memory list
      _conversations.removeAt(index);
      notifyListeners();
    } catch (e) {
      debugPrint('ConversationProvider.deleteConversation error: $e');
    }
  }

  /// Re-inserts the last deleted conversation and its messages to DB.
  /// Re-adds to _conversations list, clears _lastDeleted, and notifies listeners.
  Future<void> undoDelete() async {
    if (_lastDeleted == null) return;

    final conversation = _lastDeleted!;
    final messages = _lastDeletedMessages ?? [];

    try {
      await _db.insertConversation(conversation);
      for (final message in messages) {
        await _db.insertMessage(message);
      }

      _conversations.add(conversation);
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      _lastDeleted = null;
      _lastDeletedMessages = null;
      notifyListeners();
    } catch (e) {
      debugPrint('ConversationProvider.undoDelete error: $e');
    }
  }

  /// Updates the conversation title in DB and in the _conversations list.
  Future<void> renameConversation(String conversationId, String newTitle) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    try {
      final updated = _conversations[index].copyWith(
        title: newTitle.trim().isEmpty ? 'Untitled Conversation' : newTitle.trim(),
        updatedAt: DateTime.now(),
      );
      await _db.updateConversation(updated);
      _conversations[index] = updated;
      notifyListeners();
    } catch (e) {
      debugPrint('ConversationProvider.renameConversation error: $e');
    }
  }

  /// Deletes a single message from DB and decrements the conversation's messageCount.
  Future<void> deleteMessage(String messageId, String conversationId) async {
    try {
      await _db.deleteMessage(messageId);

      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        final conversation = _conversations[index];
        final newCount = (conversation.messageCount - 1).clamp(0, conversation.messageCount);
        final updated = conversation.copyWith(messageCount: newCount);
        await _db.updateConversation(updated);
        _conversations[index] = updated;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('ConversationProvider.deleteMessage error: $e');
    }
  }

  /// Loads all messages for the conversation and formats them as a plain-text
  /// export string: "Role: content\n\n" for each message.
  Future<String> getConversationText(String conversationId) async {
    try {
      final messages = await _db.getMessagesForConversation(conversationId);
      final buffer = StringBuffer();

      final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
      if (convIndex != -1) {
        buffer.writeln('MyTinyAI Conversation: ${_conversations[convIndex].title}');
        buffer.writeln('Exported: ${DateTime.now().toLocal()}');
        buffer.writeln('─' * 40);
        buffer.writeln();
      }

      for (final message in messages) {
        final roleLabel = message.role == 'user' ? 'You' : 'Assistant';
        buffer.writeln('$roleLabel: ${message.content}');
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('ConversationProvider.getConversationText error: $e');
      return '';
    }
  }
}