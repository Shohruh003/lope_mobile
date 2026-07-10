import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/shop_repository.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _geoAddressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _reminderDaysCtrl = TextEditingController(text: '20');
  final _reminderHoursCtrl = TextEditingController(text: '1');
  final _slotDurationCtrl = TextEditingController(text: '30');

  late List<_DayHours> _hours;
  bool _seeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hours = List.generate(
      7,
      (i) => _DayHours(
        day: _dayKeys[i],
        isOpen: i < 6,
        open: i == 5 ? '10:00' : '09:00',
        close: i == 5 ? '17:00' : '19:00',
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _geoAddressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _reminderDaysCtrl.dispose();
    _reminderHoursCtrl.dispose();
    _slotDurationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int i, bool isStart) async {
    final current = isStart ? _hours[i].open : _hours[i].close;
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      final s =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _hours[i] = _hours[i].copyWith(
          open: isStart ? s : _hours[i].open,
          close: isStart ? _hours[i].close : s);
    });
  }

  Future<void> _save() async {
    final reminderDays = int.tryParse(_reminderDaysCtrl.text.trim()) ?? 20;
    final reminderHours = int.tryParse(_reminderHoursCtrl.text.trim()) ?? 1;
    final slotDuration = int.tryParse(_slotDurationCtrl.text.trim()) ?? 30;

    if (reminderDays < 1 || reminderDays > 365) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.shop.profile.invalidReminder',
              "Eslatma kunlari 1-365 oraliqda bo'lsin"))));
      return;
    }
    if (slotDuration < 5 || slotDuration > 240) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.shop.profile.invalidSlot',
              "Slot 5-240 daqiqa oraliqda bo'lsin"))));
      return;
    }

    setState(() => _saving = true);
    try {
      final workingHours = <String, dynamic>{};
      for (final h in _hours) {
        workingHours[h.day] = {
          'isOpen': h.isOpen,
          'open': h.open,
          'close': h.close,
        };
      }
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      await ref.read(shopRepositoryProvider).updateMe({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'geoAddress': _geoAddressCtrl.text.trim(),
        'latitude': ?lat,
        'longitude': ?lng,
        'reminderDays': reminderDays,
        'reminderHoursBefore': reminderHours,
        'slotDuration': slotDuration,
        'workingHours': workingHours,
      });
      ref.invalidate(shopMeProvider);
      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openYandex() async {
    final q = _addressCtrl.text.trim();
    final lat = _latCtrl.text.trim();
    final lng = _lngCtrl.text.trim();
    final url = lat.isNotEmpty && lng.isNotEmpty
        ? 'https://yandex.uz/maps/?pt=$lng,$lat&z=16'
        : q.isNotEmpty
            ? 'https://yandex.uz/maps/?text=${Uri.encodeComponent(q)}'
            : 'https://yandex.uz/maps/';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _seed(Map<String, dynamic> m) {
    if (_seeded) return;
    _seeded = true;
    _nameCtrl.text = (m['name'] ?? '').toString();
    _phoneCtrl.text = (m['phone'] ?? '').toString();
    _addressCtrl.text = (m['address'] ?? m['location'] ?? '').toString();
    _geoAddressCtrl.text = (m['geoAddress'] ?? '').toString();
    final lat = m['latitude'];
    final lng = m['longitude'];
    if (lat is num) _latCtrl.text = lat.toString();
    if (lng is num) _lngCtrl.text = lng.toString();
    _reminderDaysCtrl.text =
        ((m['reminderDays'] ?? 20) as num).toInt().toString();
    _reminderHoursCtrl.text =
        ((m['reminderHoursBefore'] ?? 1) as num).toInt().toString();
    _slotDurationCtrl.text =
        ((m['slotDuration'] ?? 30) as num).toInt().toString();
    final wh = m['workingHours'];
    if (wh is Map) {
      for (var i = 0; i < _dayKeys.length; i++) {
        final v = wh[_dayKeys[i]];
        if (v is Map) {
          _hours[i] = _DayHours(
            day: _dayKeys[i],
            isOpen: v['isOpen'] == true,
            open: (v['open'] ?? '09:00').toString(),
            close: (v['close'] ?? '19:00').toString(),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopMeProvider);
    final dayShorts = trList(ref, 'mobile.dates.weekDaysShort',
        const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya']);
    return Scaffold(
      appBar: AppBar(
          title: Text(tr(ref, 'profile.barberProfile', "Salon profili"),
              style: AppText.titleMd)),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (m) {
          _seed(m);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
            children: [
              _SectionHeader(
                icon: Icons.store,
                title: tr(ref, 'mobile.shop.profile.basicInfo',
                    "Asosiy ma'lumotlar"),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(tr(ref, 'mobile.shop.profile.salonName', "Salon nomi")),
                    const SizedBox(height: 6),
                    TextField(controller: _nameCtrl),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'auth.phone', "Telefon")),
                    const SizedBox(height: 6),
                    TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'profile.location', "Manzil")),
                    const SizedBox(height: 6),
                    TextField(controller: _addressCtrl),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'mobile.shop.profile.geoAddress',
                        "Geo manzil (xaritada)")),
                    const SizedBox(height: 6),
                    TextField(controller: _geoAddressCtrl),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label(tr(ref, 'mobile.barber.location.lat',
                                "Kenglik")),
                            const SizedBox(height: 6),
                            TextField(
                                controller: _latCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                decoration: const InputDecoration(
                                    hintText: '41.299496')),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Label(tr(ref, 'mobile.barber.location.lng',
                                "Uzunlik")),
                            const SizedBox(height: 6),
                            TextField(
                                controller: _lngCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                decoration: const InputDecoration(
                                    hintText: '69.240073')),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: tr(ref, 'mobile.barber.location.findOnYandex',
                          "Yandex'da topish"),
                      leadingIcon: Icons.search,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: _openYandex,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: Icons.access_time,
                title: tr(ref, 'profile.workingHours', "Ish soatlari"),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: 6),
                          decoration: BoxDecoration(
                            color: _hours[i].isOpen
                                ? AppColors.primary.withValues(alpha: 0.04)
                                : AppColors.background,
                            borderRadius: AppRadius.rSm,
                            border: Border.all(
                                color: _hours[i].isOpen
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.border),
                          ),
                          child: Row(children: [
                            SizedBox(
                              width: 32,
                              child: Text(dayShorts[i],
                                  style: AppText.button.copyWith(
                                      color: _hours[i].isOpen
                                          ? AppColors.textBright
                                          : AppColors.textMuted,
                                      fontSize: 13)),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Row(children: [
                                _TimePill(
                                    label: _hours[i].open,
                                    enabled: _hours[i].isOpen,
                                    onTap: () => _pickTime(i, true)),
                                const SizedBox(width: 6),
                                const Text('—',
                                    style: TextStyle(
                                        color: AppColors.textMuted)),
                                const SizedBox(width: 6),
                                _TimePill(
                                    label: _hours[i].close,
                                    enabled: _hours[i].isOpen,
                                    onTap: () => _pickTime(i, false)),
                              ]),
                            ),
                            Switch(
                              value: _hours[i].isOpen,
                              activeThumbColor: AppColors.primary,
                              onChanged: (v) {
                                AppHaptics.selection();
                                setState(() =>
                                    _hours[i] = _hours[i].copyWith(isOpen: v));
                              },
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: Icons.settings,
                title: tr(ref, 'mobile.shop.profile.settings', "Sozlamalar"),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(tr(ref, 'mobile.shop.profile.reminderDays',
                        "Eslatma kunlari (oxirgi tashrifdan)")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reminderDaysCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(suffixText: 'kun'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'mobile.shop.profile.reminderHours',
                        "Bron oldidan eslatma (soat)")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reminderHoursCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(suffixText: 'soat'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'mobile.shop.profile.slotDuration',
                        "Slot davomiyligi")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _slotDurationCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(suffixText: 'daq'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: tr(ref, 'common.save', "Saqlash"),
                onPressed: _saving ? null : _save,
                loading: _saving,
                leadingIcon: Icons.check,
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayHours {
  const _DayHours({
    required this.day,
    required this.isOpen,
    required this.open,
    required this.close,
  });
  final String day;
  final bool isOpen;
  final String open;
  final String close;
  _DayHours copyWith({bool? isOpen, String? open, String? close}) =>
      _DayHours(
        day: day,
        isOpen: isOpen ?? this.isOpen,
        open: open ?? this.open,
        close: close ?? this.close,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppRadius.rSm,
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(title.toUpperCase(),
          style: AppText.overline
              .copyWith(color: AppColors.primary, letterSpacing: 1)),
    ]);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w500));
}

class _TimePill extends StatelessWidget {
  const _TimePill(
      {required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: enabled ? onTap : null,
      haptic: HapticStrength.light,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border),
        ),
        child: Text(label,
            style: AppText.button.copyWith(
                color: enabled ? AppColors.primary : AppColors.textMuted)),
      ),
    );
  }
}
