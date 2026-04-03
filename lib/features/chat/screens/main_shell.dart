// Step 1: Inventory
// This file DEFINES:
//   - MainShell (StatefulWidget)
//   - _MainShellState (State)
//   - State variables: _scaffoldKey (GlobalKey<ScaffoldState>), _selectedIndex (int), _chatKey (GlobalKey<ChatScreenState>)
//   - Methods: _onTabTapped, _onConversationSelected, _onNewConversation, build
//
// This file USES from other files:
//   - ChatScreen (from lib/features/chat/screens/chat_screen.dart):
//     - Constructor: ChatScreen(key: _chatKey, onOpenDrawer: callback)
//     - ChatScreenState public methods: loadConversation(String), startNewConversation()
//   - ConversationsDrawer (from lib/features/chat/widgets/conversations_drawer.dart):
//     - Constructor: ConversationsDrawer(onNewConversation, onConversationSelected, activeConversationId)
//   - ModelsScreen (from lib/features/models/screens/models_screen.dart)
//   - SettingsScreen (from lib/features/settings/screens/settings_screen.dart)
//
// Step 2: Connections
// - MainShell is navigated to from SplashScreen/OnboardingScreen via Navigator.pushReplacement
// - MainShell holds _chatKey to call ChatScreen methods from drawer callbacks
// - _scaffoldKey is used to programmatically open drawer from ChatScreen's AppBar
// - ChatScreen receives onOpenDrawer callback that calls _scaffoldKey.currentState?.openDrawer()
// - ConversationsDrawer receives onConversationSelected and onNewConversation callbacks
// - _onConversationSelected: switches to tab 0, closes drawer, calls _chatKey.currentState?.loadConversation()
// - _onNewConversation: switches to tab 0, closes drawer, calls _chatKey.currentState?.startNewConversation()
//
// Step 3: User Journey Trace
// User arrives at MainShell → sees ChatScreen (index 0) with BottomNavBar
// User taps hamburger in ChatScreen AppBar → _scaffoldKey.currentState?.openDrawer() → drawer slides in
// User taps a conversation in drawer → _onConversationSelected(id) → tab 0 selected, drawer closes,
//   loadConversation(id) called on ChatScreen state
// User taps "New Chat" in drawer → _onNewConversation() → tab 0, drawer closes, startNewConversation()
// User taps Models tab → IndexedStack shows ModelsScreen (index 1)
// User taps Settings tab → IndexedStack shows SettingsScreen (index 2)
// IndexedStack keeps all screens alive (no state loss)
//
// Step 4: Layout Sanity
// Scaffold(key: _scaffoldKey, drawer: ..., body: IndexedStack, bottomNavigationBar: ...)
// No scrollable inside scrollable issues — each tab manages its own scrolling
// BottomNavigationBar type fixed for consistent layout
// IndexedStack children are all Scaffold-based screens — no layout conflicts
// ConversationsDrawer receives _activeConversationId from _chatKey state if available

import 'package:flutter/material.dart';
import 'package:pocketai/features/chat/screens/chat_screen.dart';
import 'package:pocketai/features/chat/widgets/conversations_drawer.dart';
import 'package:pocketai/features/models/screens/models_screen.dart';
import 'package:pocketai/features/settings/screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ChatScreenState> _chatKey = GlobalKey<ChatScreenState>();

  late int _selectedIndex;
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onConversationSelected(String conversationId) {
    setState(() {
      _selectedIndex = 0;
      _activeConversationId = conversationId;
    });
    // Close the drawer
    _scaffoldKey.currentState?.closeDrawer();
    // Load the conversation in ChatScreen via GlobalKey
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatKey.currentState?.loadConversation(conversationId);
    });
  }

  void _onNewConversation() {
    setState(() {
      _selectedIndex = 0;
      _activeConversationId = null;
    });
    // Close the drawer
    _scaffoldKey.currentState?.closeDrawer();
    // Start a new conversation in ChatScreen via GlobalKey
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatKey.currentState?.startNewConversation();
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F172A),
      drawer: ConversationsDrawer(
        onConversationSelected: _onConversationSelected,
        onNewConversation: _onNewConversation,
        activeConversationId: _activeConversationId,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ChatScreen(
            key: _chatKey,
            onOpenDrawer: _openDrawer,
          ),
          const ModelsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color(0xFF334155),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          backgroundColor: const Color(0xFF1E293B),
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: const Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download_outlined),
              activeIcon: Icon(Icons.download),
              label: 'Models',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined),
              activeIcon: Icon(Icons.tune),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}