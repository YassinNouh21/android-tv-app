import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/helpers/repaint_boundaries.dart';
import 'package:mawaqit/src/pages/home/sub_screens/normal_home.dart';
import 'package:mawaqit/src/pages/home/widgets/footer.dart';
import 'package:mawaqit/src/pages/home/widgets/offline_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/portrait_footer_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/responsive_mini_salah_bar_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/TimeWidget.dart';
import 'package:mawaqit/src/pages/home/widgets/WeatherWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/themes/UIShadows.dart';
import 'package:provider/provider.dart';

import '../../../helpers/time_utils.dart';
import '../widgets/salah_items/responsive_mini_salah_bar_turkish_widget.dart';

class IqamaaCountDownSubScreen extends StatefulWidget {
  const IqamaaCountDownSubScreen({
    Key? key,
    this.onDone,
    this.isDebug = false,
    this.currentSalahIndex = 0,
    this.iqamaTime,
  }) : super(key: key);

  final bool isDebug;
  final int currentSalahIndex;
  final VoidCallback? onDone;
  final DateTime? iqamaTime;

  @override
  State<IqamaaCountDownSubScreen> createState() => _IqamaaCountDownSubScreenState();
}

class _IqamaaCountDownSubScreenState extends State<IqamaaCountDownSubScreen> {
  Duration _remainingTime = Duration.zero;
  Timer? _countdownTimer;
  late DateTime _targetIqamaTime;
  late final MosqueManager _mosqueManager;
  late final Stream<int> _countdownStream;

  @override
  void initState() {
    super.initState();
    _mosqueManager = context.read<MosqueManager>();
    final mosqueManager = _mosqueManager;
    _countdownStream = Stream.periodic(Duration(seconds: 1), (count) => count);

    if (widget.isDebug) {
      _remainingTime = Duration(minutes: 5);
      _startCountdown();
    } else {
      if (widget.iqamaTime != null) {
        _targetIqamaTime = widget.iqamaTime!;
      } else {
        var currentSalahTime = mosqueManager.actualTimes()[widget.currentSalahIndex];
        var currentIqamaTime = mosqueManager.actualIqamaTimes()[widget.currentSalahIndex];

        if (currentIqamaTime.isBefore(currentSalahTime)) {
          currentIqamaTime = currentIqamaTime.add(Duration(days: 1));
        }
        _targetIqamaTime = currentIqamaTime;
      }

      final now = mosqueManager.mosqueDate();
      _remainingTime = _targetIqamaTime.difference(now);

      // Schedule the onDone callback to be called when countdown finishes
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        Future.delayed(_remainingTime, widget.onDone);
      });
    }
  }

  /// Start the countdown timer
  void _startCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = _remainingTime - Duration(seconds: 1);
        } else {
          _countdownTimer?.cancel();
          widget.onDone?.call();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();

    // Hide flash when transitioning to IqamaSubScreen (phone flash screen)
    _mosqueManager.hideFlashTemporarily();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.read<MosqueManager>();
    final tr = S.of(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    if (mosqueManager.mosqueConfig?.iqamaFullScreenCountdown == false) return NormalHomeSubScreen();

    return SafeArea(
      child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 1.vw, vertical: 1.5.vh),
              child: Row(
                textDirection: TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OfflineWidget(),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: WeatherWidget(),
                  ),
                ],
              ),
            ),

            SizedBox(height: isPortrait ? 0.5.vh : 2.vh),

            // Clock Widget from Main Screen (compact version)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 1.vw),
              child: Container(
                height: isPortrait ? 20.vh : 18.vh,
                alignment: Alignment.center,
                child: isPortrait
                    ? HomeTimeWidget(
                        showSalahIn: false,
                        showOuterBackground: false,
                        hideSeconds: true,
                        hideBackground: true,
                      )
                    : ClipRect(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: 60.vw,
                            height: 35.vh,
                            child: HomeTimeWidget(
                              showSalahIn: false,
                              showOuterBackground: false,
                              hideSeconds: true,
                              hideBackground: true,
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            SizedBox(height: isPortrait ? 1.vh : 3.vh),

            // Main countdown section - takes up available space
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      tr.iqamaIn,
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 400 ? 6.vwr : 5.vwr,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: kIqamaCountDownTextShadow,
                        height: 1,
                      ),
                    ).animate().slide(delay: .5.seconds).fade().addRepaintBoundary(),
                  ),
                  SizedBox(height: isPortrait ? 1.vh : 2.vh),
                  Flexible(
                    flex: 2,
                    child: StreamBuilder(
                      stream: _countdownStream,
                      builder: (context, snapshot) {
                        // For normal mode, we need to update the remaining time on each tick
                        if (!widget.isDebug) {
                          final now = mosqueManager.mosqueDate();
                          _remainingTime = _targetIqamaTime.difference(now);

                          if (_remainingTime <= Duration.zero) {
                            Future.delayed(Duration(milliseconds: 80), widget.onDone);
                          }
                        }

                        // Format the remaining time into a string
                        final minutes = _remainingTime.inMinutes;
                        final seconds = _remainingTime.inSeconds % 60;
                        final formattedTime = timeTwoDigit(
                          seconds: seconds,
                          minutes: minutes,
                        );

                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 35.vw,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: kIqamaCountDownTextShadow,
                              height: 1,
                            ),
                          ).animate().fadeIn(delay: .7.seconds, duration: 2.seconds).addRepaintBoundary(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            mosqueManager.times!.isTurki
                ? ResponsiveMiniSalahBarTurkishWidget(useCompactLayout: true)
                : ResponsiveMiniSalahBarWidget(useCompactLayout: true),
            if (mosqueManager.flashEnabled && mosqueManager.mosque?.flash != null) ...[
              if (isPortrait) SizedBox(height: 1.vh),
              isPortrait ? PortraitFooterWidget(mosque: mosqueManager.mosque!) : Footer(),
            ],
          ],
      ),
    );
  }
}
