import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_clients_repository.dart';

class BarberClientsScreen extends ConsumerStatefulWidget {
  const BarberClientsScreen({super.key});

  @override
  ConsumerState<BarberClientsScreen> createState() =>
      _BarberClientsScreenState();
}

class _BarberClientsScreenState extends ConsumerState<BarberClientsScreen> {
  String _query = '';
  String _bucket = 'all';

  /// Humanized "last visit" pill — locale-neutral. Says "Bugun /
  /// Kecha / 3 kun oldin / 2 hafta oldin" instead of the previous
  /// Russian-formatted `dd.MM.yyyy` string.
  String _prettyLastVisit(DateTime dt, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visit = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(visit).inDays;
    if (diff <= 0) return tr(ref, 'mobile.dates.today', 'Bugun');
    if (diff == 1) return tr(ref, 'mobile.dates.yesterday', 'Kecha');
    if (diff < 7) return '$diff ${tr(ref, 'mobile.dates.daysAgo', 'kun oldin')}';
    if (diff < 30) {
      final w = (diff / 7).floor();
      return '$w ${tr(ref, 'mobile.dates.weeksAgo', 'hafta oldin')}';
    }
    if (diff < 365) {
      final m = (diff / 30).floor();
      return '$m ${tr(ref, 'mobile.dates.monthsAgo', 'oy oldin')}';
    }
    final y = (diff / 365).floor();
    return '$y ${tr(ref, 'mobile.dates.yearsAgo', 'yil oldin')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: AppListSkeleton());
    final async = ref.watch(barberClientsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'barberMyClients.title', 'Mijozlarim'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (list) {
          final now = DateTime.now();
          final filtered = list.where((c) {
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final hit = c.name.toLowerCase().contains(q) ||
                  c.phone.contains(_query);
              if (!hit) return false;
            }
            if (_bucket != 'all') {
              if (c.lastVisit == null) return _bucket == '60+';
              final days = now.difference(c.lastVisit!).inDays;
              switch (_bucket) {
                case '0-7':
                  if (days > 7) return false;
                  break;
                case '8-20':
                  if (days < 8 || days > 20) return false;
                  break;
                case '21-60':
                  if (days < 21 || days > 60) return false;
                  break;
                case '60+':
                  if (days <= 60) return false;
                  break;
              }
            }
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(color: context.colors.border),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: AppText.body,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      prefixIcon: Icon(Icons.search,
                          color: context.colors.textMuted, size: 20),
                      hintText: tr(ref,
                          'barberMyClients.searchPlaceholder',
                          'Ism yoki telefon'),
                      hintStyle: AppText.body
                          .copyWith(color: context.colors.textMuted),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  children: [
                    AppChip(
                      label: tr(ref, 'common.all', 'Hammasi'),
                      selected: _bucket == 'all',
                      onTap: () => setState(() => _bucket = 'all'),
                    ),
                    AppSpacing.hGapSm,
                    AppChip(
                      label: tr(ref, 'barberMyClients.days07', '0-7 kun'),
                      selected: _bucket == '0-7',
                      onTap: () => setState(() => _bucket = '0-7'),
                    ),
                    AppSpacing.hGapSm,
                    AppChip(
                      label: tr(ref, 'barberMyClients.days820',
                          '8-20 kun'),
                      selected: _bucket == '8-20',
                      onTap: () => setState(() => _bucket = '8-20'),
                    ),
                    AppSpacing.hGapSm,
                    AppChip(
                      label: tr(ref, 'barberMyClients.days2160',
                          '21-60 kun'),
                      selected: _bucket == '21-60',
                      onTap: () => setState(() => _bucket = '21-60'),
                    ),
                    AppSpacing.hGapSm,
                    AppChip(
                      label: tr(ref, 'barberMyClients.days60plus',
                          '60+ kun'),
                      selected: _bucket == '60+',
                      onTap: () => setState(() => _bucket = '60+'),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.refresh(barberClientsProvider(user.id).future),
                  child: filtered.isEmpty
                      ? ListView(
                          // Wrap the empty state in a scrollable so
                          // pull-to-refresh works even when the list is
                          // empty — previously the refresh was only
                          // reachable on populated screens.
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 360,
                              child: AppEmptyState(
                                icon: Icons.people_outline_rounded,
                                title: list.isEmpty
                                    ? tr(ref, 'mobile.barber.clients.empty',
                                        "Hali mijoz yo'q")
                                    : tr(ref, 'common.noResults',
                                        'Filterga mos mijoz topilmadi'),
                                message: list.isEmpty
                                    ? tr(ref, 'mobile.barber.clients.emptyHint',
                                        "Mijozlar sizga bir marta yozilganidan keyin bu yerda paydo bo'ladi.")
                                    : tr(ref, 'common.noResultsHint',
                                        "Qidiruvni tozalab yoki filtrni o'zgartirib ko'ring."),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => AppSpacing.gapSm,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return AppCard(
                          variant: AppCardVariant.outlined,
                          padding: AppSpacing.cardPadding,
                          child: Row(children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (c.name.isNotEmpty
                                        ? c.name[0]
                                        : (c.phone.isNotEmpty
                                            ? c.phone[c.phone.length - 1]
                                            : '?'))
                                    .toUpperCase(),
                                style: AppText.titleMd
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                            AppSpacing.hGapMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(c.name.isEmpty ? c.phone : c.name,
                                      style: AppText.titleSm),
                                  if (c.phone.isNotEmpty)
                                    Text(c.phone,
                                        style: AppText.caption),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      AppBadge(
                                        label:
                                            "${c.bookingsCount} ${tr(ref, 'barberMyClients.bookingsShort', 'bron')}",
                                        variant: AppBadgeVariant.success,
                                      ),
                                      if (c.lastVisit != null)
                                        Text(
                                          "· ${_prettyLastVisit(c.lastVisit!.toLocal(), ref)}",
                                          style: AppText.caption,
                                        ),
                                      if (c.totalSpent > 0)
                                        Text(
                                          "· ${_fmt(c.totalSpent)} ${tr(ref, 'common.currency', "so'm")}",
                                          style: AppText.caption.copyWith(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            AppSpacing.hGapSm,
                            TapScale(
                              onTap: c.phone.isEmpty
                                  ? null
                                  : () => _call(c.phone),
                              scale: 0.9,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.phone_outlined,
                                    color: AppColors.primary, size: 20),
                              ),
                            ),
                          ]),
                        ).animate().fadeIn(
                            duration: 250.ms, delay: (i * 25).ms);
                      },
                    ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _call(String phone) async {
    AppHaptics.light();
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}
