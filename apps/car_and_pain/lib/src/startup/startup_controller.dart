import 'package:core/core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../flavor.dart';
import 'app_infra.dart';
import 'startup_initializer.dart';

part 'startup_controller.g.dart';

/// Drives async startup. Exposes an `AsyncValue<Result<AppInfra, StartupFailure>>`
/// so the UI shows a splash while loading, the app shell on `Ok`, and a
/// retry-capable error screen on `Err` — with init failures represented as
/// typed [StartupFailure] values, never exceptions crossing `runApp`.
///
/// This is the `@riverpod` codegen surface for F1 (generates
/// `startupControllerProvider`).
@riverpod
Future<Result<AppInfra, StartupFailure>> startupController(Ref ref) {
  final flavor = ref.watch(flavorProvider);
  return ref.watch(startupInitializerProvider).initialize(flavor);
}
