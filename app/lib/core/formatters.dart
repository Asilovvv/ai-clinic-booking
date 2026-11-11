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

/// 2026-11-13T09:00 (format the server expects)
String formatApiDate(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)}T${_two(d.hour)}:${_two(d.minute)}';
