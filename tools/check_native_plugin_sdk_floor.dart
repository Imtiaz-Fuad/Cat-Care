/// CI-friendly native plugin SDK-floor guard.
///
/// Scans every resolved package in `pubspec.lock` for an `android/build.gradle`
/// or `android/build.gradle.kts` that hard-codes `compileSdk` below the
/// project's [`MIN_COMPILE_SDK`]. Plugins that pin a stale SDK floor are the
/// root cause of the failure class that bit us in `file_picker` (commit
/// 40075c7) and `geocoding` (commit d298789): the plugin's Gradle subproject
/// is compiled against, e.g., `android-33`, while its AndroidX transitive
/// deps require `compileSdk >= 34`, causing
/// `:checkDebugAarMetadata` to fail even though the app's `compileSdk = 36`.
///
/// Run locally with:
///   dart run tools/check_native_plugin_sdk_floor.dart
///
/// Returns exit code 0 on success, 1 if any offending plugins are found.
library;

import 'dart:io';

/// Floor below which a plugin's android/build.gradle is considered "stale".
///
/// We pin this at 34 — the minimum that modern AndroidX (androidx.fragment
/// 1.7.1, androidx.core 1.13.1, androidx.activity 1.8.1) requires. Plugins
/// that pin below this number will trip `:checkDebugAarMetadata` even though
/// the app targets compileSdk 36.
///
/// The job `android-build` in `.github/workflows/ci.yml` runs
/// `flutter build apk --debug --no-pub` and is the authoritative gate; this
/// guard catches the same class of failure locally in milliseconds instead
/// of after a 10-minute Gradle run.
const int _minCompileSdk = 34;

/// Plugins that do not ship native Android source (pure Dart) can be skipped.
const Set<String> _pureDartPlugins = <String>{
  'flutter',
  'flutter_localizations',
  'flutter_test',
  'flutter_lints',
  'cupertino_icons',
  'provider',
  'go_router',
  'go_router_builder',
  'dio',
  'logger',
  'cached_network_image',
  'uuid',
  'intl',
  'path',
  'timezone',
  'mocktail',
  'build_runner',
};

Future<int> main() async {
  final lockFile = File('pubspec.lock');
  if (!lockFile.existsSync()) {
    stderr.writeln(
      'check_native_plugin_sdk_floor: pubspec.lock not found.'
      ' Run `flutter pub get` first.',
    );
    return 1;
  }

  final packages = _parseLockFile(lockFile);
  if (packages.isEmpty) {
    stderr.writeln('check_native_plugin_sdk_floor: no packages resolved.');
    return 0;
  }

  final pubCache = _pubCacheRoot();
  if (pubCache == null) {
    stderr.writeln(
      'check_native_plugin_sdk_floor: PUB_CACHE not found.'
      ' Falling back to %LOCALAPPDATA%/Pub/Cache/hosted/pub.dev.',
    );
  }

  final offenders = <String>[];

  for (final pkg in packages) {
    if (_pureDartPlugins.contains(pkg.name)) continue;
    if (pkg.source != 'hosted') continue; // skip path/git/SDK packages

    final pluginDir = _locatePluginDir(pkg, pubCache);
    if (pluginDir == null) continue;

    final androidDir = Directory('${pluginDir.path}/android');
    if (!androidDir.existsSync()) continue; // pure-Dart plugin

    final detected = _readCompileSdkFloor(androidDir);
    if (detected == null) continue; // uses flutter.compileSdkVersion (safe)
    if (detected >= _minCompileSdk) continue;

    offenders.add(
      '${pkg.name} ${pkg.version} pins compileSdk = $detected'
      ' (need >= $_minCompileSdk) at '
      '${pluginDir.path}/android',
    );
  }

  if (offenders.isEmpty) {
    stdout.writeln(
      'Plugin SDK-floor check passed: every plugin with native Android code'
      ' either uses flutter.compileSdkVersion or pins >= $_minCompileSdk.',
    );
    return 0;
  }

  stderr.writeln(
    'Plugin SDK-floor check FAILED. The following plugins hard-code a'
    ' compileSdk below $_minCompileSdk and will fail CI:',
  );
  for (final v in offenders) {
    stderr.writeln('  - $v');
  }
  stderr.writeln(
    '\nFixes (in order of preference):\n'
    '  1. Bump the plugin to a version that uses flutter.compileSdkVersion.\n'
    '  2. If the plugin is unused, remove it from pubspec.yaml.\n'
    '  3. As a last resort, add a targeted entry in android/build.gradle.kts.',
  );
  return 1;
}

