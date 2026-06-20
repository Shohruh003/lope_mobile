import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/barber_profile_repository.dart';

/// Services CRUD: list + add/edit/delete. Each service has a name, price (so'm),
/// and duration (minutes). Web equivalent: BarberProfileEditScreen's Services
/// tab.
class BarberServicesScreen extends ConsumerWidget {
  const BarberServicesScreen({super.key, required this.barberId});
  final String barberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barberServicesProvider(barberId));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.barber.services.title', "Xizmatlarim"))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'mobile.barber.services.addBtn', "Yangi xizmat")),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_cut, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(tr(ref, 'mobile.barber.services.empty', "Hali xizmat qo'shilmagan"),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(tr(ref, 'mobile.barber.services.emptyHint', "Pastdagi tugma orqali qo'shing"),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(barberServicesProvider(barberId).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final svc = list[i];
                final name = (svc['nameUz'] ?? svc['name'] ?? '').toString();
                final price = ((svc['price'] ?? 0) as num).toInt();
                final dur = ((svc['duration'] ?? 30) as num).toInt();
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.content_cut, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text("${_fmt(price)} ${tr(ref, 'common.currency', "so'm")}  •  $dur ${tr(ref, 'booking.duration', 'daq')}",
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: () => _openEditor(context, ref, existing: svc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger, size: 20),
                        onPressed: () => _confirmDelete(context, ref, svc),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (i * 40).ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: (existing?['nameUz'] ?? existing?['name'] ?? '').toString());
    final price = TextEditingController(text: existing?['price']?.toString() ?? '');
    final dur = TextEditingController(text: existing?['duration']?.toString() ?? '30');
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                existing == null
                    ? tr(ref, 'mobile.barber.services.newTitle', "Yangi xizmat")
                    : tr(ref, 'mobile.barber.services.editTitle', "Xizmatni tahrirlash"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
                controller: name,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.barber.services.namePh',
                        "Nomi (masalan: Soch olish)"))),
            const SizedBox(height: 12),
            TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.barber.services.pricePh',
                        "Narxi (so'm)"))),
            const SizedBox(height: 12),
            TextField(
                controller: dur,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.barber.services.durationPh',
                        "Davomiyligi (daqiqa)"))),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: Text(tr(ref, 'common.save', "Saqlash")),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final body = {
      'nameUz': name.text.trim(),
      'name': name.text.trim(),
      'price': int.tryParse(price.text.trim()) ?? 0,
      'duration': int.tryParse(dur.text.trim()) ?? 30,
    };
    try {
      final repo = ref.read(barberProfileRepositoryProvider);
      if (existing == null) {
        await repo.createService(barberId, body);
      } else {
        await repo.updateService(barberId, existing['id'] as String, body);
      }
      ref.invalidate(barberServicesProvider(barberId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> svc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr(ref, 'mobile.barber.services.deleteTitle', "Xizmatni o'chirish?")),
        content: Text(tr(ref, 'mobile.barber.services.deleteAsk',
            "\"{{name}}\" o'chirilsinmi?",
            {'name': (svc['nameUz'] ?? svc['name'] ?? '').toString()})),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'common.delete', "O'chirish")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(barberProfileRepositoryProvider).deleteService(barberId, svc['id'] as String);
      ref.invalidate(barberServicesProvider(barberId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
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
