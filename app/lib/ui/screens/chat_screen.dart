import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../bloc/chat_bloc.dart';
import '../../bloc/doctors_bloc.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/strings.dart';
import '../theme.dart';
import '../widgets/chat_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;

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
      localeId: settings.lang.speechLocale,
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
        const _CategoryBar(),
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
                    onSlotTap: (slot, rescheduleId) => context
                        .read<ChatBloc>()
                        .add(ChatSlotSelected(slot, rescheduleId: rescheduleId)),
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
            if (state.messages.length > 1) return const SizedBox.shrink();
            final suggestions = strings.suggestions(state.category);
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

/// Row of business categories; the selected one narrows the assistant's search.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final categories = context.select((DoctorsBloc bloc) => bloc.state.categories);
    final selected = context.select((ChatBloc bloc) => bloc.state.category);
    if (categories.isEmpty) return const SizedBox.shrink();

    Widget chip(String? id, String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            avatar: Icon(categoryIcon(id), size: 18),
            showCheckmark: false,
            label: Text(label),
            selected: selected == id,
            onSelected: (_) => context.read<ChatBloc>().add(ChatCategorySelected(id)),
          ),
        );

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          chip(null, strings.all),
          for (final category in categories) chip(category.id, category.title),
        ],
      ),
    );
  }
}
