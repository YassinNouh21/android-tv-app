import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/helpers/mawaqit_icons_icons.dart';
import 'package:mawaqit/src/helpers/repaint_boundaries.dart';
import 'package:mawaqit/src/pages/home/widgets/FlashAnimation.dart';
import 'package:mawaqit/src/pages/home/widgets/footer.dart';
import 'package:mawaqit/src/pages/home/widgets/mosque_background_screen.dart';
import 'package:mawaqit/src/pages/home/widgets/mosque_header.dart';
import 'package:mawaqit/src/pages/home/widgets/portrait_footer_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/responsive_mini_salah_bar_turkish_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/responsive_mini_salah_bar_widget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/themes/UIShadows.dart';
import 'package:provider/provider.dart';

const _kDuhaTimeScreenDuration = Duration(seconds: 30);

/// Displays the "Duha time" announcement screen for 30 seconds.
/// Shows the mosque header, dome icons, and "Duha time" text — no audio.
class DuhaTimeSubScreen extends StatefulWidget {
  const DuhaTimeSubScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<DuhaTimeSubScreen> createState() => _DuhaTimeSubScreenState();
}

class _DuhaTimeSubScreenState extends State<DuhaTimeSubScreen> {
  Timer? _timer;
  bool _closeCalled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_kDuhaTimeScreenDuration, _closeScreenSafely);
  }

  void _closeScreenSafely() {
    if (_closeCalled) return;
    _closeCalled = true;
    _timer?.cancel();
    if (mounted) widget.onDone?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.watch<MosqueManager>();
    final mosque = mosqueManager.mosque;
    if (mosque == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _closeScreenSafely();
      });
      return const SizedBox.shrink();
    }
    final tr = S.of(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final fontScale = context.watch<UserPreferencesManager>().appFontSizeScale;

    return MosqueBackgroundScreen(
      child: Column(
        children: [
          Directionality(textDirection: TextDirection.ltr, child: MosqueHeader(mosque: mosque)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.vw),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textBaseline: TextBaseline.alphabetic,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    children: [
                      Icon(MawaqitIcons.icon_adhan, size: 12.vw * fontScale)
                          .animate()
                          .slideX(begin: -1, delay: .5.seconds)
                          .fadeIn()
                          .addRepaintBoundary(),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.vw),
                        child: Text(
                          tr.duhaTime,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.vw * fontScale,
                            color: Colors.white,
                            shadows: kHomeTextShadow,
                          ),
                        ),
                      ).animate().moveY(begin: -120).fade().addRepaintBoundary(),
                      Icon(MawaqitIcons.icon_adhan, size: 12.vw * fontScale)
                          .animate()
                          .slideX(begin: 1, delay: .5.seconds)
                          .fadeIn()
                          .addRepaintBoundary(),
                    ],
                  ).flashAnimation(),
                ),
              ),
            ),
          ),
          (mosqueManager.times?.isTurki ?? false)
              ? ResponsiveMiniSalahBarTurkishWidget(activeItem: mosqueManager.salahIndex)
              : ResponsiveMiniSalahBarWidget(activeItem: mosqueManager.salahIndex),
          if (mosqueManager.flashEnabled && mosque.flash != null) ...[
            if (isPortrait) SizedBox(height: 1.vh),
            isPortrait ? PortraitFooterWidget(mosque: mosque) : Footer(),
          ],
        ],
      ),
    );
  }
}
