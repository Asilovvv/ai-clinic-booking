import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../bloc/appointments_bloc.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/catalog_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/strings.dart';
import '../../data/booking_repository.dart';
import '../../data/models.dart';
import '../widgets/chat_widgets.dart';
import '../widgets/common.dart';

/// The conversation with the AI administrator: messages, slot cards, quick
/// prompts and the input row with voice. Needs a [ChatBloc] above it.
class ChatView extends StatefulWidget {
  const ChatView({super.key, this.scopeCategory});

  /// Niche of the business this chat belongs to. Null for the city-wide
  /// assistant, which shows the row of niches instead.
  final String? scopeCategory;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

  bool get _scoped => widget.scopeCategory != null;

  @override
  void dispose() {
    if (_speechReady) _speech.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _input.text;
    if (text.trim().isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(text));
    _input.clear();
  }

  /// Voice input: the recognized phrase is sent as soon as the client stops talking.
  Future<void> _toggleMic() async {
    final settings = context.read<SettingsCubit>().state;
    final messenger = ScaffoldMessenger.of(context);
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      _speechReady = _speechReady ||
          await _speech.initialize(
            onStatus: (status) {
              if (mounted && (status == 'done' || status == 'notListening')) {
                setState(() => _listening = false);
              }
            },
            onError: (_) {
              if (mounted) setState(() => _listening = false);
            },
          );
    } catch (_) {
      _speechReady = false;
    }
    if (!_speechReady) {
      messenger.showSnackBar(SnackBar(content: Text(settings.strings.micUnavailable)));
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: settings.lang.speechLocale),
      onResult: (result) {
        if (!mounted) return;
        _input.text = result.recognizedWords;
        if (result.finalResult) {
          setState(() => _listening = false);
          _send();
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (!_scoped) const _CategoryBar(),
        Expanded(
          child: BlocConsumer<ChatBloc, ChatState>(
            listenWhen: (prev, curr) =>
                prev.messages.length != curr.messages.length || prev.isTyping != curr.isTyping,
            listener: (context, state) => _scrollToBottom(),
            builder: (context, state) {
              final count = state.messages.length + (state.isTyping ? 1 : 0);
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                itemCount: count,
                itemBuilder: (context, index) {
                  if (index == state.messages.length) return const TypingIndicator();
                  return MessageBubble(
                    message: state.messages[index],
                    bookingKey: state.bookingKey,
                    showBusiness: !_scoped,
                    onSlotTap: (slot, rescheduleId) =>
                        context.read<ChatBloc>().add(ChatSlotSelected(slot, rescheduleId: rescheduleId)),
                  );
                },
              );
            },
          ),
        ),
        BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (prev, curr) =>
              prev.messages.length != curr.messages.length || prev.category != curr.category,
          builder: (context, state) {
            // Quick prompts are a way to start; they leave once the talk is going.
            if (state.messages.length > 1) return const SizedBox.shrink();
            final suggestions = strings.suggestions(widget.scopeCategory ?? state.category);
            return SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(suggestions[i]),
                  onPressed: () => _send(suggestions[i]),
                ),
              ),
            );
          },
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _listening ? strings.listening : strings.inputHint,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  iconSize: 24,
                  padding: const EdgeInsets.all(12),
                  style: _listening
                      ? IconButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        )
                      : null,
                  onPressed: _toggleMic,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                ),
                const SizedBox(width: 6),
                BlocBuilder<ChatBloc, ChatState>(
                  buildWhen: (prev, curr) => prev.isTyping != curr.isTyping,
                  builder: (context, state) => IconButton.filled(
                    iconSize: 24,
                    padding: const EdgeInsets.all(12),
                    onPressed: state.isTyping ? null : () => _send(),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Row of niches; the selected one narrows the assistant's search.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context) {
    final categories = context.select((CatalogBloc bloc) => bloc.state.categories);
    final selected = context.select((ChatBloc bloc) => bloc.state.category);
    if (categories.isEmpty) return const SizedBox.shrink();
    return CategoryChips(
      categories: categories,
      selected: selected,
      onSelected: (id) => context.read<ChatBloc>().add(ChatCategorySelected(id)),
    );
  }
}

/// Marks answers written by a language model. The built-in assistant, which
/// works without one, shows nothing.
class AssistantModeChip extends StatelessWidget {
  const AssistantModeChip({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select((ChatBloc bloc) => bloc.state.mode);
    if (mode != 'ai') return const SizedBox.shrink();
    return const Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(Icons.bolt, size: 16),
      label: Text('AI'),
    );
  }
}

/// The AI administrator of one business, opened from the business page.
class BusinessChatPage extends StatelessWidget {
  const BusinessChatPage({super.key, required this.business});

  final Business business;

  static Route<void> route(Business business) =>
      MaterialPageRoute(builder: (_) => BusinessChatPage(business: business));

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final settings = context.read<SettingsCubit>();
    final auth = context.read<AuthBloc>().state;
    return BlocProvider(
      create: (context) => ChatBloc(
        context.read<BookingRepository>(),
        userName: auth is AuthAuthenticated ? auth.user.name : '',
        strings: () => settings.state.strings,
        businessId: business.id,
        businessName: business.name,
      ),
      child: BlocListener<ChatBloc, ChatState>(
        // Anything booked here must show up in "My bookings".
        listenWhen: (prev, curr) => prev.revision != curr.revision,
        listener: (context, state) => context.read<AppointmentsBloc>().add(const AppointmentsRequested()),
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(business.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(strings.titleAssistant, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            actions: const [AssistantModeChip(), SizedBox(width: 12)],
          ),
          body: ChatView(scopeCategory: business.category),
        ),
      ),
    );
  }
}
