import 'package:flutter/widgets.dart';

/// Add new languages by extending [supportedLanguages] and [dictionary].
class AppLocalizations {
  AppLocalizations._();

  static const List<String> supportedLanguages = ['en', 'ru', 'tr'];

  static const Map<String, Map<String, String>> dictionary = {
    'en': {
      'appTitle': 'Gym Capture',
      'setupTitle': 'Gym Capture • Setup Wizard',
      'workTitle': 'Gym Capture • Work',
      'installAutomatically': 'Install automatically',
      'pickFfmpeg': 'Pick ffmpeg path...',
      'pickFfplay': 'Pick ffplay path...',
      'startPreview': 'Start Preview',
      'stopPreview': 'Stop Preview',
      'notSelected': 'not selected',
      'outputFolder': 'Output folder',
      'chooseOutputFolder': 'Choose output folder',
      'captureSource': 'Capture source type',
      'scanDevices': 'Scan devices',
      'codec': 'Codec',
      'bufferMin': 'Buffer min',
      'preRollSec': 'Pre-roll sec',
      'continueToWork': 'Continue to Work Screen',
      'loadSchedule': 'Load schedule',
      'scheduleEditorLabel': 'Schedule input',
      'scheduleEditorHint': 'One line: FIO;APPARATUS;CITY(optional)',
      'applySchedule': 'Apply schedule',
      'backToSetup': 'Back to setup',
      'startHotkey': 'START (Ctrl+S)',
      'stopHotkey': 'STOP (Ctrl+X)',
      'postponeHotkey': 'POSTPONE (Ctrl+D)',
      'restoreEntry': 'Restore',
      'pending': 'PENDING',
      'active': 'ACTIVE',
      'done': 'DONE',
      'postponed': 'POSTPONED',
      'language': 'Language',
    },
    'ru': {
      'appTitle': 'Гим Захват',
      'setupTitle': 'Гим Захват • Мастер настройки',
      'workTitle': 'Гим Захват • Работа',
      'installAutomatically': 'Установить автоматически',
      'pickFfmpeg': 'Выбрать путь к ffmpeg...',
      'pickFfplay': 'Выбрать путь к ffplay...',
      'startPreview': 'Запустить превью',
      'stopPreview': 'Остановить превью',
      'notSelected': 'не выбрано',
      'outputFolder': 'Папка вывода',
      'chooseOutputFolder': 'Выбрать папку вывода',
      'captureSource': 'Тип источника захвата',
      'scanDevices': 'Сканировать устройства',
      'codec': 'Кодек',
      'bufferMin': 'Буфер, мин',
      'preRollSec': 'Преролл, сек',
      'continueToWork': 'Перейти к рабочему экрану',
      'loadSchedule': 'Загрузить расписание',
      'scheduleEditorLabel': 'Ввод расписания',
      'scheduleEditorHint': 'Одна строка: ФИО;СНАРЯД;ГОРОД(необязательно)',
      'applySchedule': 'Применить расписание',
      'backToSetup': 'Назад к настройке',
      'startHotkey': 'СТАРТ (Ctrl+S)',
      'stopHotkey': 'СТОП (Ctrl+X)',
      'postponeHotkey': 'ОТЛОЖИТЬ (Ctrl+D)',
      'restoreEntry': 'Вернуть',
      'pending': 'В ОЧЕРЕДИ',
      'active': 'АКТИВНО',
      'done': 'ГОТОВО',
      'postponed': 'ОТЛОЖЕНО',
      'language': 'Язык',
    },
    'tr': {
      'appTitle': 'Gym Capture',
      'setupTitle': 'Gym Capture • Kurulum Sihirbazı',
      'workTitle': 'Gym Capture • Çalışma',
      'installAutomatically': 'Otomatik kur',
      'pickFfmpeg': 'ffmpeg yolunu seç...',
      'pickFfplay': 'ffplay yolunu seç...',
      'startPreview': 'Önizlemeyi başlat',
      'stopPreview': 'Önizlemeyi durdur',
      'notSelected': 'seçilmedi',
      'outputFolder': 'Çıktı klasörü',
      'chooseOutputFolder': 'Çıktı klasörü seç',
      'captureSource': 'Yakalama kaynağı türü',
      'scanDevices': 'Cihazları tara',
      'codec': 'Kodek',
      'bufferMin': 'Arabellek dk',
      'preRollSec': 'Ön kayıt sn',
      'continueToWork': 'Çalışma ekranına geç',
      'loadSchedule': 'Program yükle',
      'scheduleEditorLabel': 'Program girişi',
      'scheduleEditorHint': 'Her satır: AD SOYAD;EKİPMAN;ŞEHİR(opsiyonel)',
      'applySchedule': 'Programı uygula',
      'backToSetup': 'Kuruluma dön',
      'startHotkey': 'BAŞLAT (Ctrl+S)',
      'stopHotkey': 'DURDUR (Ctrl+X)',
      'postponeHotkey': 'ERTELE (Ctrl+D)',
      'restoreEntry': 'Geri yükle',
      'pending': 'BEKLİYOR',
      'active': 'AKTİF',
      'done': 'TAMAM',
      'postponed': 'ERTELENDİ',
      'language': 'Dil',
    },
  };

  static String tr(String languageCode, String key) {
    final lang = dictionary[languageCode];
    if (lang != null && lang.containsKey(key)) return lang[key]!;
    return dictionary['en']![key] ?? key;
  }
}

extension AppLocBuildContextX on BuildContext {
  String tr(String languageCode, String key) => AppLocalizations.tr(languageCode, key);
}
