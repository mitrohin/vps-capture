import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/capture_device.dart';
import '../../localization/app_localizations.dart';
import '../../state/app_controller.dart';
import '../widgets/log_panel.dart';

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.tr(lang, 'setupTitle'))),
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
            Wrap(spacing: 12, runSpacing: 8, children: [
              FilledButton(
                onPressed: state.isLoading ? null : controller.installFfmpeg,
                child: Text(AppLocalizations.tr(lang, 'installAutomatically')),
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
              OutlinedButton(
                onPressed: state.config.ffplayPath == null ? null : controller.togglePreview,
                child: Text(state.isPreviewRunning ? AppLocalizations.tr(lang, 'stopPreview') : AppLocalizations.tr(lang, 'startPreview')),
              ),
            ]),
            const SizedBox(height: 12),
            Text('ffmpeg: ${cfg.ffmpegPath ?? AppLocalizations.tr(lang, 'notSelected')}'),
            Text('ffplay: ${cfg.ffplayPath ?? AppLocalizations.tr(lang, 'notSelected')}'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('${AppLocalizations.tr(lang, 'outputFolder')}: ${cfg.outputDir ?? AppLocalizations.tr(lang, 'notSelected')}')),
              OutlinedButton(
                onPressed: () async {
                  final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select output folder');
                  if (path != null) {
                    await controller.updateConfig(cfg.copyWith(outputDir: path));
                  }
                },
                child: Text(AppLocalizations.tr(lang, 'chooseOutputFolder')),
              ),
            ]),
            const SizedBox(height: 8),
            DropdownButton<CaptureSourceKind>(
              value: cfg.sourceKind,
              hint: Text(AppLocalizations.tr(lang, 'captureSource')),
              items: sourceChoices
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (value) async {
                await controller.updateConfig(cfg.copyWith(sourceKind: value, clearVideoDevice: true, clearAudioDevice: true));
              },
            ),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton(
                onPressed: (cfg.ffmpegPath == null || cfg.sourceKind == null) ? null : controller.detectDevices,
                child: Text(AppLocalizations.tr(lang, 'scanDevices')),
              ),
              const SizedBox(width: 12),
              if (state.devices.isNotEmpty)
                Expanded(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLocalizations.tr(lang, 'detectedVideoDevices')),
                                const SizedBox(height: 4),
                                DropdownButton<CaptureDevice>(
                                value: cfg.selectedVideoDevice,
                                isExpanded: true,
                                hint: Text(AppLocalizations.tr(lang, 'selectedVideoDevices')),
                                items: state.devices
                                    .where((d) => d.type == DeviceType.video)
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d.displayLabel)))
                                    .toList(),
                                onChanged: (value) async {
                                  if (value != null) {
                                    await controller.updateConfig(cfg.copyWith(selectedVideoDevice: value));
                                  }
                                },
                              ),
                              ],
                          ), 
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(AppLocalizations.tr(lang, 'detectedAudioDevices')),
                                      const SizedBox(height: 4),
                                      DropdownButton<CaptureDevice>(
                                      value: cfg.selectedAudioDevice,
                                      isExpanded: true,
                                      hint: Text(AppLocalizations.tr(lang, 'selectedAudioDevices')),
                                      items: state.devices
                                          .where((d) => d.type == DeviceType.audio)
                                          .map((d) => DropdownMenuItem(value: d, child: Text(d.displayLabel)))
                                          .toList(),
                                      onChanged: (value) async {
                                        if (value != null) {
                                          await controller.updateConfig(cfg.copyWith(selectedAudioDevice: value));
                                        }
                                      },
                                    ),
                                  ],
                              ),
                        ),
                      ]
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              DropdownButton<String>(
                value: cfg.codec,
                hint: Text(AppLocalizations.tr(lang, 'codec')),
                items: codecOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (value) async {
                  await controller.updateConfig(cfg.copyWith(codec: value));
                },
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: '${cfg.bufferMinutes}',
                  decoration: InputDecoration(labelText: AppLocalizations.tr(lang, 'bufferMin')),
                  onChanged: (v) async {
                    final n = int.tryParse(v);
                    if (n != null) await controller.updateConfig(cfg.copyWith(bufferMinutes: n));
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: '${cfg.preRollSeconds}',
                  decoration: InputDecoration(labelText: AppLocalizations.tr(lang, 'preRollSec')),
                  onChanged: (v) async {
                    final n = int.tryParse(v);
                    if (n != null) await controller.updateConfig(cfg.copyWith(preRollSeconds: n));
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: cfg.isComplete ? controller.enterWorkMode : null,
              child: Text(AppLocalizations.tr(lang, 'continueToWork')),
            ),
            const SizedBox(height: 12),
            Expanded(child: LogPanel(logs: state.logs)),
          ],
        ),
      ),
    );
  }
}
