/// Interface languages of the app.
enum AppLang { ru, ky, en }

extension AppLangInfo on AppLang {
  String get label => switch (this) {
        AppLang.ru => 'Русский',
        AppLang.ky => 'Кыргызча',
        AppLang.en => 'English',
      };

  /// Locale passed to the speech recognizer.
  String get speechLocale => switch (this) {
        AppLang.ru => 'ru_RU',
        AppLang.ky => 'ky_KG',
        AppLang.en => 'en_US',
      };
}

/// All interface texts in three languages.
class AppStrings {
  const AppStrings(this.lang);

  final AppLang lang;

  String _t(String ru, String ky, String en) => switch (lang) {
        AppLang.ru => ru,
        AppLang.ky => ky,
        AppLang.en => en,
      };

  // ------------------------------------------------------------- general
  String get tagline => _t(
        'ИИ-администратор.\nЗапись одной фразой.',
        'ЖИ-администратор.\nБир сүйлөм менен жазылуу.',
        'AI administrator.\nBook with one sentence.',
      );
  String get retry => _t('Повторить', 'Кайталоо', 'Retry');
  String get loadError => _t('Ошибка загрузки', 'Жүктөө катасы', 'Loading failed');
  String get all => _t('Все', 'Баары', 'All');
  String get no => _t('Нет', 'Жок', 'No');

  // ---------------------------------------------------------- onboarding
  String get onboardTitle1 => _t('Запись одной фразой', 'Бир сүйлөм менен жазылуу', 'Book with one sentence');
  String get onboardText1 => _t(
        'Напишите или скажите, что нужно и когда удобно. ИИ подберёт специалиста и свободное время.',
        'Эмне керек жана качан ыңгайлуу экенин жазыңыз же айтыңыз. ЖИ адисти жана бош убакытты тандайт.',
        'Type or say what you need and when. AI finds the right specialist and a free time.',
      );
  String get onboardTitle2 => _t('Не только клиника', 'Клиника гана эмес', 'More than a clinic');
  String get onboardText2 => _t(
        'Стоматология, барбершоп, автосервис — всё в одном приложении.',
        'Стоматология, барбершоп, автосервис — баары бир тиркемеде.',
        'Dentist, barbershop, car service — all in one app.',
      );
  String get onboardTitle3 => _t('Всё под контролем', 'Баары көзөмөлдө', 'Everything under control');
  String get onboardText3 => _t(
        'Переносите и отменяйте записи прямо в чате. Ассистент работает 24/7.',
        'Жазылууларды чатта эле которуп же жокко чыгарыңыз. Ассистент 24/7 иштейт.',
        'Move or cancel bookings right in the chat. The assistant works 24/7.',
      );
  String get next => _t('Далее', 'Кийинки', 'Next');
  String get start => _t('Начать', 'Баштоо', 'Get started');
  String get skip => _t('Пропустить', 'Өткөрүү', 'Skip');

  // ---------------------------------------------------------------- auth
  String get login => _t('Вход', 'Кирүү', 'Sign in');
  String get registration => _t('Регистрация', 'Каттоо', 'Sign up');
  String get name => _t('Имя', 'Аты', 'Name');
  String get password => _t('Пароль', 'Сырсөз', 'Password');
  String get enterName => _t('Введите имя', 'Атыңызды жазыңыз', 'Enter your name');
  String get enterEmail => _t('Введите email', 'Email жазыңыз', 'Enter your email');
  String get minPassword => _t('Минимум 6 символов', 'Кеминде 6 белги', 'At least 6 characters');
  String get signIn => _t('Войти', 'Кирүү', 'Sign in');
  String get createAccount => _t('Создать аккаунт', 'Аккаунт түзүү', 'Create account');
  String get haveAccount =>
      _t('Уже есть аккаунт? Войти', 'Аккаунтуңуз барбы? Кирүү', 'Already have an account? Sign in');
  String get noAccount =>
      _t('Нет аккаунта? Зарегистрироваться', 'Аккаунтуңуз жокпу? Катталуу', 'No account? Sign up');
  String get server => _t('Сервер', 'Сервер', 'Server');

  // ---------------------------------------------------------------- home
  String get tabAssistant => _t('Ассистент', 'Ассистент', 'Assistant');
  String get tabAppointments => _t('Записи', 'Жазылуулар', 'Bookings');
  String get tabSpecialists => _t('Специалисты', 'Адистер', 'Specialists');
  String get titleAssistant => _t('ИИ-администратор', 'ЖИ-администратор', 'AI administrator');
  String get titleAppointments => _t('Мои записи', 'Менин жазылууларым', 'My bookings');
  String get settings => _t('Настройки', 'Жөндөөлөр', 'Settings');
  String get theme => _t('Тема', 'Тема', 'Theme');
  String get themeSystem => _t('Авто', 'Авто', 'Auto');
  String get themeLight => _t('Светлая', 'Жарык', 'Light');
  String get themeDark => _t('Тёмная', 'Караңгы', 'Dark');
  String get language => _t('Язык', 'Тил', 'Language');
  String get logout => _t('Выйти', 'Чыгуу', 'Sign out');

