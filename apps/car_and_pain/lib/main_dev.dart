import 'src/bootstrap.dart';
import 'src/flavor.dart';

/// Dev flavor entrypoint. Installs side-by-side with prod; distinct DB filename
/// and notification channel ids so dev reminders never collide with prod's.
void main() => bootstrap(Flavor.dev);
