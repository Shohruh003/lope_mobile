# lope_mobile

Lope Style — native Flutter app for the barbershop booking marketplace
(Uzbekistan). Mirrors the web app at `app.lopestyle.uz` and talks to the
shared NestJS backend at `api.barberbook.uz`.

## Stack
- Flutter 3.x / Dart 3.x
- Riverpod 2.x for state, go_router for navigation
- Dio HTTP client with JWT interceptor
- flutter_secure_storage for tokens
- 4 languages: uz, uz_cyr, ru, en

## Roles
- `user` → customer home (Discover / Bookings / AI Style / Profile)
- `barber` → barber panel (Schedule / Bookings / Stats / Profile)
- `barbershop` / `shop` → salon panel
- `admin` → web only

## Run
```bash
flutter pub get
flutter run
```
