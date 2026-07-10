import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';

class PublicBookingScreen extends ConsumerStatefulWidget {
  const PublicBookingScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<PublicBookingScreen> createState() =>
      _PublicBookingScreenState();
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
    final d =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
    try {
      final results = await Future.wait([
        dio.get('/schedule/$barberId/$d').then((r) {
          final d = r.data;
          if (d is Map && d['slots'] is List) {
            return (d['slots'] as List).map((e) => e.toString()).toList();
          }
          return <String>[];
        }).catchError((_) => <String>[]),
        dio.get('/bookings/booked-slots', queryParameters: {
          'barberId': barberId,
          'date': d
        }).then((r) {
          final d = r.data;
          if (d is List) return d.map((e) => e.toString()).toList();
          if (d is Map && d['slots'] is List) {
            return (d['slots'] as List).map((e) => e.toString()).toList();
          }
          return <String>[];
        }).catchError((_) => <String>[]),
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
    AppHaptics.light();
    if (_selected.isEmpty || _time == null) {
      AppHaptics.error();
      setState(() => _error = tr(ref, 'mobile.publicBooking.pickServiceTime',
          "Xizmat va vaqt tanlang"));
      return;
    }
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length != 9) {
      AppHaptics.error();
      setState(() => _error = tr(ref, 'common.validation.invalidPhone',
          "Telefon raqami noto'g'ri"));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      final picked = allServices
          .where((s) => _selected.contains((s['id'] ?? '').toString()))
          .toList();
      final services = picked
          .map((s) => {
                'id': s['id'],
                'name': (s['name'] ?? s['nameUz'] ?? '').toString(),
                'nameUz': (s['nameUz'] ?? s['name'] ?? '').toString(),
                'nameRu': (s['nameRu'] ?? '').toString(),
                'price': ((s['price'] ?? 0) as num).toInt(),
                'duration': ((s['duration'] ?? 30) as num).toInt(),
                'icon': (s['icon'] ?? '').toString(),
              })
          .toList();
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
      if (!mounted) return;
      AppHaptics.success();
      setState(() => _success = true);
    } on DioException catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      String msg = tr(ref, 'common.errorRetry', "Xatolik — qaytadan urinib ko'ring");
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      if (code == 'OTP_REQUIRED') {
        msg = tr(ref, 'mobile.publicBooking.otpRequired',
            "Bu sartarosh telefon tasdiqlashni talab qiladi. Iltimos, sartarosh bilan to'g'ridan-to'g'ri bog'laning.");
      } else if (e.response?.statusCode == 409 || code == 'SLOT_TAKEN') {
        msg = tr(ref, 'booking.slotTaken',
            "Bu vaqt allaqachon band qilingan");
      } else if (e.response?.statusCode == 404) {
        msg = tr(ref, 'mobile.publicBooking.invalidLink',
            "Bu havola eski yoki noto'g'ri");
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
      appBar: AppBar(
          title: Text(tr(ref, 'booking.title', "Yozilish"),
              style: AppText.titleMd)),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppEmptyState(
          icon: Icons.link_off_rounded,
          title: tr(ref, 'mobile.publicBooking.invalidLink',
              "Bu havola eski yoki noto'g'ri"),
          message: tr(
            ref,
            'mobile.publicBooking.invalidLinkHint',
            "Sartaroshdan yangi havola so'rang yoki ilovadan qidiring.",
          ),
        ),
        data: (barber) {
          final user = barber['user'] is Map
              ? (barber['user'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};
          final barberName =
              (barber['name'] ?? user['name'] ?? '').toString();
          final barberAvatar =
              (barber['avatar'] ?? user['avatar'] ?? '').toString();
          if (_success) return _SuccessView(name: barberName);
          final services = (barber['services'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final barberId = barber['id'].toString();
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg,
                AppSpacing.xl, AppSpacing.xxxl),
            children: [
              AppCard(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderColor: AppColors.primary.withValues(alpha: 0.2),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: barberAvatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: assetUrl(barberAvatar),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover)
                          : Container(
                              width: 64,
                              height: 64,
                              color: AppColors.surface,
                              alignment: Alignment.center,
                              child: Text(
                                  (barberName.isNotEmpty
                                          ? barberName[0]
                                          : '?')
                                      .toUpperCase(),
                                  style: AppText.titleLg
                                      .copyWith(color: AppColors.primary)),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(barberName, style: AppText.titleMd),
                        if ((barber['locationUz'] ?? barber['location'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                              (barber['locationUz'] ??
                                      barber['location'] ??
                                      '')
                                  .toString(),
                              style: AppText.bodySm),
                        ],
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: Icons.content_cut,
                title: tr(ref, 'profile.services', "Xizmatlar"),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (services.isEmpty)
                Text(
                    tr(ref, 'mobile.publicBooking.noServices',
                        "Bu sartaroshda xizmat sozlanmagan"),
                    style: AppText.bodySm)
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: services.map((s) {
                    final id = s['id'] as String;
                    final name = (s['nameUz'] ?? s['name'] ?? '').toString();
                    final price = ((s['price'] ?? 0) as num).toInt();
                    final on = _selected.contains(id);
                    return AppChip(
                      label:
                          "$name — ${_fmt(price)} ${tr(ref, 'common.currency', "so'm")}",
                      selected: on,
                      onTap: () => setState(() {
                        if (on) {
                          _selected.remove(id);
                        } else {
                          _selected.add(id);
                        }
                      }),
                    );
                  }).toList(),
                ),

              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: Icons.event,
                title: tr(ref, 'booking.date', "Sana"),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 14,
                  separatorBuilder: (context, i) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final d = DateTime.now().add(Duration(days: i));
                    final on = d.day == _date.day &&
                        d.month == _date.month &&
                        d.year == _date.year;
                    return TapScale(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() {
                          _date = DateTime(d.year, d.month, d.day);
                          _time = null;
                        });
                      },
                      haptic: HapticStrength.none,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        decoration: BoxDecoration(
                          gradient: on ? AppColors.primaryGradient : null,
                          color: on ? null : AppColors.surface,
                          borderRadius: AppRadius.rMd,
                          border: Border.all(
                              color: on
                                  ? Colors.transparent
                                  : AppColors.border),
                          boxShadow: on
                              ? AppShadows.primaryGlow(AppColors.primary)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("${d.day}",
                                style: AppText.numeric.copyWith(
                                    fontSize: 18,
                                    color: on
                                        ? Colors.white
                                        : AppColors.textBright)),
                            Text(_monthShort(d.month),
                                style: AppText.overline.copyWith(
                                    fontSize: 10,
                                    color: on
                                        ? Colors.white70
                                        : AppColors.textMuted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              _SectionHeader(
                icon: Icons.access_time,
                title: tr(ref, 'booking.time', "Vaqt"),
              ),
              const SizedBox(height: AppSpacing.sm),
              FutureBuilder<List<String>>(
                key: ValueKey(_date.toIso8601String()),
                future: _loadSlots(barberId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          AppSkeleton(
                              width: 72, height: 34, borderRadius: 20),
                          AppSkeleton(
                              width: 72, height: 34, borderRadius: 20),
                          AppSkeleton(
                              width: 72, height: 34, borderRadius: 20),
                          AppSkeleton(
                              width: 72, height: 34, borderRadius: 20),
                          AppSkeleton(
                              width: 72, height: 34, borderRadius: 20),
                          AppSkeleton(
                              width: 72, height: 34, borderRadius: 20),
                        ],
                      ),
                    );
                  }
                  final slots = snap.data!;
                  if (slots.isEmpty) {
                    return AppCard(
                      variant: AppCardVariant.flat,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.textMuted.withValues(alpha: 0.15),
                              borderRadius: AppRadius.rSm,
                            ),
                            child: const Icon(Icons.event_busy_rounded,
                                color: AppColors.textMuted, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              tr(ref, 'common.noSlots',
                                  "Bu kunda bo'sh vaqt yo'q"),
                              style: AppText.bodySm,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: slots
                        .map((t) => AppChip(
                              label: t,
                              selected: _time == t,
                              onTap: () => setState(() => _time = t),
                            ))
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: Icons.person_outline,
                title: tr(ref, 'auth.yourInfo', "Ma'lumotlaringiz"),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                            hintText:
                                tr(ref, 'auth.yourName', "Ismingiz"))),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9)
                      ],
                      decoration: const InputDecoration(
                        prefix: Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text("+998",
                                style:
                                    TextStyle(fontWeight: FontWeight.w700))),
                        hintText: "90 123 45 67",
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: AppRadius.rSm,
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(_error!,
                          style: AppText.bodySm.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: tr(ref, 'booking.title', "Yozilish"),
                onPressed: _busy ? null : () => _submit(barberId, services),
                loading: _busy,
                size: AppButtonSize.lg,
                fullWidth: true,
                leadingIcon: Icons.check_circle_outline,
              ),
            ],
          );
        },
      ),
    );
  }

  String _monthShort(int m) {
    if (m < 1 || m > 12) return '';
    const fallback = [
      'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
      'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
    ];
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

class _SuccessView extends ConsumerWidget {
  const _SuccessView({required this.name});
  final String name;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success.withValues(alpha: 0.3),
                    AppColors.success.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: AppShadows.primaryGlow(AppColors.success),
              ),
              child: const Icon(Icons.check,
                  size: 56, color: AppColors.success),
            )
                .animate()
                .scale(
                    duration: 500.ms,
                    begin: const Offset(0.4, 0.4),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack),
            const SizedBox(height: AppSpacing.lg),
            Text(
                tr(ref, 'mobile.publicBooking.successTitle',
                    "Yozildingiz!"),
                style: AppText.titleLg),
            const SizedBox(height: AppSpacing.sm),
            Text(
                tr(ref, 'mobile.publicBooking.successMsg',
                    "{{name}} sizni kutadi. Tasdiqlash SMS keladi.",
                    {'name': name}),
                style: AppText.body,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

final _publicBarberProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, slug) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/public/barbers/$slug');
  return Map<String, dynamic>.from(res.data as Map);
});
