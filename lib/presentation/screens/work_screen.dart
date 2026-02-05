import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';
import '../../state/app_controller.dart';
import '../widgets/log_panel.dart';
import '../widgets/schedule_list.dart';

class WorkScreen extends ConsumerWidget {
  const WorkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final lang = state.config.languageCode;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _MoveUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _MoveDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyS): const _StartIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyX): const _StopIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyD): const _PostponeIntent(),
      },
      child: Actions(
        actions: {
          _MoveUpIntent: CallbackAction<_MoveUpIntent>(onInvoke: (_) => controller.selectPrevious()),
          _MoveDownIntent: CallbackAction<_MoveDownIntent>(onInvoke: (_) => controller.selectNext()),
          _StartIntent: CallbackAction<_StartIntent>(onInvoke: (_) => controller.startMark()),
          _StopIntent: CallbackAction<_StopIntent>(onInvoke: (_) => controller.stopMark()),
          _PostponeIntent: CallbackAction<_PostponeIntent>(onInvoke: (_) => controller.postpone()),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.tr(lang, 'workTitle')),
              actions: [
                PopupMenuButton<String>(
                  tooltip: AppLocalizations.tr(lang, 'language'),
                  onSelected: controller.setLanguage,
                  itemBuilder: (context) => AppLocalizations.supportedLanguages
                      .map((code) => PopupMenuItem<String>(value: code, child: Text(code.toUpperCase())))
                      .toList(),
                  icon: const Icon(Icons.language),
                ),
                IconButton(
                  tooltip: AppLocalizations.tr(lang, 'loadSchedule'),
                  onPressed: controller.loadSchedule,
                  icon: const Icon(Icons.upload_file),
                ),
                IconButton(
                  tooltip: state.isPreviewRunning ? AppLocalizations.tr(lang, 'stopPreview') : AppLocalizations.tr(lang, 'startPreview'),
                  onPressed: controller.togglePreview,
                  icon: Icon(state.isPreviewRunning ? Icons.visibility_off : Icons.visibility),
                ),
                IconButton(
                  tooltip: AppLocalizations.tr(lang, 'backToSetup'),
                  onPressed: controller.backToSetup,
                  icon: const Icon(Icons.settings),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      FilledButton(onPressed: controller.startMark, child: Text(AppLocalizations.tr(lang, 'startHotkey'))),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: controller.stopMark, child: Text(AppLocalizations.tr(lang, 'stopHotkey'))),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: controller.postpone, child: Text(AppLocalizations.tr(lang, 'postponeHotkey'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ScheduleList(
                      items: state.schedule,
                      selectedIndex: state.selectedIndex,
                      onSelect: controller.selectIndex,
                      languageCode: lang,
                    ),
                  ),
                  LogPanel(logs: state.logs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveUpIntent extends Intent {
  const _MoveUpIntent();
}

class _MoveDownIntent extends Intent {
  const _MoveDownIntent();
}

class _StartIntent extends Intent {
  const _StartIntent();
}

class _StopIntent extends Intent {
  const _StopIntent();
}

class _PostponeIntent extends Intent {
  const _PostponeIntent();
}
