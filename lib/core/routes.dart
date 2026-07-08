import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import '../features/auth/domain/user.dart';

/// One place that decides "where does this user belong post-login". Both the
/// splash and the auth screens call this so role-based routing stays
/// consistent — a barber who logs in must not end up on the customer feed.
void routeToRoleHome(BuildContext context, AppUser user) {
  // 'barbershop' owns the barbershop (multiple barbers, /shop shell).
  // 'shop' owns the LopePay installments shop (/lopepay shell). These
  // are TWO DIFFERENT roles even though the words sound similar — see
  // _homeFor in app/router.dart.
  switch (user.role) {
    // Sartarosh, stilist va kosmetolog — bir xil barber ilovasiga tushadi.
    // Farq faqat SMS shablonidagi kasb so'zi ("sartarosh"/"stilist"/"kosmetolog").
    case 'barber':
    case 'stylist':
    case 'cosmetologist':
      context.go('/barber-app');
      break;
    case 'barbershop':
      context.go('/shop');
      break;
    case 'shop':
      context.go('/lopepay');
      break;
    case 'admin':
      context.go('/admin-blocked');
      break;
    default:
      context.go('/home');
  }
}
