import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routes.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// Final registration step — mirrors the web's `Register.tsx` form fields:
///   - Name input
///   - Gender toggle (👨 Erkak / 👩 Ayol)
///   - Password input with visibility toggle
///   - Promo code input (optional)
///   - Role select: Mijoz / Sartarosh / Salon ega (radio cards)
///   - "Ro'yxatdan o'tish" button
class RegisterCompleteScreen extends ConsumerStatefulWidget {
  const RegisterCompleteScreen({super.key, required this.phone});
  final String phone;
  @override
  ConsumerState<RegisterCompleteScreen> createState() => _RegisterCompleteScreenState();
}

class _RegisterCompleteScreenState extends ConsumerState<RegisterCompleteScreen> {
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  String _role = 'user';
  String? _gender; // 'MALE' | 'FEMALE'
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _promoCtrl.dispose();
    _shopNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.length < 2) {
      setState(() => _error = tr(ref, 'auth.enterName', "Ismni kiriting"));
      return;
    }
    if (password.length < 4) {
      setState(() => _error = tr(ref, 'auth.shortPassword', "Parol kamida 4 belgi"));
      return;
    }
    if (_role == 'barbershop' && _shopNameCtrl.text.trim().isEmpty) {
      setState(() => _error = tr(ref, 'auth.shopNameRequired',
          "Salon nomini kiriting"));
      return;
    }
    if (_role != 'barbershop' && _gender == null) {
      setState(() => _error = tr(ref, 'auth.genderRequired',
          "Jinsni tanlang"));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).register(
            name: name,
            phone: widget.phone,
            password: password,
            role: _role,
            gender: _role == 'barbershop' ? null : _gender,
            promoCode: _promoCtrl.text.trim().isEmpty ? null : _promoCtrl.text.trim(),
            shopName: _role == 'barbershop' ? _shopNameCtrl.text.trim() : null,
          );
      await ref.read(authControllerProvider.notifier).signedIn(user);
      if (!mounted) return;
      routeToRoleHome(context, user);
    } on Object catch (e) {
      String msg = tr(ref, 'auth.registrationError', "Ro'yxatdan o'tishda xato");
      if (e.toString().contains('SocketException')) {
        msg = tr(ref, 'common.noInternet', "Internetga ulanish yo'q");
      }
      if (e.toString().contains('409')) {
        msg = tr(ref, 'auth.phoneAlreadyRegistered', "Bu raqam allaqachon ro'yxatdan o'tgan");
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ShadCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Column(children: [
                      const ShadIconBubble(icon: Icons.person_outline),
                      const SizedBox(height: 12),
                      ShadCardTitle(tr(ref, 'auth.yourInfo', "Ma'lumotlaringiz")),
                      const SizedBox(height: 4),
                      ShadCardDescription(tr(ref, 'auth.yourInfoSub',
                          "Hisobni yakunlash uchun ma'lumotlaringizni kiriting")),
                    ]),
                  ),
                  const SizedBox(height: 18),

                  // ===== Name =====
                  ShadField(
                    label: tr(ref, 'auth.yourName', "Ismingiz"),
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                          hintText: tr(ref, 'auth.namePlaceholder', "Masalan: Shohruh")),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ===== Gender (hidden for shop role) =====
                  if (_role != 'barbershop') ...[
                    ShadLabel(tr(ref, 'auth.gender', "Jins")),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _genderBtn('MALE',
                          "👨 ${tr(ref, 'auth.genderMale', 'Erkak')}")),
                      const SizedBox(width: 8),
                      Expanded(child: _genderBtn('FEMALE',
                          "👩 ${tr(ref, 'auth.genderFemale', 'Ayol')}")),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ===== Shop name (only for shop role) =====
                  if (_role == 'barbershop') ...[
                    ShadField(
                      label: tr(ref, 'auth.shopName', "Salon nomi"),
                      child: TextField(
                        controller: _shopNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                            hintText: tr(ref, 'auth.shopNamePlaceholder',
                                "Masalan: Lope Style")),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ===== Password =====
                  ShadField(
                    label: tr(ref, 'auth.password', "Parol"),
                    child: TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "••••••",
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textMuted, size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ===== Promo code (optional) =====
                  ShadField(
                    label: tr(ref, 'auth.promoCode', "Promo-kod (ixtiyoriy)"),
                    child: TextField(
                      controller: _promoCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                          hintText: tr(ref, 'auth.promoIfAny', "Agar bor bo'lsa")),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ===== Role select =====
                  ShadLabel(tr(ref, 'auth.accountType', "Hisob turi")),
                  const SizedBox(height: 6),
                  _roleBtn('user', Icons.person,
                      tr(ref, 'auth.roleCustomer', "Mijoz"),
                      tr(ref, 'auth.roleCustomerDesc', "Sartarosh xizmatlari bron qilish")),
                  const SizedBox(height: 6),
                  _roleBtn('barber', Icons.content_cut,
                      tr(ref, 'auth.roleBarber', "Sartarosh"),
                      tr(ref, 'auth.roleBarberDesc', "Mijoz qabul qiluvchi sartarosh")),
                  const SizedBox(height: 6),
                  _roleBtn('barbershop', Icons.storefront,
                      tr(ref, 'auth.roleShop', "Salon"),
                      tr(ref, 'auth.roleShopDesc', "Sartaroshxonani boshqarish")),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tr(ref, 'auth.register', "Ro'yxatdan o'tish")),
                    ),
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderBtn(String key, String label) {
    final on = _gender == key;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _gender = on ? null : key;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppColors.primary : AppColors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: on ? Colors.white : AppColors.textMuted,
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _roleBtn(String value, IconData icon, String title, String subtitle) {
    final on = _role == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppColors.primary : AppColors.border, width: on ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        color: on ? AppColors.primary : AppColors.textBright)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppColors.primary : Colors.transparent,
              border: Border.all(color: on ? AppColors.primary : AppColors.border, width: 1.5),
            ),
            child: on ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
          ),
        ]),
      ),
    );
  }
}
