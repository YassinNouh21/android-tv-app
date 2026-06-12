import 'package:flutter/material.dart';
import 'package:mawaqit_tv_l10n/mawaqit_tv_l10n.dart';
import 'package:mawaqit/const/resource.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/AppDate.dart';
import 'package:mawaqit/src/helpers/RelativeSizes.dart';
import 'package:mawaqit/src/pages/home/widgets/AboveSalahBar.dart';
import 'package:mawaqit/src/widgets/display_text_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/responsive_mini_salah_bar_widget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/widgets/time_widget.dart';
import 'package:provider/provider.dart';

import '../widgets/salah_items/responsive_mini_salah_bar_turkish_widget.dart';

class _JumuaCenteredClock extends StatelessWidget {
  const _JumuaCenteredClock();

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.watch<MosqueManager>();
    final is12Hours = mosqueManager.mosqueConfig?.timeDisplayFormat == '12';

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final now = AppDateTime.now();
        return Center(
          child: TimeWidget.fromDate(
            dateTime: now,
            show24hFormat: !is12Hours,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 30.vw,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}

class JumuaHadithSubScreen extends StatelessWidget {
  const JumuaHadithSubScreen({Key? key, this.onDone}) : super(key: key);

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final mosqueConfig = context.read<MosqueManager>().mosqueConfig;
    final tr = S.of(context);
    final jumuaArHadith = MawaqitTvLocalizationsAr().jumuaaHadith;

    if (!mosqueConfig!.jumuaDhikrReminderEnabled!) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: _JumuaCenteredClock(),
      );
    }
    final mosqueProvider = context.read<MosqueManager>();

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(R.ASSETS_BACKGROUNDS_ISLAMIC_CONTENT_BACKGROUND_WEBP),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: AboveSalahBar(),
          ),
          Expanded(
            child: DisplayTextWidget(
              title: tr.jumuaaScreenTitle,
              arabicText: jumuaArHadith,
              translatedText: tr.jumuaaHadith,
              mainAxisAlignment: MainAxisAlignment.start,
            ),
          ),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: mosqueProvider.times!.isTurki
                  ? ResponsiveMiniSalahBarTurkishWidget(activeItem: 1)
                  : ResponsiveMiniSalahBarWidget(activeItem: 1)),
        ],
      ),
    );
  }
}
