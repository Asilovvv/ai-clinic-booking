import 'package:flutter/material.dart';

import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../theme.dart';

class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 16,
      backgroundColor: scheme.primary,
      child: Icon(Icons.auto_awesome, size: 16, color: scheme.onPrimary),
    );
  }
}

/// One chat message with optional slot cards or a booking confirmation.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.bookingKey,
    required this.onSlotTap,
    this.showBusiness = true,
  });

  final ChatMessage message;
  final String? bookingKey;
  final void Function(Slot slot, int? rescheduleId) onSlotTap;

  /// Slot cards name the business (city-wide chat) or the specialist (chat of one business).
  final bool showBusiness;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;

    final Color background;
    final Color foreground;
    if (isUser) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else if (message.isError) {
      background = scheme.errorContainer;
      foreground = scheme.onErrorContainer;
    } else {
      background = cardColor(scheme);
      foreground = scheme.onSurface;
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(message.text, style: TextStyle(color: foreground, height: 1.35, fontSize: 15)),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) const AssistantAvatar(),
                if (!isUser) const SizedBox(width: 8),
                Flexible(child: bubble),
              ],
            ),
            if (message.slots.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in message.slots)
                      SlotCard(
                        slot: slot,
                        showBusiness: showBusiness,
                        loading: bookingKey == slot.key,
                        enabled: bookingKey == null,
                        onTap: (slot) => onSlotTap(slot, message.rescheduleId),
                      ),
                  ],
                ),
              ),
            if (message.appointment != null)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 8),
                child: BookedCard(appointment: message.appointment!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable free slot suggested by the assistant.
class SlotCard extends StatelessWidget {
  const SlotCard({
    super.key,
    required this.slot,
    required this.loading,
    required this.enabled,
    required this.onTap,
    this.showBusiness = true,
  });

  final Slot slot;
  final bool loading;
  final bool enabled;
  final ValueChanged<Slot> onTap;
  final bool showBusiness;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final strings = context.strings;
    final color = scheme.onPrimaryContainer;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => onTap(slot) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 134,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(categoryIcon(slot.category), size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(slot.start),
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
                    ),
                    const Spacer(),
                    if (loading)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                Text(formatDay(slot.start, strings.lang), style: text.bodySmall?.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(
                  slot.serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: color),
                ),
                Text(
                  showBusiness ? slot.businessName : slot.specialistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: color),
                ),
                Text(
                  formatMoney(slot.price, strings),
                  style: text.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmation card shown after a successful booking.
class BookedCard extends StatelessWidget {
  const BookedCard({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final strings = context.strings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF14362A) : const Color(0xFFE8F7EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? const Color(0xFF2E7D55) : const Color(0xFF7BCB98)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: dark ? const Color(0xFF5FD08F) : const Color(0xFF1E9E52), size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.bookingConfirmed, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('${appointment.serviceName} · ${appointment.businessName}', style: text.bodySmall),
                Text(appointment.specialistName, style: text.bodySmall),
                Text(
                  '${formatDay(appointment.start, strings.lang)}, ${formatTime(appointment.start)}',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated "..." while the assistant is thinking.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const AssistantAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor(scheme),
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_controller.value - i * 0.2) % 1.0;
                  final opacity = 0.25 + 0.75 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
