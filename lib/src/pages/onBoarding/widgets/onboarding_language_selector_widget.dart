import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mawaqit/i18n/AppLanguage.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/LocaleHelper.dart';
import 'package:mawaqit/src/helpers/mawaqit_icons_icons.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    Key? key,
    required this.onSelect,
    required this.isSelected,
    required this.languages,
    this.title = "",
    this.description = "",
    this.isIconActivated = true,
  }) : super(key: key);

  /// Called when user selects a language
  final void Function(String) onSelect;

  /// List of language codes
  final List<String> languages;

  /// Controls whether to show language icons
  final bool isIconActivated;

  /// Title displayed at the top of the screen
  final String title;

  /// Description of the screen purpose
  final String description;

  /// Function to determine if a language is selected
  final bool Function(String) isSelected;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Column(
      children: [
        SizedBox(height: 1.h),

        // Title section
        _buildTitleSection(context, themeData),
        SizedBox(height: 1.5.h),

        // Language list section
        _buildLanguageListSection(context),
      ],
    );
  }

  /// Builds the title and description section
  Widget _buildTitleSection(BuildContext context, ThemeData themeData) {
    return Column(
      children: [
        Text(
          title.isEmpty ? S.of(context).appLang : title,
          style: TextStyle(
            fontSize: 16.sp, // Responsive font size
            fontWeight: FontWeight.w700,
            color: themeData.brightness == Brightness.dark ? null : themeData.primaryColor,
          ),
        ).animate().slideY().fade(),
        SizedBox(height: 0.5.h),
        Text(
          description.isEmpty ? S.of(context).descLang : description,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10.sp, // Responsive font size
            color: themeData.brightness == Brightness.dark ? null : themeData.primaryColor,
          ),
        ).animate().slideX(begin: .5).fade(),
      ],
    );
  }

  /// Builds the scrollable language list
  Widget _buildLanguageListSection(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.only(top: 1.h),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(
            vertical: 0.5.h,
            horizontal: 2.w,
          ),
          itemCount: languages.length,
          itemBuilder: (BuildContext context, int index) {
            final Locale locale = LocaleHelper.splitLocaleCode(languages[index]);
            return LanguageTile(
              onTap: () => onSelect(LocaleHelper.transformLocaleToString(locale)),
              locale: locale,
              isSelected: isSelected(LocaleHelper.transformLocaleToString(locale)),
              isIconActivated: isIconActivated,
            );
          },
        ),
      ),
    );
  }
}

class LanguageTile extends StatefulWidget {
  const LanguageTile({
    Key? key,
    required this.locale,
    required this.onTap,
    this.isIconActivated = true,
    this.isSelected = false,
  }) : super(key: key);

  final bool isIconActivated;
  final Locale locale;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<LanguageTile> {
  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final appLanguage = Provider.of<AppLanguage>(context);

    return Material(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 1.w,
          vertical: 0.5.h,
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: widget.isSelected ? themeData.focusColor : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              widget.onTap();
              setState(() {});
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 4.w,
                vertical: 1.5.h,
              ),
              child: Row(
                children: [
                  if (widget.isIconActivated)
                    Padding(
                      padding: EdgeInsets.only(right: 3.w),
                      child: flagIcon(
                        LocaleHelper.transformLocaleToString(widget.locale),
                        size: 22.sp,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      appLanguage.combinedLanguageName(
                        LocaleHelper.transformLocaleToString(widget.locale),
                        context: context,
                      ),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.normal,
                        color: widget.isSelected ? Colors.white : null,
                      ),
                    ),
                  ),
                  if (widget.isSelected)
                    Icon(
                      MawaqitIcons.icon_checked,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget flagIcon(String languageCode, {double? size}) {
    final s = size ?? 16.0.sp;
    final themeData = Theme.of(context);

    if (languageCode == 'auto') {
      return Container(
        width: s,
        height: s,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(
          Icons.sync,
          size: s * 0.45,
          color: themeData.primaryColor,
        ),
      );
    }

    // Check if it's a bilingual language code (e.g., 'fr_ar' or 'fr-ar')
    if (languageCode.contains('_') || languageCode.contains('-')) {
      final languages = languageCode.split(RegExp(r'[-_]'));

      final flagSize = s * 0.65;

      // Show both flags side by side
      return SizedBox(
        width: s * 1.4,
        height: flagSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: flagSize,
                height: flagSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/img/flag/${languages[0].toLowerCase()}.png',
                    width: flagSize,
                    height: flagSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Positioned(
              left: flagSize * 0.7,
              top: 0,
              child: Container(
                width: flagSize,
                height: flagSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/img/flag/${languages[1].toLowerCase()}.png',
                    width: flagSize,
                    height: flagSize,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Single language - show one flag
    return SizedBox(
      width: s,
      height: s,
      child: ClipOval(
        child: Image.asset(
          'assets/img/flag/${languageCode.toLowerCase()}.png',
          width: s,
          height: s,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: s,
              height: s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.3),
              ),
              child: Icon(
                Icons.language,
                size: s * 0.45,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }
}
