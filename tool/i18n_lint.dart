import 'dart:convert';
import 'dart:io';

const arbDir = 'res/values';
const sourceLang = 'en';
const baselinePath = 'tool/i18n_baseline.json';

const scriptRanges = <String, List<List<int>>>{
  'hi': [[0x0900, 0x097F]],
  'mr': [[0x0900, 0x097F]],
  'bn': [[0x0980, 0x09FF]],
  'gu': [[0x0A80, 0x0AFF]],
  'pa': [[0x0A00, 0x0A7F]],
  'or': [[0x0B00, 0x0B7F]],
  'ta': [[0x0B80, 0x0BFF]],
  'te': [[0x0C00, 0x0C7F]],
  'kn': [[0x0C80, 0x0CFF]],
  'ml': [[0x0D00, 0x0D7F]],
  'ar': [[0x0600, 0x06FF]],
  'fa': [[0x0600, 0x06FF]],
  'ur': [[0x0600, 0x06FF]],
  'my': [[0x1000, 0x109F]],
  'th': [[0x0E00, 0x0E7F]],
  'hy': [[0x0530, 0x058F]],
  'bg': [[0x0400, 0x04FF]],
  'ru': [[0x0400, 0x04FF]],
  'uk': [[0x0400, 0x04FF]],
  'ja': [[0x3040, 0x30FF], [0x4E00, 0x9FFF]],
  'ko': [[0xAC00, 0xD7AF]],
  'zh': [[0x4E00, 0x9FFF]],
};

const brandKeys = <String>{
  'cake_wallet',
  'monero_com',
  'monero_com_wallet_text',
  'haven_app',
  'haven_app_wallet_text',
  'id',
  'faq',
};

final placeholderPattern = RegExp(r'\$\{([A-Za-z0-9_]+)\}');
final unclosedPattern = RegExp(r'\$\{[^}]*$');

const noLengthCheck = <String>{'zh', 'ja', 'ko'};

final _warnings = <Finding>[];
final _errors = <Finding>[];

class Finding {
  Finding(this.lang, this.kind, this.key, this.message);

  final String lang;
  final String kind;
  final String key;
  final String message;

  String get id => '$lang|$kind|$key';

  @override
  String toString() => '$lang  ${kind.padRight(11)}  $key  $message';
}

Map<String, String> readStrings(String path) {
  final raw = json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in raw.entries)
      if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
  };
}

List<String> localeCodes() {
  final codes = <String>[];
  for (final entity in Directory(arbDir).listSync()) {
    final name = entity.uri.pathSegments.last;
    final match = RegExp(r'^strings_(.+)\.arb$').firstMatch(name);
    if (match != null) codes.add(match.group(1)!);
  }
  codes.sort();
  return codes;
}

String baseLang(String code) => code.split('_').first;

bool hasScriptChars(String value, String lang) {
  final ranges = scriptRanges[baseLang(lang)];
  if (ranges == null) return true;
  for (final rune in value.runes) {
    for (final range in ranges) {
      if (rune >= range[0] && rune <= range[1]) return true;
    }
  }
  return false;
}

List<String> placeholders(String value) =>
    placeholderPattern.allMatches(value).map((m) => m.group(1)!).toList();

const punctEquivalents = <String, String>{
  '。': '.',
  '．': '.',
  '।': '.',
  '۔': '.',
  '，': ',',
  '、': ',',
  '；': ';',
  '：': ':',
  '！': '!',
  '？': '?',
  '؟': '?',
  '။': '.',
  '၊': ',',
  '॥': '.',
  '։': '.',
};

const noPunctuationCheck = <String>{'th', 'ja', 'ko', 'zh', 'zh_TW'};

String normalizePunctChar(String value) {
  if (value.isEmpty) return '';
  final last = String.fromCharCode(value.runes.last);
  return punctEquivalents[last] ?? last;
}

const terminalPunct = {'.', ':', '?', '!', ',', ';'};

bool endsSamePunctuation(String en, String value, String lang) {
  if (noPunctuationCheck.contains(baseLang(lang))) return true;
  final enChar = normalizePunctChar(en);
  final valueChar = normalizePunctChar(value);
  final enTerminal = terminalPunct.contains(enChar);
  final valueTerminal = terminalPunct.contains(valueChar);
  if (!enTerminal) return true;
  return valueTerminal && enChar == valueChar;
}

bool isProperNounLike(String en) =>
    !en.contains(' ') && (en.length <= 6 || RegExp(r'[a-z][A-Z]').hasMatch(en));

