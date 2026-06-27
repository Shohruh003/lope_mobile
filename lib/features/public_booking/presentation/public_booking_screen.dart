import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Public, no-auth booking page reached via a shared link like
/// `app.lopestyle.uz/b/:slug`. The slug resolves to a barber server-side; the
/// customer picks a service + date + time and supplies their phone (verified
/// via SMS OTP). Mirrors the web's PublicBarberBookingPage.
class PublicBookingScreen extends ConsumerStatefulWidget {
  const PublicBookingScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<PublicBookingScreen> createState() => _PublicBookingScreenState();
}

class _PublicBookingScreenState extends ConsumerState<PublicBookingScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _selected = <String>{};
  DateTime _date = DateTime.now();
  String? _time;
  bool _busy = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> _loadSlots(String barberId) async {
    final dio = ref.read(dioProvider);
    final d = '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    try {
      // Web fetches BOTH the day-schedule and booked-slots and subtracts.
      // No public-only routes exist — these endpoints are unauthenticated
      // (no @UseGuards on either controller). Old /barbers/:id/schedule/:d
      // had no handler so public booking never had a list of times to show.
      final results = await Future.wait([
        dio
            .get('/schedule/$barberId/$d')
            .then((r) {
              final d = r.data;
              if (d is Map && d['slots'] is List) {
                return (d['slots'] as List).map((e) => e.toString()).toList();
              }
              return <String>[];
            })
            .catchError((_) => <String>[]),
        dio
            .get('/bookings/booked-slots',
                queryParameters: {'barberId': barberId, 'date': d})
            .then((r) {
              final d = r.data;
              if (d is List) return d.map((e) => e.toString()).toList();
              if (d is Map && d['slots'] is List) {
                return (d['slots'] as List).map((e) => e.toString()).toList();
              }
              return <String>[];
            })
            .catchError((_) => <String>[]),
      ]);
      final scheduleSlots = results[0];
      final booked = results[1].toSet();
      return scheduleSlots.where((s) => !booked.contains(s)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _submit(
      String barberId, List<Map<String, dynamic>> allServices) async {
    if (_selected.isEmpty || _time == null) {
      setState(() => _error = tr(ref, 'mobile.publicBooking.pickServiceTime',
          "Xizmat va vaqt tanlang"));
      return;
    }
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 9) {
      setState(() => _error = tr(ref, 'common.validation.invalidPhone',
          "Telefon raqami noto'g'ri"));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      // Backend: POST /public/bookings/:slug (public-booking.controller.ts:43).
      // Slug goes in URL, full services snapshot in body — same shape as
      // /bookings/manual minus barberId. Old /bookings/public route had no
      // handler so EVERY share-link booking was silently 404'ing.
      final picked = allServices
          .where((s) => _selected.contains((s['id'] ?? '').toString()))
          .toList();
      final services = picked.map((s) => {
            'id': s['id'],
            'name': (s['name'] ?? s['nameUz'] ?? '').toString(),
            'nameUz': (s['nameUz'] ?? s['name'] ?? '').toString(),
            'nameRu': (s['nameRu'] ?? '').toString(),
            'price': ((s['price'] ?? 0) as num).toInt(),
            'duration': ((s['duration'] ?? 30) as num).toInt(),
            'icon': (s['icon'] ?? '✂️').toString(),
          }).toList();
      final totalPrice = picked.fold<int>(
          0, (a, s) => a + ((s['price'] ?? 0) as num).toInt());
      final totalDuration = picked.fold<int>(
          0, (a, s) => a + ((s['duration'] ?? 30) as num).toInt());
      await ref.read(dioProvider).post('/public/bookings/${widget.slug}', data: {
        'date': d,
        'time': _time,
        'services': services,
        'totalPrice': totalPrice,
        'totalDuration': totalDuration,
        'guestName': _nameCtrl.text.trim(),
        'guestPhone': '+998$phone',
      });
      setState(() => _success = true);
    } on DioException catch (e) {
      // Backend codes (public-booking.service.ts:330+):
      //   OTP_REQUIRED — barber.requirePhoneOtp=true and the customer
      //     didn't include otpCode. Mobile doesn't have the OTP UI yet,
      //     so surface a clear "ask the barber" message instead of the
      //     generic "try again" toast.
      //   SLOT_TAKEN — 409, same as everywhere.
      String msg = tr(ref, 'common.errorRetry', "Xatolik — qaytadan urinib ko'ring");
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      if (code == 'OTP_REQUIRED') {
        msg = tr(ref, 'mobile.publicBooking.otpRequired',
            "Bu sartarosh telefon tasdiqlashni talab qiladi. Iltimos, sartarosh bilan to'g'ridan-to'g'ri bog'laning.");
      } else if (e.response?.statusCode == 409 || code == 'SLOT_TAKEN') {
        msg = tr(ref, 'booking.slotTaken', "Bu vaqt allaqachon band qilingan");
      } else if (e.response?.statusCode == 404) {
        msg = tr(ref, 'mobile.publicBooking.invalidLink', "Bu havola eski yoki noto'g'ri");
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_publicBarberProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'booking.title', "Yozilish"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 56, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text(tr(ref, 'mobile.publicBooking.invalidLink', "Bu havola eski yoki noto'g'ri"),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              ],
            ),
          ),
        ),
        data: (barber) {
          if (_success) return _SuccessView(name: (barber['name'] ?? '').toString());
          final services = (barber['services'] as List? ?? []).cast<Map<String, dynamic>>();
          final barberId = barber['id'].toString();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Barber hero
              Row(children: [
                ClipOval(
                  child: ((barber['avatar'] ?? '') as String).isNotEmpty
                      ? CachedNetworkImage(imageUrl: assetUrl(barber['avatar']?.toString()), width: 64, height: 64, fit: BoxFit.cover)
                      : Container(width: 64, height: 64, color: AppColors.surface, child: const Icon(Icons.person, color: AppColors.textMuted)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((barber['name'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textBright)),
                      const SizedBox(height: 4),
                      Text((barber['locationUz'] ?? barber['location'] ?? '').toString(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 24),
              Text(tr(ref, 'profile.services', "Xizmatlar"),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              if (services.isEmpty)
                Text(tr(ref, 'mobile.publicBooking.noServices',
                    "Bu sartaroshda xizmat sozlanmagan"),
                    style: const TextStyle(color: AppColors.textMuted))
              else
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: services.map((s) {
                    final id = s['id'] as String;
                    final name = (s['nameUz'] ?? s['name'] ?? '').toString();
                    final price = ((s['price'] ?? 0) as num).toInt();
                    final on = _selected.contains(id);
                    return FilterChip(
                      label: Text("$name — ${_fmt(price)} ${tr(ref, 'common.currency', "so'm")}"),
                      selected: on,
                      onSelected: (v) => setState(() {
                        if (v) {
                          _selected.add(id);
                        } else {
                          _selected.remove(id);
                        }
                      }),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 22),
              Text(tr(ref, 'booking.date', "Sana"),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 14,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final d = DateTime.now().add(Duration(days: i));
                    final on = d.day == _date.day && d.month == _date.month && d.year == _date.year;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _date = DateTime(d.year, d.month, d.day);
                        _time = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: on ? AppColors.primary : AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("${d.day}",
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
                                    color: on ? Colors.white : AppColors.textPrimary)),
                            Text(_monthShort(d.month),
                                style: TextStyle(fontSize: 11,
                                    color: on ? Colors.white70 : AppColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),
              Text(tr(ref, 'booking.time', "Vaqt"),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              FutureBuilder<List<String>>(
                key: ValueKey(_date.toIso8601String()),
                future: _loadSlots(barberId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  final slots = snap.data!;
                  if (slots.isEmpty) {
                    return Text(tr(ref, 'common.noSlots', "Bu kunda bo'sh vaqt yo'q"),
                        style: const TextStyle(color: AppColors.textMuted));
                  }
                  return Wrap(
                    spacing: 8, runSpacing: 8,
                    children: slots.map((t) => ChoiceChip(
                          label: Text(t),
                          selected: _time == t,
                          onSelected: (_) => setState(() => _time = t),
                        )).toList(),
                  );
                },
              ),

              const SizedBox(height: 22),
              Text(tr(ref, 'auth.yourInfo', "Ma'lumotlaringiz"),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                      hintText: tr(ref, 'auth.yourName', "Ismingiz"))),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                decoration: const InputDecoration(
                  prefix: Padding(padding: EdgeInsets.only(right: 6), child: Text("+998", style: TextStyle(fontWeight: FontWeight.w700))),
                  hintText: "90 123 45 67",
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _submit(barberId, services),
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr(ref, 'booking.title', "Yozilish"),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _monthShort(int m) {
    if (m < 1 || m > 12) return '';
    const fallback = ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun', 'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];
    final months = trList(ref, 'mobile.dates.months', fallback);
    return months[m - 1].substring(0, 3).toLowerCase();
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

class _SuccessView extends ConsumerWidget {
  const _SuccessView({required this.name});
  final String name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 56, color: AppColors.success),
            ).animate().scale(duration: 500.ms, begin: const Offset(0.4, 0.4), end: const Offset(1, 1), curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(tr(ref, 'mobile.publicBooking.successTitle', "Yozildingiz!"),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textBright)),
            const SizedBox(height: 8),
            Text(
                tr(ref, 'mobile.publicBooking.successMsg',
                    "{{name}} sizni kutadi. Tasdiqlash SMS keladi.",
                    {'name': name}),
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Loads barber profile by public slug — needs no auth.
final _publicBarberProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, slug) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/public/barbers/$slug');
  return Map<String, dynamic>.from(res.data as Map);
});
