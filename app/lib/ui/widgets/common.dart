import 'package:flutter/material.dart';

import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../theme.dart';

/// White rounded container used for every card of the app.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: cardColor(scheme),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Rounded square with the niche's icon on its accent colour.
class CategoryIconTile extends StatelessWidget {
  const CategoryIconTile({super.key, required this.category, this.size = 52});

  final String? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.28 : 0.13),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(categoryIcon(category), color: dark ? Colors.white : color, size: size * 0.5),
    );
  }
}

/// "★ 4.8 (12)", or nothing when there are no reviews yet.
class RatingLabel extends StatelessWidget {
  const RatingLabel({super.key, required this.rating, this.count});

  final double? rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5A623)),
        const SizedBox(width: 2),
        Text(rating!.toStringAsFixed(1), style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        if (count != null) ...[
          const SizedBox(width: 3),
          Text('($count)', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Five stars, the first [rating] of them filled.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final empty = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(Icons.star_rounded, size: size, color: i <= rating ? const Color(0xFFF5A623) : empty),
      ],
    );
  }
}

/// Centered icon, title and hint for an empty list. Scrollable, so it works inside a RefreshIndicator.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});

  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                if (text != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    text!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bold heading of a block inside a scrolling page.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Horizontal row of niches; "All" comes first.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.categories, required this.selected, required this.onSelected});

  final List<Category> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    Widget chip(String? id, String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            avatar: Icon(categoryIcon(id), size: 18),
            showCheckmark: false,
            label: Text(label),
            selected: selected == id,
            onSelected: (_) => onSelected(id),
          ),
        );

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          chip(null, strings.all),
          for (final category in categories) chip(category.id, strings.category(category.id, category.title)),
        ],
      ),
    );
  }
}

/// Horizontal strip of days: weekday on top, day of month below.
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.days, required this.selected, required this.onSelected, this.today});

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Marked with a dot when given.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lang = context.strings.lang;
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = days[i];
          final isSelected = day == selected;
          final isToday = today != null && day == today;
          final foreground = isSelected ? scheme.onPrimary : scheme.onSurface;
          return Material(
            color: isSelected ? scheme.primary : cardColor(scheme),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(day),
              child: SizedBox(
                width: 54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekdayShort(day.weekday - 1, lang),
                      style: text.bodySmall?.copyWith(color: foreground.withValues(alpha: 0.75)),
                    ),
                    Text(
                      '${day.day}',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: foreground),
                    ),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isToday ? (isSelected ? scheme.onPrimary : scheme.primary) : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Square with the day and the month of a booking.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.date, this.muted = false});

  final DateTime date;

  /// Greyed out for history.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final background = muted ? scheme.surfaceContainerHighest : scheme.primaryContainer;
    final foreground = muted ? scheme.onSurfaceVariant : scheme.onPrimaryContainer;
    return Container(
      width: 56,
      height: 62,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${date.day}', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: foreground)),
          Text(formatMonth(date, context.strings.lang), style: text.bodySmall?.copyWith(color: foreground)),
        ],
      ),
    );
  }
}

/// Small coloured pill with the status of a booking.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(
        context.strings.status(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Shows a floating message at the bottom of the screen.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
