import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'promoCode.title', "Promo kod"))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
