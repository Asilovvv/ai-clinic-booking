import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/chat_bloc.dart';
import '../widgets/chat_widgets.dart';

const _suggestions = [
  'Болит зуб, завтра после обеда',
  'Чистка в субботу утром',
  'Брекеты, ближайшее время',
  'Ребёнку к стоматологу',
  'Мои записи',
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
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
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<ChatBloc, ChatState>(
            listenWhen: (prev, curr) =>
                prev.messages.length != curr.messages.length || prev.isTyping != curr.isTyping,
            listener: (context, state) => _scrollToBottom(),
            builder: (context, state) {
              final count = state.messages.length + (state.isTyping ? 1 : 0);
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: count,
                itemBuilder: (context, index) {
                  if (index == state.messages.length) return const TypingIndicator();
                  return MessageBubble(
                    message: state.messages[index],
                    bookingKey: state.bookingKey,
                    onSlotTap: (slot) => context.read<ChatBloc>().add(ChatSlotSelected(slot)),
                  );
                },
              );
            },
          ),
        ),
        BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (prev, curr) => prev.messages.length != curr.messages.length,
          builder: (context, state) {
            if (state.messages.length > 1) return const SizedBox.shrink();
            return SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(_suggestions[i]),
                  onPressed: () => _send(_suggestions[i]),
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
                    decoration: const InputDecoration(
                      hintText: 'Например: болит зуб, завтра после обеда',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BlocBuilder<ChatBloc, ChatState>(
                  buildWhen: (prev, curr) => prev.isTyping != curr.isTyping,
                  builder: (context, state) => IconButton.filled(
                    iconSize: 26,
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
