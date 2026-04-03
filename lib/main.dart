// Step 1: Inventory
// This file DEFINES:
//   - main() function: initializes DB, providers, then calls runApp()
//   - MyApp StatelessWidget: wraps MaterialApp in MultiProvider
//
// This file USES from other files:
//   - DatabaseHelper (lib/core/services/database_helper.dart) — .instance.database getter
//   - SettingsProvider (lib/core/providers/settings_provider.dart) — constructor + .init()
//   - ModelProvider (lib/core/providers/model_provider.dart) — constructor + .loadModels()
//   - ConversationProvider (lib/core/providers/conversation_provider.dart) — constructor + .loadConversations()
//   - AppTheme (lib/core/theme/app_theme.dart) — .darkTheme static getter
//   - SplashScreen (lib/features/onboarding/screens/splash_screen.dart) — const constructor
//
// External packages:
//   - flutter/material.dart
//   - provider (MultiProvider, ChangeNotifierProvider)
//
// Step 2: Connections
// - main() creates all providers pre-initialized before runApp()
// - MyApp receives the three providers and SplashScreen as home
// - MultiProvider uses ChangeNotifierProvider.value() with pre-initialized instances
// - MaterialApp uses AppTheme.darkTheme
// - home: SplashScreen() — SplashScreen will read SettingsProvider to decide routing
//
// Step 3: User Journey Trace
// App launches → main() runs:
//   1. WidgetsFlutterBinding.ensureInitialized()
//   2. await DatabaseHelper.instance.database (creates tables)
//   3. settingsProvider = SettingsProvider(); await settingsProvider.init()
//   4. modelProvider = ModelProvider(); await modelProvider.loadModels()
//   5. conversationProvider = ConversationProvider(); await conversationProvider.loadConversations()
//   6. runApp(MyApp(settingsProvider, modelProvider, conversationProvider))
// MyApp builds MultiProvider → MaterialApp → home: SplashScreen()
// SplashScreen reads SettingsProvider.settings.onboardingComplete → routes accordingly
//
// Step 4: Layout Sanity
// No widgets beyond MaterialApp wrapper — all layout is in child screens
// MultiProvider wraps MaterialApp so all screens have access to providers
// Using ChangeNotifierProvider.value() since instances are pre-created in main()
// debugShowCheckedModeBanner: false for production look
// title: 'MyTinyAI'

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pocketai/core/theme/app_theme.dart';
import 'package:pocketai/core/services/database_helper.dart';
import 'package:pocketai/core/providers/settings_provider.dart';
import 'package:pocketai/core/providers/model_provider.dart';
import 'package:pocketai/core/providers/conversation_provider.dart';
import 'package:pocketai/features/onboarding/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database — creates tables before any provider queries them
  await DatabaseHelper.instance.database;

  // Initialize SettingsProvider with SharedPreferences before runApp
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // Initialize ModelProvider — loads model catalog from SharedPreferences
  final modelProvider = ModelProvider();
  await modelProvider.loadModels();

  // Initialize ConversationProvider — pre-loads conversation list from DB
  final conversationProvider = ConversationProvider();
  await conversationProvider.loadConversations();

  runApp(
    MyApp(
      settingsProvider: settingsProvider,
      modelProvider: modelProvider,
      conversationProvider: conversationProvider,
    ),
  );
}

class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;
  final ModelProvider modelProvider;
  final ConversationProvider conversationProvider;

  const MyApp({
    super.key,
    required this.settingsProvider,
    required this.modelProvider,
    required this.conversationProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<ModelProvider>.value(value: modelProvider),
        ChangeNotifierProvider<ConversationProvider>.value(value: conversationProvider),
      ],
      child: MaterialApp(
        title: 'MyTinyAI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}