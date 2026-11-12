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
  String get wakingUp => _t(
        'Подключаемся к серверу… Если он спал, это займёт до минуты.',
        'Серверге туташуудабыз… Эгер ал уктап жаткан болсо, бир мүнөткө чейин созулат.',
        'Connecting to the server… If it was asleep, this takes up to a minute.',
      );
  String get retry => _t('Повторить', 'Кайталоо', 'Retry');
  String get loadError => _t('Ошибка загрузки', 'Жүктөө катасы', 'Loading failed');
  String get all => _t('Все', 'Баары', 'All');
  String get no => _t('Нет', 'Жок', 'No');
  String get save => _t('Сохранить', 'Сактоо', 'Save');
  String get saved => _t('Сохранено', 'Сакталды', 'Saved');
  String get delete => _t('Удалить', 'Өчүрүү', 'Delete');
  String get close => _t('Закрыть', 'Жабуу', 'Close');
  String get back => _t('Назад', 'Артка', 'Back');
  String get som => _t('сом', 'сом', 'KGS');
  String get minutes => _t('мин', 'мүн', 'min');
  String get free => _t('Бесплатно', 'Акысыз', 'Free');
  String priceFrom(String price) => _t('от $price', '$price баштап', 'from $price');
  String get daily => _t('Ежедневно', 'Күн сайын', 'Daily');

  /// Localized name of a niche; unknown ids fall back to the server's title.
  String category(String id, String fallback) => switch (id) {
        'dental' => _t('Стоматология', 'Стоматология', 'Dental'),
        'clinic' => _t('Медцентр', 'Медборбор', 'Medical'),
        'barber' => _t('Барбершоп', 'Барбершоп', 'Barbershop'),
        'beauty' => _t('Салон красоты', 'Сулуулук салону', 'Beauty'),
        'massage' => _t('Массаж и СПА', 'Массаж жана СПА', 'Massage & spa'),
        'fitness' => _t('Фитнес', 'Фитнес', 'Fitness'),
        'auto' => _t('Автосервис', 'Автосервис', 'Car service'),
        'carwash' => _t('Автомойка', 'Унаа жуугуч', 'Car wash'),
        'tutor' => _t('Репетиторы', 'Репетиторлор', 'Tutors'),
        'vet' => _t('Ветклиника', 'Ветклиника', 'Vet'),
        _ => fallback,
      };

  // ---------------------------------------------------------- onboarding
  String get onboardTitle1 => _t('Запись одной фразой', 'Бир сүйлөм менен жазылуу', 'Book with one sentence');
  String get onboardText1 => _t(
        'Напишите или скажите, что нужно и когда удобно. ИИ подберёт специалиста и свободное время.',
        'Эмне керек жана качан ыңгайлуу экенин жазыңыз же айтыңыз. ЖИ адисти жана бош убакытты тандайт.',
        'Type or say what you need and when. AI finds the right specialist and a free time.',
      );
  String get onboardTitle2 => _t('Все услуги города', 'Шаардын бардык кызматтары', 'All city services');
  String get onboardText2 => _t(
        'Стоматология, барбершоп, салон красоты, автосервис и другие — в одном приложении.',
        'Стоматология, барбершоп, сулуулук салону, автосервис жана башкалар — бир тиркемеде.',
        'Dentists, barbers, beauty salons, car services and more — in one app.',
      );
  String get onboardTitle3 => _t('Для бизнеса', 'Бизнес үчүн', 'For business');
  String get onboardText3 => _t(
        'Владельцы получают ИИ-администратора: он принимает записи 24/7, а вы видите расписание и выручку.',
        'Ээлери ЖИ-администратор алышат: ал жазылууларды 24/7 кабыл алат, сиз графикти жана кирешени көрөсүз.',
        'Owners get an AI administrator: it takes bookings 24/7 while you see the schedule and revenue.',
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
  String get roleCustomer => _t('Я клиент', 'Кардар', 'Client');
  String get roleOwner => _t('Я владелец', 'Бизнес ээси', 'Owner');
  String get demoTitle => _t('Быстрый вход для демо', 'Демо үчүн тез кирүү', 'Quick demo sign-in');
  String get demoCustomer => _t('Клиент', 'Кардар', 'Client');
  String get demoOwner => _t('Владелец', 'Ээси', 'Owner');
  String get server => _t('Сервер', 'Сервер', 'Server');
  String get serverAddress => _t('Адрес сервера', 'Сервердин дареги', 'Server address');
  String get serverHint => _t(
        'Пусто — адрес по умолчанию',
        'Бош — демейки дарек',
        'Empty means the default address',
      );

  // ------------------------------------------------------------ customer
  String get tabCatalog => _t('Каталог', 'Каталог', 'Explore');
  String get tabAssistant => _t('Ассистент', 'Ассистент', 'Assistant');
  String get tabAppointments => _t('Записи', 'Жазылуулар', 'Bookings');
  String get tabProfile => _t('Профиль', 'Профиль', 'Profile');
  String get titleAssistant => _t('ИИ-администратор', 'ЖИ-администратор', 'AI administrator');
  String get titleAppointments => _t('Мои записи', 'Менин жазылууларым', 'My bookings');
  String hello(String name) => _t('Здравствуйте, $name', 'Саламатсызбы, $name', 'Hello, $name');

  String get searchHint => _t('Услуга, мастер или место', 'Кызмат, уста же жай', 'Service, specialist or place');
  String get promoTitle => _t('Запишитесь одной фразой', 'Бир сүйлөм менен жазылыңыз', 'Book with one sentence');
  String get promoText => _t(
        'Напишите ИИ-администратору, что нужно и когда удобно',
        'ЖИ-администраторго эмне керек жана качан ыңгайлуу экенин жазыңыз',
        'Tell the AI administrator what you need and when',
      );
  String get nothingFound => _t('Ничего не найдено', 'Эч нерсе табылган жок', 'Nothing found');
  String get openAssistant => _t('Написать', 'Жазуу', 'Start');

  String get services => _t('Услуги', 'Кызматтар', 'Services');
  String get specialists => _t('Специалисты', 'Адистер', 'Specialists');
  String get reviews => _t('Отзывы', 'Пикирлер', 'Reviews');
  String get noReviews => _t('Пока нет отзывов', 'Азырынча пикир жок', 'No reviews yet');
  String get noServicesYet => _t('Услуги пока не добавлены', 'Кызматтар азырынча кошулган жок', 'No services yet');
  String get book => _t('Записаться', 'Жазылуу', 'Book');
  String get askAi => _t('Спросить ИИ-администратора', 'ЖИ-администратордон суроо', 'Ask the AI administrator');

  String get specialist => _t('Специалист', 'Адис', 'Specialist');
  String get anySpecialist => _t('Любой', 'Каалаган', 'Any');
  String get date => _t('Дата', 'Күнү', 'Date');
  String get time => _t('Время', 'Убактысы', 'Time');
  String get noSlots => _t(
        'На этот день свободного времени нет',
        'Бул күнү бош убакыт жок',
        'No free time on this day',
      );
  String bookAt(String time) => _t('Записаться на $time', '$time жазылуу', 'Book at $time');
  String moveAt(String time) => _t('Перенести на $time', '$time которуу', 'Move to $time');
  String bookClientAt(String time) => _t('Записать на $time', '$time жазуу', 'Book for $time');
  String get chooseTime => _t('Выберите время', 'Убакытты тандаңыз', 'Choose a time');
  String get bookingDone => _t('Вы записаны!', 'Сиз жазылдыңыз!', 'You are booked!');
  String get bookingMoved => _t('Запись перенесена', 'Жазылуу которулду', 'Booking moved');
  String get bookingCreated => _t('Запись создана', 'Жазылуу түзүлдү', 'Booking created');
  String get clientName => _t('Имя клиента', 'Кардардын аты', 'Client name');
  String get phone => _t('Телефон', 'Телефон', 'Phone');

  // ---------------------------------------------------------------- chat
  String greeting(String userName) {
    final who = userName.isEmpty ? '' : ', $userName';
    return _t(
      'Здравствуйте$who! Я ИИ-администратор Smile AI. Запишу к стоматологу, в барбершоп, салон красоты, '
          'автосервис и не только. Напишите или скажите, что нужно и когда удобно.',
      'Саламатсызбы$who! Мен Smile AI ЖИ-администраторумун. Тиш доктурга, барбершопко, сулуулук салонуна, '
          'автосервиске жана башкаларга жазам. Эмне керек жана качан ыңгайлуу экенин жазыңыз же айтыңыз.',
      'Hello$who! I am the Smile AI administrator. I can book a dentist, a barber, a beauty salon, '
          'a car service and more. Type or say what you need and when.',
    );
  }

  String greetingBusiness(String business) => _t(
        'Здравствуйте! Я ИИ-администратор «$business». Подскажу цены, найду свободное время и запишу вас.',
        'Саламатсызбы! Мен «$business» ЖИ-администраторумун. Бааларды айтып, бош убакыт таап, сизди жазам.',
        'Hello! I am the AI administrator of $business. I can tell prices, find a free time and book you.',
      );

  String get inputHint => _t('Напишите или скажите…', 'Жазыңыз же айтыңыз…', 'Type or speak…');
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
  String booked(String place) => _t(
        'Готово! Вы записаны в «$place». Ждём вас!',
        'Даяр! Сиз «$place» жазылдыңыз. Күтөбүз!',
        'Done! You are booked at $place. See you!',
      );
  String moved(String place) => _t(
        'Готово! Запись в «$place» перенесена.',
        'Даяр! «$place» жазылуусу которулду.',
        'Done! Your booking at $place was moved.',
      );
  String get bookingConfirmed => _t('Запись подтверждена', 'Жазылуу ырасталды', 'Booking confirmed');

  /// Quick prompts under the chat. The offline assistant understands Russian
  /// and English, so the Kyrgyz interface keeps the Russian prompts.
  List<String> suggestions(String? category) {
    if (lang == AppLang.en) {
      return switch (category) {
        'dental' => ['Toothache, tomorrow afternoon', 'Teeth whitening on Saturday'],
        'barber' => ['Haircut tomorrow morning', 'Beard trim on Friday'],
        'auto' => ['Oil change on Friday', 'Car diagnostics tomorrow'],
        _ => ['Toothache, tomorrow afternoon', 'Haircut on Saturday morning', 'Oil change on Friday', 'My bookings'],
      };
    }
    return switch (category) {
      'dental' => ['Болит зуб, завтра после обеда', 'Чистка зубов в субботу утром', 'Детский приём'],
      'clinic' => ['Приём терапевта завтра', 'УЗИ в пятницу утром'],
      'barber' => ['Стрижка завтра утром', 'Борода в пятницу', 'Стрижка и борода'],
      'beauty' => ['Маникюр завтра вечером', 'Брови в субботу', 'Окрашивание волос'],
      'massage' => ['Массаж спины сегодня вечером', 'СПА-программа в субботу'],
      'fitness' => ['Персональная тренировка завтра утром', 'Йога в субботу'],
      'auto' => ['Замена масла в пятницу', 'Диагностика завтра утром', 'Шиномонтаж в субботу'],
      'carwash' => ['Помыть машину сегодня', 'Химчистка в субботу'],
      'tutor' => ['Английский завтра вечером', 'Подготовка к ОРТ в субботу'],
      'vet' => ['Вакцинация кошки завтра', 'Груминг в субботу'],
      _ => ['Болит зуб, завтра после обеда', 'Стрижка в субботу утром', 'Маникюр завтра', 'Мои записи'],
    };
  }

  // -------------------------------------------------------- appointments
  String get upcoming => _t('Предстоящие', 'Алдыдагы', 'Upcoming');
  String get history => _t('История', 'Тарых', 'History');
  String get noUpcoming => _t('Нет предстоящих записей', 'Алдыдагы жазылуу жок', 'No upcoming bookings');
  String get noHistory => _t('История пока пуста', 'Тарых азырынча бош', 'No history yet');
  String get noAppointmentsHint => _t(
        'Напишите ассистенту, что нужно и когда удобно — он запишет вас за секунды.',
        'Ассистентке эмне керек жана качан ыңгайлуу экенин жазыңыз — ал сизди бир нече секундда жазат.',
        'Tell the assistant what you need and when — it books you in seconds.',
      );
  String get cancelQuestion => _t('Отменить запись?', 'Жазылууну жокко чыгарасызбы?', 'Cancel this booking?');
  String get cancel => _t('Отменить', 'Жокко чыгаруу', 'Cancel booking');
  String get reschedule => _t('Перенести', 'Которуу', 'Reschedule');
  String get rate => _t('Оценить', 'Баалоо', 'Rate');
  String get rateTitle => _t('Как всё прошло?', 'Кандай өттү?', 'How was it?');
  String get reviewHint => _t('Комментарий (необязательно)', 'Комментарий (милдеттүү эмес)', 'Comment (optional)');
  String get send => _t('Отправить', 'Жөнөтүү', 'Send');
  String status(String id) => switch (id) {
        'booked' => _t('Записан', 'Жазылган', 'Booked'),
        'completed' => _t('Завершена', 'Аяктады', 'Completed'),
        'cancelled' => _t('Отменена', 'Жокко чыгарылды', 'Cancelled'),
        'no_show' => _t('Не пришёл', 'Келген жок', 'No-show'),
        _ => id,
      };

  // ------------------------------------------------------------- profile
  String get settings => _t('Настройки', 'Жөндөөлөр', 'Settings');
  String get theme => _t('Тема', 'Тема', 'Theme');
  String get themeSystem => _t('Авто', 'Авто', 'Auto');
  String get themeLight => _t('Светлая', 'Жарык', 'Light');
  String get themeDark => _t('Тёмная', 'Караңгы', 'Dark');
  String get language => _t('Язык', 'Тил', 'Language');
  String get logout => _t('Выйти', 'Чыгуу', 'Sign out');
  String get accountClient => _t('Аккаунт клиента', 'Кардар аккаунту', 'Client account');
  String get accountOwner => _t('Аккаунт владельца', 'Ээсинин аккаунту', 'Owner account');
  String get about => _t(
        'Smile AI — запись в любые сервисы города одной фразой.',
        'Smile AI — шаардын каалаган кызматына бир сүйлөм менен жазылуу.',
        'Smile AI — book any city service with one sentence.',
      );

  // --------------------------------------------------------------- owner
  String get tabToday => _t('Сегодня', 'Бүгүн', 'Today');
  String get tabBusiness => _t('Бизнес', 'Бизнес', 'Business');
  String get setupTitle => _t('Расскажите о бизнесе', 'Бизнесиңиз жөнүндө айтыңыз', 'Tell us about your business');
  String get setupText => _t(
        'ИИ-администратор начнёт принимать записи сразу после создания.',
        'ЖИ-администратор түзүлгөндөн кийин дароо жазылууларды кабыл ала баштайт.',
        'The AI administrator starts taking bookings right after you create it.',
      );
  String get niche => _t('Ниша', 'Тармак', 'Category');
  String get businessName => _t('Название', 'Аталышы', 'Name');
  String get enterBusinessName => _t('Введите название', 'Аталышын жазыңыз', 'Enter the name');
  String get address => _t('Адрес', 'Дареги', 'Address');
  String get description => _t('Описание', 'Сүрөттөмө', 'Description');
  String get opensAt => _t('Открытие', 'Ачылышы', 'Opens');
  String get closesAt => _t('Закрытие', 'Жабылышы', 'Closes');
  String get workingDays => _t('Рабочие дни', 'Иш күндөрү', 'Working days');
  String get useTemplate => _t(
        'Добавить типовые услуги ниши',
        'Тармактын типтүү кызматтарын кошуу',
        'Add typical services for this category',
      );
  String get createBusiness => _t('Создать бизнес', 'Бизнес түзүү', 'Create business');

  String get kpiToday => _t('Записей сегодня', 'Бүгүнкү жазылуулар', 'Bookings today');
  String get kpiRevenueToday => _t('Выручка сегодня', 'Бүгүнкү киреше', 'Revenue today');
  String get kpiWeek => _t('Записей за 7 дней', '7 күндөгү жазылуулар', 'Bookings in 7 days');
  String get kpiRevenueWeek => _t('Выручка за 7 дней', '7 күндүк киреше', 'Revenue in 7 days');
  String get kpiAi => _t('Принял ИИ', 'ЖИ кабыл алды', 'Taken by AI');
  String get kpiRating => _t('Рейтинг', 'Рейтинг', 'Rating');
  String get kpiLoad => _t('Загрузка сегодня', 'Бүгүнкү жүктөм', 'Load today');
  String get kpiUpcoming => _t('Записей впереди', 'Алдыдагы жазылуулар', 'Bookings ahead');
  String get weekTitle => _t('За 7 дней', '7 күндө', 'Last 7 days');
  String get chartTitle => _t('Записи по дням', 'Күндөр боюнча жазылуулар', 'Bookings by day');
  String get topServices => _t('Популярные услуги', 'Популярдуу кызматтар', 'Top services');
  String get todaySchedule => _t('Расписание на сегодня', 'Бүгүнкү график', "Today's schedule");
  String get noBookingsDay => _t('На этот день записей нет', 'Бул күнгө жазылуу жок', 'No bookings for this day');

  String get newBooking => _t('Новая запись', 'Жаңы жазылуу', 'New booking');
  String get chooseService => _t('Выберите услугу', 'Кызматты тандаңыз', 'Choose a service');
  String get markCompleted => _t('Завершить', 'Аяктоо', 'Complete');
  String get markNoShow => _t('Не пришёл', 'Келген жок', 'No-show');
  String get restore => _t('Вернуть', 'Кайтаруу', 'Restore');
  String source(String id) => switch (id) {
        'chat' => _t('ИИ', 'ЖИ', 'AI'),
        'owner' => _t('Вручную', 'Кол менен', 'Manual'),
        _ => _t('Каталог', 'Каталог', 'Catalog'),
      };

  String get staff => _t('Мастера', 'Усталар', 'Staff');
  String get addService => _t('Добавить услугу', 'Кызмат кошуу', 'Add service');
  String get addSpecialist => _t('Добавить мастера', 'Уста кошуу', 'Add specialist');
  String get editService => _t('Услуга', 'Кызмат', 'Service');
  String get editSpecialist => _t('Мастер', 'Уста', 'Specialist');
  String get serviceName => _t('Название услуги', 'Кызматтын аталышы', 'Service name');
  String get duration => _t('Длительность', 'Узактыгы', 'Duration');
  String get price => _t('Цена, сом', 'Баасы, сом', 'Price, KGS');
  String get performedBy => _t('Кто выполняет', 'Ким аткарат', 'Performed by');
  String get specialistName => _t('Имя', 'Аты', 'Name');
  String get specialistTitle => _t('Должность', 'Кызматы', 'Title');
  String get noServices => _t(
        'Добавьте первую услугу, и клиенты смогут записываться',
        'Биринчи кызматты кошуңуз, ошондо кардарлар жазыла алат',
        'Add your first service so clients can book',
      );

  String get acceptBookings => _t('Принимать записи', 'Жазылууларды кабыл алуу', 'Accept bookings');
  String get acceptBookingsHint => _t(
        'Когда выключено, бизнес скрыт из каталога',
        'Өчүрүлгөндө бизнес каталогдон жашырылат',
        'When off, the business is hidden from the catalog',
      );
  String get hiddenBanner => _t(
        'Бизнес скрыт из каталога: приём записей выключен на вкладке «Бизнес».',
        'Бизнес каталогдон жашырылган: жазылууларды кабыл алуу «Бизнес» бөлүмүндө өчүрүлгөн.',
        'The business is hidden from the catalog: bookings are turned off on the Business tab.',
      );
  String deleteQuestion(String name) => _t('Удалить «$name»?', '«$name» өчүрүлсүнбү?', 'Delete $name?');
}
