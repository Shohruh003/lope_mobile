import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/data/balance_repository.dart';

/// Single text-field screen — enter a promo code, hit "Faollashtirish".
/// Server returns either `{bonus: amount}` on success or an error.
class PromoCodeScreen extends ConsumerStatefulWidget {
  const PromoCodeScreen({super.key});

  @override
  ConsumerState<PromoCodeScreen> createState() => _PromoCodeScreenState();
}

class _PromoCodeScreenState extends ConsumerState<PromoCodeScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;
  int? _bonus;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = tr(ref, 'mobile.promo.enterCode', "Kodni kiriting"));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _bonus = null;
    });
    try {
      final res = await ref.read(dioProvider).post('/promo/redeem', data: {'code': code});
      final data = res.data;
      final bonus = (data is Map && data['bonus'] != null)
          ? ((data['bonus']) as num).toInt()
          : 0;
      setState(() => _bonus = bonus);
      final user = ref.read(authControllerProvider).user;
      if (user != null) ref.invalidate(myBalanceProvider(user.id));
    } on DioException catch (e) {
      String msg = tr(ref, 'mobile.promo.invalidCode', "Xato — kod noto'g'ri");
      if (e.response?.statusCode == 404) {
        msg = tr(ref, 'mobile.promo.notFound', "Bunday kod yo'q");
      }
      if (e.response?.statusCode == 409) {
        msg = tr(ref, 'mobile.promo.alreadyUsed', "Bu kod allaqachon ishlatilgan");
      }
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = tr(ref, 'common.errorRetry', "Xatolik — qaytadan urinib ko'ring"));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'promoCode.title', "Promo kod"))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ===== Your own referral code card (mirrors web) =====
            if (user != null) ...[
              _MyReferralCard(user: user),
              const SizedBox(height: 22),
            ],

            // ===== Enter someone else's promo code =====
            Text(tr(ref, 'mobile.promo.enterTitle', "Promo kod kiriting"),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textBright)),
            const SizedBox(height: 8),
            Text(tr(ref, 'mobile.promo.hint', "Yaroqli kod balansingizga bonus qo'shadi"),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.textBright),
                decoration: const InputDecoration(hintText: "PROMO-XXXX"),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              if (_bonus != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _bonus == 0
                            ? tr(ref, 'mobile.promo.activated', "Kod faollashtirildi!")
                            : tr(ref, 'mobile.promo.bonusAdded',
                                "Balansga +{{amount}} {{currency}} qo'shildi",
                                {
                                  'amount': _fmt(_bonus!),
                                  'currency': tr(ref, 'common.currency', "so'm"),
                                }),
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _redeem,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr(ref, 'mobile.promo.activate', "Faollashtirish"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
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
            : "${tr(ref, 'common.error', 'Xatolik')}: $e";
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
            const Icon(Icons.card_giftcard, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
                tr(ref, 'mobile.promo.myCodeTitle', "Sizning referral kodingiz"),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
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
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 18),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
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
