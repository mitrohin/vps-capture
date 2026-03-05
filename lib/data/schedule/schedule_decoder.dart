import 'dart:convert';

class ScheduleDecoder {
  String decode(List<int> bytes) {
    final cp1251 = _decodeCp1251(bytes);

    String? utf8Text;
    try {
      utf8Text = utf8.decode(bytes);
    } catch (_) {
      return cp1251;
    }

    if (_looksLikeMojibake(utf8Text) && _cyrillicCount(cp1251) > _cyrillicCount(utf8Text)) {
      return cp1251;
    }

    if (_cyrillicCount(utf8Text) == 0 && _cyrillicCount(cp1251) > 0) {
      return cp1251;
    }

    return utf8Text;
  }

  String _decodeCp1251(List<int> bytes) {
    final out = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        out.writeCharCode(b);
      } else if (b == 0xA8) {
        out.writeCharCode(0x0401);
      } else if (b == 0xB8) {
        out.writeCharCode(0x0451);
      } else if (b >= 0xC0) {
        out.writeCharCode(0x0410 + (b - 0xC0));
      } else {
        out.writeCharCode(0x00A0 + (b - 0x80));
      }
    }
    return out.toString();
  }

  int _cyrillicCount(String value) {
    final matches = RegExp(r'[А-Яа-яЁё]').allMatches(value);
    return matches.length;
  }

  bool _looksLikeMojibake(String value) {
    final suspicious = RegExp(r'[ÃÓÒÍ‚‡¬◊√¡ƒ—≈œ»«ÕﬂŸ]');
    return suspicious.allMatches(value).length >= 3;
  }
}
