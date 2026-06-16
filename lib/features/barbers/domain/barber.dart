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

  factory Barber.fromJson(Map<String, dynamic> json) {
    return Barber(
      id: json['id'] as String,
      name: (json['name'] ?? '') as String,
      avatar: (json['avatar'] ?? '') as String,
      rating: ((json['rating'] ?? 0) as num).toDouble(),
      reviewCount: ((json['reviewCount'] ?? 0) as num).toInt(),
      location: (json['locationUz'] ?? json['location'] ?? '') as String,
      bio: (json['bioUz'] ?? json['bio'] ?? '') as String,
      phone: json['phone'] as String?,
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
    );
  }
}

class BarberService {
  BarberService({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.icon,
  });

  final String id;
  final String name;
  final int price;
  final int duration; // minutes
  final String icon;

  factory BarberService.fromJson(Map<String, dynamic> json) {
    return BarberService(
      id: json['id'] as String,
      name: (json['nameUz'] ?? json['name'] ?? '') as String,
      price: ((json['price'] ?? 0) as num).toInt(),
      duration: ((json['duration'] ?? 30) as num).toInt(),
      icon: (json['icon'] ?? '✂️') as String,
    );
  }
}
