const _months = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];
const _weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

String _two(int n) => n.toString().padLeft(2, '0');

/// 09:00
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// пт, 13 ноя
String formatDay(DateTime d) => '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// ноя
String formatMonth(DateTime d) => _months[d.month - 1];

/// 2026-11-13T09:00 (format the server expects)
String formatApiDate(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)}T${_two(d.hour)}:${_two(d.minute)}';
