import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';

// ---------------------------------------------------------------- events

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// The patient typed a message.
final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// The patient tapped a slot card suggested by the assistant.
final class ChatSlotSelected extends ChatEvent {
  const ChatSlotSelected(this.slot);

  final Slot slot;

  @override
  List<Object?> get props => [slot];
}

// ----------------------------------------------------------------- state

const _unset = Object();

class ChatState extends Equatable {
  const ChatState({
    required this.messages,
    this.isTyping = false,
    this.bookingKey,
    this.mode = 'rules',
    this.lastBooked,
  });

  factory ChatState.initial(String userName) => ChatState(messages: [
        ChatMessage.assistant(
          'Здравствуйте${userName.isEmpty ? '' : ', $userName'}! '
          'Я ИИ-администратор клиники Smile. Опишите, что беспокоит и когда удобно прийти — '
          'я подберу врача и свободное время.',
        ),
      ]);

  final List<ChatMessage> messages;

  /// The assistant is "typing" (waiting for the server).
  final bool isTyping;

  /// Key of the slot currently being booked, null when idle.
  final String? bookingKey;

  /// "ai" or "rules" — which assistant answered last.
  final String mode;

  /// Most recent appointment created from the chat.
  final Appointment? lastBooked;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isTyping,
    Object? bookingKey = _unset,
    String? mode,
    Appointment? lastBooked,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      bookingKey: identical(bookingKey, _unset) ? this.bookingKey : bookingKey as String?,
      mode: mode ?? this.mode,
      lastBooked: lastBooked ?? this.lastBooked,
    );
  }

  @override
  List<Object?> get props => [messages, isTyping, bookingKey, mode, lastBooked];
}

// ------------------------------------------------------------------ bloc

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._repository, {String userName = ''}) : super(ChatState.initial(userName)) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatSlotSelected>(_onSlotSelected);
  }

  final ClinicRepository _repository;

  Future<void> _onMessageSent(ChatMessageSent event, Emitter<ChatState> emit) async {
    final text = event.text.trim();
    if (text.isEmpty || state.isTyping) return;

    final history = state.messages;
    emit(state.copyWith(messages: [...history, ChatMessage.user(text)], isTyping: true));
    try {
      final reply = await _repository.chat(text, history);
      emit(state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.assistant(reply.reply, slots: reply.slots, appointment: reply.appointment),
        ],
        isTyping: false,
        mode: reply.mode,
        lastBooked: reply.appointment,
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
    emit(state.copyWith(bookingKey: slot.key));
    try {
      final appointment = await _repository.book(slot);
      // Old suggestions are stale once something is booked.
      final cleared = state.messages.map((m) => m.slots.isEmpty ? m : m.withoutSlots()).toList();
      emit(state.copyWith(
        messages: [
          ...cleared,
          ChatMessage.user('Запишите меня: ${formatDay(slot.start)}, ${formatTime(slot.start)}'),
          ChatMessage.assistant(
            'Готово! Вы записаны к врачу ${appointment.doctorName}. Ждём вас в клинике Smile.',
            appointment: appointment,
          ),
        ],
        bookingKey: null,
        lastBooked: appointment,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        messages: [...state.messages, ChatMessage.error(e.message)],
        bookingKey: null,
      ));
    }
  }
}
