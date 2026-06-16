import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';

import '../features/auth/domain/user.dart';

/// One place that decides "where does this user belong post-login". Both the
/// splash and the auth screens call this so role-based routing stays
/// consistent — a barber who logs in must not end up on the customer feed.
void routeToRoleHome(BuildContext context, AppUser user) {
  switch (user.role) {
    case 'barber':
      context.go('/barber-app');
      break;
    case 'barbershop':
    case 'shop':
      context.go('/shop');
      break;
    case 'admin':
      context.go('/admin-blocked');
      break;
    default:
      context.go('/home');
  }
}
