class Booking {
  Booking({
    required this.id,
    required this.barberId,
    required this.barberName,
    required this.barberAvatar,
    required this.date,
    required this.time,
    required this.status,
    required this.totalPrice,
    required this.totalDuration,
    required this.services,
    required this.createdAt,
    this.userName = '',
    this.userPhone,
    this.guestName,
    this.guestPhone,
    this.notes,
  });

  final String id;
  final String barberId;
  final String barberName;
  final String barberAvatar;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm
  final String status; // confirmed | completed | cancelled
  final int totalPrice;
  final int totalDuration;
  final List<BookingService> services;
  final DateTime createdAt;
  final String userName;
  final String? userPhone;
  final String? guestName;
  final String? guestPhone;
  final String? notes;

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      barberId: json['barberId'] as String,
      barberName: (json['barberName'] ?? '') as String,
      barberAvatar: (json['barberAvatar'] ?? '') as String,
      date: json['date'] as String,
      time: json['time'] as String,
      status: (json['status'] ?? 'confirmed') as String,
      totalPrice: ((json['totalPrice'] ?? 0) as num).toInt(),
      totalDuration: ((json['totalDuration'] ?? 0) as num).toInt(),
      services: (json['services'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(BookingService.fromJson)
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      userName: (json['userName'] ?? '') as String,
      userPhone: json['userPhone'] as String?,
      guestName: json['guestName'] as String?,
      guestPhone: json['guestPhone'] as String?,
      notes: (json['notes'] as String?)?.isEmpty ?? true
          ? null
          : json['notes'] as String,
    );
  }
}

class BookingService {
  BookingService({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.icon,
  });

  final String id;
  final String name;
  final int price;
  final int duration;
  final String icon;

  factory BookingService.fromJson(Map<String, dynamic> json) {
    return BookingService(
      id: (json['id'] ?? '') as String,
      name: (json['nameUz'] ?? json['name'] ?? '') as String,
      price: ((json['price'] ?? 0) as num).toInt(),
      duration: ((json['duration'] ?? 30) as num).toInt(),
      icon: (json['icon'] ?? '✂️') as String,
    );
  }
}