class _LockEntry {
  _LockEntry(this.name, this.version, this.source);
  final String name;
  final String version;
  final String source;
}

/// Very small YAML parser scoped to the fields we need from pubspec.lock.
List<_LockEntry> _parseLockFile(File lockFile) {
  final lines = lockFile.readAsLinesSync();
  final entries = <_LockEntry>[];
  String? name;
  String? version;
  String? source;
  bool inPackages = false;

  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.startsWith('packages:')) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (line.startsWith('  ') && !line.startsWith('    ')) {
      // new package header, e.g. "  file_picker:"
      final m = RegExp(r'^  ([a-z0-9_]+):\s*$').firstMatch(line);
      if (m != null) {
        if (name != null && source != null && version != null) {
          entries.add(_LockEntry(name, version, source));
        }
        name = m.group(1);
        version = null;
        source = null;
      }
    }
    final vMatch = RegExp(r'^\s+version:\s*"([^"]+)"').firstMatch(line);
    if (vMatch != null) version = vMatch.group(1);
    final sMatch = RegExp(r'^\s+source:\s*(\S+)').firstMatch(line);
    if (sMatch != null) source = sMatch.group(1);
    // stopping condition: end of `packages:` reached at top level
    if (line.startsWith('sdks:') || line.startsWith('flutter:')) break;
  }

  if (name != null && source != null && version != null) {
    entries.add(_LockEntry(name, version, source));
  }
  return entries;
}

String? _pubCacheRoot() {
  final env = Platform.environment;
  if (env['PUB_CACHE'] != null && Directory(env['PUB_CACHE']!).existsSync()) {
    return env['PUB_CACHE']!;
  }
  // Windows default
  final localAppData = env['LOCALAPPDATA'];
  if (localAppData != null) {
    final candidate = '$localAppData/Pub/Cache/hosted/pub.dev';
    if (Directory(candidate).existsSync()) return candidate;
  }
  // macOS / Linux default
  final home = env['HOME'];
  if (home != null) {
    final mac = '$home/.pub-cache/hosted/pub.dev';
    if (Directory(mac).existsSync()) return mac;
  }
  return null;
}

Directory? _locatePluginDir(_LockEntry pkg, String? pubCache) {
  if (pubCache == null) return null;
  final dir = Directory('$pubCache/${pkg.name}-${pkg.version}');
  return dir.existsSync() ? dir : null;
}

/// Returns the integer compileSdk floor declared in the plugin's
/// android/build.gradle(.kts), or null if no hard-coded value is found
/// (i.e. the plugin inherits `flutter.compileSdkVersion`).
int? _readCompileSdkFloor(Directory androidDir) {
  final candidates = <File>[
    File('${androidDir.path}/build.gradle'),
    File('${androidDir.path}/build.gradle.kts'),
  ];
  for (final f in candidates) {
    if (!f.existsSync()) continue;
    final content = f.readAsStringSync();
    final m = _compileSdkRegex.firstMatch(content);
    if (m != null) {
      return int.tryParse(m.group(1)!);
    }
  }
  return null;
}

/// Matches the integer literal following any `compileSdk` keyword in either
/// Groovy (`compileSdk 34`) or Kotlin DSL (`compileSdk = 34`, `compileSdk = 36`).
/// Deliberately does NOT match `project.ext.compileSdk` or
/// `flutter.compileSdkVersion` — those are safe references that resolve at
/// Gradle task time.
final RegExp _compileSdkRegex = RegExp(
  r'compileSdk(?:Version)?\s*=?\s*(\d+)',
  multiLine: true,
);
