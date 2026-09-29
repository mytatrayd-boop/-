// The 12 cartoon avatars, ported from avatarSVG()/AVS in design/prototype.html.

class AvatarSpec {
  const AvatarSpec({
    required this.bg,
    required this.skin,
    required this.wear,
    required this.wc,
    required this.body,
    this.beard,
    this.glasses = false,
  });
  final String bg, skin, wear, wc, body;
  final String? beard;
  final bool glasses;
}

const avatarKeys = ['dad', 'dad2', 'grandpa', 'mom', 'mom2', 'grandma', 'teen', 'boy', 'boy2', 'girl', 'girl2', 'baby'];

const avatarSpecs = <String, AvatarSpec>{
  'dad': AvatarSpec(bg: '#CFE6DE', skin: '#E8B98E', wear: 'shemagh', wc: '#C7343B', beard: '#3B2A20', body: '#FFFFFF'),
  'dad2': AvatarSpec(bg: '#E9E1CC', skin: '#D29A70', wear: 'shemagh', wc: '#FFFFFF', beard: '#2A1E17', body: '#FFFFFF'),
  'grandpa': AvatarSpec(bg: '#DCE3EE', skin: '#E3B08A', wear: 'shemagh', wc: '#FFFFFF', beard: '#EDEDED', body: '#D9CFB8'),
  'mom': AvatarSpec(bg: '#F6E3D6', skin: '#EDC4A0', wear: 'hijab', wc: '#2F6158', body: '#2F6158'),
  'mom2': AvatarSpec(bg: '#E4E0F3', skin: '#D6A07A', wear: 'hijab', wc: '#6B4C8A', body: '#6B4C8A'),
  'grandma': AvatarSpec(bg: '#EEE6D6', skin: '#E2AF88', wear: 'hijab', wc: '#2B2B2B', body: '#2B2B2B', glasses: true),
  'teen': AvatarSpec(bg: '#DDEFD9', skin: '#E4B38A', wear: 'cap', wc: '#1F3B5A', body: '#F2F2F2'),
  'boy': AvatarSpec(bg: '#FCE7B8', skin: '#EDBE95', wear: 'taqiyah', wc: '#FFFFFF', body: '#FFFFFF'),
  'boy2': AvatarSpec(bg: '#D6EAF8', skin: '#D9A47C', wear: 'hair', wc: '#2A1E17', body: '#3A7BD5'),
  'girl': AvatarSpec(bg: '#FADADD', skin: '#F0C7A2', wear: 'hijab', wc: '#E27A9A', body: '#E27A9A'),
  'girl2': AvatarSpec(bg: '#FFF0C9', skin: '#E8B791', wear: 'pony', wc: '#3B2418', body: '#F29E4C'),
  'baby': AvatarSpec(bg: '#E3F4EC', skin: '#F3CFAE', wear: 'curl', wc: '#5A3A26', body: '#8FD1BE'),
};

final _cache = <String, String>{};

String avatarSvg(String key) => _cache.putIfAbsent(key, () => _build(avatarSpecs[key] ?? avatarSpecs['boy']!));

