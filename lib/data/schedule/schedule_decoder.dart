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

    return utf8Text;
  }

  String _decodeCp1251(List<int> bytes) {
    const cp1251HighBlock = <int>[
      0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
      0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
      0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
      0xFFFD, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
      0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
      0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
      0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
      0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
    ];

    final out = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        out.writeCharCode(b);
      } else if (b >= 0xC0) {
        out.writeCharCode(0x0410 + (b - 0xC0));
      } else {
        out.writeCharCode(cp1251HighBlock[b - 0x80]);
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
