import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';

/// Mirrors the web `BarberScheduleScreen.tsx` 1:1:
///   1. Voice booking card at the top (hold-to-record mic button)
///   2. Horizontal 30-day date scroller — selected pill = primary bg, days
///      with slots = normal border, empty days = opacity 40%
///   3. Day header "12-yanvar, dushanba"
///   4. Either empty state with "Jadval yaratish" CTA OR a 3-column slot
///      grid with status-tinted buttons (green=available, blue=booked,
///      red=blocked) — lock icon top-right on blocked
class BarberScheduleScreen extends ConsumerStatefulWidget {
  const BarberScheduleScreen({super.key});

  @override
  ConsumerState<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends ConsumerState<BarberScheduleScreen> {
  late DateTime _selectedDate;

  // Voice recording state
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _voiceLoading = false;

  static const _months = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
  ];
  static const _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _weekDaysLong = [
    'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _slotStatus(String time, List<String> booked, List<String> blocked) {
    if (blocked.contains(time)) return 'blocked';
    if (booked.contains(time)) return 'booked';
    return 'available';
  }

  Future<void> _toggleRecording(String barberId) async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _voiceLoading = true;
      });
      if (path != null) {
        try {
          await ref.read(barberPanelRepositoryProvider).parseVoiceBooking(
                barberId: barberId,
                audioPath: path,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ovoz qabul qilindi")));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
          }
        }
      }
      setState(() => _voiceLoading = false);
      _refreshDay(barberId);
    } else {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Mikrofon ruxsati berilmadi")));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _isRecording = true);
    }
  }

  void _refreshDay(String barberId) {
    final key = (barberId: barberId, date: _dateStr(_selectedDate));
    ref.invalidate(scheduleSlotsProvider(key));
    ref.invalidate(bookedSlotsProvider(key));
    ref.invalidate(blockedSlotsProvider(key));
  }

  Future<void> _openSlotAction(String barberId, String time, String status) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(time,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textBright)),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (status == 'available')
            ListTile(
              leading: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
              title: const Text("Mijoz qo'shish",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Manual bron yaratish",
                  style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(sheetCtx).pop('book'),
            ),
          if (status != 'blocked')
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.danger),
              title: const Text("Slotni bloklash"),
              onTap: () => Navigator.of(sheetCtx).pop('block'),
            ),
          if (status == 'blocked')
            ListTile(
              leading: const Icon(Icons.lock_open, color: AppColors.success),
              title: const Text("Blokni olib tashlash"),
              onTap: () => Navigator.of(sheetCtx).pop('unblock'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text("Slotni o'chirish"),
            onTap: () => Navigator.of(sheetCtx).pop('delete'),
          ),
          ListTile(
            leading: const Icon(Icons.close, color: AppColors.textMuted),
            title: const Text("Yopish"),
            onTap: () => Navigator.of(sheetCtx).pop(null),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    try {
      final dateStr = _dateStr(_selectedDate);
      final repo = ref.read(barberPanelRepositoryProvider);
      if (picked == 'book') {
        if (!mounted) return;
        await _openManualBookingDialog(barberId, dateStr, time);
        return;
      }
      if (picked == 'block' || picked == 'unblock') {
        await repo.toggleSlotBlock(barberId, dateStr, time);
      } else if (picked == 'delete') {
        final current = await repo.getDaySchedule(barberId, dateStr);
        final updated = current.where((t) => t != time).toList();
        await repo.saveDaySchedule(barberId: barberId, date: dateStr, slots: updated);
      }
      _refreshDay(barberId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    }
  }

  /// Manual booking dialog — barber types client name + phone, selects
  /// services from their list, and submits POST /bookings/manual with the
  /// pre-filled time.
  Future<void> _openManualBookingDialog(String barberId, String dateStr, String time) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final services =
        await ref.read(barberPanelRepositoryProvider).servicesForBarber(barberId);
    if (!mounted) return;
    final selected = <String>{};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text("$time uchun mijoz qo'shish",
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBright)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await _pickContact();
                      if (picked == null) return;
                      setSheet(() {
                        if (picked.name.isNotEmpty) nameCtrl.text = picked.name;
                        if (picked.phone.isNotEmpty) phoneCtrl.text = picked.phone;
                      });
                    },
                    icon: const Icon(Icons.perm_contact_calendar_outlined, size: 16),
                    label: const Text("Kontakt"),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: "Mijoz ismi"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: "Telefon (ixtiyoriy)"),
                ),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  const Text("Xizmatlar belgilanmagan",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                else ...[
                  const Text("Xizmat",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: services.map((s) {
                      final id = s['id'] as String;
                      final name = (s['nameUz'] ?? s['name'] ?? '').toString();
                      final on = selected.contains(id);
                      return FilterChip(
                        label: Text(name),
                        selected: on,
                        onSelected: (v) => setSheet(() {
                          if (v) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(true),
                    child: const Text("Saqlash"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    try {
      await ref.read(barberPanelRepositoryProvider).createManual(
            barberId: barberId,
            date: dateStr,
            time: time,
            serviceIds: selected.toList(),
            guestName: nameCtrl.text.trim(),
            guestPhone: phoneCtrl.text.trim(),
          );
      _refreshDay(barberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Mijoz qo'shildi")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  Future<void> _openAddSchedule(String barberId) async {
    // Pick: generator or single slot
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Jadval qo'shish",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textBright)),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.auto_awesome_motion, color: AppColors.primary),
            title: const Text("Avtomatik (vaqt oralig'i)"),
            subtitle: const Text("Boshlanish va tugash vaqtidan slotlar generatsiya"),
            onTap: () => Navigator.of(sheetCtx).pop('generator'),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: AppColors.primary),
            title: const Text("Bitta slot qo'shish"),
            subtitle: const Text("Aniq bir HH:MM vaqtni qo'shish"),
            onTap: () => Navigator.of(sheetCtx).pop('single'),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (choice == 'single') {
      if (!mounted) return;
      final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
      if (picked == null) return;
      final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      try {
        final dateStr = _dateStr(_selectedDate);
        final current = await ref.read(barberPanelRepositoryProvider).getDaySchedule(barberId, dateStr);
        if (current.contains(time)) return;
        final updated = [...current, time]..sort();
        await ref.read(barberPanelRepositoryProvider)
            .saveDaySchedule(barberId: barberId, date: dateStr, slots: updated);
        _refreshDay(barberId);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    } else if (choice == 'generator') {
      if (mounted) context.push('/barber/schedule-generator');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final barberId = user.id;
    final dateStr = _dateStr(_selectedDate);
    final key = (barberId: barberId, date: dateStr);

    final slotsAsync = ref.watch(scheduleSlotsProvider(key));
    final bookedAsync = ref.watch(bookedSlotsProvider(key));
    final blockedAsync = ref.watch(blockedSlotsProvider(key));

    final selectedWeekday = _weekDaysLong[_selectedDate.weekday - 1];
    final dateHeader = "${_selectedDate.day}-${_months[_selectedDate.month - 1].toLowerCase()}, ${selectedWeekday.toLowerCase()}";

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ===== Voice booking card =====
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _voiceLoading ? null : () => _toggleRecording(barberId),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRecording
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRecording
                            ? "Yozilmoqda..."
                            : (_voiceLoading ? "Tahlil qilinmoqda..." : "Ovoz bilan bron"),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBright),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isRecording
                            ? "To'xtatish uchun yana bosing"
                            : "Mikrofonni bosib, ismni, vaqtni ayting",
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _isRecording ? AppColors.danger : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _voiceLoading
                      ? const Center(
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        )
                      : Icon(_isRecording ? Icons.mic_off : Icons.mic, color: Colors.white, size: 22),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 14),

          // ===== Date scroller (30 days) =====
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (context, i) {
                final d = DateTime.now().add(Duration(days: i));
                final dateOnly = DateTime(d.year, d.month, d.day);
                final selectedOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                final isSelected = dateOnly.isAtSameMomentAs(selectedOnly);
                final isToday = i == 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _selectedDate = dateOnly),
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isToday ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekDays[d.weekday - 1].toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white70 : AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.day.toString(),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.textBright),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _months[d.month - 1].substring(0, 3).toLowerCase(),
                            style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? Colors.white70 : AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // ===== Day header =====
          Text(dateHeader,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textBright)),
          const SizedBox(height: 10),

          // ===== Slot grid OR empty state =====
          slotsAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted)),
            ),
            data: (slots) {
              if (slots.isEmpty) {
                // Empty state — dashed box + button
                return _EmptyState(onAdd: () => _openAddSchedule(barberId));
              }

              final booked = bookedAsync.maybeWhen(data: (v) => v, orElse: () => <String>[]);
              final blocked = blockedAsync.maybeWhen(data: (v) => v, orElse: () => <String>[]);

              return Column(children: [
                // Legend + Add button
                Row(children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      children: const [
                        _LegendDot(color: Color(0xFF22C55E), label: "Bo'sh"),
                        _LegendDot(color: Color(0xFF3B82F6), label: "Band"),
                        _LegendDot(color: Color(0xFFEF4444), label: "Bloklangan"),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _openAddSchedule(barberId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.add, size: 14, color: AppColors.primary),
                        SizedBox(width: 2),
                        Text("Qo'shish",
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),

                const SizedBox(height: 10),

                // 3-column slot grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final time = slots[i];
                    final status = _slotStatus(time, booked, blocked);
                    final color = status == 'booked'
                        ? const Color(0xFF3B82F6)
                        : status == 'blocked'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF22C55E);
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openSlotAction(barberId, time, status),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Stack(children: [
                          Center(
                            child: Text(time,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                          ),
                          if (status == 'blocked')
                            Positioned(
                              top: 2, right: 4,
                              child: Icon(Icons.lock, size: 11, color: color.withValues(alpha: 0.7)),
                            ),
                          if (status == 'booked')
                            Positioned(
                              top: 2, right: 4,
                              child: Text("BAND",
                                  style: TextStyle(
                                      fontSize: 8, fontWeight: FontWeight.w800, color: color)),
                            ),
                        ]),
                      ),
                    ).animate().fadeIn(duration: 150.ms, delay: (i * 15).ms);
                  },
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  /// Open the OS contact picker and return the first chosen contact's
  /// (name, phone) tuple. Returns `null` on cancel or denied permission.
  /// Phone is normalised to digits-only with optional leading "+".
  Future<_PickedContact?> _pickContact() async {
    // The picker itself is permissionless on both platforms, BUT to read the
    // chosen contact's phone numbers on Android we need READ_CONTACTS.
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final hasPerm = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kontaktlarga ruxsat berilmadi")));
      }
      return null;
    }
    try {
      final c = await FlutterContacts.native
          .showPicker(properties: {ContactProperty.name, ContactProperty.phone});
      if (c == null) return null;
      final name = (c.displayName ?? '').trim();
      final phone = (c.phones.isNotEmpty ? c.phones.first.number : '')
          .replaceAll(RegExp(r'[^\d+]'), '');
      return _PickedContact(name: name, phone: phone);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Kontaktni o'qib bo'lmadi: $e")));
      }
      return null;
    }
  }
}

class _PickedContact {
  const _PickedContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(children: [
        const Icon(Icons.access_time, color: AppColors.textMuted, size: 40),
        const SizedBox(height: 8),
        const Text("Jadval yo'q",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textBright)),
        const SizedBox(height: 4),
        const Text("Ish vaqtingizni belgilang",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Jadval qo'shish"),
            onPressed: onAdd,
          ),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
    ]);
  }
}
