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

    final videoDevices = state.devices.where((d) => d.type == DeviceType.video).toList();
    final audioDevices = state.devices.where((d) => d.type == DeviceType.audio).toList();
    final selectedVideoValue = _resolveSelectedDevice(cfg.selectedVideoDevice, videoDevices);
    final selectedAudioValue = _resolveSelectedDevice(cfg.selectedAudioDevice, audioDevices);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(AppLocalizations.tr(lang, 'setupTitle')),
            const SizedBox(width: 5),
            Text(AppLocalizations.tr(lang, 'setupVersion'), 
              style:
              TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13)
              ),
            Text(cfg.version,
              style:
              TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13))
            ],
          )
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
            Row(
              children: [
                IntrinsicWidth(
                  child: DropdownButton<CaptureSourceKind>(
                    value: cfg.sourceKind,
                    hint: Text(AppLocalizations.tr(lang, 'captureSource')),
                    items: sourceChoices
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (value) async {
                      await controller.updateConfig(cfg.copyWith(sourceKind: value, clearVideoDevice: true, clearAudioDevice: true));
                    },
                  ),
                ),
              ]
            ),
            const SizedBox(height: 8),
            Row(children: [
              FilledButton(
                onPressed: (cfg.ffmpegPath == null || cfg.sourceKind == null) ? null : controller.detectDevices,
                child: Text(AppLocalizations.tr(lang, 'scanDevices')),
              ),
              const SizedBox(width: 12),
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
                              value: selectedVideoValue,
                              isExpanded: true,
                              hint: Text(AppLocalizations.tr(lang, 'selectedVideoDevices')),
                              items: videoDevices
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
                                    value: selectedAudioValue,
                                    isExpanded: true,
                                    hint: Text(AppLocalizations.tr(lang, 'selectedAudioDevices')),
                                    items: audioDevices
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
            ]),
            const SizedBox(height: 8),
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
                    decoration: InputDecoration(labelText: AppLocalizations.tr(lang, 'bufferMin'), border: const OutlineInputBorder()),
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
                    decoration: InputDecoration(labelText: AppLocalizations.tr(lang, 'preRollSec'), border: const OutlineInputBorder()),
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
                    onChanged: (value) async {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty && trimmed != state.config.ffmpegPreset) {
                        await controller.updateConfig(state.config.copyWith(ffmpegPreset: trimmed));
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
                    onChanged: (value) async {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty && trimmed != state.config.movFlags) {
                        await controller.updateConfig(state.config.copyWith(movFlags: trimmed));
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
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: cfg.isComplete && state.devices.isNotEmpty ? controller.enterWorkMode : null,
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
