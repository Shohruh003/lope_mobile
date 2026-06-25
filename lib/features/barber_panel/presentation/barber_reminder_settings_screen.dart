import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_profile_repository.dart';

/// Two-knob settings for the SMS reminder system:
///   reminderHoursBefore: 1..6 — how far before a booking to send the SMS
///     (web restricted to 1..6 in commit 9bfae71; SMS provider rate-limits
///      anything longer than ~6h reliably)
///   reminderDays: 7..30 — lookback window for the "next reminder due" sweep
class BarberReminderSettingsScreen extends ConsumerStatefulWidget {
  const BarberReminderSettingsScreen({super.key});

  @override
  ConsumerState<BarberReminderSettingsScreen> createState() => _BarberReminderSettingsScreenState();
}

class _BarberReminderSettingsScreenState extends ConsumerState<BarberReminderSettingsScreen> {
  int _hours = 1;
  int _days = 14;
  bool _saving = false;
  bool _seeded = false;

  Future<void> _save(String barberId) async {
    setState(() => _saving = true);
    try {
      await ref.read(barberProfileRepositoryProvider).updateBarber(barberId, {
        'reminderHoursBefore': _hours,
        'reminderDays': _days,
      });
      ref.invalidate(barberProfileProvider(barberId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(barberProfileProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.barber.reminders.title', "Eslatma sozlamalari"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _hours = ((b['reminderHoursBefore'] ?? 1) as num).toInt().clamp(1, 6);
            _days = ((b['reminderDays'] ?? 14) as num).toInt().clamp(7, 30);
          }
          final isShopManaged =
              (b['barbershopId'] ?? '').toString().isNotEmpty;
          if (isShopManaged) {
            // Shop-managed barber: cron uses the salon's reminder values,
            // not the barber's. Saving here would set ignored fields, so
            // we explain and hide the steppers — mirrors web's
            // BarberReminderSettingsScreen `isShopManaged` branch.
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                tr(ref,
                                    'reminderSettings.shopManagedTitle',
                                    "Salon eslatma sozlamalarini boshqaradi"),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textBright)),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                            tr(ref,
                                'reminderSettings.shopManagedDescription',
                                "Siz salonga biriktirilgansiz. Eslatmalar vaqti va davri salon profilida belgilanadi."),
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.5)),
                      ]),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                tr(ref, 'mobile.barber.reminders.hint',
                    "Mijozlarga SMS bilan eslatma jo'natiladi. Quyida vaqtni va davrni sozlang."),
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),

              _SectionLabel(tr(ref, 'mobile.barber.reminders.hoursLabel', "Bron oldidan necha soat")),
              _Stepper(
                value: _hours,
                min: 1, max: 6,
                suffix: tr(ref, 'mobile.barber.reminders.hoursSuffix', " soat"),
                onChanged: (v) => setState(() => _hours = v),
              ),

              const SizedBox(height: 18),
              _SectionLabel(tr(ref, 'mobile.barber.reminders.daysLabel', "Eslatma davri (kunlarda)")),
              _Stepper(
                value: _days,
                min: 7, max: 30,
                suffix: tr(ref, 'mobile.barber.reminders.daysSuffix', " kun"),
                onChanged: (v) => setState(() => _days = v),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(user.id),
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

// ignore: non_constant_identifier_names
Widget _SectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
    );

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
          ),
          Expanded(
            child: Center(
              child: Text("$value$suffix",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
