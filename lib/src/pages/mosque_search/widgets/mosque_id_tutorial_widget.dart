import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/main.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sizer/sizer.dart';
import 'package:mawaqit/src/widgets/safe_youtube_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class MosqueIdTutorialWidget extends StatelessWidget {
  const MosqueIdTutorialWidget({super.key});

  static const _tutorialVideoId = 'PPrybo_ASR0';

  Future<void> _openVideoDialog(BuildContext context) async {
    final controller = YoutubePlayerController(
      initialVideoId: _tutorialVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: true,
        enableCaption: false,
      ),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _TutorialVideoDialog(controller: controller),
      );
    } catch (e, st) {
      logger.e('Failed to open tutorial video dialog', error: e, stackTrace: st);
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final s = S.of(context);

    final accentColor = isDark ? Colors.white : theme.primaryColor;
    final subtleColor = isDark ? Colors.white70 : theme.primaryColor.withOpacity(0.7);

    final steps = [
      _StepItem(icon: Icons.language, text: s.tutorialStep1),
      _StepItem(icon: Icons.mosque, text: s.tutorialStep2),
      _StepItem(icon: Icons.pin, text: s.tutorialStep3),
      _StepItem(icon: Icons.tv, text: s.tutorialStep4),
    ];

    final userPrefs = context.watch<UserPreferencesManager>();
    final isPortrait = userPrefs.calculatedOrientation == Orientation.portrait;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableH = constraints.maxHeight;
        // Treat screens taller than 480px in landscape as "large TV"
        final isLargeTV = !isPortrait && availableH > 480;

        final stepFontSize = isPortrait ? 8.5.sp : (isLargeTV ? 8.sp : 6.sp);
        final titleFontSize = isPortrait ? 11.sp : (isLargeTV ? 11.sp : 10.sp);
        final subtitleFontSize = isPortrait ? 8.sp : (isLargeTV ? 8.sp : 7.sp);
        final scanTitleFontSize = isPortrait ? 9.sp : (isLargeTV ? 10.sp : 9.sp);
        final scanDescFontSize = isPortrait ? 7.5.sp : (isLargeTV ? 8.sp : 7.sp);
        final fullTutorialFontSize = isPortrait ? 10.sp : (isLargeTV ? 9.sp : 7.sp);
        final iconSize = isLargeTV ? 28.0 : 22.0;
        final iconInnerSize = isLargeTV ? 16.0 : 12.0;
        final qrSize = isPortrait ? 60.0 : (isLargeTV ? 95.0 : 75.0);
        final stepSpacing = isPortrait ? 3.0 : (isLargeTV ? 8.0 : 5.0);
        final sectionSpacing = isPortrait ? 4.0 : (isLargeTV ? 12.0 : 8.0);
        final videoMaxHeight = availableH * (isPortrait ? 0.15 : (isLargeTV ? 0.32 : 0.25));

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isPortrait ? 16 : 24,
            vertical: isPortrait ? 0 : 4,
          ),
          child: Column(
            mainAxisAlignment: isPortrait ? MainAxisAlignment.start : MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.tutorialGetStarted,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              Text(
                s.tutorialDontHaveId,
                style: TextStyle(
                  fontSize: subtitleFontSize,
                  color: subtleColor,
                ),
              ),
              SizedBox(height: sectionSpacing),
              ...List.generate(steps.length, (i) {
                final step = steps[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: stepSpacing),
                  child: Row(
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(isDark ? 0.3 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Icon(step.icon, size: iconInnerSize, color: accentColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: s.tutorialStep('${i + 1}'),
                                style: TextStyle(
                                  fontSize: stepFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              TextSpan(
                                text: step.text,
                                style: TextStyle(
                                  fontSize: stepFontSize,
                                  color: subtleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              Divider(color: subtleColor.withOpacity(0.3), height: sectionSpacing * 1.5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: QrImageView(
                      padding: EdgeInsets.zero,
                      data: 'https://mawaqit.net/en/backoffice/register/',
                      version: QrVersions.auto,
                      size: qrSize,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.tutorialScanToRegister,
                          style: TextStyle(
                            fontSize: scanTitleFontSize,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.tutorialScanDescription,
                          style: TextStyle(
                            fontSize: scanDescFontSize,
                            color: subtleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(color: subtleColor.withOpacity(0.3), height: sectionSpacing * 1.5),
              Center(
                child: Text(
                  s.tutorialFullTutorial,
                  style: TextStyle(
                    fontSize: fullTutorialFontSize,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
              SizedBox(height: sectionSpacing * 0.5),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: videoMaxHeight),
                child: _buildVideoThumbnail(context, theme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoThumbnail(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: () => _openVideoDialog(context),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.select) {
            _openVideoDialog(context);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFocused ? theme.primaryColor : Colors.white24,
                  width: isFocused ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: 'https://img.youtube.com/vi/$_tutorialVideoId/0.jpg',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, size: 40, color: Colors.white54),
                        ),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TutorialVideoDialog extends StatelessWidget {
  final YoutubePlayerController controller;

  const _TutorialVideoDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: SafeYoutubePlayer(
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem {
  final IconData icon;
  final String text;

  const _StepItem({required this.icon, required this.text});
}
