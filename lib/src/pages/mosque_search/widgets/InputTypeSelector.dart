import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:mawaqit/src/pages/mosque_search/widgets/chromecast_mosque_input_search.dart';
import 'package:mawaqit/src/pages/mosque_search/widgets/MosqueInputId.dart';
import 'package:mawaqit/src/pages/mosque_search/widgets/MosqueInputSearch.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/toggle_button_widget.dart';
import 'package:page_transition/page_transition.dart';
import 'package:sizer/sizer.dart';

import '../../../../i18n/l10n.dart';
import '../../../helpers/Api.dart';
import 'package:mawaqit/src/state_management/on_boarding/on_boarding.dart';
import 'chromecast_mosque_input_id.dart';
import 'package:mawaqit/src/state_management/device_info/device_info_notifier.dart';

class InputTypeSelector extends ConsumerStatefulWidget {
  const InputTypeSelector({
    required this.nextButtonFocusNode,
    super.key,
    this.onDone,
    this.isOnboarding = false,
  });

  final void Function()? onDone;
  final fp.Option<FocusNode> nextButtonFocusNode;
  final bool isOnboarding;

  @override
  _InputTypeSelectorState createState() => _InputTypeSelectorState();
}

class _InputTypeSelectorState extends ConsumerState<InputTypeSelector> {
  bool _hasSelectedYes = false;
  bool _hasSelectedNo = false;

  @override
  void initState() {
    super.initState();
    // Only auto-select and navigate during onboarding
    if (widget.isOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleYesSelection();
      });
    }
  }

  bool get _isPhone {
    final deviceInfo = ref.watch(deviceInfoProvider);
    final isTV = deviceInfo.valueOrNull?.isBoxOrAndroidTV ?? false;
    if (isTV) return false;
    return MediaQuery.of(context).size.shortestSide < 480;
  }

  void _handleYesSelection() {
    setState(() {
      _hasSelectedYes = true;
      _hasSelectedNo = false;
    });

    widget.nextButtonFocusNode.fold(
      () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            alignment: Alignment.center,
            child: _isPhone
                ? MosqueInputId(
                    onDone: widget.onDone,
                    isOnboarding: widget.isOnboarding,
                  )
                : ChromeCastMosqueInputId(
                    onDone: widget.onDone,
                    isOnboarding: widget.isOnboarding,
                  ),
          ),
        );
      },
      (focus) {
        Future.delayed(Duration(milliseconds: 300), () {
          if (focus.canRequestFocus) {
            focus.requestFocus();
          }
        });
      },
    );
    ref.read(mosqueInputTypeSelectorProvider.notifier).state = SelectionType.mosqueId;
  }

  void _handleNoSelection() {
    setState(() {
      _hasSelectedYes = false;
      _hasSelectedNo = true;
    });

    widget.nextButtonFocusNode.fold(
      () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            alignment: Alignment.center,
            child: _isPhone
                ? MosqueInputSearch(
                    onDone: widget.onDone,
                    isOnboarding: widget.isOnboarding,
                  )
                : ChromeCastMosqueInputSearch(
                    onDone: widget.onDone,
                    isOnboarding: widget.isOnboarding,
                  ),
          ),
        );
      },
      (focus) {
        Future.delayed(Duration(milliseconds: 300), () {
          if (focus.canRequestFocus) {
            focus.requestFocus();
          }
        });
      },
    );
    ref.read(mosqueInputTypeSelectorProvider.notifier).state = SelectionType.mosqueName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    // Adjust font sizes based on orientation
    final double headerFontSize = isPortrait ? 11.sp : 14.sp;
    final double buttonFontSize = isPortrait ? 8.sp : 12.sp;

    // Adjust width factor based on orientation
    final double widthFactor = isPortrait ? 0.9 : 0.75;

    return Material(
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header section
            _buildHeader(theme, headerFontSize),
            SizedBox(height: isPortrait ? 0.h : 2.h),

            // Options section
            _buildOptions(
              theme: theme,
              buttonFontSize: buttonFontSize,
              isPortrait: isPortrait,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    double headerFontSize,
  ) {
    return Column(
      children: [
        AutoSizeText(
          S.of(context).doYouKnowMosqueId,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: headerFontSize,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildOptions({
    required ThemeData theme,
    required double buttonFontSize,
    required bool isPortrait,
  }) {
    return Column(
      children: [
        _buildOption(
          theme: theme,
          isSelected: _hasSelectedYes,
          onToggle: _handleYesSelection,
          label: S.of(context).yes,
          buttonFontSize: buttonFontSize,
          isPortrait: isPortrait,
        ),
        SizedBox(height: isPortrait ? 2 : 2.h),
        _buildOption(
          theme: theme,
          isSelected: _hasSelectedNo,
          onToggle: _handleNoSelection,
          label: S.of(context).no,
          buttonFontSize: buttonFontSize,
          isPortrait: isPortrait,
        ),
      ],
    );
  }

  Widget _buildOption({
    required ThemeData theme,
    required bool isSelected,
    required VoidCallback onToggle,
    required String label,
    required double buttonFontSize,
    required bool isPortrait,
  }) {
    return ToggleButtonWidget(
      isSelected: isSelected,
      onPressed: onToggle,
      label: label,
      textStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: buttonFontSize,
        height: 1.2,
      ),
      isPortrait: isPortrait,
    );
  }
}

enum SelectionType {
  mosqueId,
  mosqueName,
}

final mosqueInputTypeSelectorProvider = StateProvider<SelectionType>((ref) {
  return SelectionType.mosqueId;
});
