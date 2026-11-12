import 'strings.dart';

const _monthsRu = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const _monthsKy = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const _weekdaysRu = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const _weekdaysKy = ['дш', 'шш', 'шр', 'бш', 'жм', 'иш', 'жк'];
const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<String> _months(AppLang lang) => switch (lang) {
      AppLang.ru => _monthsRu,
      AppLang.ky => _monthsKy,
      AppLang.en => _monthsEn,
    };

List<String> _weekdays(AppLang lang) => switch (lang) {
      AppLang.ru => _weekdaysRu,
      AppLang.ky => _weekdaysKy,
      AppLang.en => _weekdaysEn,
    };

String _two(int n) => n.toString().padLeft(2, '0');

/// 09:00
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// пт, 13 ноя
String formatDay(DateTime d, [AppLang lang = AppLang.ru]) =>
    '${_weekdays(lang)[d.weekday - 1]}, ${d.day} ${_months(lang)[d.month - 1]}';

/// ноя
String formatMonth(DateTime d, [AppLang lang = AppLang.ru]) => _months(lang)[d.month - 1];

/// пт (0 is Monday)
String weekdayShort(int index, [AppLang lang = AppLang.ru]) => _weekdays(lang)[index % 7];

/// 2026-11-13T09:00 (what the server expects for a start time)
String formatApiDate(DateTime d) => '${formatApiDay(d)}T${_two(d.hour)}:${_two(d.minute)}';

/// 2026-11-13
String formatApiDay(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// A price: 1 200 сом, or "Free" for zero.
String formatMoney(int amount, AppStrings s) => amount == 0 ? s.free : formatSum(amount, s);

/// A sum of money: 12 500 сом (zero stays "0 сом").
String formatSum(int amount, AppStrings s) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer ${s.som}';
}

/// 60 мин
String formatDuration(int minutes, AppStrings s) => '$minutes ${s.minutes}';

/// 09:00–18:00
String formatHours(int open, int close) => '${_two(open)}:00–${_two(close)}:00';

/// пн–сб, "Daily" for all seven days, or a list for anything irregular.
String formatWorkingDays(List<int> days, AppStrings s) {
  final sorted = [...days]..sort();
  if (sorted.length == 7) return s.daily;
  if (sorted.isEmpty) return '';
  final consecutive = sorted.last - sorted.first == sorted.length - 1;
  if (consecutive && sorted.length > 1) {
    return '${weekdayShort(sorted.first, s.lang)}–${weekdayShort(sorted.last, s.lang)}';
  }
  return sorted.map((d) => weekdayShort(d, s.lang)).join(', ');
}
