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
    this.referralCode,
    this.referralsCount = 0,
  });

  final String id;
  final String name;
  final String phone;
  final String role; // 'user' | 'barber' | 'admin' | 'barbershop' | 'shop'
  final String? avatar;
  final String? referralCode;
  final int referralsCount;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        avatar: json['avatar'] as String?,
        referralCode: json['referralCode'] as String?,
        referralsCount:
            ((json['referralsCount'] ?? 0) as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        if (avatar != null) 'avatar': avatar,
        if (referralCode != null) 'referralCode': referralCode,
        'referralsCount': referralsCount,
      };

  AppUser copyWith({String? referralCode, int? referralsCount}) => AppUser(
        id: id,
        name: name,
        phone: phone,
        role: role,
        avatar: avatar,
        referralCode: referralCode ?? this.referralCode,
        referralsCount: referralsCount ?? this.referralsCount,
      );
}
