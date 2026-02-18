import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';

class GifTitres extends StatefulWidget {
  const GifTitres({
    super.key,
    required this.fio,
    required this.city,
    required this.lang,
  });

  final String fio, city;
  final String lang;

  @override
  State<GifTitres> createState() => _GifTitresState();
}

class _GifTitresState extends State<GifTitres> {
  static const Map<String, String> gifs = {
    'blue': 'lib/data/assets/blue.gif',
    'red': 'lib/data/assets/red.gif',
    'fitness': 'lib/data/assets/fitness.gif',
    'lenta': 'lib/data/assets/lenta.gif',
  };
  
  String selectedGif = gifs.keys.first;
  
  final TextEditingController _timeController = TextEditingController();
  int selectedTime = 0;
  
  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      selectedTime = int.tryParse(value) ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 330,
          width: double.infinity,
          color: const Color(0xFF00FF52),
          padding: const EdgeInsets.only(left: 0, right: 0, top: 0, bottom: 10),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  gifs[selectedGif]!,
                  fit: BoxFit.cover,
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
              Positioned(
                bottom: 20,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fio,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.city,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> scheduleGifDisplay() async {
    try {
      if (selectedTime > 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Гифка будет показана через $selectedTime секунд'),
            duration: const Duration(seconds: 2),
          ),
        );
        
        await Future.delayed(Duration(seconds: selectedTime));
      }

      if (!mounted) return;
      await _displayGif();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _displayGif() async {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Показываем гифку: $selectedGif'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}