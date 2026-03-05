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
import 'package:mawaqit/src/pages/home/sub_screens/iqamaa_time_widget.dart';
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
  late DateTime _targetIqamaTime;
  late final MosqueManager _mosqueManager;
  late final Stream<int> _countdownStream;
  Timer? _onDoneTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _mosqueManager = context.read<MosqueManager>();
    _countdownStream = Stream.periodic(const Duration(seconds: 1), (count) => count);
    _initializeCountdown();
  }

  void _initializeCountdown() {
    if (widget.isDebug) {
      _targetIqamaTime = DateTime.now().add(const Duration(minutes: 5));
      _scheduleOnDoneCallback(const Duration(minutes: 5));
    } else {
      _targetIqamaTime = _calculateTargetIqamaTime();
      final now = _mosqueManager.mosqueDate();
      final remainingTime = _targetIqamaTime.difference(now);
      _scheduleOnDoneCallback(remainingTime);
    }
  }

  DateTime _calculateTargetIqamaTime() {
    if (widget.iqamaTime != null) {
      return widget.iqamaTime!;
    }

    var currentSalahTime = _mosqueManager.actualTimes()[widget.currentSalahIndex];
    var currentIqamaTime = _mosqueManager.actualIqamaTimes()[widget.currentSalahIndex];

    if (currentIqamaTime.isBefore(currentSalahTime)) {
      currentIqamaTime = currentIqamaTime.add(const Duration(days: 1));
    }
    return currentIqamaTime;
  }

  void _scheduleOnDoneCallback(Duration delay) {
    if (delay <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) widget.onDone?.call();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onDoneTimer = Timer(delay, () {
        if (!_isDisposed) widget.onDone?.call();
      });
    });
  }

  Duration _calculateRemainingTime() {
    if (widget.isDebug) {
      return _targetIqamaTime.difference(DateTime.now());
    }
    return _targetIqamaTime.difference(_mosqueManager.mosqueDate());
  }

  String _formatRemainingTime() {
    final remaining = _calculateRemainingTime();
    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) widget.onDone?.call();
      });
      return "00:00";
    }
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return timeTwoDigit(seconds: seconds, minutes: minutes);
  }

  Widget _buildCountdownText({required double fontSize}) {
    return StreamBuilder(
      stream: _countdownStream,
      builder: (context, snapshot) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatRemainingTime(),
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: kIqamaCountDownTextShadow,
              height: 1,
            ),
          ).animate().fadeIn(delay: .7.seconds, duration: 2.seconds).addRepaintBoundary(),
        );
      },
    );
  }

  Widget _buildSalahBar() {
    return _mosqueManager.times!.isTurki
        ? const ResponsiveMiniSalahBarTurkishWidget(useCompactLayout: true)
        : const ResponsiveMiniSalahBarWidget(useCompactLayout: true);
  }

  Widget _buildHeaderRow({EdgeInsets? padding}) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          OfflineWidget(),
          Directionality(
            textDirection: TextDirection.ltr,
            child: WeatherWidget(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _onDoneTimer?.cancel();

    // Hide flash when transitioning to IqamaSubScreen (phone flash screen)
    _mosqueManager.hideFlashTemporarily();

    super.dispose();
  }

  /// Check if the screen is standard resolution (1920x1080 or less)
  bool _isStandardResolution(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width <= 1920 && size.height <= 1080;
  }

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.read<MosqueManager>();

    if (mosqueManager.mosqueConfig?.iqamaFullScreenCountdown == false) return const NormalHomeSubScreen();

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    // Portrait always uses new layout; landscape uses new for standard res, old for high res
    if (isPortrait || _isStandardResolution(context)) {
      return _buildNewLayout(context, mosqueManager);
    } else {
      return _buildOldLayout(context, mosqueManager);
    }
  }

  /// Old layout for high resolution screens (larger than 1920x1080)
  Widget _buildOldLayout(BuildContext context, MosqueManager mosqueManager) {
    final tr = S.of(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return SafeArea(
      child: Column(
        children: [
          _buildHeaderRow(padding: EdgeInsets.symmetric(horizontal: 1.vw, vertical: 1.vh)),

          // Clock Widget - compact version without redundant black box
          Container(
            height: 20.vh,
            alignment: Alignment.center,
            child: const IqamaaTimeWidget(hideSeconds: true),
          ),

          // Main countdown section - takes up available space
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    tr.iqamaIn,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 400 ? 6.vwr : 7.vwr,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: kIqamaCountDownTextShadow,
                      height: 1,
                    ),
                  ).animate().slide(delay: .5.seconds).fade().addRepaintBoundary(),
                ),
                SizedBox(height: 1.vh),
                Flexible(
                  flex: 2,
                  child: _buildCountdownText(fontSize: 35.vw),
                ),
              ],
            ),
          ),
          _buildSalahBar(),
          if (mosqueManager.flashEnabled && mosqueManager.mosque?.flash != null) ...[
            if (isPortrait) SizedBox(height: 1.vh),
            isPortrait ? PortraitFooterWidget(mosque: mosqueManager.mosque!) : const Footer(),
          ],
        ],
      ),
    );
  }

  /// New layout for standard resolution screens (1920x1080 or less)
  Widget _buildNewLayout(BuildContext context, MosqueManager mosqueManager) {
    final tr = S.of(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return SafeArea(
      child: Column(
        children: [
          _buildHeaderRow(padding: EdgeInsets.symmetric(horizontal: 1.vw, vertical: 1.5.vh)),

          SizedBox(height: isPortrait ? 0.5.vh : 1.5.vh),

          // Clock Widget - Using custom widget for landscape mode
          _buildClockWidget(isPortrait),

          SizedBox(height: isPortrait ? 1.vh : 4.vh),

          // Main countdown section - takes up available space
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr.iqamaIn,
                  style: TextStyle(
                    fontSize: isPortrait ? (MediaQuery.of(context).size.width < 400 ? 6.vwr : 5.vwr) : 6.5.vwr,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: kIqamaCountDownTextShadow,
                    height: 1,
                  ),
                ).animate().slide(delay: .5.seconds).fade().addRepaintBoundary(),
                SizedBox(height: isPortrait ? 1.vh : 2.5.vh),
                Flexible(
                  child: Center(
                    child: _buildCountdownText(fontSize: isPortrait ? 35.vw : 13.vw),
                  ),
                ),
              ],
            ),
          ),
          _buildSalahBar(),
          if (mosqueManager.flashEnabled && mosqueManager.mosque?.flash != null) ...[
            if (isPortrait) SizedBox(height: 1.vh),
            isPortrait ? PortraitFooterWidget(mosque: mosqueManager.mosque!) : const Footer(),
          ],
        ],
      ),
    );
  }

  Widget _buildClockWidget(bool isPortrait) {
    if (isPortrait) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 1.vw),
        child: Container(
          height: 20.vh,
          alignment: Alignment.center,
          child: const HomeTimeWidget(
            showSalahIn: false,
            showOuterBackground: false,
            hideSeconds: true,
            hideBackground: true,
          ),
        ),
      );
    }
    return Container(
      height: 20.vh,
      alignment: Alignment.center,
      child: const IqamaaTimeWidget(hideSeconds: true),
    );
  }
}
