import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_profile_repository.dart';

/// Mirrors `BarberLocationPage.tsx`. Two modes:
///   - **View mode** (default): card with address + lat/lng + copy button +
///     "Manzilni o'zgartirish" CTA
///   - **Edit mode**: address text + lat/lng inputs + "Yandex'da topish" +
///     Save/Cancel
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
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.barber.location.invalidLatLng', "Lat/Lng noto'g'ri"))));
      return;
    }
    setState(() => _saving = true);
    try {
      // Prisma rejects unknown args — only send the three columns the
      // Barber model actually has. Web sends exactly these three.
      await ref.read(barberProfileRepositoryProvider).updateBarber(barberId, {
        'latitude': lat,
        'longitude': lng,
        'geoAddress': _addressCtrl.text.trim(),
      });
      ref.invalidate(barberProfileProvider(barberId));
      if (mounted) {
        setState(() => _editing = false);
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
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.barber.location.copied', "Nusxalandi"))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberProfileProvider(user.id));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(children: [
          // ===== Header =====
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.location_on, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(tr(ref, 'barberApp.myLocation', "Manzilim"),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright)),
            ]),
          ),

          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                      style: const TextStyle(color: AppColors.textMuted))),
              data: (b) {
                if (!_seeded) {
                  _seeded = true;
                  _latCtrl.text = (b['latitude'] ?? b['lat'] ?? '').toString();
                  _lngCtrl.text = (b['longitude'] ?? b['lng'] ?? '').toString();
                  _addressCtrl.text = (b['geoAddress'] ?? b['locationUz'] ?? b['location'] ?? '').toString();
                }
                final hasLocation = _addressCtrl.text.isNotEmpty;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_editing) ...[
                      // ===== Edit mode =====
                      Text(
                        tr(ref, 'mobile.barber.location.editHint',
                            "Mijozlar sizni xaritada topa olishi uchun aniq manzil va koordinatalarni kiriting"),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 14),

                      const ShadLabel("Manzil matni"),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                            hintText: tr(ref, 'mobile.barber.location.addressPlaceholder',
                                "Toshkent, Yunusobod tumani, Amir Temur ko'chasi 7")),
                      ),

                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            const ShadLabel("Latitude"),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _latCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: AppColors.textBright,
                                  fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(hintText: "41.311081"),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            const ShadLabel("Longitude"),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _lngCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: AppColors.textBright,
                                  fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(hintText: "69.240562"),
                            ),
                          ]),
                        ),
                      ]),

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: Text(
                              tr(ref, 'mobile.barber.location.openYandex',
                                  "Yandex Maps'dan koordinata olish"),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _openYandex,
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _editing = false),
                              child: Text(tr(ref, 'common.cancel', "Bekor")),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _saving ? null : () => _save(user.id),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(tr(ref, 'common.save', "Saqlash")),
                            ),
                          ),
                        ),
                      ]),
                    ] else ...[
                      // ===== View mode =====
                      if (hasLocation)
                        ShadCard(
                          padding: const EdgeInsets.all(14),
                          child: Stack(children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2, right: 8),
                                  child: Icon(Icons.location_on,
                                      color: AppColors.primary, size: 16),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(right: 30),
                                        child: Text(_addressCtrl.text,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textBright,
                                                height: 1.4)),
                                      ),
                                      if (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          "${_latCtrl.text}, ${_lngCtrl.text}",
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                              color: AppColors.textMuted),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _copyAddress(_addressCtrl.text),
                                child: Container(
                                  width: 26, height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.copy,
                                      size: 12, color: AppColors.textMuted),
                                ),
                              ),
                            ),
                          ]),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 26),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.location_off,
                                  size: 36, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              Text(tr(ref, 'barbers.locationNotSet', "Manzil belgilanmagan"),
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 13)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.location_on, size: 16),
                          label: Text(hasLocation
                              ? "Manzilni o'zgartirish"
                              : "Manzilni belgilash"),
                          onPressed: () => setState(() => _editing = true),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
