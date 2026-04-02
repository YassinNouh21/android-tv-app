import 'package:flutter/material.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:sizer/sizer.dart';
import 'package:mawaqit/src/models/calendar/MawaqitHijriCalendar.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/widgets/ScreenWithAnimation.dart';
import 'package:provider/provider.dart';

class HijriAdjustmentsScreen extends StatelessWidget {
  const HijriAdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mosqueManager = Provider.of<MosqueManager>(context);
    final userPrefs = Provider.of<UserPreferencesManager>(context);

    return Scaffold(
      body: ScreenWithAnimationWidget(
        animation: 'settings',
        child: Center(
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                S.of(context).hijriAdjustments,
                style: Theme.of(context).textTheme.titleMedium?.apply(fontSizeFactor: 2),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              Text(
                S.of(context).hijriAdjustmentsDescription,
                style: Theme.of(context).textTheme.bodyLarge?.apply(fontSizeFactor: 1.8),
                textAlign: TextAlign.center,
              ),
              Divider(indent: 50, endIndent: 50),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 0.8.h),
                child: ListTile(
                  autofocus: userPrefs.hijriAdjustments == null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onTap: () {
                    userPrefs.hijriAdjustments = null;
                    Navigator.pop(context);
                  },
                  title: Text(
                    '${S.current.backoffice_default}',
                    style: Theme.of(context).textTheme.titleLarge?.apply(fontSizeFactor: 1.5),
                  ),
                  subtitle: Text(
                    '${S.current.recommended}',
                    style: Theme.of(context).textTheme.bodyMedium?.apply(fontSizeFactor: 1.3),
                  ),
                  trailing: Text(
                    MawaqitHijriCalendar.fromDateWithAdjustments(
                      mosqueManager.mosqueDate(),
                      adjustment: mosqueManager.times?.hijriAdjustment ?? 0,
                      force30Days: mosqueManager.times?.hijriDateForceTo30 ?? false,
                    ).formatMawaqitType(),
                    style: Theme.of(context).textTheme.bodyLarge?.apply(fontSizeFactor: 1.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              for (var i = -2; i <= 2; i++)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 0.8.h),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    autofocus: userPrefs.hijriAdjustments == i,
                    onTap: () {
                      userPrefs.hijriAdjustments = i;
                      Navigator.pop(context);
                    },
                    title: Text(
                      i > 0 ? '+$i' : '$i',
                      style: Theme.of(context).textTheme.titleLarge?.apply(fontSizeFactor: 1.5),
                    ),
                    trailing: Text(
                      MawaqitHijriCalendar.fromDateWithAdjustments(
                        mosqueManager.mosqueDate(),
                        adjustment: i,
                        force30Days: mosqueManager.times?.hijriDateForceTo30 ?? false,
                      ).formatMawaqitType(),
                      style: Theme.of(context).textTheme.bodyLarge?.apply(fontSizeFactor: 1.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
