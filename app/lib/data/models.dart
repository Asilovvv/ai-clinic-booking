import 'package:equatable/equatable.dart';

import '../core/formatters.dart';

List<int> _ints(dynamic value) => (value as List? ?? const []).map((e) => e as int).toList();

class User extends Equatable {
  const User({required this.id, required this.name, required this.email, this.role = 'customer'});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String? ?? 'customer',
      );

  final int id;
  final String name;
  final String email;

  /// "customer" or "owner".
  final String role;

  bool get isOwner => role == 'owner';

  @override
  List<Object?> get props => [id, name, email, role];
}

/// A niche: dental, barbershop, car service...
class Category extends Equatable {
  const Category({required this.id, required this.title});

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(id: json['id'] as String, title: json['title'] as String);

  final String id;
  final String title;

  @override
  List<Object?> get props => [id];
}

/// A person or a resource (a wash bay) that performs services.
class Specialist extends Equatable {
  const Specialist({required this.id, required this.name, this.title = ''});

  factory Specialist.fromJson(Map<String, dynamic> json) => Specialist(
        id: json['id'] as int,
        name: json['name'] as String,
        title: json['title'] as String? ?? '',
      );

  final int id;
  final String name;
  final String title;

  String get initials =>
      name.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

  @override
  List<Object?> get props => [id, name, title];
}

class Service extends Equatable {
  const Service({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.price,
    this.description = '',
    this.specialistIds = const [],
  });

  factory Service.fromJson(Map<String, dynamic> json) => Service(
        id: json['id'] as int,
        name: json['name'] as String,
        durationMin: json['duration_min'] as int,
        price: json['price'] as int,
        description: json['description'] as String? ?? '',
        specialistIds: _ints(json['specialist_ids']),
      );

  final int id;
  final String name;
  final int durationMin;
  final int price;
  final String description;

  /// Who performs the service.
  final List<int> specialistIds;

  @override
  List<Object?> get props => [id, name, durationMin, price, description, specialistIds];
}

class Review extends Equatable {
  const Review({required this.rating, required this.comment, required this.author});

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        rating: json['rating'] as int,
        comment: json['comment'] as String? ?? '',
        author: json['author'] as String? ?? '',
      );

  final int rating;
  final String comment;
  final String author;

  @override
  List<Object?> get props => [rating, comment, author];
}

/// A business. Lists in the catalog carry the summary; one loaded on its own
/// also has services, specialists and reviews.
class Business extends Equatable {
  const Business({
    required this.id,
    required this.category,
    required this.name,
    this.description = '',
    this.address = '',
    this.phone = '',
    this.openHour = 9,
    this.closeHour = 18,
    this.workingDays = const [0, 1, 2, 3, 4, 5],
    this.isActive = true,
    this.rating,
    this.reviewsCount = 0,
    this.priceFrom,
    this.searchText = '',
    this.services = const [],
    this.specialists = const [],
    this.reviews = const [],
  });

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json['id'] as int,
        category: json['category'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        openHour: json['open_hour'] as int? ?? 9,
        closeHour: json['close_hour'] as int? ?? 18,
        workingDays: _ints(json['working_days']),
        isActive: json['is_active'] as bool? ?? true,
        rating: (json['rating'] as num?)?.toDouble(),
        reviewsCount: json['reviews_count'] as int? ?? 0,
        priceFrom: json['price_from'] as int?,
        searchText: json['search_text'] as String? ?? '',
        services: (json['services'] as List? ?? const [])
            .map((e) => Service.fromJson(e as Map<String, dynamic>))
            .toList(),
        specialists: (json['specialists'] as List? ?? const [])
            .map((e) => Specialist.fromJson(e as Map<String, dynamic>))
            .toList(),
        reviews: (json['reviews'] as List? ?? const [])
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String category;
  final String name;
  final String description;
  final String address;
  final String phone;
  final int openHour;
  final int closeHour;

  /// 0 is Monday.
  final List<int> workingDays;
  final bool isActive;
  final double? rating;
  final int reviewsCount;
  final int? priceFrom;

  /// Lower-cased name, address and service names for the catalog search.
  final String searchText;
  final List<Service> services;
  final List<Specialist> specialists;
  final List<Review> reviews;

  @override
  List<Object?> get props => [
        id, category, name, description, address, phone, openHour, closeHour, workingDays,
        isActive, rating, reviewsCount, priceFrom, services, specialists, reviews,
      ];
}

/// A free start time of a service with a specialist.
class Slot extends Equatable {
  const Slot({
    required this.businessId,
    required this.businessName,
    required this.serviceId,
    required this.serviceName,
    required this.specialistId,
    required this.specialistName,
    required this.start,
    this.category = '',
    this.price = 0,
    this.durationMin = 30,
    this.specialistTitle = '',
  });

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        businessId: json['business_id'] as int,
        businessName: json['business_name'] as String,
        category: json['category'] as String? ?? '',
        serviceId: json['service_id'] as int,
        serviceName: json['service_name'] as String,
        price: json['price'] as int? ?? 0,
        durationMin: json['duration_min'] as int? ?? 30,
        specialistId: json['specialist_id'] as int,
        specialistName: json['specialist_name'] as String,
        specialistTitle: json['specialist_title'] as String? ?? '',
        start: DateTime.parse(json['start'] as String),
      );

