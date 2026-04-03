// Step 1: Inventory
// This file DEFINES: PromptTemplatesBottomSheet (StatefulWidget + State)
// Fields used from PromptTemplate: id, title, template, category (all exist in the generated model)
// Methods used: PromptTemplate.allTemplates (static getter, exists)
// Imports needed: flutter/material.dart, package:pocketai/core/models/prompt_template.dart
//
// Step 2: Connections
// This widget is shown from ChatScreen via showModalBottomSheet
// onTemplateSelected callback: (String) => void — inserts template text into ChatScreen's _textController
// After selection: Navigator.pop(context) dismisses the sheet
//
// Step 3: User Journey Trace
// User taps template icon in ChatScreen → showModalBottomSheet shows PromptTemplatesBottomSheet
// User sees DraggableScrollableSheet with drag handle, title, 4 category tabs
// User taps a tab (Productivity/Learning/Creative/Code) → TabBarView shows filtered templates
// User taps a template tile → onTemplateSelected(template.template) called → Navigator.pop(context)
// ChatScreen receives callback, sets _textController.text = template text
//
// Step 4: Layout Sanity
// DraggableScrollableSheet provides its own scroll controller — pass to ListView
// TabBar + TabBarView need TabController (TickerProviderStateMixin)
// Column inside Container: DragHandle + Title + TabBar + Expanded(TabBarView) — no unbounded scroll issues
// ListView inside TabBarView gets the scrollController from DraggableScrollableSheet's builder
// Categories: ['Productivity', 'Learning', 'Creative', 'Code'] — 4 tabs, length:4

import 'package:flutter/material.dart';
import 'package:pocketai/core/models/prompt_template.dart';

class PromptTemplatesBottomSheet extends StatefulWidget {
  final void Function(String template) onTemplateSelected;

  const PromptTemplatesBottomSheet({
    super.key,
    required this.onTemplateSelected,
  });

  @override
  State<PromptTemplatesBottomSheet> createState() =>
      _PromptTemplatesBottomSheetState();
}

class _PromptTemplatesBottomSheetState
    extends State<PromptTemplatesBottomSheet>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _categories = [
    'Productivity',
    'Learning',
    'Creative',
    'Code',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<PromptTemplate> _templatesByCategory(String category) {
    return PromptTemplate.allTemplates
        .where((t) => t.category == category)
        .toList();
  }

  Widget _buildTemplateTile(PromptTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        title: Text(
          template.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            template.template,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFF64748B),
        ),
        onTap: () {
          widget.onTemplateSelected(template.template);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Prompt Templates',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              // TabBar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF3B82F6),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF3B82F6),
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Productivity'),
                  Tab(text: 'Learning'),
                  Tab(text: 'Creative'),
                  Tab(text: 'Code'),
                ],
              ),
              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categories.map((category) {
                    final templates = _templatesByCategory(category);
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: templates
                          .map((t) => _buildTemplateTile(t))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}