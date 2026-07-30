/// Curated hairstyle catalogue shown to the user in AI Style. Each
/// preset carries a stable [key] the backend receives as a style hint,
/// a localised [name] shown on the tile, and an optional [imageUrl].
///
/// [imageUrl] is a local asset path (assets/hairstyles/{key}.jpg) — the
/// tile shows the image and the app also passes it to the AI as a
/// reference so the generation matches the preset. When null the tile
/// falls back to a gradient placeholder (still selectable — the AI
/// interprets the [key] as a text prompt).
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

  /// Either a local asset path (starts with 'assets/') or an https URL.
  final String? imageUrl;
}

String _asset(String key) => 'assets/hairstyles/$key.jpg';

/// The curated catalogue. Add / remove entries here; the picker widget
/// slices by gender + category on demand.
final List<HairstylePreset> kHairstylePresets = [
  // ────── Male hair ──────
  HairstylePreset(key: 'buzz_cut',     name: 'Buzz Cut',     gender: 'male', imageUrl: _asset('buzz_cut')),
  HairstylePreset(key: 'crew_cut',     name: 'Crew Cut',     gender: 'male', imageUrl: _asset('crew_cut')),
  HairstylePreset(key: 'fade',         name: 'Fade',         gender: 'male', imageUrl: _asset('fade')),
  HairstylePreset(key: 'under_cut',    name: 'Under Cut',    gender: 'male', imageUrl: _asset('under_cut')),
  HairstylePreset(key: 'pompadour',    name: 'Pompadour',    gender: 'male', imageUrl: _asset('pompadour')),
  HairstylePreset(key: 'slick_back',   name: 'Slick Back',   gender: 'male', imageUrl: _asset('slick_back')),
  HairstylePreset(key: 'texture_crop', name: 'Texture Crop', gender: 'male', imageUrl: _asset('texture_crop')),
  HairstylePreset(key: 'messy_curls',  name: 'Messy Curls',  gender: 'male', imageUrl: _asset('messy_curls')),
  HairstylePreset(key: 'quiff',        name: 'Quiff',        gender: 'male', imageUrl: _asset('quiff')),
  HairstylePreset(key: 'man_bun',      name: 'Man Bun',      gender: 'male', imageUrl: _asset('man_bun')),
  HairstylePreset(key: 'side_part',    name: 'Side Part',    gender: 'male', imageUrl: _asset('side_part')),
  HairstylePreset(key: 'ivy_league',   name: 'Ivy League',   gender: 'male', imageUrl: _asset('ivy_league')),

  // ────── Male beard ──────
  HairstylePreset(key: 'beard_short_stubble', name: 'Short Stubble', gender: 'male', category: 'beard', imageUrl: _asset('beard_short_stubble')),
  HairstylePreset(key: 'beard_full',          name: 'Full Beard',    gender: 'male', category: 'beard', imageUrl: _asset('beard_full')),
  HairstylePreset(key: 'beard_goatee',        name: 'Goatee',        gender: 'male', category: 'beard', imageUrl: _asset('beard_goatee')),
  HairstylePreset(key: 'beard_van_dyke',      name: 'Van Dyke',      gender: 'male', category: 'beard', imageUrl: _asset('beard_van_dyke')),
  HairstylePreset(key: 'beard_balbo',         name: 'Balbo',         gender: 'male', category: 'beard', imageUrl: _asset('beard_balbo')),
  HairstylePreset(key: 'beard_circle',        name: 'Circle Beard',  gender: 'male', category: 'beard', imageUrl: _asset('beard_circle')),

  // ────── Female hair ──────
  HairstylePreset(key: 'pixie_cut',     name: 'Pixie Cut',     gender: 'female', imageUrl: _asset('pixie_cut')),
  HairstylePreset(key: 'bob',           name: 'Bob',           gender: 'female', imageUrl: _asset('bob')),
  HairstylePreset(key: 'lob',           name: 'Long Bob',      gender: 'female', imageUrl: _asset('lob')),
  HairstylePreset(key: 'shag',          name: 'Shag',          gender: 'female', imageUrl: _asset('shag')),
  HairstylePreset(key: 'layers',        name: 'Layered',       gender: 'female', imageUrl: _asset('layers')),
  HairstylePreset(key: 'blowout',       name: 'Blowout',       gender: 'female', imageUrl: _asset('blowout')),
  HairstylePreset(key: 'beach_waves',   name: 'Beach Waves',   gender: 'female', imageUrl: _asset('beach_waves')),
  HairstylePreset(key: 'braids',        name: 'Braids',        gender: 'female', imageUrl: _asset('braids')),
  HairstylePreset(key: 'ponytail',      name: 'Ponytail',      gender: 'female', imageUrl: _asset('ponytail')),
  HairstylePreset(key: 'high_bun',      name: 'High Bun',      gender: 'female', imageUrl: _asset('high_bun')),
  HairstylePreset(key: 'straight_long', name: 'Straight Long', gender: 'female', imageUrl: _asset('straight_long')),
  HairstylePreset(key: 'curly_long',    name: 'Curly Long',    gender: 'female', imageUrl: _asset('curly_long')),

  // ────── Female hair color ──────
  HairstylePreset(key: 'color_blonde',    name: 'Blonde',    gender: 'female', category: 'hair_color', imageUrl: _asset('color_blonde')),
  HairstylePreset(key: 'color_brunette',  name: 'Brunette',  gender: 'female', category: 'hair_color', imageUrl: _asset('color_brunette')),
  HairstylePreset(key: 'color_red',       name: 'Red',       gender: 'female', category: 'hair_color', imageUrl: _asset('color_red')),
  HairstylePreset(key: 'color_platinum',  name: 'Platinum',  gender: 'female', category: 'hair_color', imageUrl: _asset('color_platinum')),
  HairstylePreset(key: 'color_ombre',     name: 'Ombre',     gender: 'female', category: 'hair_color', imageUrl: _asset('color_ombre')),
  HairstylePreset(key: 'color_balayage',  name: 'Balayage',  gender: 'female', category: 'hair_color', imageUrl: _asset('color_balayage')),
];

/// Filter helper — used by the picker widget to slice by selected
/// (gender, category) tuple.
List<HairstylePreset> presetsFor(String gender, String category) {
  return kHairstylePresets
      .where((p) => p.gender == gender && p.category == category)
      .toList(growable: false);
}
