import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../presentation/screens/root_screen.dart';
import '../state/app_controller.dart';

class GymCaptureApp extends ConsumerWidget {
  const GymCaptureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final lang = state.config.languageCode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppLocalizations.tr(lang, 'appTitle'),
      locale: Locale(lang),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}
