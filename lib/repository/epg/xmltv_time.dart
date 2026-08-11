/// XMLTV `start`/`stop` timestamps: `YYYYMMDDHHmmss [±HHMM]`.
class XmlTvTime {
  XmlTvTime._();

  static final RegExp _re = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})'
    r'(?:\s*([+-])(\d{2}):?(\d{2}))?',
  );

  /// Parses an XMLTV timestamp. Returns UTC. Null when unparseable.
  static DateTime? parse(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.length < 14) return null;
    final m = _re.firstMatch(s);
    if (m == null) return null;
    final year = int.tryParse(m.group(1)!);
    final month = int.tryParse(m.group(2)!);
    final day = int.tryParse(m.group(3)!);
    final hour = int.tryParse(m.group(4)!);
    final minute = int.tryParse(m.group(5)!);
    final second = int.tryParse(m.group(6)!);
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }
    var dt = DateTime.utc(year, month, day, hour, minute, second);
    final sign = m.group(7);
    if (sign != null) {
      final oh = int.tryParse(m.group(8) ?? '0') ?? 0;
      final om = int.tryParse(m.group(9) ?? '0') ?? 0;
      final offset = Duration(hours: oh, minutes: om);
      dt = sign == '+' ? dt.subtract(offset) : dt.add(offset);
    }
    return dt;
  }
}
