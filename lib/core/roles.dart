/// Barber-like rollar to'plami — sartarosh (barber), stilist va kosmetolog
/// bir xil biznes-logikani ishlatadi (profil, jadval, bookinglar, ilova).
/// Har joyda `role == 'barber'` tekshiruvi endi shu funksiya orqali o'tadi —
/// yangi rol qo'shsak, faqat shu yerni yangilash kifoya.
bool isBarberRole(String? role) {
  return role == 'barber' || role == 'stylist' || role == 'cosmetologist';
}

/// Rol nomiga qarab UI'da ko'rsatiladigan o'zbek so'zi (SMS'dagi bilan bir xil).
String roleToProfessionWord(String? role) {
  if (role == 'stylist') return 'stilist';
  if (role == 'cosmetologist') return 'kosmetolog';
  return 'sartarosh';
}