  final int businessId;
  final String businessName;
  final String category;
  final int serviceId;
  final String serviceName;
  final int price;
  final int durationMin;
  final int specialistId;
  final String specialistName;
  final String specialistTitle;
  final DateTime start;

  /// Unique key of a slot: one service, one specialist, one start time.
  String get key => '$serviceId|$specialistId|${formatApiDate(start)}';

  @override
  List<Object?> get props => [serviceId, specialistId, start];
}

class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.serviceId,
    required this.serviceName,
    required this.specialistId,
    required this.specialistName,
    required this.start,
    this.category = '',
    this.price = 0,
    this.durationMin = 30,
    this.status = 'booked',
    this.source = 'app',
    this.clientName = '',
    this.clientPhone = '',
    this.upcoming = true,
    this.canReview = false,
    this.reviewRating,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as int,
        businessId: json['business_id'] as int,
        businessName: json['business_name'] as String,
        category: json['category'] as String? ?? '',
        serviceId: json['service_id'] as int,
        serviceName: json['service_name'] as String,
        price: json['price'] as int? ?? 0,
        durationMin: json['duration_min'] as int? ?? 30,
        specialistId: json['specialist_id'] as int,
        specialistName: json['specialist_name'] as String,
        start: DateTime.parse(json['start'] as String),
        status: json['status'] as String? ?? 'booked',
        source: json['source'] as String? ?? 'app',
        clientName: json['client_name'] as String? ?? '',
        clientPhone: json['client_phone'] as String? ?? '',
        upcoming: json['upcoming'] as bool? ?? false,
        canReview: json['can_review'] as bool? ?? false,
        reviewRating: (json['review'] as Map<String, dynamic>?)?['rating'] as int?,
      );

  final int id;
  final int businessId;
  final String businessName;
  final String category;
  final int serviceId;
  final String serviceName;
  final int price;
  final int durationMin;
  final int specialistId;
  final String specialistName;
  final DateTime start;

  /// booked, completed, cancelled or no_show.
  final String status;

  /// chat (taken by the AI), app (catalog) or owner (typed in by the owner).
  final String source;
  final String clientName;
  final String clientPhone;

  /// Still ahead and active.
  final bool upcoming;

  /// The visit is over and has not been rated yet.
  final bool canReview;
  final int? reviewRating;

  DateTime get end => start.add(Duration(minutes: durationMin));

  @override
  List<Object?> get props => [id, serviceId, specialistId, start, status, upcoming, canReview, reviewRating];
}

enum ChatRole { user, assistant }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.role,
    required this.text,
    this.slots = const [],
    this.appointment,
    this.rescheduleId,
    this.isError = false,
  });

  const ChatMessage.user(String text) : this(role: ChatRole.user, text: text);

  const ChatMessage.assistant(
    String text, {
    List<Slot> slots = const [],
    Appointment? appointment,
    int? rescheduleId,
  }) : this(
          role: ChatRole.assistant,
          text: text,
          slots: slots,
          appointment: appointment,
          rescheduleId: rescheduleId,
        );

  const ChatMessage.error(String text) : this(role: ChatRole.assistant, text: text, isError: true);

  final ChatRole role;
  final String text;
  final List<Slot> slots;
  final Appointment? appointment;

  /// When set, tapping a slot moves this booking instead of creating a new one.
  final int? rescheduleId;
  final bool isError;

  ChatMessage withoutSlots() =>
      ChatMessage(role: role, text: text, appointment: appointment, isError: isError);

  @override
  List<Object?> get props => [role, text, slots, appointment, rescheduleId, isError];
}

