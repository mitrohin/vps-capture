import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/config_services.dart';
import '../../state/app_controller.dart';

class GifTitres extends ConsumerStatefulWidget {
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
  ConsumerState<GifTitres> createState() => GifTitresState();
}

class GifTitresState extends ConsumerState<GifTitres> {
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

  Map<String, double> get _currentPositions => _configService.textPositions[widget.selectedGif]!;

  void showGifWithData({required String fio, required String city, String? gifKey}) {
    _resetGif();
    setState(() {
      _currentFio = fio;
      _currentCity = city;
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
    final provider = AssetImage(gifs[widget.selectedGif]!);
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
    final gifToShow = gifKey ?? widget.selectedGif;
    
    try {
      if (delay > 0) {
        if (!mounted) return;
        _scheduleTimer = Timer(Duration(seconds: delay), () {
          if (mounted) {
            showGifWithData(
              fio: fio,
              city: city,
              gifKey: gifToShow,
            );
          }
        });
      } else {
        showGifWithData(
          fio: fio,
          city: city,
          gifKey: gifToShow,
        );
      }
      
    } catch (e) {
      if (!mounted) return;
    }
  }

  String get currentSelectedGif => widget.selectedGif;
  int get currentDelay => widget.delayTime;

  @override
  void initState() {
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
    // final configGif = ref.watch(appControllerProvider.select(
    //   (state) => state.config.selectedGif
    // ));
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
                      gifs[widget.selectedGif]!,
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
                    ).animate().fadeIn(
                      delay: Duration(milliseconds: widget.delayTime*270),
                      duration: Duration(milliseconds: (270).toInt())
                      ),
                  ),
                  if (_isShowingGif)
                  Positioned(
                    left: constraints.maxWidth * _currentPositions['cityLeft']!,
                    bottom: constraints.maxHeight * _currentPositions['cityBottom']!, 
                    child: Text(
                      _currentCity.toUpperCase(),
                      style: TextStyle(
                        color: widget.selectedGif == "red" ? Colors.black : Colors.white,
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
                    ).animate().fadeIn(
                      delay: Duration(milliseconds: widget.delayTime*320),
                      duration: Duration(milliseconds: (320).toInt())
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