  // ---------------------------------------------------------------- chat
  String greeting(String userName) {
    final who = userName.isEmpty ? '' : ', $userName';
    return _t(
      'Здравствуйте$who! Я ИИ-администратор Smile AI. Запишу к стоматологу, в барбершоп или '
          'автосервис. Напишите или скажите, что нужно и когда удобно.',
      'Саламатсызбы$who! Мен Smile AI ЖИ-администраторумун. Тиш доктурга, барбершопко же '
          'автосервиске жазам. Эмне керек жана качан ыңгайлуу экенин жазыңыз же айтыңыз.',
      'Hello$who! I am the Smile AI administrator. I can book a dentist, a barbershop or '
          'a car service. Type or say what you need and when.',
    );
  }

  String get inputHint => _t(
        'Например: стрижка завтра утром',
        'Мисалы: стрижка завтра утром',
        'E.g. haircut tomorrow morning',
      );
  String get listening => _t('Говорите…', 'Сүйлөңүз…', 'Listening…');
  String get micUnavailable => _t(
        'Голосовой ввод недоступен на этом устройстве',
        'Бул түзмөктө үн менен жазуу жеткиликсиз',
        'Voice input is not available on this device',
      );
  String bookMe(String day, String time) =>
      _t('Запишите меня: $day, $time', 'Мени жазыңыз: $day, $time', 'Book me: $day, $time');
  String moveTo(String day, String time) =>
      _t('Перенесите на: $day, $time', 'Которуңуз: $day, $time', 'Move to: $day, $time');
  String booked(String specialist) => _t(
        'Готово! Вы записаны: $specialist. Ждём вас!',
        'Даяр! Сиз жазылдыңыз: $specialist. Күтөбүз!',
        'Done! You are booked with $specialist. See you!',
      );
  String moved(String specialist) => _t(
        'Готово! Запись перенесена: $specialist.',
        'Даяр! Жазылуу которулду: $specialist.',
        'Done! Your booking with $specialist was moved.',
      );
  String get bookingConfirmed => _t('Запись подтверждена', 'Жазылуу ырасталды', 'Booking confirmed');

  /// Quick prompts under the chat. The offline assistant understands Russian
  /// and English, so Kyrgyz interface keeps the Russian prompts.
  List<String> suggestions(String? category) {
    if (lang == AppLang.en) {
      return switch (category) {
        'dental' => ['Toothache, tomorrow afternoon', 'Teeth whitening on Saturday morning', 'Braces, nearest time'],
        'barber' => ['Haircut tomorrow morning', 'Beard trim on Friday', 'Hair coloring on Saturday'],
        'auto' => ['Oil change on Friday', 'Car diagnostics tomorrow morning', 'New tires on Saturday'],
        _ => ['Toothache, tomorrow afternoon', 'Haircut on Saturday morning', 'Oil change on Friday', 'My appointments'],
      };
    }
    return switch (category) {
      'dental' => ['Болит зуб, завтра после обеда', 'Чистка в субботу утром', 'Брекеты, ближайшее время', 'Ребёнку к стоматологу'],
      'barber' => ['Стрижка завтра утром', 'Оформить бороду в пятницу', 'Окрашивание в субботу'],
      'auto' => ['Замена масла в пятницу', 'Диагностика завтра утром', 'Шиномонтаж в субботу'],
      _ => ['Болит зуб, завтра после обеда', 'Стрижка в субботу утром', 'Замена масла в пятницу', 'Мои записи'],
    };
  }

  // -------------------------------------------------------- appointments
  String get noAppointments => _t('Записей пока нет', 'Азырынча жазылуу жок', 'No bookings yet');
  String get noAppointmentsHint => _t(
        'Напишите ассистенту, что нужно и когда удобно — он запишет вас за секунды.',
        'Ассистентке эмне керек жана качан ыңгайлуу экенин жазыңыз — ал сизди бир нече секундда жазат.',
        'Tell the assistant what you need and when — it books you in seconds.',
      );
  String get cancelQuestion => _t('Отменить запись?', 'Жазылууну жокко чыгарасызбы?', 'Cancel this booking?');
  String get cancel => _t('Отменить', 'Жокко чыгаруу', 'Cancel booking');

  // --------------------------------------------------------- specialists
  String get bookViaAi => _t('Записаться через ИИ', 'ЖИ аркылуу жазылуу', 'Book via AI');
}
