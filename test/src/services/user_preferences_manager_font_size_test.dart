import 'package:flutter_test/flutter_test.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests for the app-wide font-size setting added in the font-scaling feature.
///
/// These encode the contract every screen depends on:
///   - the default must stay `medium` (1.0) so existing installs keep today's size,
///   - the choice must persist across restarts (that is the whole point of a setting),
///   - each size must map to its exact scale multiplier (a wrong value silently
///     breaks the feature on every screen at once).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserPreferencesManager.appFontSize', () {
    test('defaults to medium / scale 1.0 when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await UserPreferencesManager().init();

      expect(prefs.appFontSize, AppFontSize.medium);
      expect(prefs.appFontSizeScale, 1.0);
    });

    test('persists the selected size across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await UserPreferencesManager().init();

      prefs.appFontSize = AppFontSize.extraLarge;
      expect(prefs.appFontSize, AppFontSize.extraLarge);

      // A second manager over the same store simulates an app restart: it must
      // read back the persisted value, not fall back to the default.
      final reloaded = await UserPreferencesManager().init();
      expect(reloaded.appFontSize, AppFontSize.extraLarge);
      expect(reloaded.appFontSizeScale, 1.2);
    });

    test('maps every size to its documented scale multiplier', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await UserPreferencesManager().init();

      const expectedScale = <AppFontSize, double>{
        AppFontSize.small: 0.9,
        AppFontSize.medium: 1.0,
        AppFontSize.large: 1.1,
        AppFontSize.extraLarge: 1.2,
      };

      for (final entry in expectedScale.entries) {
        prefs.appFontSize = entry.key;
        expect(prefs.appFontSizeScale, entry.value, reason: 'scale for ${entry.key}');
      }
    });
  });
}
