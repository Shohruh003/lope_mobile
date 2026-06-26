import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

/// Edit the salon's profile and operations settings. Mirrors the web
/// BarbershopSettings page: name / phone / address, daily working
/// hours (7-day grid), reminderDays, reminderHoursBefore,
/// slotDuration. Map picker (lat/lng) is deferred — addressed via
/// the address text input for now.
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
        isOpen: i < 6, // Sunday off by default
        open: i == 5 ? '10:00' : '09:00', // Saturday opens later
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
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
      appBar: AppBar(title: Text(tr(ref, 'profile.barberProfile', "Salon profili"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                style: const TextStyle(color: AppColors.textMuted))),
        data: (m) {
          _seed(m);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Section(tr(ref, 'mobile.shop.profile.basicInfo', "Asosiy ma'lumotlar")),
              const SizedBox(height: 8),
              _Label(tr(ref, 'mobile.shop.profile.salonName', "Salon nomi")),
              const SizedBox(height: 6),
              TextField(controller: _nameCtrl),
              const SizedBox(height: 12),
              _Label(tr(ref, 'auth.phone', "Telefon")),
              const SizedBox(height: 6),
              TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _Label(tr(ref, 'profile.location', "Manzil")),
              const SizedBox(height: 6),
              TextField(controller: _addressCtrl),
              const SizedBox(height: 12),
              _Label(tr(ref, 'mobile.shop.profile.geoAddress',
                  "Geo manzil (xaritada)")),
              const SizedBox(height: 6),
              TextField(controller: _geoAddressCtrl),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label(tr(
                          ref, 'mobile.barber.location.lat', "Kenglik")),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label(tr(
                          ref, 'mobile.barber.location.lng', "Uzunlik")),
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search, size: 16),
                  label: Text(tr(ref, 'mobile.barber.location.findOnYandex',
                      "Yandex'da topish")),
                  onPressed: _openYandex,
                ),
              ),
              const SizedBox(height: 22),
              _Section(tr(ref, 'profile.workingHours', "Ish soatlari")),
              const SizedBox(height: 8),
              for (var i = 0; i < 7; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 28,
                      child: Text(dayShorts[i],
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(children: [
                        _TimePill(
                            label: _hours[i].open,
                            enabled: _hours[i].isOpen,
                            onTap: () => _pickTime(i, true)),
                        const SizedBox(width: 6),
                        const Text('—', style: TextStyle(color: AppColors.textMuted)),
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
                      onChanged: (v) => setState(() =>
                          _hours[i] = _hours[i].copyWith(isOpen: v)),
                    ),
                  ]),
                ),

              const SizedBox(height: 22),
              _Section(tr(ref, 'mobile.shop.profile.settings', "Sozlamalar")),
              const SizedBox(height: 8),
              _Label(tr(ref, 'mobile.shop.profile.reminderDays', "Eslatma kunlari (oxirgi tashrifdan)")),
              const SizedBox(height: 6),
              TextField(
                controller: _reminderDaysCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'kun'),
              ),
              const SizedBox(height: 12),
              _Label(tr(ref, 'mobile.shop.profile.reminderHours',
                  "Bron oldidan eslatma (soat)")),
              const SizedBox(height: 6),
              TextField(
                controller: _reminderHoursCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'soat'),
              ),
              const SizedBox(height: 12),
              _Label(tr(ref, 'mobile.shop.profile.slotDuration', "Slot davomiyligi")),
              const SizedBox(height: 6),
              TextField(
                controller: _slotDurationCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'daq'),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
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

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600));
}

class _TimePill extends StatelessWidget {
  const _TimePill(
      {required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: enabled ? AppColors.primary : AppColors.textMuted)),
      ),
    );
  }
}
