// Generic entry point — defaults to the edilab flavor.
// For explicit flavor builds use lib/main_edilab.dart or lib/main_aken.dart.
// All init lives in the shared bootstrap so the entrypoints can never drift.
import 'package:engquest/core/bootstrap.dart';
import 'package:engquest/core/config/flavor_config.dart';

void main() => bootstrapApp(Flavor.edilab);
