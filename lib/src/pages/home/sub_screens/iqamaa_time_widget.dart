import 'package:flutter/material.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/pages/home/widgets/CurrentTimeWidget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:provider/provider.dart';
import 'package:timeago_flutter/timeago_flutter.dart';

import 'package:mawaqit/src/pages/home/widgets/HomeDateWidget.dart';

/// Custom TimeWidget specifically for IqamaaCountDownSubScreen
/// This widget has enhanced visibility and custom sizing for the iqamaa countdown screen
class IqamaaTimeWidget extends TimerRefreshWidget {
  const IqamaaTimeWidget({
    super.key,
    this.hideSeconds = false,
    super.refreshRate = const Duration(seconds: 1),
  });

  final bool hideSeconds;

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.watch<MosqueManager>();

    final timeContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CurrentTimeWidget(hideSeconds: hideSeconds),
        SizedBox(height: 0.5.vh),
        HomeDateWidget(),
      ],
    );

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 1.vwr),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Color.lerp(Colors.black, mosqueManager.getColorTheme(), 0.9)!.withOpacity(.7),
                backgroundBlendMode: BlendMode.screen,
              ),
              padding: EdgeInsets.symmetric(vertical: 1.5.vw, horizontal: 5.vw),
              child: timeContent,
            ),
          ),
        ),
      ),
    );
  }
}
