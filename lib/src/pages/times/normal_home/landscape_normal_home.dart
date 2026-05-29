import 'dart:developer';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/AppDate.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/pages/home/widgets/TimeWidget.dart';
import 'package:mawaqit/src/pages/home/widgets/footer.dart';
import 'package:mawaqit/src/pages/home/widgets/mosque_header.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/SalahItem.dart';
import 'package:mawaqit/src/pages/times/widgets/jumua_widget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:provider/provider.dart';

import '../../../../i18n/AppLanguage.dart';
import '../../../../main.dart';
import '../../../services/user_preferences_manager.dart';
import '../../../state_management/app_update/app_update_notifier.dart';
import '../../../state_management/app_update/app_update_state.dart';
import '../../../widgets/show_update_alert.dart';
import '../../home/widgets/FadeInOut.dart';

class LandscapeNormalHome extends riverpod.ConsumerStatefulWidget {
  const LandscapeNormalHome({super.key});

  @override
  riverpod.ConsumerState createState() => _LandscapeNormalHomeState();
}

class _LandscapeNormalHomeState extends riverpod.ConsumerState<LandscapeNormalHome> {
  String salahName(int index) {
    switch (index) {
      case 0:
        return S.current.fajr;
      case 1:
        return S.current.duhr;
      case 2:
        return S.current.asr;
      case 3:
        return S.current.maghrib;
      case 4:
        return S.current.isha;
      default:
        return '';
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mosque = Provider.of<MosqueManager>(context, listen: false);
      ref.read(appUpdateProvider.notifier).startUpdateScheduler(
            mosque,
            context.read<AppLanguage>().appLocal.languageCode,
            context,
          );
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, (previous, next) {
      if (next.hasValue && !next.isReloading && next.value!.appUpdateStatus == AppUpdateStatus.updateAvailable) {
        log('update available ${next.value} || ${next.isReloading} || ${next.isLoading} || ${next.hasValue}');
        showUpdateAlert(
          context: context,
          duration: Duration(minutes: 5),
          content: next.value!.releaseNote,
          title: next.value!.message,
          onPressed: () => ref.read(appUpdateProvider.notifier).openStore(),
          onDismissPressed: () => ref.read(appUpdateProvider.notifier).dismissUpdate(),
        );
      }
    });

    final mosqueManager = context.watch<MosqueManager>();
    final fontScale = context.watch<UserPreferencesManager>().appFontSizeScale;
    final today = mosqueManager.useTomorrowTimes ? AppDateTime.tomorrow() : AppDateTime.now();

    final times = mosqueManager.times!.dayTimesStrings(today);
    final iqamas = mosqueManager.times!.dayIqamaStrings(today);

    final isIqamaMoreImportant = mosqueManager.mosqueConfig!.iqamaMoreImportant == true;
    final iqamaEnabled = mosqueManager.mosqueConfig?.iqamaEnabled == true;

    final nextActiveSalah = mosqueManager.mosqueConfig!.iqamaMoreImportant == true
        ? mosqueManager.nextSalahAfterIqamaIndex()
        : mosqueManager.nextSalahIndex();

    // Bottom salah row's flex grows with fontScale so the 5 prayer cards have
    // physical room to render larger. Without this, FittedBox(scaleDown) inside
    // SalahItemWidget would scale the bigger fonts back down to fit a fixed card.
    // Middle stays at 30; bottom goes 19→20→21→22. Growth is intentionally
    // gentle: aggressive bottom growth squeezes the middle row's "Salah in"
    // countdown into a vertical overflow at scale 1.2.
    final bottomRowFlex = (20 + (fontScale - 1.0) * 10).round();

    return Column(
      children: [
        MosqueHeader(mosque: mosqueManager.mosque!),
        Expanded(
          flex: 30,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Center(
                  child: FadeInOutWidget(
                    duration: Duration(seconds: 15),
                    disableSecond: mosqueManager.isImsakEnabled == false,
                    first: SalahItemWidget(
                      removeBackground: true,
                      title: S.of(context).shuruk,
                      time: mosqueManager.getShurukTimeString() ?? '',
                      isIqamaMoreImportant: mosqueManager.mosqueConfig!.iqamaMoreImportant == true,
                    ),
                    secondDuration: Duration(seconds: 15),
                    second: SalahItemWidget(
                      title: S.of(context).imsak,
                      time: mosqueManager.imsak ?? "",
                      removeBackground: true,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                // Guard against vertical overflow on short panels: the bottom prayer row
                // grows with fontScale (shrinking this slot) while the clock's text grows.
                // FittedBox scales the clock down only if it would overflow; on tall panels
                // (e.g. the demoed 1920x1080) it is a no-op and the clock renders at full size.
                child: LayoutBuilder(
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: HomeTimeWidget().animate().fadeIn().slideY(begin: -1),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child:
                    Center(child: JumuaWidget().animate(delay: Duration(milliseconds: 500)).slideX(begin: 1).fadeIn()),
              ),
            ],
          ),
        ),
        Expanded(
          flex: bottomRowFlex,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.vw),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  SalahItemWidget(
                    title: salahName(i),
                    time: times[i],
                    iqama: iqamas[i],
                    withDivider: false,
                    showIqama: iqamaEnabled,
                    active:
                        nextActiveSalah == i && (i != 1 || !AppDateTime.isFriday || mosqueManager.times?.jumua == null),
                    isIqamaMoreImportant: isIqamaMoreImportant,
                  ),
              ]
                  .mapIndexed((i, e) => Expanded(
                          child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1.vw),
                        child: e.animate(delay: Duration(milliseconds: 100 * i)).slideY(begin: 1).fadeIn(),
                      )))
                  .toList(),
            ),
          ),
        ),
        Footer().animate().fade().slideY(begin: 1),
      ],
    );
  }
}
