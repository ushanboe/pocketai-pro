// Step 1: Inventory
// This file DEFINES: Conversation class with fields: id, title, modelId, modelName, systemPrompt,
//   temperature, maxTokens, createdAt, updatedAt, messageCount
// Methods: constructor, copyWith, toMap (sqflite), fromMap (sqflite row), toJson, fromJson
// No imports from other project files needed — pure data class
// Uses: dart:convert for json encoding/decoding if needed (actually just Map<String,dynamic> so no dart:convert needed)
//
// Step 2: Connections
// This file is imported by:
//   - database_helper.dart (for table operations)
//   - conversation_provider.dart (for state management)
//   - chat_screen.dart (for displaying conversation info)
//   - conversations_drawer.dart (for listing conversations)
// No navigation in this file — pure data model
//
// Step 3: User Journey Trace
// Pure data class — no user interaction. Used throughout the app for CRUD operations.
// toMap() stores DateTime as ISO8601 string (sqflite doesn't have native DateTime type)
// fromMap() parses ISO8601 string back to DateTime
// copyWith() allows partial updates (e.g., updating title, updatedAt, messageCount)
//
// Step 4: Layout Sanity
// No widgets — pure Dart data class
// DateTime stored as String in SQLite (ISO8601 format)
// double stored as REAL in SQLite
// int stored as INTEGER in SQLite
// String stored as TEXT in SQLite

class Conversation {
  final String id;
  final String title;
  final String modelId;
  final String modelName;
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  const Conversation({
    required this.id,
    required this.title,
    required this.modelId,
    required this.modelName,
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  Conversation copyWith({
    String? id,
    String? title,
    String? modelId,
    String? modelName,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
    );
  }

  /// Converts to a Map suitable for sqflite insertion/update.
  /// DateTime fields are stored as ISO8601 strings.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'modelId': modelId,
      'modelName': modelName,
      'systemPrompt': systemPrompt,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'messageCount': messageCount,
    };
  }

  /// Constructs a Conversation from a sqflite row Map.
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      title: map['title'] as String,
      modelId: map['modelId'] as String,
      modelName: map['modelName'] as String,
      systemPrompt: map['systemPrompt'] as String,
      temperature: (map['temperature'] as num).toDouble(),
      maxTokens: map['maxTokens'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updatedAt'] as String).toLocal(),
      messageCount: map['messageCount'] as int,
    );
  }

  /// Converts to a JSON-compatible Map (identical structure to toMap for this model).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'modelId': modelId,
      'modelName': modelName,
      'systemPrompt': systemPrompt,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'messageCount': messageCount,
    };
  }

  /// Constructs a Conversation from a JSON Map (e.g., decoded from jsonDecode).
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      modelId: json['modelId'] as String,
      modelName: json['modelName'] as String,
      systemPrompt: json['systemPrompt'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      maxTokens: json['maxTokens'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      messageCount: json['messageCount'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Conversation(id: $id, title: $title, modelId: $modelId, '
        'messageCount: $messageCount, updatedAt: $updatedAt)';
  }
}