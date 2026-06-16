import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text("Xizmatlarim")),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text("Yangi xizmat"),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_cut, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text("Hali xizmat qo'shilmagan",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text("Pastdagi tugma orqali qo'shing",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
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
                            Text("${_fmt(price)} so'm  •  $dur daq",
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
            Text(existing == null ? "Yangi xizmat" : "Xizmatni tahrirlash",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(hintText: "Nomi (masalan: Soch olish)")),
            const SizedBox(height: 12),
            TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "Narxi (so'm)")),
            const SizedBox(height: 12),
            TextField(
                controller: dur,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "Davomiyligi (daqiqa)")),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> svc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Xizmatni o'chirish?"),
        content: Text("\"${(svc['nameUz'] ?? svc['name'] ?? '').toString()}\" o'chirilsinmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text("Bekor")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text("O'chirish"),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
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
