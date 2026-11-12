import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/catalog_bloc.dart';
import '../../bloc/load_status.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/formatters.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'business_screen.dart';

/// The city's businesses: search, niches and cards.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.onOpenAssistant});

  /// Switches to the assistant tab.
  final VoidCallback onOpenAssistant;

  Future<void> _refresh(BuildContext context) async {
    final bloc = context.read<CatalogBloc>()..add(const CatalogRequested());
    await bloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state.status == LoadStatus.failure && state.businesses.isEmpty) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: strings.loadError,
            text: state.error,
            action: FilledButton.tonal(
              onPressed: () => context.read<CatalogBloc>().add(const CatalogRequested()),
              child: Text(strings.retry),
            ),
          );
        }
        final loading = state.businesses.isEmpty && state.status != LoadStatus.success;
        final visible = state.visible;
        return RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: _SearchField(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _PromoCard(onTap: onOpenAssistant),
              ),
              const SizedBox(height: 12),
              CategoryChips(
                categories: state.categories,
                selected: state.selected,
                onSelected: (id) => context.read<CatalogBloc>().add(CatalogCategorySelected(id)),
              ),
              const SizedBox(height: 4),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 8),
                      Text(strings.nothingFound),
                    ],
                  ),
                )
              else
                for (final business in visible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: BusinessCard(business: business),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    context.read<CatalogBloc>().add(CatalogSearchChanged(value));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: _changed,
      decoration: InputDecoration(
        hintText: context.strings.searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  _changed('');
                },
              ),
      ),
    );
  }
}

/// Invitation to book through the AI administrator.
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(gradient: brandGradient),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.promoTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(strings.promoText, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    strings.openAssistant,
                    style: const TextStyle(color: brandDark, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One business in the catalog.
class BusinessCard extends StatelessWidget {
  const BusinessCard({super.key, required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = text.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return AppCard(
      onTap: () {
        hideMessage(context);
        Navigator.of(context).push(BusinessScreen.route(business));
      },
      child: Row(
        children: [
          CategoryIconTile(category: business.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  [strings.category(business.category, business.category), business.address]
                      .where((part) => part.isNotEmpty)
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                const SizedBox(height: 6),
                // A Wrap, so a long price or a large font moves to a second line instead of overflowing.
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (business.rating != null) RatingLabel(rating: business.rating, count: business.reviewsCount),
                    if (business.priceFrom != null)
                      Text(
                        strings.priceFrom(formatMoney(business.priceFrom!, strings)),
                        style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(formatHours(business.openHour, business.closeHour), style: muted),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.outline),
        ],
      ),
    );
  }
}
