import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:google_fonts/google_fonts.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/main.dart';
import 'package:mawaqit/src/models/mosque.dart';
import 'package:mawaqit/src/pages/mosque_search/widgets/permission_screen_with_button.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/permissions_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/state_management/on_boarding/on_boarding.dart';
import 'package:mawaqit/src/widgets/mosque_simple_tile.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/on_boarding_permission_adhan_screen.dart';
import 'package:mawaqit/src/widgets/permissionScreenNavigator.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

import '../../../../i18n/AppLanguage.dart';
import '../../../helpers/AppRouter.dart';
import '../../../helpers/SharedPref.dart';
import '../../../state_management/random_hadith/random_hadith_notifier.dart';
import '../../home/OfflineHomeScreen.dart';

class MosqueInputId extends ConsumerStatefulWidget {
  const MosqueInputId({
    super.key,
    this.onDone,
    this.selectedNode = const fp.None(),
    this.isOnboarding = false,
  });

  final void Function()? onDone;
  final fp.Option<FocusNode> selectedNode;
  final bool isOnboarding;

  @override
  ConsumerState<MosqueInputId> createState() => _MosqueInputIdState();
}

class _MosqueInputIdState extends ConsumerState<MosqueInputId> {
  final inputController = TextEditingController();
  Mosque? searchOutput;
  SharedPref sharedPref = SharedPref();
  final FocusNode _focusNode = FocusNode(debugLabel: 'mosque_search_node');

  bool loading = false;
  String? error;
  bool isKeyboardVisible = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(mosqueManagerProvider.notifier).state = fp.None();
      _focusNode.requestFocus();
      isKeyboardVisible = true;
    });

    // Add listener to focus node to detect keyboard close
    _focusNode.addListener(_onFocusChange);

    super.initState();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && isKeyboardVisible) {
      // The focus was lost, which might indicate keyboard was closed
      isKeyboardVisible = false;

      FocusScope.of(context).focusInDirection(TraversalDirection.up);
    } else if (_focusNode.hasFocus && !isKeyboardVisible) {
      // Focus gained, keyboard likely opened
      isKeyboardVisible = true;
    }
  }

  void _setMosqueId(String mosqueId) async {
    if (mosqueId.isEmpty) {
      if (!mounted) return;
      return setState(() => error = S.of(context).missingMosqueId);
    }
    if (int.tryParse(mosqueId) == null) {
      if (!mounted) return;
      return setState(() => error = S.of(context).mosqueIdIsNotValid(mosqueId));
    }

    if (!mounted) return;
    setState(() {
      error = null;
      loading = true;
    });

    final mosqueManager = context.read<MosqueManager>();

    await mosqueManager.searchMosqueWithId(mosqueId).then((value) {
      if (!mounted) return; // Check before setState
      setState(() {
        searchOutput = value;
        loading = false;
      });
    }).catchError((e, stack) {
      debugPrintStack(stackTrace: stack, label: e.toString());
      if (!mounted) return; // Check before setState

      if (e is InvalidMosqueId) {
        setState(() {
          loading = false;
          error = S.of(context).mosqueIdIsNotValid(mosqueId);
        });
      } else {
        setState(() {
          loading = false;
          error = S.of(context).backendError;
        });
      }
    });
  }

  Future<void> _handleMosqueSelection() async {
    final mosqueManager = context.read<MosqueManager>();

    try {
      await mosqueManager.setMosqueUUid(searchOutput!.uuid.toString());

      final hadithLangCode = await context.read<AppLanguage>().getHadithLanguage(mosqueManager);
      ref.read(randomHadithNotifierProvider.notifier).fetchAndCacheHadith(language: hadithLangCode);

      // Set the mosque type in the provider
      if (searchOutput != null) {
        if (searchOutput?.type == "MOSQUE") {
          ref.read(mosqueManagerProvider.notifier).state = fp.Option.fromNullable(SearchSelectionType.mosque);
        } else {
          ref.read(mosqueManagerProvider.notifier).state = fp.Option.fromNullable(SearchSelectionType.home);
        }
      }

      if (!mounted) return; // Check before navigation/callback

      // Only check permissions if NOT in onboarding flow
/*       if (!widget.isOnboarding && searchOutput?.type != "MOSQUE") {
        await PermissionScreenNavigator.checkAndShowPermissionScreen(
          context: context,
          selectedNode: widget.selectedNode,
          onComplete: () {
            if (mounted) {
              widget.onDone?.call();
            }
          },
        );
      } else { */
      widget.onDone?.call();
      /*   } */
    } catch (e, stack) {
      if (!mounted) return; // Check before setState

      if (e is InvalidMosqueId) {
        setState(() {
          loading = false;
          error = S.of(context).slugError;
        });
      } else {
        setState(() {
          loading = false;
          error = S.of(context).backendError;
        });
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      child: Align(
        alignment: Alignment(0, -.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.of(context).selectMosqueId,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: theme.brightness == Brightness.dark ? null : theme.primaryColor,
              ),
            ),
            SizedBox(height: 10),
            buildInputWidget(context, theme),
            if (searchOutput != null)
              MosqueSimpleTile(
                key: ValueKey(searchOutput!.uuid),
                autoFocus: true,
                mosque: searchOutput!,
                selectedNode: widget.selectedNode,
                onTap: _handleMosqueSelection,
              ).animate().slideY(begin: 1).fade(),
          ],
        ),
      ),
    );
  }

  Padding buildInputWidget(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        child: TextFormField(
          focusNode: _focusNode,
          controller: inputController,
          style: GoogleFonts.inter(
            color: theme.brightness == Brightness.dark ? null : theme.primaryColor,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          onFieldSubmitted: _setMosqueId,
          cursorColor: theme.brightness == Brightness.dark ? null : theme.primaryColor,
          keyboardType: TextInputType.number,
          autofocus: true,
          textInputAction: TextInputAction.search,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp("[0-9]")),
          ],
          decoration: InputDecoration(
            filled: true,
            errorText: error,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
            hintText: S.of(context).selectWithMosqueId,
            hintStyle: TextStyle(
              fontSize: 8.sp,
              fontWeight: FontWeight.normal,
              color: theme.brightness == Brightness.dark ? null : theme.primaryColor.withOpacity(0.4),
            ),
            suffixIcon: IconButton(
              tooltip: "Search by Id",
              icon: loading ? CircularProgressIndicator() : Icon(Icons.search),
              color: theme.brightness == Brightness.dark ? Colors.white70 : theme.primaryColor,
              onPressed: () => _setMosqueId(inputController.text),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: theme.primaryColor, width: 1),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: 2,
              horizontal: 20,
            ),
          ),
        ),
      ),
    );
  }
}
