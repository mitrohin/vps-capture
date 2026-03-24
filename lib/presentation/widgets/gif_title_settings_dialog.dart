import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/config_services.dart';
import '../../domain/models/gif_title_theme.dart';
import '../../localization/app_localizations.dart';
import '../../state/app_controller.dart';

class GifTitleSettingsDialog extends ConsumerStatefulWidget {
  const GifTitleSettingsDialog({
    super.key,
    required this.languageCode,
    required this.initialGifKey,
    required this.onRunTest,
  });

  final String languageCode;
  final String initialGifKey;
  final ValueChanged<String> onRunTest;

  @override
  ConsumerState<GifTitleSettingsDialog> createState() => _GifTitleSettingsDialogState();
}

class _GifTitleSettingsDialogState extends ConsumerState<GifTitleSettingsDialog> {
  static const List<Color> _presetColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
  ];

  late String _selectedGifKey;
  late final TextEditingController _fioColorController;
  late final TextEditingController _cityColorController;

  @override
  void initState() {
    super.initState();
    _selectedGifKey = widget.initialGifKey;
    final theme = _selectedTheme;
    _fioColorController = TextEditingController(text: _formatColor(theme.fioColor));
    _cityColorController = TextEditingController(text: _formatColor(theme.cityColor));
  }

  GifTitleTheme get _selectedTheme {
    final themes = ref.read(appControllerProvider).config.resolvedGifTitleThemes;
    return themes[_selectedGifKey] ?? ConfigService.defaultTitleThemes[_selectedGifKey]!;
  }

  @override
  void dispose() {
    _fioColorController.dispose();
    _cityColorController.dispose();
    super.dispose();
  }

  String _formatColor(Color color) {
    final value = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#$value';
  }

  Color? _parseColor(String value) {
    final normalized = value.replaceAll('#', '').trim();
    if (normalized.length != 6 && normalized.length != 8) {
      return null;
    }
    final parsed = int.tryParse(normalized.length == 6 ? 'FF$normalized' : normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  void _syncColorControllers(GifTitleTheme theme) {
    _fioColorController.text = _formatColor(theme.fioColor);
    _cityColorController.text = _formatColor(theme.cityColor);
  }

  Future<void> _updateTheme(GifTitleTheme Function(GifTitleTheme theme) update) async {
    await ref.read(appControllerProvider.notifier).updateGifTitleTheme(_selectedGifKey, update);
    if (!mounted) {
      return;
    }
    _syncColorControllers(_selectedTheme);
    setState(() {});
  }

  Future<void> _applyColor({required bool isFio, required String rawValue}) async {
    final color = _parseColor(rawValue);
    if (color == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.tr(widget.languageCode, 'gifTitleColorInvalid'))),
      );
      return;
    }

    await _updateTheme(
      (theme) => isFio ? theme.copyWith(fioColor: color) : theme.copyWith(cityColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageCode;
    final currentTheme = ref.watch(
      appControllerProvider.select(
        (state) => state.config.resolvedGifTitleThemes[_selectedGifKey] ?? ConfigService.defaultTitleThemes[_selectedGifKey]!,
      ),
    );

    return Dialog(
      alignment: const Alignment(0, -0.92),
      insetPadding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.sizeOf(context).height - 40,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.tr(lang, 'gifTitleSettingsTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: AppLocalizations.tr(lang, 'close'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.tr(lang, 'gifTitleSettingsHint'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGifKey,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr(lang, 'gifTitleTemplateLabel'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ConfigService.defaultTitleThemes.keys
                      .map((gifKey) => DropdownMenuItem<String>(value: gifKey, child: Text(gifKey)))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedGifKey = value;
                      _syncColorControllers(_selectedTheme);
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildEditors(context, currentTheme, lang),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await ref.read(appControllerProvider.notifier).resetGifTitleTheme(_selectedGifKey);
                        if (!mounted) {
                          return;
                        }
                        _syncColorControllers(_selectedTheme);
                        setState(() {});
                      },
                      child: Text(AppLocalizations.tr(lang, 'gifTitleResetCurrent')),
                    ),
                    FilledButton.tonal(
                      onPressed: () => widget.onRunTest(_selectedGifKey),
                      child: Text(AppLocalizations.tr(lang, 'gifTitleRunTest')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppLocalizations.tr(lang, 'close')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditors(BuildContext context, GifTitleTheme currentTheme, String lang) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;
        final fioEditor = _EditorSection(
          title: AppLocalizations.tr(lang, 'gifTitleNameSection'),
          fontScale: currentTheme.fioFontScale,
          horizontalPosition: currentTheme.fioLeft,
          verticalPosition: currentTheme.fioBottom,
          min: 0.08,
          max: 0.24,
          divisions: 16,
          sizeLabel: AppLocalizations.tr(lang, 'gifTitleTextSize'),
          colorLabel: AppLocalizations.tr(lang, 'gifTitleTextColor'),
          horizontalLabel: AppLocalizations.tr(lang, 'gifTitleHorizontalPosition'),
          verticalLabel: AppLocalizations.tr(lang, 'gifTitleVerticalPosition'),
          controller: _fioColorController,
          selectedColor: currentTheme.fioColor,
          presetColors: _presetColors,
          onScaleChanged: (value) => _updateTheme((theme) => theme.copyWith(fioFontScale: value)),
          onHorizontalChanged: (value) => _updateTheme((theme) => theme.copyWith(fioLeft: value)),
          onVerticalChanged: (value) => _updateTheme((theme) => theme.copyWith(fioBottom: value)),
          onSubmitted: (value) => _applyColor(isFio: true, rawValue: value),
          onPresetSelected: (color) => _updateTheme((theme) => theme.copyWith(fioColor: color)),
        );
        final cityEditor = _EditorSection(
          title: AppLocalizations.tr(lang, 'gifTitleCitySection'),
          fontScale: currentTheme.cityFontScale,
          horizontalPosition: currentTheme.cityLeft,
          verticalPosition: currentTheme.cityBottom,
          min: 0.06,
          max: 0.18,
          divisions: 12,
          sizeLabel: AppLocalizations.tr(lang, 'gifTitleTextSize'),
          colorLabel: AppLocalizations.tr(lang, 'gifTitleTextColor'),
          horizontalLabel: AppLocalizations.tr(lang, 'gifTitleHorizontalPosition'),
          verticalLabel: AppLocalizations.tr(lang, 'gifTitleVerticalPosition'),
          controller: _cityColorController,
          selectedColor: currentTheme.cityColor,
          presetColors: _presetColors,
          onScaleChanged: (value) => _updateTheme((theme) => theme.copyWith(cityFontScale: value)),
          onHorizontalChanged: (value) => _updateTheme((theme) => theme.copyWith(cityLeft: value)),
          onVerticalChanged: (value) => _updateTheme((theme) => theme.copyWith(cityBottom: value)),
          onSubmitted: (value) => _applyColor(isFio: false, rawValue: value),
          onPresetSelected: (color) => _updateTheme((theme) => theme.copyWith(cityColor: color)),
        );

        if (isNarrow) {
          return Column(
            children: [
              fioEditor,
              const SizedBox(height: 12),
              cityEditor,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fioEditor),
            const SizedBox(width: 12),
            Expanded(child: cityEditor),
          ],
        );
      },
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.fontScale,
    required this.horizontalPosition,
    required this.verticalPosition,
    required this.min,
    required this.max,
    required this.divisions,
    required this.sizeLabel,
    required this.colorLabel,
    required this.horizontalLabel,
    required this.verticalLabel,
    required this.controller,
    required this.selectedColor,
    required this.presetColors,
    required this.onScaleChanged,
    required this.onHorizontalChanged,
    required this.onVerticalChanged,
    required this.onSubmitted,
    required this.onPresetSelected,
  });

  final String title;
  final double fontScale;
  final double horizontalPosition;
  final double verticalPosition;
  final double min;
  final double max;
  final int divisions;
  final String sizeLabel;
  final String colorLabel;
  final String horizontalLabel;
  final String verticalLabel;
  final TextEditingController controller;
  final Color selectedColor;
  final List<Color> presetColors;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<double> onHorizontalChanged;
  final ValueChanged<double> onVerticalChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<Color> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: fontScale,
              min: min,
              max: max,
              divisions: divisions,
              label: fontScale.toStringAsFixed(2),
              onChanged: onScaleChanged,
            ),
            Text('$sizeLabel: ${fontScale.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 420) {
                  return Column(
                    children: [
                      _PositionSlider(
                        label: horizontalLabel,
                        value: horizontalPosition,
                        onChanged: onHorizontalChanged,
                      ),
                      const SizedBox(height: 8),
                      _PositionSlider(
                        label: verticalLabel,
                        value: verticalPosition,
                        onChanged: onVerticalChanged,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PositionSlider(
                        label: horizontalLabel,
                        value: horizontalPosition,
                        onChanged: onHorizontalChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PositionSlider(
                        label: verticalLabel,
                        value: verticalPosition,
                        onChanged: onVerticalChanged,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _ColorEditor(
              label: colorLabel,
              controller: controller,
              selectedColor: selectedColor,
              presetColors: presetColors,
              onSubmitted: onSubmitted,
              onPresetSelected: onPresetSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionSlider extends StatelessWidget {
  const _PositionSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value,
          min: 0,
          max: 1,
          divisions: 100,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ColorEditor extends StatelessWidget {
  const _ColorEditor({
    required this.label,
    required this.controller,
    required this.selectedColor,
    required this.presetColors,
    required this.onSubmitted,
    required this.onPresetSelected,
  });

  final String label;
  final TextEditingController controller;
  final Color selectedColor;
  final List<Color> presetColors;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<Color> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: '#FFFFFFFF',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => onSubmitted(controller.text),
              icon: const Icon(Icons.check),
            ),
          ),
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in presetColors)
              InkWell(
                onTap: () => onPresetSelected(color),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedColor == color ? Colors.tealAccent : Colors.white24,
                      width: selectedColor == color ? 3 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
