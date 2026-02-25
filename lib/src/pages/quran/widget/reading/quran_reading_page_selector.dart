import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/state_management/quran/reading/quran_reading_notifer.dart';
import 'package:sizer/sizer.dart';

class QuranReadingPageSelector extends ConsumerStatefulWidget {
  final int totalPages;
  final int currentPage;
  final bool isPortrait;
  final ScrollController scrollController;

  const QuranReadingPageSelector({
    required this.totalPages,
    required this.currentPage,
    required this.scrollController,
    required this.isPortrait,
  });

  @override
  ConsumerState createState() => _QuranReadingPageSelectorState();
}

class _QuranReadingPageSelectorState extends ConsumerState<QuranReadingPageSelector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Optional: Add scroll to current page logic if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final needsRotation = widget.isPortrait && size.width > size.height;

    return RotatedBox(
      quarterTurns: needsRotation ? -1 : 0,
      child: AlertDialog(
        title: SizedBox(
          width: double.maxFinite,
          child: Text(
            S.of(context).chooseQuranPage,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          height: 60.h,
          child: GridView.builder(
            controller: widget.scrollController,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.isPortrait ? 4 : 6,
              childAspectRatio: 3 / 2,
            ),
            itemCount: widget.totalPages,
            itemBuilder: (BuildContext context, int index) {
              final isSelected = index == widget.currentPage;
              return InkWell(
                onTap: () {
                  ref.read(quranReadingNotifierProvider.notifier).updatePage(
                        index,
                        isPortairt: widget.isPortrait,
                      );
                  Navigator.of(context).pop();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).focusColor : null,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.bold : null,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
