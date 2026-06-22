import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

/// Edit the salon's public profile — name, phone, address, description.
class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(shopRepositoryProvider).updateMe({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      });
      ref.invalidate(shopMeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopMeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Salon profili")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")),
        data: (m) {
          if (!_seeded) {
            _seeded = true;
            _nameCtrl.text = (m['name'] ?? '').toString();
            _phoneCtrl.text = (m['phone'] ?? '').toString();
            _addressCtrl.text = (m['address'] ?? m['location'] ?? '').toString();
            _descCtrl.text = (m['description'] ?? '').toString();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Label("Salon nomi"),
              const SizedBox(height: 6),
              TextField(controller: _nameCtrl),

              const SizedBox(height: 14),
              _Label("Telefon"),
              const SizedBox(height: 6),
              TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone),

              const SizedBox(height: 14),
              _Label("Manzil"),
              const SizedBox(height: 6),
              TextField(controller: _addressCtrl),

              const SizedBox(height: 14),
              _Label("Tavsif"),
              const SizedBox(height: 6),
              TextField(controller: _descCtrl, maxLines: 4),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Saqlash"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ignore: non_constant_identifier_names
  Widget _Label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600));
}
