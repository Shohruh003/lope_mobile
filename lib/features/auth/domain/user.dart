/// Minimal user shape mirroring the NestJS Auth controller response. We only
/// keep the fields the mobile app uses; full data is fetched from /barbers
/// or /bookings as needed.
class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.avatar,
  });

  final String id;
  final String name;
  final String phone;
  final String role; // 'user' | 'barber' | 'admin' | 'barbershop' | 'shop'
  final String? avatar;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        avatar: json['avatar'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        if (avatar != null) 'avatar': avatar,
      };
}
