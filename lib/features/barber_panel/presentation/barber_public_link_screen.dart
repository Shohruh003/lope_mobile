import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
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

  Future<void> _save(String barberId) async {
    setState(() => _saving = true);
    try {
      await ref.read(barberProfileRepositoryProvider).updateBarber(barberId, {
        'notifyBookingsBySms': _notifyBySms,
        'telegramBotUsername': _tgController.text.trim(),
      });
      ref.invalidate(barberProfileProvider(barberId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
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
      appBar: AppBar(title: const Text("Ommaviy havola")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e")),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _notifyBySms = b['notifyBookingsBySms'] == true;
            _tgController.text = (b['telegramBotUsername'] ?? '').toString();
          }
          final slug = (b['publicSlug'] ?? '').toString();
          final link = slug.isEmpty ? null : 'https://app.lopestyle.uz/b/$slug';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                "Mijozlar uchun ommaviy bron havolasi. Telegram, SMS yoki ijtimoiy tarmoqlarda ulashing.",
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
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
                  child: const Text("Public slug hali sozlanmagan. Veb-versiyada faollashtiring.",
                      style: TextStyle(color: AppColors.warning, fontSize: 13)),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Sizning havolangiz", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(link, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text("Nusxa"),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: link));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nusxalandi")));
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text("Ochish"),
                            onPressed: () => _openUrl(link),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

              const SizedBox(height: 20),
              SwitchListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                value: _notifyBySms,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _notifyBySms = v),
                title: const Text("Bron qabul qilinganda SMS"),
                subtitle: const Text("Yangi bron tushganda telefoningizga SMS keladi",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),

              const SizedBox(height: 16),
              const Text("Telegram bot username",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _tgController,
                decoration: const InputDecoration(hintText: "@username"),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(user.id),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Saqlash"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
