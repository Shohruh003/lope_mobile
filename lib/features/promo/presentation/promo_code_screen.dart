import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';

/// Promo code screen — mirrors web's CustomerPromoCodePage. Shows the user's
/// own referral code (read + edit + invite count). The earlier
/// 'enter someone else's code' redemption section was wired to a
/// /promo/redeem endpoint that doesn't exist on the backend (web doesn't
/// have a redeem endpoint either — promo codes are only applied at
/// registration via /auth/register's optional promoCode body field).
class PromoCodeScreen extends ConsumerWidget {
  const PromoCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'promoCode.title', "Promo kod"))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (user != null) _MyReferralCard(user: user),
          ],
        ),
      ),
    );
  }
}

class _MyReferralCard extends ConsumerStatefulWidget {
  const _MyReferralCard({required this.user});
  final AppUser user;

  @override
  ConsumerState<_MyReferralCard> createState() => _MyReferralCardState();
}

class _MyReferralCardState extends ConsumerState<_MyReferralCard> {
  bool _editing = false;
  bool _saving = false;
  final _editCtrl = TextEditingController();
  static final _allowed = RegExp(r'^[A-Z0-9]{1,20}$');

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = _editCtrl.text.trim().toUpperCase();
    if (!_allowed.hasMatch(next)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'promoCode.invalidFormat',
              "Faqat A-Z va 0-9 (1-20 belgi)"))));
      return;
    }
    if (next == (widget.user.referralCode ?? '')) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      final newCode =
          await ref.read(authRepositoryProvider).updateMyReferralCode(next);
      await ref
          .read(authControllerProvider.notifier)
          .updateReferralCode(newCode);
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                tr(ref, 'promoCode.updated', "Promo kod yangilandi"))));
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('409')
            ? tr(ref, 'promoCode.taken', "Bu kod allaqachon olingan")
            : "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}";
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.user.referralCode ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.card_giftcard, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
                tr(ref, 'mobile.promo.myCodeTitle', "Sizning referral kodingiz"),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          if (_editing)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _editCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      fontSize: 20),
                  decoration: const InputDecoration(
                    hintText: 'PROMO20',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _saving
                    ? null
                    : () => setState(() => _editing = false),
              ),
              IconButton(
                icon: _saving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, color: Colors.white),
                onPressed: _saving ? null : _save,
              ),
            ])
          else
            Row(children: [
              Expanded(
                child: Text(code.isEmpty ? '—' : code,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        letterSpacing: 2)),
              ),
              if (code.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(tr(ref,
                            'mobile.barber.location.copied', "Nusxalandi"))));
                  },
                ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                onPressed: () {
                  _editCtrl.text = code;
                  setState(() => _editing = true);
                },
              ),
            ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.people_outline, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
                tr(ref, 'mobile.promo.invitedCount',
                    "{{n}} kishi sizning kodingizdan foydalandi",
                    {'n': '${widget.user.referralsCount}'}),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}
