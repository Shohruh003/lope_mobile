import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_profile_repository.dart';

/// Shareable booking URL + SMS notification preference + Telegram bot
/// username. Mirrors web's BarberPublicLinkScreen.
class BarberPublicLinkScreen extends ConsumerStatefulWidget {
  const BarberPublicLinkScreen({super.key});

  @override
  ConsumerState<BarberPublicLinkScreen> createState() => _BarberPublicLinkScreenState();
}

class _BarberPublicLinkScreenState extends ConsumerState<BarberPublicLinkScreen> {
  bool _seeded = false;
  bool _notifyBySms = false;
  final _tgController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tgController.dispose();
    super.dispose();
  }

  Future<void> _save(String barberId, {required bool shopManaged}) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(barberProfileRepositoryProvider);
      // Shop-managed barbers can't toggle their own SMS — backend rejects it
      // because the shop owns the balance. The web screen hides the switch
      // entirely; we mirror that and only fire the dedicated endpoint for
      // standalone barbers.
      if (!shopManaged) {
        await repo.updateNotifyBookingsBySms(barberId, _notifyBySms);
      }
      // We intentionally DON'T save telegramBotUsername anymore — the
      // bot is provisioned by an admin via BotFather (see
      // barber-bots.controller.ts) and the barber can only view it,
      // exactly like web's BarberPublicLinkScreen.
      ref.invalidate(barberProfileProvider(barberId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(ref, 'common.saved', "Saqlandi"))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Only allow http/https before launching — no `javascript:` or `file:` and
  /// no `tel:`/`sms:` slipping through for things that aren't actually phones.
  Future<void> _openUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(barberProfileProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.barber.publicLink.title', "Ommaviy havola"))),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _notifyBySms = b['notifyBookingsBySms'] == true;
            _tgController.text = (b['telegramBotUsername'] ?? '').toString();
          }
          final shopManaged = (b['barbershopId'] ?? '').toString().isNotEmpty;
          final slug = (b['publicSlug'] ?? '').toString();
          final link = slug.isEmpty ? null : 'https://app.lopestyle.uz/b/$slug';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                tr(ref, 'mobile.barber.publicLink.hint',
                    "Mijozlar uchun ommaviy bron havolasi. Telegram, SMS yoki ijtimoiy tarmoqlarda ulashing."),
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (link == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                      tr(ref, 'mobile.barber.publicLink.slugMissing',
                          "Public slug hali sozlanmagan. Veb-versiyada faollashtiring."),
                      style: const TextStyle(color: AppColors.warning, fontSize: 13)),
                )
              else ...[
                _LinkCard(
                  title: tr(ref, 'mobile.barber.publicLink.directTitle',
                      "To'g'ridan-to'g'ri havola"),
                  subtitle: tr(ref, 'mobile.barber.publicLink.directDesc',
                      "Brauzerda ochiladigan ommaviy bron sahifasi"),
                  url: link,
                  icon: Icons.link,
                  iconColor: AppColors.primary,
                  onCopy: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr(ref, 'mobile.barber.location.copied',
                            "Nusxalandi"))));
                  },
                  onOpen: () => _openUrl(link),
                ),
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  // Telegram bot deep-link: customer's phone is implicitly
                  // verified by Telegram, so this is the cleanest invite
                  // surface. Same format as the web BarberPublicLinkCard.
                  const tgBot = 'lope_style_bot';
                  final tgUrl = 'https://t.me/$tgBot?start=$slug';
                  return _LinkCard(
                    title: tr(ref, 'mobile.barber.publicLink.tgTitle',
                        "Telegram bot havolasi"),
                    subtitle: tr(ref, 'mobile.barber.publicLink.tgDesc',
                        "Telegram ichida ochiladi, telefon avtomatik tasdiqlanadi"),
                    url: tgUrl,
                    icon: Icons.send,
                    iconColor: const Color(0xFF2AABEE),
                    onCopy: () async {
                      await Clipboard.setData(ClipboardData(text: tgUrl));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(tr(ref, 'mobile.barber.location.copied',
                              "Nusxalandi"))));
                    },
                    onOpen: () => _openUrl(tgUrl),
                  );
                }),
              ],

              if (!shopManaged && link != null) ...[
                const SizedBox(height: 20),
                SwitchListTile(
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  value: _notifyBySms,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _notifyBySms = v),
                  title: Text(tr(ref, 'mobile.barber.publicLink.notifyTitle', "Bron qabul qilinganda SMS")),
                  subtitle: Text(
                      tr(ref, 'mobile.barber.publicLink.notifyHint',
                          "Yangi bron tushganda telefoningizga SMS keladi"),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],

              // Personal Telegram bot — read-only display, mirrors web.
              // The bot is set up by an admin (BotFather token), barber
              // can only see + copy the @username.
              if (_tgController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2AABEE).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF2AABEE).withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.send, size: 18, color: Color(0xFF2AABEE)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('@${_tgController.text}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Color(0xFF2AABEE))),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new,
                          size: 18, color: Color(0xFF2AABEE)),
                      onPressed: () =>
                          _openUrl('https://t.me/${_tgController.text}'),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(user.id, shopManaged: shopManaged),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr(ref, 'common.save', "Saqlash")),
                ),
              ),
            ],
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
    required this.onCopy,
    required this.onOpen,
  });
  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 10),
        Text(url,
            style: TextStyle(color: iconColor, fontSize: 13, fontFamily: 'monospace'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Nusxa', style: TextStyle(fontSize: 12)),
              onPressed: onCopy,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Ochish', style: TextStyle(fontSize: 12)),
              onPressed: onOpen,
            ),
          ),
        ]),
      ]),
    );
  }
}
