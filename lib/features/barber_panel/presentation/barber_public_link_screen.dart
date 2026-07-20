import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_profile_repository.dart';

class BarberPublicLinkScreen extends ConsumerStatefulWidget {
  const BarberPublicLinkScreen({super.key});

  @override
  ConsumerState<BarberPublicLinkScreen> createState() =>
      _BarberPublicLinkScreenState();
}

class _BarberPublicLinkScreenState
    extends ConsumerState<BarberPublicLinkScreen> {
  bool _seeded = false;
  bool _notifyBySms = false;
  final _tgController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tgController.dispose();
    super.dispose();
  }

  Future<void> _save(String barberId,
      {required bool shopManaged}) async {
    AppHaptics.medium();
    setState(() => _saving = true);
    try {
      final repo = ref.read(barberProfileRepositoryProvider);
      if (!shopManaged) {
        await repo.updateNotifyBookingsBySms(barberId, _notifyBySms);
      }
      ref.invalidate(barberProfileProvider(barberId));
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return;
    AppHaptics.light();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberProfileProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.publicLink.title', 'Ommaviy havola'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _notifyBySms = b['notifyBookingsBySms'] == true;
            _tgController.text =
                (b['telegramBotUsername'] ?? '').toString();
          }
          final shopManaged =
              (b['barbershopId'] ?? '').toString().isNotEmpty;
          final slug = (b['publicSlug'] ?? '').toString();
          final link = slug.isEmpty
              ? null
              : 'https://app.lopestyle.uz/b/$slug';
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _seeded = false;
              // ignore: unused_result
              ref.refresh(barberProfileProvider(user.id));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
              children: [
              Text(
                tr(ref, 'mobile.barber.publicLink.hint',
                    'Mijozlar uchun ommaviy bron havolasi. Telegram, SMS yoki ijtimoiy tarmoqlarda ulashing.'),
                style: AppText.bodyLg
                    .copyWith(color: context.colors.textSecondary),
              ),
              AppSpacing.gapLg,
              if (link == null)
                AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderColor:
                      AppColors.warning.withValues(alpha: 0.3),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            AppColors.warning.withValues(alpha: 0.2),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: const Icon(Icons.warning_amber,
                          color: AppColors.warning, size: 18),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        tr(
                            ref,
                            'mobile.barber.publicLink.slugMissing',
                            'Public slug hali sozlanmagan. Veb-versiyada faollashtiring.'),
                        style: AppText.bodySm
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ]),
                )
              else ...[
                _LinkCard(
                  title: tr(ref,
                      'mobile.barber.publicLink.directTitle',
                      "To'g'ridan-to'g'ri havola"),
                  subtitle: tr(ref,
                      'mobile.barber.publicLink.directDesc',
                      'Brauzerda ochiladigan ommaviy bron sahifasi'),
                  url: link,
                  icon: Icons.link,
                  iconColor: AppColors.primary,
                  copyLabel: tr(ref, 'common.copy', 'Nusxa'),
                  openLabel: tr(ref, 'common.open', 'Ochish'),
                  onCopy: () async {
                    AppHaptics.light();
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(tr(
                                ref,
                                'mobile.barber.location.copied',
                                'Nusxalandi'))));
                  },
                  onOpen: () => _openUrl(link),
                ),
                AppSpacing.gapSm,
                Builder(builder: (_) {
                  const tgBot = 'lope_style_bot';
                  final tgUrl =
                      'https://t.me/$tgBot?start=$slug';
                  return _LinkCard(
                    title: tr(ref,
                        'mobile.barber.publicLink.tgTitle',
                        'Telegram bot havolasi'),
                    subtitle: tr(ref,
                        'mobile.barber.publicLink.tgDesc',
                        'Telegram ichida ochiladi, telefon avtomatik tasdiqlanadi'),
                    url: tgUrl,
                    icon: Icons.send,
                    iconColor: const Color(0xFF2AABEE),
                    copyLabel: tr(ref, 'common.copy', 'Nusxa'),
                    openLabel: tr(ref, 'common.open', 'Ochish'),
                    onCopy: () async {
                      AppHaptics.light();
                      await Clipboard.setData(
                          ClipboardData(text: tgUrl));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(tr(
                                  ref,
                                  'mobile.barber.location.copied',
                                  'Nusxalandi'))));
                    },
                    onOpen: () => _openUrl(tgUrl),
                  );
                }),
              ],
              if (!shopManaged && link != null) ...[
                AppSpacing.gapLg,
                AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.15),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: const Icon(Icons.sms_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(ref,
                                'mobile.barber.publicLink.notifyTitle',
                                'Bron qabul qilinganda SMS'),
                            style: AppText.titleSm,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(ref,
                                'mobile.barber.publicLink.notifyHint',
                                'Yangi bron tushganda telefoningizga SMS keladi'),
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    // Auto-save the toggle instead of gating on a
                    // separate Save button — the switch flip IS the
                    // intent, so persisting immediately matches the
                    // user's mental model. Small spinner while the
                    // network call is in-flight prevents rapid-tap
                    // double-fires.
                    _saving
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          )
                        : Switch(
                            value: _notifyBySms,
                            activeThumbColor: AppColors.primary,
                            onChanged: (v) async {
                              AppHaptics.selection();
                              setState(() => _notifyBySms = v);
                              await _save(user.id,
                                  shopManaged: shopManaged);
                            },
                          ),
                  ]),
                ),
              ],
              if (_tgController.text.isNotEmpty) ...[
                AppSpacing.gapLg,
                AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  color: const Color(0xFF2AABEE).withValues(alpha: 0.1),
                  borderColor:
                      const Color(0xFF2AABEE).withValues(alpha: 0.35),
                  onTap: () => _openUrl(
                      'https://t.me/${_tgController.text}'),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2AABEE)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send,
                          color: Color(0xFF2AABEE), size: 20),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        '@${_tgController.text}',
                        style: AppText.titleSm.copyWith(
                          color: const Color(0xFF2AABEE),
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new,
                        color: Color(0xFF2AABEE), size: 18),
                  ]),
                ),
              ],
              // Save button removed — the SMS switch auto-saves on
              // change so a separate Save action is redundant.
            ],
            ),
          );
        },
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.iconColor,
    required this.copyLabel,
    required this.openLabel,
    required this.onCopy,
    required this.onOpen,
  });
  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  final Color iconColor;
  final String copyLabel;
  final String openLabel;
  final VoidCallback onCopy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: AppRadius.rSm,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleSm),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
          ]),
          AppSpacing.gapSm,
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              borderRadius: AppRadius.rSm,
            ),
            child: Text(
              url,
              style: AppText.caption.copyWith(
                color: iconColor,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppSpacing.gapMd,
          Row(children: [
            Expanded(
              child: AppButton(
                label: copyLabel,
                leadingIcon: Icons.copy,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                fullWidth: true,
                onPressed: onCopy,
              ),
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: AppButton(
                label: openLabel,
                leadingIcon: Icons.open_in_new,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.sm,
                fullWidth: true,
                onPressed: onOpen,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
