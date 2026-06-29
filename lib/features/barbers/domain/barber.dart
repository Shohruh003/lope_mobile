/// Minimal Barber shape used in lists + detail pages. We keep only what the
/// mobile screens actually need; the full record (working hours, gallery,
/// services) loads lazily in the detail view.
class Barber {
  Barber({
    required this.id,
    required this.name,
    required this.avatar,
    required this.rating,
    required this.reviewCount,
    required this.location,
    this.bio = '',
    this.phone,
    this.experience,
    this.isAvailable = true,
    this.barbershopId,
    this.publicSlug,
    this.services = const [],
    this.gallery = const [],
    this.workingHours,
    this.lat,
    this.lng,
    this.instagram,
    this.telegram,
    this.facebook,
    this.vipUntil,
    this.targetGender,
  });

  final String id;
  final String name;
  final String avatar;
  final double rating;
  final int reviewCount;
  final String location;
  final String bio;
  final String? phone;
  final dynamic experience; // String or int — backend mixes both
  final bool isAvailable;
  final String? barbershopId;
  final String? publicSlug;
  final List<BarberService> services;
  final List<String> gallery;
  final Map<String, dynamic>? workingHours;
  final double? lat;
  final double? lng;
  final String? instagram;
  final String? telegram;
  final String? facebook;
  final DateTime? vipUntil;
  final String? targetGender; // 'MALE_ONLY' | 'FEMALE_ONLY' | null

  /// Convenience flag for the header crown — true while vipUntil is in the
  /// future.
  bool get isVip {
    final until = vipUntil;
    if (until == null) return false;
    return until.isAfter(DateTime.now());
  }

  factory Barber.fromJson(Map<String, dynamic> json) {
    // Backend's barber.findMany includes the related User under a nested
    // `user` key (barbers.service.ts:findAll/findById). The Barber row
    // itself has no name/phone/avatar — those live on Barber.user. Web's
    // transformBarber() does the same unwrap (apiClient.ts:137-139); we
    // mirror that shape here. Flat fallbacks keep the older /barbers/:id
    // shape we sometimes re-use working.
    final user = json['user'] is Map
        ? (json['user'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return Barber(
      id: json['id'] as String,
      name: (json['name'] ?? user['name'] ?? '') as String,
      avatar: (json['avatar'] ?? user['avatar'] ?? '') as String,
      rating: ((json['rating'] ?? 0) as num).toDouble(),
      reviewCount: ((json['reviewCount'] ?? 0) as num).toInt(),
      location: (json['locationUz'] ?? json['location'] ?? '') as String,
      bio: (json['bioUz'] ?? json['bio'] ?? '') as String,
      phone: (json['phone'] ?? user['phone']) as String?,
      experience: json['experience'],
      isAvailable: json['isAvailable'] as bool? ?? true,
      barbershopId: json['barbershopId'] as String?,
      publicSlug: json['publicSlug'] as String?,
      services: (json['services'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(BarberService.fromJson)
              .toList() ??
          [],
      gallery: (json['gallery'] as List?)?.map((e) => e.toString()).toList() ?? [],
      workingHours: json['workingHours'] is Map
          ? Map<String, dynamic>.from(json['workingHours'] as Map)
          : null,
      lat: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble(),
      lng: (json['longitude'] as num?)?.toDouble() ?? (json['lng'] as num?)?.toDouble(),
      instagram: _readSocial(json, 'instagram'),
      telegram: _readSocial(json, 'telegram'),
      facebook: _readSocial(json, 'facebook'),
      vipUntil: json['vipUntil'] != null
          ? DateTime.tryParse(json['vipUntil'].toString())
          : null,
      targetGender: json['targetGender']?.toString(),
    );
  }

  /// `socialLinks` may be present as either a nested map or flat fields.
  static String? _readSocial(Map<String, dynamic> json, String key) {
    final flat = json[key];
    if (flat is String && flat.isNotEmpty) return flat;
    final nested = json['socialLinks'];
    if (nested is Map && nested[key] is String && (nested[key] as String).isNotEmpty) {
      return nested[key] as String;
    }
    return null;
  }
}

class BarberService {
  BarberService({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.icon,
    this.nameUz = '',
    this.nameRu = '',
    this.priceMax,
  });

  final String id;
  /// Localised display name — populated from `nameUz` when present so the
  /// UI doesn't have to know which locale field came back.
  final String name;
  /// Original `nameUz` / `nameRu` retained so the booking POST can ship
  /// both — backend's bookings.service.create signature wants both.
  final String nameUz;
  final String nameRu;
  final int price;
  final int? priceMax; // when set, displayed as "min – max"
  final int duration; // minutes
  final String icon;

  factory BarberService.fromJson(Map<String, dynamic> json) {
    final raw = json['priceMax'];
    final nameUz = (json['nameUz'] ?? '') as String;
    final nameRu = (json['nameRu'] ?? '') as String;
    final name = nameUz.isNotEmpty
        ? nameUz
        : (json['name'] ?? nameRu) as String;
    return BarberService(
      id: json['id'] as String,
      name: name,
      nameUz: nameUz,
      nameRu: nameRu,
      price: ((json['price'] ?? 0) as num).toInt(),
      priceMax: raw is num ? raw.toInt() : null,
      duration: ((json['duration'] ?? 30) as num).toInt(),
      icon: (json['icon'] ?? '✂️') as String,
    );
  }
}