String _build(AvatarSpec a) {
  final w = a.wc;
  const sh = 'rgba(0,0,0,.12)';
  var back = '', front = '', beard = '';
  final fr = a.wear == 'curl' ? 16 : 14;
  switch (a.wear) {
    case 'shemagh':
      final dots = w != '#FFFFFF'
          ? '<g fill="#fff" opacity=".6"><circle cx="15" cy="46" r="1.1"/><circle cx="49" cy="46" r="1.1"/><circle cx="14" cy="54" r="1.1"/><circle cx="50" cy="54" r="1.1"/><circle cx="18" cy="38" r="1.1"/><circle cx="46" cy="38" r="1.1"/></g>'
          : '';
      back = '<path d="M11 62 Q8 26 32 12 Q56 26 53 62 Q45 52 44 38 L20 38 Q19 52 11 62Z" fill="$w" stroke="$sh"/>$dots';
      front = '<path d="M18 34 Q32 16 46 34 Q32 26 18 34Z" fill="$w" stroke="$sh"/><path d="M19 25.5 Q32 17.5 45 25.5" fill="none" stroke="#1d1d1d" stroke-width="3.2" stroke-linecap="round"/>';
      beard = '<path d="M20.5 39 Q21.5 55 32 56 Q42.5 55 43.5 39 Q41 48 32 48.5 Q23 48 20.5 39Z" fill="${a.beard}"/><path d="M27 42 Q32 40 37 42" stroke="${a.beard}" stroke-width="2.4" fill="none" stroke-linecap="round"/>';
    case 'hijab':
      back = '<path d="M10 64 Q6 27 32 11 Q58 27 54 64 Q46 54 45 40 L19 40 Q18 54 10 64Z" fill="$w"/>';
      front = '<path d="M18 36 Q32 15 46 36 Q32 25 18 36Z" fill="$w"/>';
    case 'taqiyah':
      front = '<path d="M17.5 31 Q32 13 46.5 31Z" fill="#fff" stroke="#d9d4c7"/><g fill="#cfc8b6"><circle cx="26" cy="26" r="1"/><circle cx="32" cy="23" r="1"/><circle cx="38" cy="26" r="1"/></g>';
    case 'hair':
      front = '<path d="M17 36 Q15 18 32 18 Q49 18 47 36 Q45 27 39 25 Q31 30 23 26 Q19 29 17 36Z" fill="$w"/>';
    case 'cap':
      front = '<path d="M17.5 32 Q17 16 32 16 Q47 16 46.5 32Z" fill="$w"/><path d="M40 30 Q53 29 55 33 L40 33Z" fill="$w"/><circle cx="32" cy="16.5" r="1.8" fill="#D9B26A"/>';
    case 'pony':
      back = '<circle cx="14" cy="32" r="7.5" fill="$w"/><circle cx="50" cy="32" r="7.5" fill="$w"/><circle cx="18.5" cy="27" r="2.6" fill="#E27A9A"/><circle cx="45.5" cy="27" r="2.6" fill="#E27A9A"/>';
      front = '<path d="M17 36 Q16 18 32 18 Q48 18 47 36 Q41 26 32 28 Q23 26 17 36Z" fill="$w"/>';
    case 'curl':
      front = '<path d="M29 21.5 Q31 13 38 17 Q34 17 34 21" stroke="$w" stroke-width="2.6" fill="none" stroke-linecap="round"/>';
  }
  final hasBeard = beard.isNotEmpty;
  final mouth = hasBeard
      ? '<path d="M29 44.5 Q32 46.5 35 44.5" stroke="#F3D9C8" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
      : '<path d="M28 41.5 Q32 45 36 41.5" stroke="#7a3b2e" stroke-width="1.8" fill="none" stroke-linecap="round"/>';
  final glasses = a.glasses
      ? '<g fill="none" stroke="#5a4a3a" stroke-width="1.3"><circle cx="27" cy="35" r="3.6"/><circle cx="37" cy="35" r="3.6"/><path d="M30.6 35 L33.4 35"/></g>'
      : '';
  final blush = hasBeard ? '0' : '.35';
  return '<svg viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg"><rect width="64" height="64" fill="${a.bg}"/>'
      '<path d="M8 66 Q8 49 32 49 Q56 49 56 66Z" fill="${a.body}" stroke="$sh"/>$back'
      '<circle cx="32" cy="${a.wear == 'curl' ? 35 : 36}" r="$fr" fill="${a.skin}"/>$beard'
      '<circle cx="27" cy="35" r="1.8" fill="#2a1e17"/><circle cx="37" cy="35" r="1.8" fill="#2a1e17"/>$glasses'
      '<circle cx="23.5" cy="40" r="2.4" fill="#F28B82" opacity="$blush"/><circle cx="40.5" cy="40" r="2.4" fill="#F28B82" opacity="$blush"/>$mouth$front</svg>';
}
