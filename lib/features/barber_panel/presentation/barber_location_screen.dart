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

class BarberLocationScreen extends ConsumerStatefulWidget {
  const BarberLocationScreen({super.key});
  @override
  ConsumerState<BarberLocationScreen> createState() =>
      _BarberLocationScreenState();
}

class _BarberLocationScreenState
    extends ConsumerState<BarberLocationScreen> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _seeded = false;
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String barberId) async {
    AppHaptics.medium();
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      AppHaptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.barber.location.invalidLatLng',
              "Kenglik / Uzunlik noto'g'ri"))));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(barberProfileRepositoryProvider)
          .updateBarber(barberId, {
        'latitude': lat,
        'longitude': lng,
        'geoAddress': _addressCtrl.text.trim(),
      });
      ref.invalidate(barberProfileProvider(barberId));
      AppHaptics.success();
      if (mounted) {
        setState(() => _editing = false);
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

  Future<void> _openYandex() async {
    AppHaptics.light();
    final lat = _latCtrl.text.trim();
    final lng = _lngCtrl.text.trim();
    final url = (lat.isEmpty || lng.isEmpty)
        ? 'https://yandex.uz/maps/?text=Tashkent'
        : 'https://yandex.uz/maps/?pt=$lng,$lat&z=16';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyAddress(String text) async {
    AppHaptics.light();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.barber.location.copied',
              'Nusxalandi'))));
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
        title: Row(children: [
          const Icon(Icons.location_on,
              color: AppColors.primary, size: 22),
          AppSpacing.hGapSm,
          Text(
            tr(ref, 'barberApp.myLocation', 'Manzilim'),
            style: AppText.titleMd,
          ),
        ]),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _latCtrl.text =
                (b['latitude'] ?? b['lat'] ?? '').toString();
            _lngCtrl.text =
                (b['longitude'] ?? b['lng'] ?? '').toString();
            _addressCtrl.text = (b['geoAddress'] ??
                    b['locationUz'] ??
                    b['location'] ??
                    '')
                .toString();
          }
          final hasLocation = _addressCtrl.text.isNotEmpty;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _seeded = false;
              // Force a re-fetch — ref.watch above will re-emit on the
              // new state so we don't need the returned future here.
              // ignore: unused_result
              ref.refresh(barberProfileProvider(user.id));
            },
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              if (_editing) ...[
                Text(
                  tr(ref, 'mobile.barber.location.editHint',
                      'Mijozlar sizni xaritada topa olishi uchun aniq manzil va koordinatalarni kiriting'),
                  style: AppText.bodyLg
                      .copyWith(color: context.colors.textSecondary),
                ),
                AppSpacing.gapLg,
                AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr(ref, 'mobile.barber.location.addressLabel',
                            'Manzil matni'),
                        style: AppText.overline,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        style: AppText.body,
                        decoration: InputDecoration(
                          hintText: tr(
                              ref,
                              'mobile.barber.location.addressPlaceholder',
                              "Toshkent, Yunusobod tumani, Amir Temur ko'chasi 7"),
                        ),
                      ),
                      AppSpacing.gapMd,
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                tr(ref,
                                    'mobile.barber.location.latitude',
                                    'Kenglik'),
                                style: AppText.overline,
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _latCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.\-]'))
                                ],
                                style: AppText.body.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: const InputDecoration(
                                    hintText: '41.311081'),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.hGapSm,
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                tr(ref,
                                    'mobile.barber.location.longitude',
                                    'Uzunlik'),
                                style: AppText.overline,
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _lngCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.\-]'))
                                ],
                                style: AppText.body.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: const InputDecoration(
                                    hintText: '69.240562'),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      AppSpacing.gapMd,
                      AppButton(
                        label: tr(
                            ref,
                            'mobile.barber.location.openYandex',
                            "Yandex Maps'dan koordinata olish"),
                        leadingIcon: Icons.open_in_new,
                        variant: AppButtonVariant.secondary,
                        fullWidth: true,
                        onPressed: _openYandex,
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'common.cancel', 'Bekor'),
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = false),
                      fullWidth: true,
                    ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'common.save', 'Saqlash'),
                      variant: AppButtonVariant.primary,
                      loading: _saving,
                      onPressed: _saving ? null : () => _save(user.id),
                      fullWidth: true,
                    ),
                  ),
                ]),
              ] else ...[
                if (hasLocation)
                  AppCard(
                    variant: AppCardVariant.outlined,
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.15),
                            borderRadius: AppRadius.rSm,
                          ),
                          child: const Icon(Icons.location_on,
                              color: AppColors.primary, size: 22),
                        ),
                        AppSpacing.hGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(_addressCtrl.text,
                                  style: AppText.body),
                              if (_latCtrl.text.isNotEmpty &&
                                  _lngCtrl.text.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${_latCtrl.text}, ${_lngCtrl.text}',
                                  style: AppText.caption.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        AppSpacing.hGapSm,
                        TapScale(
                          onTap: () =>
                              _copyAddress(_addressCtrl.text),
                          scale: 0.9,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: context.colors.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.copy,
                                size: 14,
                                color: context.colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AppEmptyState(
                    icon: Icons.location_off,
                    title: tr(ref, 'barbers.locationNotSet',
                        'Manzil belgilanmagan'),
                  ),
                AppSpacing.gapLg,
                AppButton(
                  label: hasLocation
                      ? tr(
                          ref,
                          'mobile.barber.location.changeBtn',
                          "Manzilni o'zgartirish")
                      : tr(
                          ref,
                          'mobile.barber.location.setBtn',
                          'Manzilni belgilash'),
                  leadingIcon: Icons.location_on,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => setState(() => _editing = true),
                ),
              ],
            ],
          ),
          );
        },
      ),
    );
  }
}