void checkLocale(String lang, Map<String, String> source) {
  final path = '$arbDir/strings_$lang.arb';
  Map<String, String> target;
  try {
    target = readStrings(path);
  } catch (e) {
    _errors.add(Finding(lang, 'parse', path, '$e'));
    return;
  }

  for (final key in source.keys) {
    if (!target.containsKey(key)) {
      _errors.add(Finding(lang, 'missing', key, 'absent from $path'));
    }
  }
  for (final key in target.keys) {
    if (!source.containsKey(key)) {
      _warnings.add(Finding(lang, 'extra', key, 'not present in strings_en.arb'));
    }
  }

  for (final entry in target.entries) {
    final key = entry.key;
    final value = entry.value;
    final en = source[key];
    if (en == null) continue;

    if (value.trim().isEmpty) {
      _errors.add(Finding(lang, 'empty', key, 'empty translation'));
      continue;
    }
    if (unclosedPattern.hasMatch(value)) {
      _errors.add(Finding(lang, 'unclosed', key, 'unterminated \${ placeholder'));
    }

    final enPlaceholders = placeholders(en);
    final placeholdersTarget = placeholders(value);

    final unknown = placeholdersTarget.where((p) => !enPlaceholders.contains(p)).toList();
    if (unknown.isNotEmpty) {
      _warnings.add(Finding(lang, 'ph-rename', key,
          'placeholder(s) ${unknown.join(", ")} not in English: $en'));
    } else if (placeholdersTarget.length > enPlaceholders.length) {
      _warnings.add(Finding(lang, 'ph-extra', key,
          'uses ${placeholdersTarget.length} placeholders, English uses ${enPlaceholders.length}'));
    }

    if (unknown.isEmpty && placeholdersTarget.length == enPlaceholders.length) {
      for (var i = 0; i < placeholdersTarget.length; i++) {
        if (placeholdersTarget[i] != enPlaceholders[i]) {
          _warnings.add(Finding(lang, 'ph-order', key,
              'placeholder $i is ${placeholdersTarget[i]}, English has ${enPlaceholders[i]}'));
          break;
        }
      }
    }

    for (final p in enPlaceholders.toSet()) {
      final want = enPlaceholders.where((e) => e == p).length;
      final got = placeholdersTarget.where((e) => e == p).length;
      if (got > want) {
        _errors.add(Finding(lang, 'ph-count', key,
            'placeholder $p used $got times, English uses $want'));
      }
    }

    if (placeholdersTarget.isEmpty && enPlaceholders.isNotEmpty) {
      _errors.add(Finding(lang, 'ph-dropped', key, 'drops ${enPlaceholders.join(", ")}'));
    }

    final enLeading = en.startsWith(' ');
    final enTrailing = en.endsWith(' ');
    if (enLeading != value.startsWith(' ') || enTrailing != value.endsWith(' ')) {
      _warnings.add(Finding(lang, 'space', key,
          'leading/trailing space differs from English'));
    }

    if (!brandKeys.contains(key) &&
        value == en &&
        !isProperNounLike(en) &&
        scriptRanges.containsKey(baseLang(lang))) {
      _warnings.add(Finding(lang, 'identical', key, 'identical to English'));
    }

    if (!hasScriptChars(value, lang) &&
        !brandKeys.contains(key) &&
        !isProperNounLike(en)) {
      _warnings.add(Finding(lang, 'script', key,
          'no ${baseLang(lang)} script characters'));
    }

    if (!noLengthCheck.contains(baseLang(lang)) && en.length >= 25) {
      final ratio = value.length / en.length;
      if (ratio < 0.5 || ratio > 2.2) {
        _warnings.add(Finding(lang, 'length', key,
            'length ratio ${ratio.toStringAsFixed(2)} (${en.length} -> ${value.length})'));
      }
    }

    if (!endsSamePunctuation(en, value, lang)) {
      _warnings.add(Finding(lang, 'punct', key,
          'end punctuation differs from English: "${en[en.length - 1]}" vs "${value[value.length - 1]}"'));
    }
  }
}

Set<String> loadBaseline() {
  final file = File(baselinePath);
  if (!file.existsSync()) return {};
  final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  return (data['accepted'] as List<dynamic>).cast<String>().toSet();
}

void writeBaseline(Set<String> ids) {
  final sorted = ids.toList()..sort();
  File(baselinePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({'accepted': sorted}) + '\n');
}

void main(List<String> args) {
  var langs = <String>[];
  var strict = false;
  var updateBaseline = false;

  for (final arg in args) {
    if (arg == '--strict') strict = true;
    if (arg == '--update-baseline') updateBaseline = true;
    final langArg = RegExp(r'^--lang=(.+)$').firstMatch(arg);
    if (langArg != null) langs = langArg.group(1)!.split(',');
  }

  final sourcePath = '$arbDir/strings_$sourceLang.arb';
  if (!File(sourcePath).existsSync()) {
    stderr.writeln('Missing $sourcePath');
    exit(2);
  }
  final source = readStrings(sourcePath);

  final available = localeCodes().where((l) => l != sourceLang).toList();
  if (langs.isEmpty) langs = available;
  for (final lang in langs) {
    if (!available.contains(lang)) {
      stderr.writeln('No ARB file for locale "$lang" in $arbDir/');
      exit(2);
    }
    checkLocale(lang, source);
  }

  final baseline = loadBaseline();
  final freshErrors = _errors.where((f) => !baseline.contains(f.id)).toList();
  final freshWarnings = _warnings.where((f) => !baseline.contains(f.id)).toList();

  if (updateBaseline) {
    writeBaseline({...baseline, ..._errors.map((f) => f.id), ..._warnings.map((f) => f.id)});
    stdout.writeln('Baseline updated: ${baselinePath}');
    return;
  }

  stdout.writeln('Checked ${langs.length} locale(s) against ${source.length} '
      'English strings.');
  if (baseline.isNotEmpty) {
    stdout.writeln('Baseline accepts ${baseline.length} known finding(s).');
  }
  for (final f in freshErrors) stdout.writeln('error    $f');
  for (final f in freshWarnings) stdout.writeln('warn     $f');

  final known = _errors.length + _warnings.length - freshErrors.length - freshWarnings.length;
  stdout.writeln('\n${freshErrors.length} error(s), ${freshWarnings.length} warning(s)'
      '${known > 0 ? ", $known baselined" : ""}.');

  if (freshErrors.isNotEmpty || (strict && freshWarnings.isNotEmpty)) exit(1);
}
