import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_profile_repository.dart';

/// Barber's location editor. Manual lat/lng + address fields plus an "Open
/// in Google Maps" helper so the barber can grab their coords visually.
class BarberLocationScreen extends ConsumerStatefulWidget {
  const BarberLocationScreen({super.key});

  @override
  ConsumerState<BarberLocationScreen> createState() => _BarberLocationScreenState();
}

class _BarberLocationScreenState extends ConsumerState<BarberLocationScreen> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String barberId) async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lat/Lng noto'g'ri")));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(barberProfileRepositoryProvider).updateBarber(barberId, {
        'lat': lat,
        'lng': lng,
        'locationUz': _addressCtrl.text.trim(),
        'location': _addressCtrl.text.trim(),
      });
      ref.invalidate(barberProfileProvider(barberId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openMap() async {
    final lat = _latCtrl.text.trim();
    final lng = _lngCtrl.text.trim();
    final q = (lat.isEmpty || lng.isEmpty) ? 'Tashkent' : '$lat,$lng';
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(barberProfileProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: const Text("Manzilim")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e")),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _latCtrl.text = (b['lat'] ?? '').toString();
            _lngCtrl.text = (b['lng'] ?? '').toString();
            _addressCtrl.text = (b['locationUz'] ?? b['location'] ?? '').toString();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                "Mijozlar sizni Google Maps'da topa olishi uchun manzilingizni belgilang.",
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),

              const _Label("Manzil matni"),
              const SizedBox(height: 6),
              TextField(controller: _addressCtrl, decoration: const InputDecoration(hintText: "Shahar, ko'cha, uy")),

              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label("Latitude"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _latCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\-]'))],
                        decoration: const InputDecoration(hintText: "41.311081"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label("Longitude"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _lngCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\-]'))],
                        decoration: const InputDecoration(hintText: "69.240562"),
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text("Google Maps'da ko'rsatish"),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(user.id),
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
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600));
}
