import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../localization/app_localizations.dart';
import '../presentation/screens/root_screen.dart';
import '../state/app_controller.dart';

class GymCaptureApp extends ConsumerStatefulWidget {
  const GymCaptureApp({super.key});

  @override
  ConsumerState<GymCaptureApp> createState() => _GymCaptureAppState();
}

class _GymCaptureAppState extends ConsumerState<GymCaptureApp> with WindowListener {
  bool _isClosing = false;
  bool _allowWindowClose = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await windowManager.setPreventClose(true);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_allowWindowClose) {
      return;
    }

    if (_isClosing) {
      return;
    }

    _isClosing = true;
    try {
      await ref.read(appControllerProvider.notifier).shutdown().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Shutdown timed out. Forcing window close.');
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Shutdown failed during window close: $error');
      debugPrint('$stackTrace');
    } finally {
      _allowWindowClose = true;
      await windowManager.setPreventClose(false);
      await windowManager.close();
      _isClosing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final lang = state.config.languageCode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppLocalizations.tr(lang, 'appTitle'),
      locale: Locale(lang),
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      home: const RootScreen(),
    );
  }
}
