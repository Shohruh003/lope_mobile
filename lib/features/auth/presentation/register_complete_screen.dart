import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/routes.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

class RegisterCompleteScreen extends ConsumerStatefulWidget {
  const RegisterCompleteScreen({super.key, required this.phone});
  final String phone;
  @override
  ConsumerState<RegisterCompleteScreen> createState() =>
      _RegisterCompleteScreenState();
}

class _RegisterCompleteScreenState
    extends ConsumerState<RegisterCompleteScreen> {
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  String _role = 'user';
  String? _gender;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  String _promoStatus = 'idle';
  Timer? _promoDebounce;

  @override
  void initState() {
    super.initState();
    _promoCtrl.addListener(_onPromoChanged);
  }

  void _onPromoChanged() {
    final v = _promoCtrl.text.trim();
    _promoDebounce?.cancel();
    if (v.isEmpty) {
      setState(() => _promoStatus = 'idle');
      return;
    }
    setState(() => _promoStatus = 'checking');
    _promoDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final res = await ref
            .read(dioProvider)
            .get('/auth/check-promo', queryParameters: {'code': v});
        final valid = res.data is Map && res.data['valid'] == true;
        if (!mounted) return;
        setState(() => _promoStatus = valid ? 'valid' : 'invalid');
      } on DioException {
        if (!mounted) return;
        setState(() => _promoStatus = 'invalid');
      }
    });
  }

  @override
  void dispose() {
    _promoDebounce?.cancel();
    _promoCtrl.removeListener(_onPromoChanged);
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _promoCtrl.dispose();
    _shopNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    AppHaptics.medium();
    final name = _nameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.length < 2) {
      AppHaptics.error();
      setState(() =>
          _error = tr(ref, 'auth.enterName', 'Ismni kiriting'));
      return;
    }
    if (password.length < 4) {
      AppHaptics.error();
      setState(() => _error =
          tr(ref, 'auth.shortPassword', 'Parol kamida 4 belgi'));
      return;
    }
    if (_role == 'barbershop' && _shopNameCtrl.text.trim().isEmpty) {
      AppHaptics.error();
      setState(() => _error = tr(
          ref, 'auth.shopNameRequired', 'Salon nomini kiriting'));
      return;
    }
    if (_role != 'barbershop' && _gender == null) {
      AppHaptics.error();
      setState(() =>
          _error = tr(ref, 'auth.genderRequired', 'Jinsni tanlang'));
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
            promoCode: _promoCtrl.text.trim().isEmpty
                ? null
                : _promoCtrl.text.trim(),
            shopName:
                _role == 'barbershop' ? _shopNameCtrl.text.trim() : null,
          );
      await ref.read(authControllerProvider.notifier).signedIn(user);
      if (!mounted) return;
      AppHaptics.success();
      routeToRoleHome(context, user);
    } on Object catch (e) {
      AppHaptics.error();
      String msg = tr(ref, 'auth.registrationError',
          "Ro'yxatdan o'tishda xato");
      if (e.toString().contains('SocketException')) {
        msg = tr(ref, 'common.noInternet', "Internetga ulanish yo'q");
      }
      if (e.toString().contains('409')) {
        msg = tr(ref, 'auth.phoneAlreadyRegistered',
            "Bu raqam allaqachon ro'yxatdan o'tgan");
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: AppRadius.rXl,
                        boxShadow:
                            AppShadows.primaryGlow(AppColors.primary),
                      ),
                      child: const Icon(Icons.person_outline,
                          color: Colors.white, size: 32),
                    ),
                  ).animate().scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 500.ms,
                      curve: Curves.easeOutBack),
                  AppSpacing.gapLg,
                  Text(
                    tr(ref, 'auth.yourInfo', "Ma'lumotlaringiz"),
                    style: AppText.titleLg,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(ref, 'auth.yourInfoSub',
                        "Hisobni yakunlash uchun ma'lumotlaringizni kiriting"),
                    style: AppText.bodyLg
                        .copyWith(color: context.colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXxl,

                  AppCard(
                    variant: AppCardVariant.outlined,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    radius: AppRadius.xl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Name
                        Text(tr(ref, 'auth.yourName', 'Ismingiz'),
                            style: AppText.overline),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          style: AppText.body,
                          decoration: InputDecoration(
                            hintText: tr(ref, 'auth.namePlaceholder',
                                'Masalan: Shohruh'),
                          ),
                        ),
                        AppSpacing.gapMd,

                        // Gender
                        if (_role != 'barbershop') ...[
                          Text(tr(ref, 'auth.gender', 'Jins'),
                              style: AppText.overline),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: _genderBtn(
                                  'MALE',
                                  "👨 ${tr(ref, 'auth.genderMale', 'Erkak')}"),
                            ),
                            AppSpacing.hGapSm,
                            Expanded(
                              child: _genderBtn(
                                  'FEMALE',
                                  "👩 ${tr(ref, 'auth.genderFemale', 'Ayol')}"),
                            ),
                          ]),
                          AppSpacing.gapMd,
                        ],

                        // Shop name
                        if (_role == 'barbershop') ...[
                          Text(tr(ref, 'auth.shopName', 'Salon nomi'),
                              style: AppText.overline),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _shopNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: AppText.body,
                            decoration: InputDecoration(
                              hintText: tr(ref, 'auth.shopNamePlaceholder',
                                  'Masalan: Lope Style'),
                            ),
                          ),
                          AppSpacing.gapMd,
                        ],

                        // Password
                        Text(tr(ref, 'auth.password', 'Parol'),
                            style: AppText.overline),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          style: AppText.body,
                          decoration: InputDecoration(
                            hintText: '••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: context.colors.textMuted,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        AppSpacing.gapMd,

                        // Promo
                        Text(
                            tr(ref, 'auth.promoCode',
                                'Promo-kod (ixtiyoriy)'),
                            style: AppText.overline),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _promoCtrl,
                          textCapitalization:
                              TextCapitalization.characters,
                          style: AppText.body,
                          decoration: InputDecoration(
                            hintText: tr(ref, 'auth.promoIfAny',
                                "Agar bor bo'lsa"),
                            suffixIcon: _promoStatus == 'checking'
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  )
                                : _promoStatus == 'valid'
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.success,
                                        size: 20)
                                    : _promoStatus == 'invalid'
                                        ? const Icon(Icons.cancel,
                                            color: AppColors.danger,
                                            size: 20)
                                        : null,
                          ),
                        ),
                        if (_promoStatus == 'valid')
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              tr(ref, 'auth.promoValid',
                                  'Promo-kod yaroqli'),
                              style: AppText.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else if (_promoStatus == 'invalid')
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 4, left: 4),
                            child: Text(
                              tr(ref, 'auth.promoInvalid',
                                  "Promo-kod noto'g'ri"),
                              style: AppText.caption.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        AppSpacing.gapMd,

                        // Role
                        Text(tr(ref, 'auth.accountType', 'Hisob turi'),
                            style: AppText.overline),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceElevated,
                            borderRadius: AppRadius.rMd,
                            border:
                                Border.all(color: context.colors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _role,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down,
                                  color: context.colors.textMuted),
                              onChanged: (v) {
                                if (v != null) {
                                  AppHaptics.selection();
                                  setState(() => _role = v);
                                }
                              },
                              items: [
                                DropdownMenuItem(
                                  value: 'user',
                                  child: Text(tr(ref,
                                      'auth.roleCustomer', 'Mijoz')),
                                ),
                                DropdownMenuItem(
                                  value: 'barber',
                                  child: Text(tr(ref,
                                      'auth.roleBarber', 'Sartarosh')),
                                ),
                                DropdownMenuItem(
                                  value: 'stylist',
                                  child: Text(tr(ref,
                                      'auth.roleStylist', 'Stilist')),
                                ),
                                DropdownMenuItem(
                                  value: 'cosmetologist',
                                  child: Text(tr(
                                      ref,
                                      'auth.roleCosmetologist',
                                      'Kosmetolog')),
                                ),
                                DropdownMenuItem(
                                  value: 'barbershop',
                                  child: Text(tr(ref,
                                      'auth.roleShop', 'Salon')),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          AppSpacing.gapMd,
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.danger
                                  .withValues(alpha: 0.1),
                              borderRadius: AppRadius.rSm,
                              border: Border.all(
                                color: AppColors.danger
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 16),
                              AppSpacing.hGapSm,
                              Expanded(
                                child: Text(_error!,
                                    style: AppText.bodySm.copyWith(
                                        color: AppColors.danger)),
                              ),
                            ]),
                          ),
                        ],

                        AppSpacing.gapLg,
                        AppButton(
                          label: tr(ref, 'auth.register',
                              "Ro'yxatdan o'tish"),
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          loading: _loading,
                          onPressed: _loading ? null : _submit,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderBtn(String key, String label) {
    final on = _gender == key;
    return TapScale(
      onTap: () {
        AppHaptics.selection();
        setState(() {
          _gender = on ? null : key;
        });
      },
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: on ? AppColors.primaryGradient : null,
          color: on ? null : context.colors.surfaceElevated,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: on ? AppColors.primary : context.colors.border,
            width: on ? 2 : 1,
          ),
          boxShadow:
              on ? AppShadows.primaryGlow(AppColors.primary) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.body.copyWith(
            color: on ? Colors.white : context.colors.textPrimary,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
