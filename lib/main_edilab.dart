// Entry point for the [Flavor.edilab] build.
//
// Run with:
//   flutter run  -t lib/main_edilab.dart
//   flutter build web -t lib/main_edilab.dart
//
// All init lives in the shared bootstrap (lib/core/bootstrap.dart) so flavor
// entrypoints can never drift from each other.
import 'package:engquest/core/bootstrap.dart';
import 'package:engquest/core/config/flavor_config.dart';

void main() => bootstrapApp(Flavor.edilab);
