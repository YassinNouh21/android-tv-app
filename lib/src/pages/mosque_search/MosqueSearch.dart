import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:mawaqit/src/pages/mosque_search/widgets/InputTypeSelector.dart';
import 'package:mawaqit/src/pages/mosque_search/widgets/MosqueInputSearch.dart';

class MosqueSearch extends StatefulWidget {
  MosqueSearch({
    Key? key,
    required this.nextButtonFocusNode,
    this.onDone,
    this.isOnboarding = false,
    this.noFocusNode,
  }) : super(key: key);

  final void Function()? onDone;
  final fp.Option<FocusNode> nextButtonFocusNode;
  final bool isOnboarding;

  /// External focus node for the "No" option (onboarding nav-bar Up target).
  final FocusNode? noFocusNode;

  @override
  State<MosqueSearch> createState() => _MosqueSearchState();
}

class _MosqueSearchState extends State<MosqueSearch> {
  final navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Onboarding: skip the Navigator so buttons share a scope with the video.
    if (widget.isOnboarding) {
      return InputTypeSelector(
        onDone: widget.onDone,
        nextButtonFocusNode: widget.nextButtonFocusNode,
        isOnboarding: widget.isOnboarding,
        noFocusNode: widget.noFocusNode,
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (navKey.currentState!.canPop()) {
          navKey.currentState!.pop();
          return false;
        }
        return true;
      },
      child: Navigator(
        key: navKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => InputTypeSelector(
            onDone: widget.onDone,
            nextButtonFocusNode: widget.nextButtonFocusNode,
            isOnboarding: widget.isOnboarding,
            noFocusNode: widget.noFocusNode,
          ),
        ),
      ),
    );
  }
}
