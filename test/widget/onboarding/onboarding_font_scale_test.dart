import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:mawaqit_tv_l10n/mawaqit_tv_l10n.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/onboarding_about_widget.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';

class MockUserPreferencesManager extends Mock implements UserPreferencesManager {}

/// Regression test for the font-scaling feature.
///
/// AutoSizeText asserts `minFontSize % stepGranularity == 0`. The feature briefly
/// wrote `minFontSize: <int> * fontScale`, which at a non-1.0 scale produces a
/// non-integer (e.g. `10 * 1.1 == 11.000000000000002`) and crashed the onboarding
/// screens with "MinFontSize must be a multiple of stepGranularity". This guards
/// that a non-1.0 scale builds those screens without throwing.
void main() {
  testWidgets('onboarding builds at the largest font scale without an AutoSizeText assertion',
      (WidgetTester tester) async {
    final prefs = MockUserPreferencesManager();
    // 1.1 is the "large" scale that produced the off-by-float minFontSize.
    when(() => prefs.appFontSizeScale).thenReturn(1.1);

    await tester.pumpWidget(
      Sizer(
        builder: (context, orientation, deviceType) => ChangeNotifierProvider<UserPreferencesManager>.value(
          value: prefs,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [MawaqitTvLocalizations.delegate],
            home: Scaffold(body: OnBoardingMawaqitAboutWidget()),
          ),
        ),
      ),
    );
    // Drain the focus timers scheduled in initState so none stay pending.
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
    expect(find.byType(OnBoardingMawaqitAboutWidget), findsOneWidget);
  });
}
