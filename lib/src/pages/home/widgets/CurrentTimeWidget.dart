import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mawaqit/src/helpers/LocaleHelper.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/themes/UIShadows.dart';
import 'package:provider/provider.dart';

class CurrentTimeWidget extends StatelessWidget {
  const CurrentTimeWidget({
    Key? key,
    this.hideSeconds = false,
  }) : super(key: key);

  final bool hideSeconds;

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.watch<MosqueManager>();
    final fontScale = context.watch<UserPreferencesManager>().appFontSizeScale;

    final now = mosqueManager.mosqueDate();

    final mosqueConfig = mosqueManager.mosqueConfig;
    bool is12hourFormat = mosqueConfig?.timeDisplayFormat == "12";

    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat("${is12hourFormat ? "hh:mm" : "HH:mm"}").format(now),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 8.vwr * fontScale,
                shadows: kHomeTextShadow,
                color: Colors.white,
                height: 1,
              ),
            ),
            if (!hideSeconds)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ':${DateFormat('ss', 'en').format(now)}',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: (is12hourFormat ? 4.vwr : 6.vwr) * fontScale,
                      shadows: kHomeTextShadow,
                      height: is12hourFormat ? 1 : null,
                    ),
                  ),
                  if (is12hourFormat)
                    Padding(
                      padding: EdgeInsets.only(bottom: .6.vh, left: .9.vw),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 8.vwr * fontScale),
                        child: FittedBox(
                          child: Text(
                            DateFormat('a', LocaleHelper.getAmPmLocale(Localizations.localeOf(context).languageCode))
                                .format(now),
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 3.2.vwr * fontScale,
                              shadows: kHomeTextShadow,
                              height: .9,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (hideSeconds && is12hourFormat)
              Padding(
                padding: EdgeInsets.only(left: 1.vw),
                child: Text(
                  DateFormat('a', LocaleHelper.getAmPmLocale(Localizations.localeOf(context).languageCode)).format(now),
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 4.vwr * fontScale,
                    shadows: kHomeTextShadow,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
