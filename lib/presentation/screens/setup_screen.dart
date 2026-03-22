import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/capture_device.dart';
import '../../localization/app_localizations.dart';
import '../../state/app_controller.dart';
import '../widgets/judge_server_status.dart';
import '../widgets/log_panel.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appControllerProvider.notifier).prepareSetupScreen());
  }

  Future<void> _confirmFullReset(
    BuildContext context,
    WidgetRef ref,
    String languageCode,
  ) async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.tr(languageCode, 'fullResetWarningTitle')),
        content: Text(AppLocalizations.tr(languageCode, 'fullResetWarningMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.tr(languageCode, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.tr(languageCode, 'reset')),
          ),
        ],
      ),
    );

    if (shouldReset == true && context.mounted) {
      await ref.read(appControllerProvider.notifier).resetAllSettings();
    }
  }

  Future<void> _confirmAutomaticInstall(
    BuildContext context,
    WidgetRef ref,
    String languageCode,
  ) async {
    final shouldInstall = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.tr(languageCode, 'installAutomaticallyQuestionTitle')),
        content: Text(AppLocalizations.tr(languageCode, 'installAutomaticallyQuestionMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.tr(languageCode, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.tr(languageCode, 'installAutomatically')),
          ),
        ],
      ),
    );

    if (shouldInstall == true && context.mounted) {
      await ref.read(appControllerProvider.notifier).installFfmpeg();
    }
  }

  double? _parseSecondsValue(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final cfg = state.config;
    final lang = cfg.languageCode;

    final sourceChoices = <CaptureSourceKind>[
      if (Platform.isMacOS) CaptureSourceKind.avFoundation,
      if (Platform.isWindows) CaptureSourceKind.directShow,
      CaptureSourceKind.deckLink,
    ];

    final codecOptions = Platform.isMacOS
        ? const ['h264_videotoolbox', 'hevc_videotoolbox', 'libx264']
        : const ['libx264', 'h264_nvenc', 'hevc_nvenc', 'h264_qsv', 'hevc_qsv', 'h264_amf', 'hevc_amf'];

    final videoDevices = state.devices.where((d) => d.type == DeviceType.video).toList();
    final audioDevices = state.devices.where((d) => d.type == DeviceType.audio).toList();
    final selectedVideoValue = _resolveSelectedDevice(cfg.selectedVideoDevice, videoDevices);
    final selectedAudioValue = _resolveSelectedDevice(cfg.selectedAudioDevice, audioDevices);

    final subtleActionStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.grey.shade700,
      side: BorderSide(color: Colors.grey.shade400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5,
                runSpacing: 6,
                children: [
                  Text(AppLocalizations.tr(lang, 'setupTitle')),
                  Text(
                    AppLocalizations.tr(lang, 'setupVersion'),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Text(
                    cfg.version,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  JudgeServerStatusIndicator(
                    languageCode: lang,
                    status: state.judgeWebServerStatus,
                    isSetupMode: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: AppLocalizations.tr(lang, 'continueToWork'),
              child: IconButton(
                onPressed: cfg.isComplete && state.devices.isNotEmpty ? controller.enterWorkMode : null,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${AppLocalizations.tr(lang, 'language')}: '),
                DropdownButton<String>(
                  value: cfg.languageCode,
                  items: AppLocalizations.supportedLanguages
                      .map((code) => DropdownMenuItem(value: code, child: Text(code.toUpperCase())))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      controller.setLanguage(value);
                    }
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select output folder');
                    if (path != null) {
                      await controller.updateConfig(cfg.copyWith(outputDir: path));
                    }
                  },
                  child: Text(AppLocalizations.tr(lang, 'chooseOutputFolder')),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final path = await FilePicker.platform.pickFiles(dialogTitle: 'Pick ffmpeg binary').then((v) => v?.files.single.path);
                    if (path != null) {
                      await controller.updateConfig(cfg.copyWith(ffmpegPath: path));
                    }
                  },
                  child: Text(AppLocalizations.tr(lang, 'pickFfmpeg')),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final path = await FilePicker.platform.pickFiles(dialogTitle: 'Pick ffplay binary').then((v) => v?.files.single.path);
                    if (path != null) {
                      await controller.updateConfig(cfg.copyWith(ffplayPath: path));
                    }
                  },
                  child: Text(AppLocalizations.tr(lang, 'pickFfplay')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('ffmpeg: ${cfg.ffmpegPath ?? AppLocalizations.tr(lang, 'notSelected')}'),
            Text('ffplay: ${cfg.ffplayPath ?? AppLocalizations.tr(lang, 'notSelected')}'),
            const SizedBox(height: 8),
            Text('${AppLocalizations.tr(lang, 'outputFolder')}: ${cfg.outputDir ?? AppLocalizations.tr(lang, 'notSelected')}'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.tr(lang, 'captureSetupSectionTitle'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.tr(lang, 'captureSetupSectionHint'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 255,
                        child: _buildSelectorCard(
                          context: context,
                          title: AppLocalizations.tr(lang, 'captureSource'),
                          description: AppLocalizations.tr(lang, 'captureSourceHelp'),
                          child: DropdownButtonFormField<CaptureSourceKind>(
                            value: cfg.sourceKind,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.tr(lang, 'captureSourceLabel'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: sourceChoices
                                .map((source) => DropdownMenuItem(
                                      value: source,
                                      child: Text(_sourceLabel(lang, source)),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              await controller.updateConfig(
                                cfg.copyWith(
                                  sourceKind: value,
                                  clearVideoDevice: true,
                                  clearAudioDevice: true,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 255,
                        child: _buildSelectorCard(
                          context: context,
                          title: AppLocalizations.tr(lang, 'selectedVideoDevices'),
                          description: AppLocalizations.tr(lang, 'videoDeviceHelp'),
                          child: DropdownButtonFormField<CaptureDevice>(
                            value: selectedVideoValue,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.tr(lang, 'detectedVideoDevices'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: videoDevices
                                .map((device) => DropdownMenuItem(
                                      value: device,
                                      child: Text(device.displayLabel, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                await controller.updateConfig(cfg.copyWith(selectedVideoDevice: value));
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 255,
                        child: _buildSelectorCard(
                          context: context,
                          title: AppLocalizations.tr(lang, 'selectedAudioDevices'),
                          description: AppLocalizations.tr(lang, 'audioDeviceHelp'),
                          child: DropdownButtonFormField<CaptureDevice>(
                            value: selectedAudioValue,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.tr(lang, 'detectedAudioDevices'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: audioDevices
                                .map((device) => DropdownMenuItem(
                                      value: device,
                                      child: Text(device.displayLabel, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                await controller.updateConfig(cfg.copyWith(selectedAudioDevice: value));
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 255,
                        child: _buildSelectorCard(
                          context: context,
                          title: AppLocalizations.tr(lang, 'codec'),
                          description: AppLocalizations.tr(lang, 'codecHelp'),
                          child: DropdownButtonFormField<String>(
                            value: cfg.codec,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.tr(lang, 'codecLabel'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: codecOptions
                                .map((codec) => DropdownMenuItem(value: codec, child: Text(codec)))
                                .toList(),
                            onChanged: (value) async {
                              await controller.updateConfig(cfg.copyWith(codec: value));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: (cfg.ffmpegPath == null || cfg.sourceKind == null) ? null : controller.detectDevices,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(AppLocalizations.tr(lang, 'scanDevices')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    initialValue: '${cfg.fps}',
                    decoration: const InputDecoration(labelText: 'FPS', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) async {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0 && parsed != state.config.fps) {
                        await controller.updateConfig(state.config.copyWith(fps: parsed));
                      }
                    },
                    onFieldSubmitted: (value) async {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        await controller.updateConfig(state.config.copyWith(fps: parsed));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: '${cfg.segmentSeconds}',
                    decoration: const InputDecoration(labelText: 'Segment sec', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (value) async {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        await controller.updateConfig(cfg.copyWith(segmentSeconds: parsed));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: '${cfg.bufferMinutes}',
                    decoration: InputDecoration(
                      labelText: AppLocalizations.tr(lang, 'bufferMin'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (value) async {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        await controller.updateConfig(cfg.copyWith(bufferMinutes: parsed));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: '${cfg.preRollSeconds}',
                    decoration: InputDecoration(
                      labelText: AppLocalizations.tr(lang, 'preRollSec'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (value) async {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed >= 0) {
                        await controller.updateConfig(cfg.copyWith(preRollSeconds: parsed));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: (cfg.recordingStartTrimMillis / 1000).toStringAsFixed(1),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.tr(lang, 'recordingStartTrimSec'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onFieldSubmitted: (value) async {
                      final parsed = _parseSecondsValue(value);
                      if (parsed != null && parsed >= 0) {
                        await controller.updateConfig(
                          cfg.copyWith(recordingStartTrimMillis: (parsed * 1000).round()),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: cfg.videoBitrate,
                    decoration: const InputDecoration(labelText: 'Video bitrate', border: OutlineInputBorder()),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) async {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty && trimmed != state.config.videoBitrate) {
                        await controller.updateConfig(state.config.copyWith(videoBitrate: trimmed));
                      }
                    },
                    onFieldSubmitted: (value) async {
                      if (value.trim().isNotEmpty) {
                        await controller.updateConfig(state.config.copyWith(videoBitrate: value.trim()));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: cfg.audioBitrate,
                    decoration: const InputDecoration(labelText: 'Audio bitrate', border: OutlineInputBorder()),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) async {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty && trimmed != state.config.audioBitrate) {
                        await controller.updateConfig(state.config.copyWith(audioBitrate: trimmed));
                      }
                    },
                    onFieldSubmitted: (value) async {
                      if (value.trim().isNotEmpty) {
                        await controller.updateConfig(state.config.copyWith(audioBitrate: value.trim()));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: cfg.ffmpegPreset,
                    decoration: const InputDecoration(labelText: 'FFmpeg preset', border: OutlineInputBorder()),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty && trimmed != state.config.ffmpegPreset) {
                        controller.updateConfigDebounced(state.config.copyWith(ffmpegPreset: trimmed));
                      }
                    },
                    onFieldSubmitted: (value) async {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty) {
                        await controller.updateConfig(state.config.copyWith(ffmpegPreset: trimmed));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: cfg.movFlags,
                    decoration: const InputDecoration(labelText: 'movflags', border: OutlineInputBorder()),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty && trimmed != state.config.movFlags) {
                        controller.updateConfigDebounced(state.config.copyWith(movFlags: trimmed));
                      }
                    },
                    onFieldSubmitted: (value) async {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty) {
                        await controller.updateConfig(state.config.copyWith(movFlags: trimmed));
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    initialValue: '${cfg.webServerPort}',
                    decoration: InputDecoration(
                      labelText: AppLocalizations.tr(lang, 'judgeWebPort'),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (value) async {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed >= 1024 && parsed <= 65535) {
                        await controller.updateConfig(cfg.copyWith(webServerPort: parsed));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: subtleActionStyle,
                  onPressed: state.isLoading ? null : () => _confirmAutomaticInstall(context, ref, lang),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(AppLocalizations.tr(lang, 'installAutomatically')),
                ),
                OutlinedButton.icon(
                  style: subtleActionStyle,
                  onPressed: (state.isLoading ||
                          cfg.ffplayPath == null ||
                          cfg.ffmpegPath == null ||
                          cfg.sourceKind == null ||
                          cfg.selectedVideoDevice == null ||
                          cfg.selectedAudioDevice == null)
                      ? null
                      : controller.togglePreview,
                  icon: Icon(state.isPreviewRunning ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  label: Text(
                    AppLocalizations.tr(lang, state.isPreviewRunning ? 'stopPreview' : 'startPreview'),
                  ),
                ),
                OutlinedButton.icon(
                  style: subtleActionStyle,
                  onPressed: (state.isLoading ||
                          cfg.ffmpegPath == null ||
                          cfg.outputDir == null ||
                          cfg.sourceKind == null ||
                          cfg.selectedVideoDevice == null ||
                          cfg.selectedAudioDevice == null)
                      ? null
                      : controller.toggleTestRecording,
                  icon: Icon(state.isTestRecording ? Icons.stop_circle_outlined : Icons.fiber_manual_record_rounded),
                  label: Text(
                    AppLocalizations.tr(lang, state.isTestRecording ? 'stopTestRecording' : 'startTestRecording'),
                  ),
                ),
                OutlinedButton.icon(
                  style: subtleActionStyle.copyWith(
                    foregroundColor: WidgetStatePropertyAll(Colors.red.shade400),
                    side: WidgetStatePropertyAll(BorderSide(color: Colors.red.shade200)),
                  ),
                  onPressed: state.isLoading ? null : () => _confirmFullReset(context, ref, lang),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: Text(AppLocalizations.tr(lang, 'fullResetSettings')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: LogPanel(logs: state.logs)),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorCard({
    required BuildContext context,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  String _sourceLabel(String languageCode, CaptureSourceKind kind) {
    switch (kind) {
      case CaptureSourceKind.avFoundation:
        return AppLocalizations.tr(languageCode, 'sourceTypeAvFoundation');
      case CaptureSourceKind.directShow:
        return AppLocalizations.tr(languageCode, 'sourceTypeDirectShow');
      case CaptureSourceKind.deckLink:
        return AppLocalizations.tr(languageCode, 'sourceTypeDeckLink');
    }
  }
}

CaptureDevice? _resolveSelectedDevice(
  CaptureDevice? selectedDevice,
  List<CaptureDevice> availableDevices,
) {
  if (selectedDevice == null) {
    return null;
  }

  for (final device in availableDevices) {
    if (device.id == selectedDevice.id && device.type == selectedDevice.type) {
      return device;
    }
  }

  return null;
}
