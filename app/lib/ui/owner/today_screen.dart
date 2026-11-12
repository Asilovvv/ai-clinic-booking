import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/load_status.dart';
import '../../bloc/owner_cubit.dart';
import '../../bloc/owner_stats_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'appointment_tile.dart';

/// The owner's dashboard: today's numbers, the week and today's schedule.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final active = context.select((OwnerCubit cubit) => cubit.state.business?.isActive ?? true);
    return BlocBuilder<OwnerStatsCubit, OwnerStatsState>(
      builder: (context, state) {
        final hasData = state.status == LoadStatus.success || state.stats.byDay.isNotEmpty;
        if (!hasData && state.status == LoadStatus.failure) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: strings.loadError,
            text: state.error,
            action: FilledButton.tonal(
              onPressed: () => context.read<OwnerStatsCubit>().load(),
              child: Text(strings.retry),
            ),
          );
        }
        if (!hasData) return const Center(child: CircularProgressIndicator());

        final stats = state.stats;
        final today = [
          (Icons.event_available, strings.kpiToday, '${stats.todayCount}'),
          (Icons.payments_outlined, strings.kpiRevenueToday, formatSum(stats.todayRevenue, strings)),
          (Icons.donut_large, strings.kpiLoad, '${stats.loadPercent}%'),
          (Icons.upcoming_outlined, strings.kpiUpcoming, '${stats.upcoming}'),
        ];
        final week = [
          (Icons.date_range, strings.kpiWeek, '${stats.bookings}'),
          (Icons.trending_up, strings.kpiRevenueWeek, formatSum(stats.revenue, strings)),
          (Icons.auto_awesome, strings.kpiAi, '${stats.aiBookings} · ${stats.aiPercent}%'),
          (
            Icons.star_rounded,
            strings.kpiRating,
            stats.rating == null ? '—' : '${stats.rating!.toStringAsFixed(1)} (${stats.reviewsCount})',
          ),
        ];
        final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
        return RefreshIndicator(
          onRefresh: () => context.read<OwnerStatsCubit>().load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            children: [
              if (!active)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off_outlined, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.hiddenBanner,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              _KpiGrid(items: today),
              SectionTitle(strings.todaySchedule),
              if (stats.today.isEmpty)
                Padding(padding: const EdgeInsets.all(8), child: Text(strings.noBookingsDay, style: muted)),
              for (final appointment in stats.today)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OwnerAppointmentTile(appointment: appointment),
                ),
              SectionTitle(strings.weekTitle),
              _KpiGrid(items: week),
              const SizedBox(height: 8),
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(strings.chartTitle, style: muted),
                    ),
                    _BarChart(days: stats.byDay),
                  ],
                ),
              ),
              if (stats.topServices.isNotEmpty) ...[
                SectionTitle(strings.topServices),
                AppCard(
                  child: Column(
                    children: [
                      for (final service in stats.topServices)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  service.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('${service.count} ×', style: theme.textTheme.bodyMedium),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 96,
                                child: Text(
                                  formatSum(service.revenue, strings),
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Two columns of numbers.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});

  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.05,
      children: [for (final (icon, title, value) in items) _Kpi(icon: icon, title: title, value: value)],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bookings per day as bars; the last bar is today.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.days});

  final List<DayStat> days;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = context.strings.lang;
    final peak = days.fold<int>(1, (max, day) => day.count > max ? day.count : max);
    const height = 96.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${days[i].count}', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  height: 4 + (height - 4) * days[i].count / peak,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: i == days.length - 1 ? scheme.primary : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  weekdayShort(days[i].date.weekday - 1, lang),
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
