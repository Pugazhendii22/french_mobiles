/// Works out which series a model belongs to — "A series", "Reno series".
///
/// Model documents carry no `series` field: the catalogue was imported with
/// only `model`, `release_year`, `image_url` and `specs`. Rather than backfill
/// a field onto every document (and have to keep it correct forever), the
/// series is read out of the name, which is consistently "<Brand> <Model>".
///
/// **This is mirrored in `admin-panel/app.js` as `deriveSeries()`.** The admin
/// panel groups models the same way, so the two must agree — change one and
/// change the other, or the same phone will sit in different series depending
/// on which screen you look at.
library;

/// Words naming a whole line rather than a series. Without this every Samsung
/// would land in "Galaxy series", which separates nothing.
const Set<String> _familyWords = {'galaxy', 'moto', 'redmi', 'poco', 'mi'};

final RegExp _leadingLetters = RegExp(r'^([A-Za-z]{1,2})\d');
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _notAlphanumeric = RegExp(r'[^A-Za-z0-9]');
final RegExp _fromFirstDigit = RegExp(r'\d.*$');

String deriveSeries(String modelName, String brandId) {
  var name = modelName.trim();
  if (name.isEmpty) return 'Other';

  final brand = brandId.toLowerCase();
  if (brand.isNotEmpty && name.toLowerCase().startsWith('$brand ')) {
    name = name.substring(brand.length + 1).trim();
  }

  var tokens = name.split(_whitespace).where((t) => t.isNotEmpty).toList();
  if (tokens.length > 1 && _familyWords.contains(tokens.first.toLowerCase())) {
    tokens = tokens.sublist(1);
  }
  if (tokens.isEmpty) return 'Other';

  // "A17", "S21", "G54" — the leading letters name the series.
  final match = _leadingLetters.firstMatch(tokens.first);
  if (match != null) return '${match.group(1)!.toUpperCase()} series';

  // "Edge", "Reno10", "Razr+" — the word names the series, with the
  // generation number and any "+" dropped so they group together.
  final word = tokens.first
      .replaceAll(_notAlphanumeric, '')
      .replaceAll(_fromFirstDigit, '');
  return word.isEmpty ? 'Other' : '$word series';
}
