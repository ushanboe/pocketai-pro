// Step 1: Inventory
// This file DEFINES: DatabaseHelper singleton class with:
//   - Private constructor + singleton pattern via static instance
//   - _database field (Database?)
//   - database getter (lazy initialization)
//   - _initDatabase() private method
//   - _onCreate() private method (creates tables + indexes)
//   - insertConversation(Conversation) → Future<void>
//   - getAllConversations() → Future<List<Conversation>>
//   - updateConversation(Conversation) → Future<void>
//   - deleteConversation(String conversationId) → Future<void>
//   - insertMessage(Message) → Future<void>
//   - getMessagesForConversation(String conversationId) → Future<List<Message>>
//   - deleteMessage(String messageId) → Future<void>
//
// This file USES from other files:
//   - Conversation (from lib/core/models/conversation.dart) — toMap(), fromMap()
//   - Message (from lib/core/models/message.dart) — toMap(), fromMap()
//
// External packages used:
//   - sqflite (Database, openDatabase, getDatabasesPath)
//   - path (join)
//
// Step 2: Connections
// This file is imported by:
//   - conversation_provider.dart: ConversationProvider.DatabaseHelper.instance for all CRUD
//   - main.dart: await DatabaseHelper.instance.database to init before runApp()
//
// Table schema from spec:
//   conversations: id TEXT PK, title TEXT, modelId TEXT, modelName TEXT, systemPrompt TEXT,
//     temperature REAL, maxTokens INTEGER, createdAt TEXT, updatedAt TEXT, messageCount INTEGER
//   messages: id TEXT PK, conversationId TEXT FK, role TEXT, content TEXT, timestamp TEXT,
//     tokenCount INTEGER, generationTimeMs INTEGER
//   Indexes: messages(conversationId), conversations(updatedAt)
//
// Step 3: User Journey Trace
// 1. main() calls await DatabaseHelper.instance.database → triggers _initDatabase() → creates tables
// 2. ConversationProvider.loadConversations() → DatabaseHelper.instance.getAllConversations()
// 3. ConversationProvider.createConversation() → DatabaseHelper.instance.insertConversation()
// 4. ConversationProvider.addMessage() → DatabaseHelper.instance.insertMessage()
//    + DatabaseHelper.instance.updateConversation() for updatedAt/messageCount
// 5. ConversationProvider.getMessages() → DatabaseHelper.instance.getMessagesForConversation()
// 6. ConversationProvider.deleteConversation() → DatabaseHelper.instance.deleteConversation()
//    (cascade deletes messages too)
// 7. ConversationProvider.deleteMessage() → DatabaseHelper.instance.deleteMessage()
// 8. ConversationProvider.undoDelete() → insertConversation() + insertMessage() for each
//
// Step 4: Layout Sanity
// No widgets — pure service class
// Use getDatabasesPath() + join() for cross-platform path
// Version 1 database, _onCreate creates both tables
// CASCADE delete on messages when conversation deleted (via SQL trigger or manual delete)
// Since sqflite doesn't auto-cascade, deleteConversation deletes messages first then conversation
// Column names must match exactly what Conversation.toMap() and Message.toMap() produce:
//   Conversation.toMap() keys: id, title, modelId, modelName, systemPrompt, temperature, maxTokens, createdAt, updatedAt, messageCount
//   Message.toMap() keys: id, conversationId, role, content, timestamp, tokenCount, generationTimeMs

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pocketai/core/models/conversation.dart';
import 'package:pocketai/core/models/message.dart';

class DatabaseHelper {
  static const String _databaseName = 'pocketai.db';
  static const int _databaseVersion = 1;

  static const String _conversationsTable = 'conversations';
  static const String _messagesTable = 'messages';

  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create conversations table
    await db.execute('''
      CREATE TABLE $_conversationsTable (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        modelId TEXT NOT NULL,
        modelName TEXT NOT NULL,
        systemPrompt TEXT NOT NULL,
        temperature REAL NOT NULL,
        maxTokens INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        messageCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create messages table
    await db.execute('''
      CREATE TABLE $_messagesTable (
        id TEXT PRIMARY KEY NOT NULL,
        conversationId TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        tokenCount INTEGER NOT NULL DEFAULT 0,
        generationTimeMs INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (conversationId) REFERENCES $_conversationsTable(id)
      )
    ''');

    // Index on messages.conversationId for fast lookups
    await db.execute('''
      CREATE INDEX idx_messages_conversation_id
      ON $_messagesTable (conversationId)
    ''');

    // Index on conversations.updatedAt for sorting by most recent
    await db.execute('''
      CREATE INDEX idx_conversations_updated_at
      ON $_conversationsTable (updatedAt)
    ''');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Conversation CRUD
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> insertConversation(Conversation conversation) async {
    final db = await database;
    await db.insert(
      _conversationsTable,
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Conversation>> getAllConversations() async {
    final db = await database;
    final rows = await db.query(
      _conversationsTable,
      orderBy: 'updatedAt DESC',
    );
    return rows.map((row) => Conversation.fromMap(row)).toList();
  }

  Future<void> updateConversation(Conversation conversation) async {
    final db = await database;
    await db.update(
      _conversationsTable,
      conversation.toMap(),
      where: 'id = ?',
      whereArgs: [conversation.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    // Delete all messages for this conversation first (manual cascade)
    await db.delete(
      _messagesTable,
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
    // Then delete the conversation itself
    await db.delete(
      _conversationsTable,
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Message CRUD
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      _messagesTable,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessagesForConversation(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      _messagesTable,
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((row) => Message.fromMap(row)).toList();
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete(
      _messagesTable,
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Utility
  // ─────────────────────────────────────────────────────────────────────────────

  /// Closes the database connection. Call during app teardown if needed.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}