/// Curated hairstyle catalogue shown to the user in AI Style. Each
/// preset carries a stable [key] the backend receives as a style hint,
/// a localised [name] shown on the tile, and an optional [imageUrl].
///
/// When [imageUrl] is set the app downloads the thumbnail and passes it
/// to the AI as a reference image — same code path the manual upload
/// uses. When it's null the tile falls back to a gradient placeholder
/// (still selectable — the AI will interpret the [key] as a text
/// prompt).
///
/// Real image URLs live in one place so the catalogue can be extended
/// (or swapped for a CDN / remote config) without touching the UI. To
/// wire in real preset photos later: point [imageUrl] at a hosted
/// square image (300x300 or larger) — no other change required.
class HairstylePreset {
  const HairstylePreset({
    required this.key,
    required this.name,
    required this.gender,
    this.category = 'hair',
    this.imageUrl,
  });

  final String key;
  final String name;

  /// 'male' | 'female' — matches the two style pickers in the app.
  final String gender;

  /// 'hair' | 'beard' | 'hair_color' | 'eyebrows' | 'lips' | 'eyelashes'
  final String category;

  final String? imageUrl;
}

/// The curated catalogue. Add / remove entries here; the picker widget
/// slices by gender + category on demand.
const List<HairstylePreset> kHairstylePresets = [
  // ────── Male hair ──────
  HairstylePreset(key: 'buzz_cut', name: 'Buzz Cut', gender: 'male'),
  HairstylePreset(key: 'crew_cut', name: 'Crew Cut', gender: 'male'),
  HairstylePreset(key: 'fade', name: 'Fade', gender: 'male'),
  HairstylePreset(key: 'under_cut', name: 'Under Cut', gender: 'male'),
  HairstylePreset(key: 'pompadour', name: 'Pompadour', gender: 'male'),
  HairstylePreset(key: 'slick_back', name: 'Slick Back', gender: 'male'),
  HairstylePreset(key: 'texture_crop', name: 'Texture Crop', gender: 'male'),
  HairstylePreset(key: 'messy_curls', name: 'Messy Curls', gender: 'male'),
  HairstylePreset(key: 'quiff', name: 'Quiff', gender: 'male'),
  HairstylePreset(key: 'man_bun', name: 'Man Bun', gender: 'male'),
  HairstylePreset(key: 'side_part', name: 'Side Part', gender: 'male'),
  HairstylePreset(key: 'ivy_league', name: 'Ivy League', gender: 'male'),

  // ────── Male beard ──────
  HairstylePreset(
      key: 'beard_short_stubble',
      name: 'Short Stubble',
      gender: 'male',
      category: 'beard'),
  HairstylePreset(
      key: 'beard_full', name: 'Full Beard', gender: 'male', category: 'beard'),
  HairstylePreset(
      key: 'beard_goatee', name: 'Goatee', gender: 'male', category: 'beard'),
  HairstylePreset(
      key: 'beard_van_dyke',
      name: 'Van Dyke',
      gender: 'male',
      category: 'beard'),
  HairstylePreset(
      key: 'beard_balbo', name: 'Balbo', gender: 'male', category: 'beard'),
  HairstylePreset(
      key: 'beard_circle', name: 'Circle Beard', gender: 'male', category: 'beard'),

  // ────── Female hair ──────
  HairstylePreset(key: 'pixie_cut', name: 'Pixie Cut', gender: 'female'),
  HairstylePreset(key: 'bob', name: 'Bob', gender: 'female'),
  HairstylePreset(key: 'lob', name: 'Long Bob', gender: 'female'),
  HairstylePreset(key: 'shag', name: 'Shag', gender: 'female'),
  HairstylePreset(key: 'layers', name: 'Layered', gender: 'female'),
  HairstylePreset(key: 'blowout', name: 'Blowout', gender: 'female'),
  HairstylePreset(key: 'beach_waves', name: 'Beach Waves', gender: 'female'),
  HairstylePreset(key: 'braids', name: 'Braids', gender: 'female'),
  HairstylePreset(key: 'ponytail', name: 'Ponytail', gender: 'female'),
  HairstylePreset(key: 'high_bun', name: 'High Bun', gender: 'female'),
  HairstylePreset(key: 'straight_long', name: 'Straight Long', gender: 'female'),
  HairstylePreset(key: 'curly_long', name: 'Curly Long', gender: 'female'),

  // ────── Female hair color ──────
  HairstylePreset(
      key: 'color_blonde',
      name: 'Blonde',
      gender: 'female',
      category: 'hair_color'),
  HairstylePreset(
      key: 'color_brunette',
      name: 'Brunette',
      gender: 'female',
      category: 'hair_color'),
  HairstylePreset(
      key: 'color_red',
      name: 'Red',
      gender: 'female',
      category: 'hair_color'),
  HairstylePreset(
      key: 'color_platinum',
      name: 'Platinum',
      gender: 'female',
      category: 'hair_color'),
  HairstylePreset(
      key: 'color_ombre',
      name: 'Ombre',
      gender: 'female',
      category: 'hair_color'),
  HairstylePreset(
      key: 'color_balayage',
      name: 'Balayage',
      gender: 'female',
      category: 'hair_color'),
];

/// Filter helper — used by the picker widget to slice by selected
/// (gender, category) tuple.
List<HairstylePreset> presetsFor(String gender, String category) {
  return kHairstylePresets
      .where((p) => p.gender == gender && p.category == category)
      .toList(growable: false);
}
