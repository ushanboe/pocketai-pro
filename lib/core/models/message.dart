// Step 1: Inventory
// This file DEFINES: Message class with fields:
//   - id: String (UUID v4)
//   - conversationId: String (FK to Conversation.id)
//   - role: String ('user' or 'assistant')
//   - content: String (full message text)
//   - timestamp: DateTime (UTC)
//   - tokenCount: int (estimated via content.split(' ').length * 1.3)
//   - generationTimeMs: int (ms to generate, 0 for user messages)
// Methods: constructor, copyWith, toMap, fromMap, toJson, fromJson
// Also: equality, hashCode, toString overrides
//
// This file uses: NO imports from other project files — pure data class
// Imports needed: none beyond dart core (no dart:convert needed since we return Map<String,dynamic>)
//
// Step 2: Connections
// Imported by: database_helper.dart, conversation_provider.dart, chat_screen.dart
// No navigation — pure data model
// toMap/fromMap used by sqflite (DateTime as ISO8601 string)
// toJson/fromJson used for serialization (same structure)
//
// Step 3: User Journey Trace
// Pure data class — no user interaction
// tokenCount computed as (content.split(' ').length * 1.3).round() approximation
// generationTimeMs is 0 for user messages, actual ms for assistant messages
// DateTime stored as UTC ISO8601 string in SQLite
//
// Step 4: Layout Sanity
// No widgets — pure Dart data class
// Follow exact same pattern as Conversation model already generated
// DateTime stored as ISO8601 string (toUtc().toIso8601String())
// DateTime parsed back with DateTime.parse(...).toLocal()
// int fields cast directly, num fields use .toDouble() if needed

class Message {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final DateTime timestamp;
  final int tokenCount;
  final int generationTimeMs;

  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.tokenCount,
    required this.generationTimeMs,
  });

  /// Creates a copy of this Message with the given fields replaced.
  Message copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    DateTime? timestamp,
    int? tokenCount,
    int? generationTimeMs,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      tokenCount: tokenCount ?? this.tokenCount,
      generationTimeMs: generationTimeMs ?? this.generationTimeMs,
    );
  }

  /// Converts to a Map suitable for sqflite insertion/update.
  /// DateTime is stored as UTC ISO8601 string.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'tokenCount': tokenCount,
      'generationTimeMs': generationTimeMs,
    };
  }

  /// Constructs a Message from a sqflite row Map.
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversationId'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String).toLocal(),
      tokenCount: map['tokenCount'] as int,
      generationTimeMs: map['generationTimeMs'] as int,
    );
  }

  /// Converts to a JSON-compatible Map (identical structure to toMap for this model).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'tokenCount': tokenCount,
      'generationTimeMs': generationTimeMs,
    };
  }

  /// Constructs a Message from a JSON Map (e.g., decoded from jsonDecode).
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      tokenCount: json['tokenCount'] as int,
      generationTimeMs: json['generationTimeMs'] as int,
    );
  }

  /// Estimates token count from content using word-count approximation.
  /// Uses content.split(' ').length * 1.3 as a rough token estimate.
  static int estimateTokenCount(String content) {
    final wordCount = content.trim().isEmpty
        ? 0
        : content.trim().split(RegExp(r'\s+')).length;
    return (wordCount * 1.3).round();
  }

  /// Returns true if this message is from the user role.
  bool get isUser => role == 'user';

  /// Returns true if this message is from the assistant role.
  bool get isAssistant => role == 'assistant';

  /// Returns the generation speed in tokens per second, or 0 if not applicable.
  double get tokensPerSecond {
    if (generationTimeMs <= 0 || !isAssistant) return 0.0;
    return tokenCount / (generationTimeMs / 1000.0);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Message(id: $id, conversationId: $conversationId, role: $role, '
        'tokenCount: $tokenCount, generationTimeMs: $generationTimeMs, '
        'timestamp: $timestamp)';
  }
}