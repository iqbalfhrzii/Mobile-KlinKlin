class TimezoneHelper {
  /// Mendapatkan label zona waktu (WIB, WITA, atau WIT)
  /// berdasarkan nama cabang, kode cabang, atau offset jam perangkat.
  static String getTimezoneLabel([String? branchName]) {
    final b = (branchName ?? '').trim().toLowerCase();

    // 1. Cek Cabang / Wilayah WITA (UTC+8)
    // Bali, NTB, NTT, Kalimantan Timur, Kalimantan Selatan, Kalimantan Utara, seluruh Sulawesi
    if (b.isNotEmpty) {
      // Kode Cabang KlinKlin
      if (b == 'dps' || b == 'tbn' || b == 'smd' || b == 'bpp' || b == 'mks' ||
          b == 'bjm' || b == 'mtr' || b == 'kpg' || b == 'mdo' || b == 'plu' ||
          b == 'kdi' || b == 'gto' || b == 'mmj') {
        return 'WITA';
      }

      // Bali
      if (b.contains('denpasar') ||
          b.contains('bali') ||
          b.contains('tabanan') ||
          b.contains('badung') ||
          b.contains('gianyar') ||
          b.contains('buleleng') ||
          b.contains('klungkung') ||
          b.contains('bangli') ||
          b.contains('karangasem') ||
          b.contains('jembrana') ||
          b.contains('kuta') ||
          b.contains('ubud') ||
          b.contains('sanur')) {
        return 'WITA';
      }

      // Kalimantan Timur, Kalsel, Kaltara
      if (b.contains('balikpapan') ||
          b.contains('samarinda') ||
          b.contains('banjarmasin') ||
          b.contains('banjarbaru') ||
          b.contains('tarakan') ||
          b.contains('bontang') ||
          b.contains('kutai') ||
          b.contains('berau') ||
          b.contains('nunukan') ||
          b.contains('penajam') ||
          b.contains('ikn') ||
          b.contains('kalsel') ||
          b.contains('kaltim') ||
          b.contains('kaltara')) {
        return 'WITA';
      }

      // Seluruh Sulawesi
      if (b.contains('makassar') ||
          b.contains('manado') ||
          b.contains('palu') ||
          b.contains('kendari') ||
          b.contains('gorontalo') ||
          b.contains('mamuju') ||
          b.contains('parepare') ||
          b.contains('palopo') ||
          b.contains('bitung') ||
          b.contains('baubau') ||
          b.contains('sulawesi') ||
          b.contains('sulsel') ||
          b.contains('sulteng') ||
          b.contains('sulut') ||
          b.contains('sultra') ||
          b.contains('sulbar')) {
        return 'WITA';
      }

      // NTB & NTT
      if (b.contains('mataram') ||
          b.contains('lombok') ||
          b.contains('sumbawa') ||
          b.contains('bima') ||
          b.contains('kupang') ||
          b.contains('labuan bajo') ||
          b.contains('flores') ||
          b.contains('ende') ||
          b.contains('maumere') ||
          b.contains('ntb') ||
          b.contains('ntt')) {
        return 'WITA';
      }

      // 2. Cek Cabang / Wilayah WIT (UTC+9)
      // Maluku & Papua
      if (b.contains('ambon') ||
          b.contains('ternate') ||
          b.contains('tidore') ||
          b.contains('jayapura') ||
          b.contains('sorong') ||
          b.contains('manokwari') ||
          b.contains('merauke') ||
          b.contains('timika') ||
          b.contains('biak') ||
          b.contains('nabire') ||
          b.contains('maluku') ||
          b.contains('papua')) {
        return 'WIT';
      }
    }

    // 3. Fallback: gunakan offset zona waktu perangkat pengguna
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    if (offsetHours == 8) return 'WITA';
    if (offsetHours == 9) return 'WIT';

    return 'WIB';
  }

  /// Mendapatkan offset jam (7 untuk WIB, 8 untuk WITA, 9 untuk WIT)
  static int getTimezoneOffsetHours([String? branchName]) {
    final tz = getTimezoneLabel(branchName);
    if (tz == 'WITA') return 8;
    if (tz == 'WIT') return 9;
    return 7;
  }

  /// Melakukan parsing timestamp UTC dari server Laravel (baik format ISO dengan 'Z'
  /// maupun format datetime biasa "YYYY-MM-DD HH:mm:ss") ke DateTime UTC.
  static DateTime? parseServerTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      if (raw.isUtc) return raw;
      return DateTime.utc(
        raw.year,
        raw.month,
        raw.day,
        raw.hour,
        raw.minute,
        raw.second,
        raw.millisecond,
        raw.microsecond,
      );
    }
    String str = raw.toString().trim();
    if (str.isEmpty || str == '-') return null;
    if (!str.endsWith('Z') && !str.contains('+') && !RegExp(r'-\d{2}:\d{2}$').hasMatch(str)) {
      if (str.contains(' ')) {
        str = '${str.replaceFirst(' ', 'T')}Z';
      } else if (str.contains('T')) {
        str = '${str}Z';
      }
    }
    return DateTime.tryParse(str)?.toUtc();
  }

  /// Memformat timestamp server UTC ke string tanggal & jam lokal cabang (WIB / WITA / WIT).
  /// Contoh: "04 Sep 2026 15:30 WITA"
  static String formatDateTime(dynamic rawDate, {String? branchName, bool includeTimezone = true}) {
    final utc = parseServerTimestamp(rawDate);
    if (utc == null) return '-';

    final offsetHours = getTimezoneOffsetHours(branchName);
    final localDt = utc.add(Duration(hours: offsetHours));
    final tzLabel = getTimezoneLabel(branchName);

    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = localDt.day.toString().padLeft(2, '0');
    final month = months[localDt.month];
    final year = localDt.year;
    final hour = localDt.hour.toString().padLeft(2, '0');
    final minute = localDt.minute.toString().padLeft(2, '0');

    if (includeTimezone) {
      return '$day $month $year $hour:$minute $tzLabel';
    }
    return '$day $month $year $hour:$minute';
  }
}
