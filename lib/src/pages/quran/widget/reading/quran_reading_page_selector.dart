import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/state_management/quran/reading/quran_reading_notifer.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sizer/sizer.dart';

class QuranReadingPageSelector extends ConsumerStatefulWidget {
  final int totalPages;
  final int currentPage;
  final bool isPortrait;

  const QuranReadingPageSelector({
    required this.totalPages,
    required this.currentPage,
    required this.isPortrait,
  });

  @override
  ConsumerState createState() => _QuranReadingPageSelectorState();
}

class _QuranReadingPageSelectorState extends ConsumerState<QuranReadingPageSelector> {
  final AutoScrollController _scrollController = AutoScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.scrollToIndex(
        widget.currentPage,
        preferPosition: AutoScrollPosition.middle,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isActuallyPortrait {
    final deviceOrientation = MediaQuery.of(context).orientation;
    return (deviceOrientation == Orientation.portrait && !widget.isPortrait) ||
        (deviceOrientation == Orientation.landscape && widget.isPortrait);
  }

  int get _crossAxisCount => _isActuallyPortrait ? 4 : 6;

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
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _crossAxisCount,
              childAspectRatio: 3 / 2,
            ),
            itemCount: widget.totalPages,
            itemBuilder: (BuildContext context, int index) {
              final isSelected = index == widget.currentPage;
              return AutoScrollTag(
                key: ValueKey(index),
                controller: _scrollController,
                index: index,
                child: InkWell(
                  onTap: () {
                    ref.read(quranReadingNotifierProvider.notifier).updatePage(
                          index,
                          isPortairt: _isActuallyPortrait,
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
