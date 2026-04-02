import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/state_management/quran/recite/recite_notifier.dart';
import 'package:mawaqit/src/state_management/quran/quran/quran_notifier.dart';
import 'package:sizer/sizer.dart';

enum QuranErrorType { reciter, surah }

class ReciterErrorWidget extends ConsumerStatefulWidget {
  final Object error;
  final FocusNode focusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;
  final QuranErrorType errorType;
  final VoidCallback? onRetry;

  const ReciterErrorWidget({
    super.key,
    required this.error,
    required this.focusNode,
    this.onNavigateUp,
    this.onNavigateDown,
    this.errorType = QuranErrorType.reciter,
    this.onRetry,
  });

  @override
  ConsumerState<ReciterErrorWidget> createState() => _ReciterErrorWidgetState();
}

class _ReciterErrorWidgetState extends ConsumerState<ReciterErrorWidget> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKey = _handleKeyEvent;
    widget.focusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.onNavigateUp != null) {
        widget.onNavigateUp!();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && widget.onNavigateDown != null) {
        widget.onNavigateDown!();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _handleRetry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
    } else {
      if (widget.errorType == QuranErrorType.reciter) {
        ref.invalidate(reciteNotifierProvider);
      } else {
        ref.invalidate(quranNotifierProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 25.sp,
            ),
            SizedBox(height: 2.h),
            Text(
              widget.errorType == QuranErrorType.reciter
                  ? S.of(context).reciterLoadError
                  : S.of(context).surahLoadError,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              S.of(context).reciterNetworkError,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.sp,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              focusNode: widget.focusNode,
              autofocus: true,
              onPressed: _handleRetry,
              icon: Icon(Icons.refresh, size: 10.sp),
              label: Text(
                S.of(context).retry,
                style: TextStyle(fontSize: 10.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFocused ? Theme.of(context).primaryColor : Colors.grey.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 4.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
