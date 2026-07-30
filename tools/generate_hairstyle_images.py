"""Generate the 30 hairstyle preset thumbnails via Gemini Flash Image
and save them to assets/hairstyles/{key}.jpg.

Run this on the production server (the one that already talks to
Gemini for the AI Style feature) — that host is the only place the
GEMINI_API_KEY works without IP/quota headaches.

--- Usage on the server ---

  cd ~/lope_mobile           # clone or pull the mobile repo first if needed
                             # (git clone https://github.com/Shohruh003/lope_mobile.git)
  export GEMINI_API_KEY=$(grep GEMINI_API_KEY ~/lope_backend/.env | cut -d= -f2)
  python3 tools/generate_hairstyle_images.py

Then commit and push the generated PNGs:

  git add assets/hairstyles
  git -c user.email=YOUR_EMAIL -c user.name='YOUR NAME' \\
      commit -m 'chore(assets): add generated hairstyle preset thumbnails'
  git push origin main

--- Notes ---

- Rerunnable: existing files > 5KB are skipped, so re-running only
  fills in whatever failed last time.
- Rate-paced with a 1.2s sleep between requests so the server doesn't
  spike Gemini's per-minute quota.
- If any preset comes back < 5KB or errors, the script keeps going and
  prints a summary at the end.
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')

API_KEY = os.environ.get('GEMINI_API_KEY', '').strip()
if not API_KEY:
    print('ERROR: GEMINI_API_KEY env var not set. Export it first:')
    print('  export GEMINI_API_KEY=$(grep GEMINI_API_KEY ~/lope_backend/.env | cut -d= -f2)')
    sys.exit(2)

# Backend uses these three models in order (see ai-style.service.ts).
# We start with the primary; if a preset gets 429 or 5xx from it we
# retry through the fallback list.
MODELS = [
    'gemini-3.1-flash-image-preview',
    'gemini-2.5-flash-image',
    'gemini-3-pro-image-preview',
]

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'assets', 'hairstyles',
)
os.makedirs(OUT_DIR, exist_ok=True)

# Kept intentionally identical across presets so the whole catalog
# reads as one coherent look. Only the hairstyle + gender description
# varies per row.
COMMON = (
    "Professional barbershop portfolio photo. Head-and-shoulders "
    "portrait. Neutral studio backdrop (dark charcoal grey). Clean "
    "soft lighting from the front-left. Sharp focus on the hair. "
    "Photorealistic, magazine-quality, natural skin tones. Subject "
    "faces the camera, calm neutral expression, no glasses, no hat, "
    "no visible logos. Square 1:1 composition. High detail."
)

def male_hair(name, extra):
    return (
        f"Young adult man (20-30 years old) with a {name} hairstyle. "
        f"{extra} {COMMON}"
    )

def male_beard(name, extra):
    return (
        f"Young adult man (25-35 years old) showing a {name} beard "
        f"style. Standard short haircut on top. {extra} Focus on the "
        f"facial hair shape. {COMMON}"
    )

def female_hair(name, extra):
    return (
        f"Young adult woman (20-30 years old) with a {name} hairstyle. "
        f"{extra} {COMMON}"
    )

def female_color(name, extra):
    return (
        f"Young adult woman (20-30 years old) with a shoulder-length "
        f"straight cut, {name} hair color. {extra} Same cut across all "
        f"color variants so the customer sees the COLOR difference, "
        f"not the shape. {COMMON}"
    )

PRESETS = [
    # Male hair
    ('buzz_cut',      male_hair('very short Buzz Cut', 'Uniform ~3mm length all over, clean edges, no fade.')),
    ('crew_cut',      male_hair('Crew Cut', 'Short on top (~2cm), tapered sides, classic conservative shape.')),
    ('fade',          male_hair('mid Fade', 'Longer on top (~4cm), skin fade at temples blending upward.')),
    ('under_cut',     male_hair('Undercut', 'Long slicked-back top (~7cm), buzzed sides with sharp disconnected line.')),
    ('pompadour',     male_hair('Pompadour', 'Voluminous top swept up and back, shorter tapered sides.')),
    ('slick_back',    male_hair('Slick Back', 'Long top combed straight back with light pomade shine, neat sides.')),
    ('texture_crop',  male_hair('Textured Crop', 'Choppy short top with fringe forward, faded sides.')),
    ('messy_curls',   male_hair('Messy Curls', 'Natural curly top ~5cm, tousled styling, faded sides.')),
    ('quiff',         male_hair('Quiff', 'Front section lifted and swept up-and-back, medium sides.')),
    ('man_bun',       male_hair('Man Bun', 'Long hair tied in a bun at the back of the head.')),
    ('side_part',     male_hair('classic Side Part', 'Sharp hard-part line, combed sideways, neat classic look.')),
    ('ivy_league',    male_hair('Ivy League', 'Slightly longer Crew Cut with enough top length to part, tidy preppy look.')),
    # Male beard
    ('beard_short_stubble', male_beard('Short Stubble', '2-3 day stubble, uniform trim, well-groomed.')),
    ('beard_full',          male_beard('Full Beard',    'Thick medium-length full beard, neatly shaped edges.')),
    ('beard_goatee',        male_beard('Goatee',        'Chin-and-mustache goatee, clean-shaven cheeks.')),
    ('beard_van_dyke',      male_beard('Van Dyke',      'Pointed goatee with disconnected mustache, sharp lines.')),
    ('beard_balbo',         male_beard('Balbo',         'Trimmed floating beard along the jaw with mustache, no sideburns.')),
    ('beard_circle',        male_beard('Circle Beard',  'Rounded chin beard connected with a mustache in a circle shape.')),
    # Female hair
    ('pixie_cut',      female_hair('Pixie Cut',              'Very short cropped hair, textured top, feminine and modern.')),
    ('bob',            female_hair('classic Bob',            'Chin-length blunt cut, straight and sleek.')),
    ('lob',            female_hair('Long Bob (Lob)',         'Collarbone-length blunt cut, straight with soft ends.')),
    ('shag',           female_hair('Shag',                   'Layered choppy cut with fringe, textured 70s-inspired shape.')),
    ('layers',         female_hair('layered long haircut',   'Shoulder-length hair with soft face-framing layers.')),
    ('blowout',        female_hair('bouncy Blowout',         'Voluminous shoulder-length hair blown out for lift and shine.')),
    ('beach_waves',    female_hair('Beach Waves',            'Loose relaxed waves, tousled beach-inspired styling.')),
    ('braids',         female_hair('French Braid',           'Neat single French braid down the back.')),
    ('ponytail',       female_hair('sleek high Ponytail',    'Smooth slicked-back ponytail high on the head.')),
    ('high_bun',       female_hair('High Bun',               'Clean top-of-head bun, no flyaways.')),
    ('straight_long',  female_hair('long straight hair',     'Hair below shoulders, perfectly straight and shiny.')),
    ('curly_long',     female_hair('long curly hair',        'Natural spiral curls falling past the shoulders.')),
    # Female hair color
    ('color_blonde',    female_color('honey blonde',         'Warm golden tone.')),
    ('color_brunette',  female_color('rich chocolate brunette', 'Deep warm brown.')),
    ('color_red',       female_color('vibrant copper red',   'Saturated auburn/copper.')),
    ('color_platinum',  female_color('platinum silver blonde', 'Icy near-white with silver undertones.')),
    ('color_ombre',     female_color('brunette-to-blonde ombre', 'Dark roots melting to sun-kissed light ends.')),
    ('color_balayage',  female_color('sun-kissed balayage',  'Hand-painted highlights on medium brown base.')),
]

def call_gemini(model, prompt):
    """Single generate call. Returns raw image bytes or raises."""
    url = (
        f'https://generativelanguage.googleapis.com/v1beta/models/'
        f'{model}:generateContent?key={API_KEY}'
    )
    body = json.dumps({
        'contents': [{
            'role': 'user',
            'parts': [{'text': prompt}],
        }],
        'generationConfig': {
            'responseModalities': ['IMAGE'],
        },
    }).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=body,
        headers={'Content-Type': 'application/json'},
        method='POST',
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        payload = json.loads(resp.read().decode('utf-8'))
    parts = (payload.get('candidates') or [{}])[0].get('content', {}).get('parts', [])
    for p in parts:
        data = (
            p.get('inlineData', {}).get('data')
            or p.get('inline_data', {}).get('data')
        )
        if data:
            return base64.b64decode(data)
    raise RuntimeError(f'no image data in response: {json.dumps(payload)[:300]}')


def generate(prompt):
    """Try each model in order; only re-attempt on 429/5xx (transient)."""
    last_err = None
    for model in MODELS:
        try:
            return call_gemini(model, prompt), model
        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8', errors='ignore')[:200]
            last_err = f'{model} HTTP {e.code}: {body}'
            if e.code in (429, 500, 502, 503, 504):
                # Transient — fall through to next model
                continue
            # Anything else (400, 401, 403) is not going to be fixed
            # by switching model, bail out
            raise RuntimeError(last_err)
        except Exception as e:
            last_err = f'{model} ERR: {e}'
            continue
    raise RuntimeError(last_err or 'all models failed')


def main():
    print(f'Generating {len(PRESETS)} preset images -> {OUT_DIR}')
    ok = 0
    fail = []
    for key, prompt in PRESETS:
        out_path = os.path.join(OUT_DIR, f'{key}.jpg')
        if os.path.exists(out_path) and os.path.getsize(out_path) > 5000:
            print(f'  [SKIP] {key} (already {os.path.getsize(out_path)//1024} KB)')
            ok += 1
            continue
        try:
            print(f'  [....] {key}', end=' ', flush=True)
            image_bytes, model = generate(prompt)
            with open(out_path, 'wb') as f:
                f.write(image_bytes)
            print(f'-> {len(image_bytes)//1024} KB via {model}')
            ok += 1
            time.sleep(1.2)
        except Exception as e:
            print(f'FAIL: {str(e)[:200]}')
            fail.append(key)
    print(f'\nDone: {ok}/{len(PRESETS)} OK. Failed: {fail if fail else "none"}')
    if ok >= len(PRESETS) // 2:
        print('\nNext step:')
        print('  git add assets/hairstyles')
        print("  git -c user.email=... -c user.name='...' commit -m 'assets: hairstyle thumbnails'")
        print('  git push origin main')


if __name__ == '__main__':
    main()
