import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations.dart';
import '../../state/app_controller.dart';
import '../widgets/log_panel.dart';
import '../widgets/schedule_list.dart';

class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  late final TextEditingController _scheduleInputController;

  @override
  void initState() {
    super.initState();
    _scheduleInputController = TextEditingController();
  }

  @override
  void dispose() {
    _scheduleInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  TextField(
                    controller: _scheduleInputController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: AppLocalizations.tr(lang, 'scheduleEditorLabel'),
                      hintText: AppLocalizations.tr(lang, 'scheduleEditorHint'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => controller.applySchedule(_scheduleInputController.text),
                      icon: const Icon(Icons.playlist_add_check),
                      label: Text(AppLocalizations.tr(lang, 'applySchedule')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ScheduleList(
                      items: state.schedule,
                      selectedIndex: state.selectedIndex,
                      onSelect: controller.selectIndex,
                      onStart: controller.startMark,
                      onStop: controller.stopMark,
                      onPostpone: controller.postpone,
                      onRestore: controller.restoreItem,
                      isRecordingMarked: state.isRecordingMarked,
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
