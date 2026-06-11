// Entry point for the [Flavor.aken] commercial build ("A-KEN Quest").
//
// Run with:
//   flutter run  -t lib/main_aken.dart
//   flutter build web -t lib/main_aken.dart
//
// Stripe billing is stubbed — integrate the real SDK when ready.
// All init lives in the shared bootstrap (lib/core/bootstrap.dart) so flavor
// entrypoints can never drift from each other.
import 'package:engquest/core/bootstrap.dart';
import 'package:engquest/core/config/flavor_config.dart';

void main() => bootstrapApp(Flavor.aken);
