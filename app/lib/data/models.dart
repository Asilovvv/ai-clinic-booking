import 'package:equatable/equatable.dart';

import '../core/formatters.dart';

class User extends Equatable {
  const User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  final int id;
  final String name;
  final String email;

  @override
  List<Object?> get props => [id, name, email];
}

/// A kind of business the assistant can book: dental clinic, barbershop, car service.
class Category extends Equatable {
  const Category({required this.id, required this.title, required this.place});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        title: json['title'] as String,
        place: json['place'] as String,
      );

  final String id;
  final String title;
  final String place;

  @override
  List<Object?> get props => [id];
}

/// A specialist: dentist, barber or mechanic.
class Doctor extends Equatable {
  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.title,
    required this.description,
    this.category = 'dental',
  });

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'] as int,
        name: json['name'] as String,
        specialty: json['specialty'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String? ?? 'dental',
      );

  final int id;
  final String name;
  final String specialty;
  final String title;
  final String description;
  final String category;

  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join();

  @override
  List<Object?> get props => [id];
}

class Slot extends Equatable {
  const Slot({
    required this.doctorId,
    required this.doctorName,
    required this.doctorTitle,
    required this.start,
    this.category = 'dental',
  });

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        doctorId: json['doctor_id'] as int,
        doctorName: json['doctor_name'] as String,
        doctorTitle: json['doctor_title'] as String,
        start: DateTime.parse(json['start'] as String),
        category: json['category'] as String? ?? 'dental',
      );

  final int doctorId;
  final String doctorName;
  final String doctorTitle;
  final DateTime start;
  final String category;

  /// Unique key of a slot: one doctor, one start time.
  String get key => '$doctorId|${formatApiDate(start)}';

  @override
  List<Object?> get props => [doctorId, start];
}

class Appointment extends Equatable {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.doctorTitle,
    required this.start,
    this.category = 'dental',
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as int,
        doctorId: json['doctor_id'] as int,
        doctorName: json['doctor_name'] as String,
        doctorTitle: json['doctor_title'] as String,
        start: DateTime.parse(json['start'] as String),
        category: json['category'] as String? ?? 'dental',
      );

  final int id;
  final int doctorId;
  final String doctorName;
  final String doctorTitle;
  final DateTime start;
  final String category;

  @override
  List<Object?> get props => [id, doctorId, start];
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

  /// When set, tapping a slot moves this appointment instead of creating a new one.
  final int? rescheduleId;
  final bool isError;

  ChatMessage withoutSlots() => ChatMessage(
        role: role,
        text: text,
        appointment: appointment,
        isError: isError,
      );

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
        slots: (json['slots'] as List? ?? [])
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

  /// Appointment the offered slots are meant to move, if any.
  final int? rescheduleId;

  /// The assistant booked, moved or cancelled something on the server.
  final bool changed;
}
