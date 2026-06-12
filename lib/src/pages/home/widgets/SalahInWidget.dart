import 'package:flutter/material.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:provider/provider.dart';

import '../../../helpers/StringUtils.dart';
import '../../../helpers/mawaqit_icons_icons.dart';
import '../../../themes/UIShadows.dart';

class SalahInWidget extends StatelessWidget {
  const SalahInWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.read<MosqueManager>();
    final fontScale = context.watch<UserPreferencesManager>().appFontSizeScale;
    final nextSalahTime = mosqueManager.nextSalahAfter();

    var nextSalahIndex = mosqueManager.nextSalahIndex();
    var nextSalahName = mosqueManager.salahName(nextSalahIndex);

    if (nextSalahIndex == 1 && mosqueManager.mosqueDate().weekday == DateTime.friday && mosqueManager.typeIsMosque) {
      nextSalahName = S.of(context).jumua;
    }

    String countDownText = StringManager.getPrayerCountdown(
      context,
      nextSalahTime,
      nextSalahName,
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      // scaleDown so the scaled icons + countdown can't overflow the narrow
      // 70%-width clock area in portrait at Large/X-Large.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          mainAxisSize: MainAxisSize.min,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Icon(MawaqitIcons.icon_adhan, color: Colors.white, size: 2.3.vwr * fontScale),
            Container(
              constraints: BoxConstraints(maxWidth: 30.vwr * fontScale),
              padding: EdgeInsets.symmetric(horizontal: 1.45.vwr),
              child: FittedBox(
                child: Text(
                  mosqueManager.getActiveCountdownText(context, countDownText),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 2.8.vwr * fontScale,
                    color: Colors.white,
                    shadows: kHomeTextShadow,
                  ),
                ),
              ),
            ),
            Icon(MawaqitIcons.icon_adhan, color: Colors.white, size: 2.3.vwr * fontScale),
          ],
        ),
      ),
    );
  }
}
