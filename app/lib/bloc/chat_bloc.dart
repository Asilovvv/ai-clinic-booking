import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/strings.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';

// ---------------------------------------------------------------- events

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// The client typed or dictated a message.
final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.text, {this.doctorId});

  final String text;

  /// Set when the request is about one specific specialist.
  final int? doctorId;

  @override
  List<Object?> get props => [text, doctorId];
}

/// The client tapped a slot card suggested by the assistant.
final class ChatSlotSelected extends ChatEvent {
  const ChatSlotSelected(this.slot, {this.rescheduleId});

  final Slot slot;

  /// Appointment to move to this slot; null means "create a new booking".
  final int? rescheduleId;

  @override
  List<Object?> get props => [slot, rescheduleId];
}

/// The client picked a business category (null = all).
final class ChatCategorySelected extends ChatEvent {
  const ChatCategorySelected(this.category);

  final String? category;

  @override
  List<Object?> get props => [category];
}

// ----------------------------------------------------------------- state

const _unset = Object();

class ChatState extends Equatable {
  const ChatState({
    required this.messages,
    this.isTyping = false,
    this.bookingKey,
    this.mode = 'rules',
    this.category,
    this.revision = 0,
  });

  final List<ChatMessage> messages;

  /// The assistant is "typing" (waiting for the server).
  final bool isTyping;

  /// Key of the slot currently being booked, null when idle.
  final String? bookingKey;

  /// "ai" or "rules" — which assistant answered last.
  final String mode;

  /// Selected business category id, null for all.
  final String? category;

  /// Grows every time the chat changed bookings on the server,
  /// so other screens know they must reload.
  final int revision;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    Object? bookingKey = _unset,
    String? mode,
    Object? category = _unset,
    int? revision,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      bookingKey: identical(bookingKey, _unset) ? this.bookingKey : bookingKey as String?,
      mode: mode ?? this.mode,
      category: identical(category, _unset) ? this.category : category as String?,
      revision: revision ?? this.revision,
    );
  }

  @override
  List<Object?> get props => [messages, isTyping, bookingKey, mode, category, revision];
}

// ------------------------------------------------------------------ bloc

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._repository, {String userName = '', AppStrings Function()? strings})
      : _strings = strings ?? (() => const AppStrings(AppLang.ru)),
        super(ChatState(messages: [
          ChatMessage.assistant((strings?.call() ?? const AppStrings(AppLang.ru)).greeting(userName)),
        ])) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatSlotSelected>(_onSlotSelected);
    on<ChatCategorySelected>((event, emit) => emit(state.copyWith(category: event.category)));
  }

  final ClinicRepository _repository;

  /// Current interface texts (the language can change while the app runs).
  final AppStrings Function() _strings;

  Future<void> _onMessageSent(ChatMessageSent event, Emitter<ChatState> emit) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isTyping) return;

    final history = state.messages;
    emit(state.copyWith(messages: [...history, ChatMessage.user(text)], isTyping: true));
    try {
      final reply = await _repository.chat(
        text,
        history,
        category: state.category,
        doctorId: event.doctorId,
      );
      final changed = reply.changed || reply.appointment != null;
      emit(state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.assistant(
            reply.reply,
            slots: reply.slots,
            appointment: reply.appointment,
            rescheduleId: reply.rescheduleId,
          ),
        ],
        isTyping: false,
        mode: reply.mode,
        revision: changed ? state.revision + 1 : state.revision,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        messages: [...state.messages, ChatMessage.error(e.message)],
        isTyping: false,
      ));
    }
  }

  Future<void> _onSlotSelected(ChatSlotSelected event, Emitter<ChatState> emit) async {
    if (state.bookingKey != null) return;
    final slot = event.slot;
    final s = _strings();
    final day = formatDay(slot.start, s.lang);
    final time = formatTime(slot.start);
    final moving = event.rescheduleId != null;

    emit(state.copyWith(bookingKey: slot.key));
    try {
      final appointment = moving
          ? await _repository.reschedule(event.rescheduleId!, slot)
          : await _repository.book(slot);
      // Old suggestions are stale once something is booked.
      final cleared = state.messages.map((m) => m.slots.isEmpty ? m : m.withoutSlots()).toList();
      emit(state.copyWith(
        messages: [
          ...cleared,
          ChatMessage.user(moving ? s.moveTo(day, time) : s.bookMe(day, time)),
          ChatMessage.assistant(
            moving ? s.moved(appointment.doctorName) : s.booked(appointment.doctorName),
            appointment: appointment,
          ),
        ],
        bookingKey: null,
        revision: state.revision + 1,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        messages: [...state.messages, ChatMessage.error(e.message)],
        bookingKey: null,
      ));
    }
  }
}
