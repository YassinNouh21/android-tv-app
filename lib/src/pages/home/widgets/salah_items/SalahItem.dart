import 'package:flutter/material.dart';
import 'package:mawaqit/i18n/AppLanguage.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/pages/home/widgets/orientation_widget.dart';
import 'package:mawaqit/src/themes/UIShadows.dart';
import 'package:mawaqit/src/widgets/time_widget.dart';
import 'package:provider/provider.dart';

import '../../../../services/mosque_manager.dart';
import '../../../../services/user_preferences_manager.dart';

class SalahItemWidget extends StatelessOrientationWidget {
  SalahItemWidget({
    Key? key,
    required this.time,
    this.title,
    this.iqama,
    this.iqama2,
    this.active = false,
    this.removeBackground = false,
    this.withDivider = true,
    this.showIqama = true,
    this.isIqamaMoreImportant = false,
  }) : super(key: key);

  final String? title;
  final String time;
  final String? iqama;

  /// this only applied to Jumma pray as it is might have iqama times
  /// normal pray will have only one iqama time
  final String? iqama2;

  /// show divider only when both time and iqama exists
  final bool withDivider;
  final bool active;
  final bool removeBackground;
  final bool showIqama;

  /// make iqama larger than the time
  final bool isIqamaMoreImportant;

  @override
  Widget buildLandscape(BuildContext context) {
    final fontScale = context.watch<UserPreferencesManager>().appFontSizeScale;
    double titleFont = 3.vwr;
    double bigFont = 4.5.vwr;
    double smallFont = 3.6.vwr;

    final mosqueProvider = context.watch<MosqueManager>();
    final mosqueConfig = mosqueProvider.mosqueConfig;
    final is12period = mosqueConfig?.timeDisplayFormat == "12";

    return Container(
      margin: EdgeInsets.all(1.vw),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2.vw),
        color: active
            ? mosqueProvider.getColorTheme().withOpacity(.5)
            : removeBackground
                ? null
                : Colors.black.withOpacity(.5),
      ),
      padding: EdgeInsets.symmetric(vertical: 1.6.vr, horizontal: 1.vwr),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title's container and TextStyle.height both use 1.0 (was 1.2/1.5).
            // The Container exactly matches the text's natural size, so FittedBox
            // doesn't scale and the title still renders at fontSize titleFont*fontScale.
            // The trimmed line-height padding hands ~17px of vertical room back to
            // the Flexible(time) below, which is what the time/iqama need to render
            // at full 1.2× natural size without being scaled back down.
            if (title != null && title!.trim().isNotEmpty)
              Container(
                height: titleFont * fontScale,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    maxLines: 1,
                    title ?? "",
                    style: TextStyle(
                      fontSize: titleFont * fontScale,
                      shadows: kHomeTextShadow,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 0.5.vr),
            Flexible(
              child: FittedBox(
                alignment: Alignment.center,
                fit: BoxFit.scaleDown,
                child: _buildTimeContent(context, bigFont * fontScale, smallFont * fontScale, is12period),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildPortrait(BuildContext context) {
    final fontScale = context.watch<UserPreferencesManager>().appFontSizeScale;
    double titleFont = 3.5.vwr;
    double bigFont = 4.vwr;
    double smallFont = 3.vwr;

    final mosqueProvider = context.watch<MosqueManager>();
    final mosqueConfig = mosqueProvider.mosqueConfig;
    final is12period = mosqueConfig?.timeDisplayFormat == "12";

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2.vw),
        color: active
            ? mosqueProvider.getColorTheme().withOpacity(.5)
            : removeBackground
                ? null
                : Colors.black.withOpacity(.5),
      ),
      padding: EdgeInsets.symmetric(vertical: 1.vr, horizontal: 1.vwr),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // See landscape note: the parent layout's flex must also grow with
            // fontScale, otherwise the time below stays the same visual size.
            if (title != null && title!.trim().isNotEmpty)
              Container(
                height: titleFont * fontScale * 1.2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    maxLines: 1,
                    title ?? "",
                    style: TextStyle(
                      fontSize: titleFont * fontScale,
                      shadows: kHomeTextShadow,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 0.5.vh),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildTimeContent(context, bigFont * fontScale, smallFont * fontScale, is12period),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeContent(BuildContext context, double bigFont, double smallFont, bool is12period) {
    final isArabic = context.read<AppLanguage>().isArabic();

    if (iqama2 != null) {
      // Three times layout
      return Column(
        children: [
          if (time.trim().isEmpty)
            Icon(Icons.dnd_forwardslash, size: 6.vwr)
          else
            TimeWidget.fromString(
              show24hFormat: !is12period,
              time: time,
              style: TextStyle(
                fontSize: bigFont,
                fontWeight: FontWeight.w700,
                shadows: kHomeTextShadow,
                color: Colors.white,
                height: 1,
              ),
            ),
          Container(
            margin: EdgeInsets.symmetric(vertical: 1.vr),
            width: 20.vwr,
            height: 1,
            color: Colors.white,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TimeWidget.fromString(
                show24hFormat: !is12period,
                time: iqama!,
                style: TextStyle(
                  fontSize: smallFont,
                  fontWeight: FontWeight.w700,
                  shadows: kHomeTextShadow,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Container(
                height: bigFont,
                width: 1,
                margin: EdgeInsets.symmetric(horizontal: 1.vwr),
                color: Colors.white,
              ),
              TimeWidget.fromString(
                show24hFormat: !is12period,
                time: iqama2!,
                style: TextStyle(
                  fontSize: smallFont,
                  fontWeight: FontWeight.w700,
                  shadows: kHomeTextShadow,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Original two times layout
      return Column(
        children: [
          if (time.trim().isEmpty)
            Icon(Icons.dnd_forwardslash, size: 6.vwr)
          else
            Container(
              decoration: (iqama != null && showIqama && withDivider)
                  ? BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white, width: 1)),
                    )
                  : null,
              child: TimeWidget.fromString(
                show24hFormat: !is12period,
                time: time,
                style: TextStyle(
                  fontSize: isIqamaMoreImportant ? smallFont : bigFont,
                  fontWeight: FontWeight.w700,
                  shadows: kHomeTextShadow,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          if (iqama != null && showIqama && !withDivider) SizedBox(height: isArabic ? 0.7.vr : 0.5.vwr),
          if (iqama != null && showIqama)
            TimeWidget.fromString(
              show24hFormat: !is12period,
              time: iqama!,
              style: TextStyle(
                fontSize: isIqamaMoreImportant ? bigFont : smallFont,
                fontWeight: FontWeight.bold,
                shadows: kHomeTextShadow,
                letterSpacing: 1,
                color: Colors.white,
                height: 1.0,
              ),
            ),
        ],
      );
    }
  }
}
