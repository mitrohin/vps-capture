import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/config_services.dart';
import '../../domain/models/gif_title_theme.dart';
import '../../localization/app_localizations.dart';
import '../../state/app_controller.dart';
import 'gif_titres.dart';

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

    return AlertDialog(
      title: Text(AppLocalizations.tr(lang, 'gifTitleSettingsTitle')),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                ),
                items: GifTitres.gifs.keys
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 860;
                  final preview = _SettingsPreview(gifKey: _selectedGifKey, theme: currentTheme);
                  final editors = _buildEditors(context, currentTheme, lang);

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [preview, const SizedBox(height: 16), editors],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: preview),
                      const SizedBox(width: 16),
                      Expanded(child: editors),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
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
    );
  }

  Widget _buildEditors(BuildContext context, GifTitleTheme currentTheme, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.tr(lang, 'gifTitleNameSection'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: currentTheme.fioFontScale,
          min: 0.08,
          max: 0.24,
          divisions: 16,
          label: currentTheme.fioFontScale.toStringAsFixed(2),
          onChanged: (value) => _updateTheme((theme) => theme.copyWith(fioFontScale: value)),
        ),
        Text('${AppLocalizations.tr(lang, 'gifTitleTextSize')}: ${currentTheme.fioFontScale.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
        _ColorEditor(
          label: AppLocalizations.tr(lang, 'gifTitleTextColor'),
          controller: _fioColorController,
          selectedColor: currentTheme.fioColor,
          presetColors: _presetColors,
          onSubmitted: (value) => _applyColor(isFio: true, rawValue: value),
          onPresetSelected: (color) => _updateTheme((theme) => theme.copyWith(fioColor: color)),
        ),
        const SizedBox(height: 20),
        Text(
          AppLocalizations.tr(lang, 'gifTitleCitySection'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: currentTheme.cityFontScale,
          min: 0.06,
          max: 0.18,
          divisions: 12,
          label: currentTheme.cityFontScale.toStringAsFixed(2),
          onChanged: (value) => _updateTheme((theme) => theme.copyWith(cityFontScale: value)),
        ),
        Text('${AppLocalizations.tr(lang, 'gifTitleTextSize')}: ${currentTheme.cityFontScale.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
        _ColorEditor(
          label: AppLocalizations.tr(lang, 'gifTitleTextColor'),
          controller: _cityColorController,
          selectedColor: currentTheme.cityColor,
          presetColors: _presetColors,
          onSubmitted: (value) => _applyColor(isFio: false, rawValue: value),
          onPresetSelected: (color) => _updateTheme((theme) => theme.copyWith(cityColor: color)),
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

class _SettingsPreview extends StatelessWidget {
  const _SettingsPreview({required this.gifKey, required this.theme});

  final String gifKey;
  final GifTitleTheme theme;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  GifTitres.gifs[gifKey]!,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  left: constraints.maxWidth * theme.fioLeft,
                  bottom: constraints.maxHeight * theme.fioBottom,
                  child: Text(
                    'ИВАНОВА МАРИЯ',
                    style: TextStyle(
                      color: theme.fioColor,
                      fontSize: constraints.maxHeight * theme.fioFontScale,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: constraints.maxWidth * theme.cityLeft,
                  bottom: constraints.maxHeight * theme.cityBottom,
                  child: Text(
                    'САНКТ-ПЕТЕРБУРГ',
                    style: TextStyle(
                      color: theme.cityColor,
                      fontSize: constraints.maxHeight * theme.cityFontScale,
                      shadows: const [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
