import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/services/config_services.dart';

class GifTitres extends StatefulWidget {
  const GifTitres({
    super.key,
    required this.lang,
    required this.delayTime,
    required this.selectedGif,
  });

  final String lang;
  final int delayTime;
  final String selectedGif;

  @override
  State<GifTitres> createState() => GifTitresState();
}

class GifTitresState extends State<GifTitres> {
  final ConfigService _configService = ConfigService();
  final Map<String, String> gifs = {
    'blue': 'lib/data/assets/blue.gif',
    'red': 'lib/data/assets/red.gif',
    'fitness': 'lib/data/assets/fitness.gif',
    'lenta': 'lib/data/assets/lenta.gif',
  };
  
  
  String _currentFio = '';
  String _currentCity = '';
  bool _isShowingGif = false;
  Timer? _hideGifTimer;
  Timer? _scheduleTimer;
  late String _selectedGif;

  Map<String, double> get _currentPositions => _configService.textPositions[_selectedGif]!;

  void showGifWithData({required String fio, required String city, String? gifKey}) {
    _resetGif();
    setState(() {
      _currentFio = fio;
      _currentCity = city;
      if (gifKey != null && gifs.containsKey(gifKey)) {
        _selectedGif = gifKey;
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
    final provider = AssetImage(gifs[_selectedGif]!);
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
    
    final delay = customDelay ?? widget.delayTime;
    
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

  String get currentSelectedGif => _selectedGif;
  int get currentDelay => widget.delayTime;

  @override
  void initState() {
    _selectedGif = widget.selectedGif;
    _loadConfig();
    super.initState();
  }

  Future<void> _loadConfig() async {
    await _configService.loadConfig();
  }

  @override
  void dispose() {
    _hideGifTimer?.cancel();
    _scheduleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Column(
      children: [
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
                      gifs[_selectedGif]!,
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
                    ).animate().fadeIn(duration: Duration(milliseconds: (widget.delayTime * 1000 + 700).toInt())),
                  ),
                  if (_isShowingGif)
                  Positioned(
                    left: constraints.maxWidth * _currentPositions['cityLeft']!,
                    bottom: constraints.maxHeight * _currentPositions['cityBottom']!, 
                    child: Text(
                      _currentCity.toUpperCase(),
                      style: TextStyle(
                        color: _selectedGif == "red" ? Colors.black : Colors.white,
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
                    ).animate().fadeIn(duration: Duration(milliseconds: (widget.delayTime * 1000 + 850).toInt())),
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