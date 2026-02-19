import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';

import '../../localization/app_localizations.dart';

class GifTitres extends StatefulWidget {
  const GifTitres({
    super.key,
    required this.lang,
  });

  final String lang;

  @override
  State<GifTitres> createState() => GifTitresState();
}

class GifTitresState extends State<GifTitres> {
  static const Map<String, String> gifs = {
    'blue': 'lib/data/assets/blue.gif',
    'red': 'lib/data/assets/red.gif',
    'fitness': 'lib/data/assets/fitness.gif',
    'lenta': 'lib/data/assets/lenta.gif',
  };
  final Map<String, Map<String, double>> textPositions = {
    'blue': {
      'fioLeft': 0.25,
      'fioBottom': 0.45,
      'cityLeft': 0.2,
      'cityBottom': 0.15,
    },
    'red': {
      'fioLeft': 0.25,
      'fioBottom': 0.45,
      'cityLeft': 0.2,
      'cityBottom': 0.15,
    },
    'fitness': {
      'fioLeft': 0.25,
      'fioBottom': 0.5,
      'cityLeft': 0.45,
      'cityBottom': 0.23,
    },
    'lenta': {
      'fioLeft': 0.23,
      'fioBottom': 0.28,
      'cityLeft': 0.25,
      'cityBottom': 0.18,
    },
  };
  
  String selectedGif = gifs.keys.first;
  String _currentFio = '';
  String _currentCity = '';
  int selectedTime = 3;
  bool _isShowingGif = false;
  Timer? _hideGifTimer;
  Timer? _scheduleTimer;

  final TextEditingController _timeController = TextEditingController();
  Map<String, double> get _currentPositions => textPositions[selectedGif]!;

  void showGifWithData({required String fio, required String city, String? gifKey}) {
    _resetGif();
    setState(() {
      _currentFio = fio;
      _currentCity = city;
      if (gifKey != null && gifs.containsKey(gifKey)) {
        selectedGif = gifKey;
      }
      _isShowingGif = true;
    });
    _hideGifTimer?.cancel();
    _hideGifTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isShowingGif = false;
        });
      }
    });
  }

  void _resetGif() {
    final provider = AssetImage(gifs[selectedGif]!);
    provider.evict();
    setState(() {});
  }

  void hideGif() {
    _hideGifTimer?.cancel();
    _scheduleTimer?.cancel();
    if (mounted) {
      setState(() {
        _isShowingGif = false;
      });
    }
  }

  void scheduleGifDisplay({
    required String fio,
    required String city,
    String? gifKey,
    int? customDelay,
  }) async {
    _scheduleTimer?.cancel();
    _hideGifTimer?.cancel();
    
    final delay = customDelay ?? selectedTime;
    
    try {
      if (delay > 0) {
        if (!mounted) return;
        _scheduleTimer = Timer(Duration(seconds: delay), () {
          if (mounted) {
            showGifWithData(
              fio: fio,
              city: city,
              gifKey: gifKey,
            );
          }
        });
      } else {
        showGifWithData(
          fio: fio,
          city: city,
          gifKey: gifKey,
        );
      }
      
    } catch (e) {
      if (!mounted) return;
    }
  }

  String get currentSelectedGif => selectedGif;
  int get currentDelay => selectedTime;

  @override
  void initState() {
    super.initState();
    _timeController.text = '2';
  }

  @override
  void dispose() {
    _hideGifTimer?.cancel();
    _scheduleTimer?.cancel();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedGif,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr(widget.lang, 'nameGifsTitre'),
                    border: const OutlineInputBorder(),
                  ),
                  items: gifs.keys.map((String key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(key),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedGif = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _timeController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.tr(widget.lang, 'labelTimerGifs'),
                    border: const OutlineInputBorder(),
                    hintText: AppLocalizations.tr(widget.lang, 'hintTimerGifs'),
                    suffixText: AppLocalizations.tr(widget.lang, 'suffixTimerGifs'),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      selectedTime = int.tryParse(value) ?? 3;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: screenSize.height * 0.3,
          width: double.infinity,
          color: const Color(0xFF00FF52),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  if (_isShowingGif)
                  Positioned.fill(
                    child: Image.asset(
                      gifs[selectedGif]!,
                      fit: BoxFit.cover,
                      gaplessPlayback: false,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey,
                          child: const Center(
                            child: Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 50,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isShowingGif)
                  Positioned(
                    left: constraints.maxWidth * _currentPositions['fioLeft']!, 
                    bottom: constraints.maxHeight * _currentPositions['fioBottom']!,
                    child: Text(
                      _currentFio.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: constraints.maxHeight * 0.15,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms),
                  ),
                  if (_isShowingGif)
                  Positioned(
                    left: constraints.maxWidth * _currentPositions['cityLeft']!,
                    bottom: constraints.maxHeight * _currentPositions['cityBottom']!, 
                    child: Text(
                      _currentCity.toUpperCase(),
                      style: TextStyle(
                        color: selectedGif == "red" ? Colors.black : Colors.white,
                        fontSize: constraints.maxHeight * 0.1,
                        fontWeight: FontWeight.normal,
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
        )
      ],
    );
  }
}