class ChatReply {
  const ChatReply({
    required this.reply,
    required this.slots,
    required this.appointment,
    required this.mode,
    this.rescheduleId,
    this.changed = false,
  });

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
        reply: json['reply'] as String,
        slots: (json['slots'] as List? ?? const [])
            .map((e) => Slot.fromJson(e as Map<String, dynamic>))
            .toList(),
        appointment: json['appointment'] == null
            ? null
            : Appointment.fromJson(json['appointment'] as Map<String, dynamic>),
        mode: json['mode'] as String? ?? 'rules',
        rescheduleId: json['reschedule_id'] as int?,
        changed: json['changed'] as bool? ?? false,
      );

  final String reply;
  final List<Slot> slots;
  final Appointment? appointment;

  /// "ai" when an LLM answered, "rules" for the offline assistant.
  final String mode;

  /// Booking the offered slots are meant to move, if any.
  final int? rescheduleId;

  /// The assistant booked, moved or cancelled something on the server.
  final bool changed;
}

class DayStat extends Equatable {
  const DayStat({required this.date, required this.count, required this.revenue});

  factory DayStat.fromJson(Map<String, dynamic> json) => DayStat(
        date: DateTime.parse(json['date'] as String),
        count: json['count'] as int,
        revenue: json['revenue'] as int,
      );

  final DateTime date;
  final int count;
  final int revenue;

  @override
  List<Object?> get props => [date, count, revenue];
}

class ServiceStat extends Equatable {
  const ServiceStat({required this.name, required this.count, required this.revenue});

  factory ServiceStat.fromJson(Map<String, dynamic> json) => ServiceStat(
        name: json['name'] as String,
        count: json['count'] as int,
        revenue: json['revenue'] as int,
      );

  final String name;
  final int count;
  final int revenue;

  @override
  List<Object?> get props => [name, count, revenue];
}

/// Numbers of the owner's dashboard.
class OwnerStats extends Equatable {
  const OwnerStats({
    this.todayCount = 0,
    this.todayRevenue = 0,
    this.loadPercent = 0,
    this.upcoming = 0,
    this.bookings = 0,
    this.revenue = 0,
    this.aiBookings = 0,
    this.rating,
    this.reviewsCount = 0,
    this.byDay = const [],
    this.topServices = const [],
    this.today = const [],
  });

  factory OwnerStats.fromJson(Map<String, dynamic> json) => OwnerStats(
        todayCount: json['today_count'] as int? ?? 0,
        todayRevenue: json['today_revenue'] as int? ?? 0,
        loadPercent: json['load_percent'] as int? ?? 0,
        upcoming: json['upcoming'] as int? ?? 0,
        bookings: json['bookings'] as int? ?? 0,
        revenue: json['revenue'] as int? ?? 0,
        aiBookings: json['ai_bookings'] as int? ?? 0,
        rating: (json['rating'] as num?)?.toDouble(),
        reviewsCount: json['reviews_count'] as int? ?? 0,
        byDay: (json['by_day'] as List? ?? const [])
            .map((e) => DayStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        topServices: (json['top_services'] as List? ?? const [])
            .map((e) => ServiceStat.fromJson(e as Map<String, dynamic>))
            .toList(),
        today: (json['today'] as List? ?? const [])
            .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int todayCount;
  final int todayRevenue;
  final int loadPercent;
  final int upcoming;

  /// Bookings and revenue of the last seven days.
  final int bookings;
  final int revenue;

  /// How many of those bookings the AI administrator took in the chat.
  final int aiBookings;
  final double? rating;
  final int reviewsCount;
  final List<DayStat> byDay;
  final List<ServiceStat> topServices;

  /// Today's schedule.
  final List<Appointment> today;

  int get aiPercent => bookings == 0 ? 0 : (100 * aiBookings / bookings).round();

  @override
  List<Object?> get props => [
        todayCount, todayRevenue, loadPercent, upcoming, bookings, revenue, aiBookings,
        rating, reviewsCount, byDay, topServices, today,
      ];
}
