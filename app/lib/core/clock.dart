/// Where the app takes "now" from. Tests replace it with a fixed moment, so
/// calendars and "today" do not depend on when the tests run.
class AppClock {
  const AppClock([this._now]);

  final DateTime Function()? _now;

  DateTime now() => _now?.call() ?? DateTime.now();
}
