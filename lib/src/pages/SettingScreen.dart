import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:fpdart/fpdart.dart' hide State;

import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/const/constants.dart';
import 'package:mawaqit/src/data/data_source/device_info_data_source.dart';
import 'package:mawaqit/src/helpers/AppRouter.dart';
import 'package:mawaqit/src/helpers/connectivity_provider.dart';
import 'package:mawaqit/src/helpers/mawaqit_icons_icons.dart';
import 'package:mawaqit/src/models/address_model.dart';
import 'package:mawaqit/src/pages/HijriAdjustmentsScreen.dart';
import 'package:mawaqit/src/pages/LanguageScreen.dart';
import 'package:mawaqit/src/pages/MosqueSearchScreen.dart';
import 'package:mawaqit/src/pages/TimezoneScreen.dart';
import 'package:mawaqit/src/pages/WifiSelectorScreen.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/on_boarding_permission_adhan_screen.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/widgets.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/theme_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/state_management/manual_app_update/manual_update_notifier.dart';
import 'package:mawaqit/src/state_management/on_boarding/on_boarding.dart';
import 'package:mawaqit/src/state_management/quran/recite/recite_notifier.dart';
import 'package:mawaqit/src/widgets/ScreenWithAnimation.dart';
import 'package:mawaqit/src/widgets/manual_update_dialog.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:sizer/sizer.dart';
import 'package:upgrader/upgrader.dart';

import '../../i18n/AppLanguage.dart';
import '../../main.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/TimeShiftManager.dart';
import '../services/FeatureManager.dart';
import '../state_management/app_update/app_update_notifier.dart';
import '../state_management/manual_app_update/manual_update_state.dart';
import '../state_management/quran/download_quran/download_quran_notifier.dart';
import '../state_management/random_hadith/random_hadith_notifier.dart';
import '../widgets/screen_lock_widget.dart';
import '../widgets/time_picker_widget.dart';
import 'home/widgets/show_check_internet_dialog.dart';
import 'rtsp_camera_settings_screen.dart';

enum _LaunchMode { mainPrayer, secondaryPrayer, announcement, quran }

_LaunchMode _getLaunchMode(UserPreferencesManager prefs) {
  switch (prefs.appMode) {
    case AppMode.normal:
      return prefs.isSecondaryScreen ? _LaunchMode.secondaryPrayer : _LaunchMode.mainPrayer;
    case AppMode.announcement:
      return _LaunchMode.announcement;
    case AppMode.quran:
      return _LaunchMode.quran;
  }
}

void _setLaunchMode(UserPreferencesManager prefs, _LaunchMode mode) {
  switch (mode) {
    case _LaunchMode.mainPrayer:
      prefs.appMode = AppMode.normal;
      prefs.isSecondaryScreen = false;
    case _LaunchMode.secondaryPrayer:
      prefs.appMode = AppMode.normal;
      prefs.isSecondaryScreen = true;
    case _LaunchMode.announcement:
      prefs.appMode = AppMode.announcement;
      prefs.isSecondaryScreen = false;
    case _LaunchMode.quran:
      prefs.appMode = AppMode.quran;
      prefs.isSecondaryScreen = false;
  }
}

class SettingScreen extends ConsumerStatefulWidget {
  const SettingScreen({super.key});

  @override
  ConsumerState createState() => _SettingScreenState();
}

class _SettingScreenState extends ConsumerState<SettingScreen> {
  bool isBoxOrAndroidTV = false;
  int androidSdkVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TimeShiftManager().initializeTimes();
      await ref.read(onBoardingProvider.notifier).isDeviceRooted();
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final bool deviceIsBoxOrAndroidTV = await DeviceInfoDataSource().isBoxOrAndroidTV();
      setState(() {
        isBoxOrAndroidTV = deviceIsBoxOrAndroidTV;
        androidSdkVersion = androidInfo.version.sdkInt;
      });

      final appLanguage = Provider.of<AppLanguage>(context, listen: false);
      final mosqueManager = Provider.of<MosqueManager>(context, listen: false);
      await appLanguage.getHadithLanguage(mosqueManager);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildSettingScreen(context, ref);
  }

  Widget _buildSettingScreen(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appLanguage = Provider.of<AppLanguage>(context);
    final userPreferences = context.watch<UserPreferencesManager>();
    final themeManager = context.watch<ThemeNotifier>();
    final String checkInternet = S.of(context).noInternet;
    final String hadithLanguage = S.of(context).connectToChangeHadith;
    final TimeShiftManager timeShiftManager = TimeShiftManager();
    final featureManager = Provider.of<FeatureManager>(context);
    final isDeviceRooted = ref.watch(onBoardingProvider).maybeWhen(
          orElse: () => false,
          data: (value) => value.isRootedDevice,
        );

    ref.listen(manualUpdateNotifierProvider, (previous, next) {
      switch (next.value?.status) {
        case UpdateStatus.available:
          UpdateDialog.show(context, ref);
          break;
        case UpdateStatus.notAvailable:
          UpdateDialog.showNoUpdateAvailableDialog(context);
          break;
        default:
          break;
      }
    });

    return ScreenWithAnimationWidget(
      animation: 'settings',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(S.of(context).settings, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 20),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Section 1: Global (open by default)
                    _CollapsibleSection(
                      title: S.of(context).settingsSectionGlobal,
                      icon: Icons.public,
                      initiallyExpanded: true,
                      children: [
                        _SettingItem(
                          title: S.of(context).hijriDateAdjustment,
                          subtitle: S.of(context).hijriAdjustmentsDescription,
                          icon: Icon(Icons.calendar_month, size: 35),
                          onTap: () => AppRouter.push(HijriAdjustmentsScreen()),
                        ),
                        _SettingItem(
                          title: S.of(context).interfaceLanguage,
                          subtitle: S.of(context).descLang,
                          icon: Icon(Icons.translate, size: 35),
                          onTap: () {
                            ref.invalidate(reciteNotifierProvider);
                            AppRouter.push(LanguageScreen());
                          },
                        ),
                        _SettingItem(
                          title: S.of(context).randomHadithLanguage,
                          subtitle: S.of(context).hadithLangDesc,
                          icon: Icon(Icons.menu_book, size: 35),
                          onTap: () async {
                            final userPreference = await appLanguage.getHadithLanguagePreference();

                            if (!mounted) return;

                            AppRouter.push(
                              LanguageScreen(
                                isIconActivated: true,
                                title: S.of(context).randomHadithLanguage,
                                description: S.of(context).descLang,
                                languages: appLanguage.hadithLocalizedLanguage.keys.toList(),
                                isSelected: (langCode) {
                                  return userPreference == langCode;
                                },
                                onSelect: (langCode) async {
                                  await ref.read(connectivityProvider.notifier).checkInternetConnection();
                                  ref.watch(connectivityProvider).maybeWhen(
                                    orElse: () {
                                      showCheckInternetDialog(
                                        context: context,
                                        onRetry: () {
                                          AppRouter.pop();
                                        },
                                        title: checkInternet,
                                        content: hadithLanguage,
                                      );
                                    },
                                    data: (isConnectedToInternet) async {
                                      if (isConnectedToInternet == ConnectivityStatus.disconnected) {
                                        showCheckInternetDialog(
                                          context: context,
                                          onRetry: () {
                                            AppRouter.pop();
                                          },
                                          title: checkInternet,
                                          content: hadithLanguage,
                                        );
                                      } else {
                                        await context.read<AppLanguage>().setHadithLanguage(langCode);
                                        if (!mounted) return;

                                        final mosqueManager = context.read<MosqueManager>();
                                        final actualLanguage =
                                            await context.read<AppLanguage>().getHadithLanguage(mosqueManager);
                                        if (!mounted) return;

                                        await ref
                                            .read(randomHadithNotifierProvider.notifier)
                                            .getRandomHadith(language: actualLanguage);
                                        if (!mounted) return;

                                        AppRouter.pop();
                                      }
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        _SettingItem(
                          title: S.of(context).rtspCameraSettingTitle,
                          subtitle: S.of(context).rtspCameraSettingDesc,
                          icon: Icon(Icons.videocam, size: 35),
                          onTap: () async {
                            await ref.read(connectivityProvider.notifier).checkInternetConnection();
                            ref.watch(connectivityProvider).maybeWhen(
                              orElse: () {
                                showCheckInternetDialog(
                                  context: context,
                                  onRetry: () {
                                    AppRouter.pop();
                                  },
                                  title: checkInternet,
                                  content: S.of(context).checkInternetLiveCamera,
                                );
                              },
                              data: (isConnectedToInternet) {
                                if (isConnectedToInternet == ConnectivityStatus.disconnected) {
                                  showCheckInternetDialog(
                                    context: context,
                                    onRetry: () {
                                      AppRouter.pop();
                                    },
                                    title: checkInternet,
                                    content: S.of(context).checkInternetLiveCamera,
                                  );
                                } else {
                                  AppRouter.push(RTSPCameraSettingsScreen());
                                }
                              },
                            );
                          },
                        ),
                        _SettingItem(
                          title: S.of(context).changeMosque,
                          subtitle: S.of(context).searchMosque,
                          icon: Icon(MawaqitIcons.icon_mosque, size: 35),
                          onTap: () => AppRouter.push(
                            MosqueSearchScreen(
                              nextButtonFocusNode: None(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Section 2: Display
                    _CollapsibleSection(
                      title: S.of(context).appDisplayMode,
                      icon: Icons.display_settings,
                      children: [
                        _SettingDropdownItem<_LaunchMode>(
                          title: S.of(context).applicationModes,
                          subtitle: S.of(context).appDisplayModeExplanation,
                          icon: Icon(Icons.dashboard, size: 35),
                          value: _getLaunchMode(userPreferences),
                          items: _LaunchMode.values,
                          onChanged: (value) {
                            if (value != null) _setLaunchMode(userPreferences, value);
                          },
                          itemLabelBuilder: (mode) {
                            switch (mode) {
                              case _LaunchMode.mainPrayer:
                                return S.of(context).launchModeMainPrayer;
                              case _LaunchMode.secondaryPrayer:
                                return S.of(context).launchModeSecondaryPrayer;
                              case _LaunchMode.announcement:
                                return S.of(context).announcement;
                              case _LaunchMode.quran:
                                return S.of(context).quran;
                            }
                          },
                        ),
                        _SettingSwitchItem(
                          title: S.of(context).lightMode,
                          icon: Icon(
                            theme.brightness == Brightness.light ? Icons.dark_mode : Icons.light_mode,
                            size: 35,
                          ),
                          onChanged: (value) => themeManager.toggleMode(),
                          value: themeManager.isLightTheme ?? false,
                        ),
                        _SettingSwitchItem(
                          title: S.of(context).iqamaShowClock,
                          subtitle: S.of(context).iqamaShowClockDesc,
                          icon: const Icon(Icons.access_time_outlined, size: 35),
                          value: userPreferences.iqamaShowClock,
                          onChanged: (value) => userPreferences.iqamaShowClock = value,
                        ),
                        _SettingItem(
                          title: S.of(context).orientation,
                          subtitle: S.of(context).selectYourMawaqitTvAppOrientation,
                          icon: Icon(Icons.screen_rotation, size: 35),
                          onTap: () => AppRouter.push(
                            ScreenWithAnimationWidget(
                              animation: 'welcome',
                              child: OnBoardingOrientationWidget(
                                onNext: AppRouter.pop,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Section 3: Device
                    _CollapsibleSection(
                      title: S.of(context).deviceSettings,
                      icon: Icons.devices,
                      children: [
                        if (isDeviceRooted)
                          _SettingItem(
                            title: S.of(context).screenLock,
                            subtitle: S.of(context).screenLockDesc,
                            icon: Icon(Icons.power_settings_new, size: 35),
                            onTap: () => showDialog(
                              context: context,
                              builder: (context) => ScreenLockModal(
                                timeShiftManager: timeShiftManager,
                              ),
                            ),
                          ),
                        _SettingItem(
                          title: S.of(context).timezone,
                          subtitle: S.of(context).descTimezone,
                          icon: Icon(Icons.schedule, size: 35),
                          onTap: () => AppRouter.push(TimezoneScreen()),
                        ),
                        _SettingItem(
                          title: S.of(context).wifi,
                          subtitle: S.of(context).descWifi,
                          icon: Icon(Icons.wifi, size: 35),
                          onTap: () => AppRouter.push(WifiSelectorScreen()),
                        ),
                        if (featureManager.isFeatureEnabled("timezone_shift") &&
                            timeShiftManager.deviceModel == "MAWABOX" &&
                            timeShiftManager.isLauncherInstalled)
                          _SettingItem(
                            title: S.of(context).timeSetting,
                            subtitle: S.of(context).timeSettingDesc,
                            icon: Icon(MawaqitIcons.icon_clock, size: 35),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => TimePickerModal(
                                  timeShiftManager: timeShiftManager,
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    // Section 4: Update
                    _CollapsibleSection(
                      title: S.of(context).update,
                      icon: Icons.system_update_alt,
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            return _SettingSwitchItem(
                              title: S.of(context).automaticUpdate,
                              subtitle: S.of(context).automaticUpdateDescription,
                              icon: Icon(Icons.notifications_active, size: 35),
                              onChanged: (value) {
                                logger.d('setting: disable the update $value');
                                ref.read(appUpdateProvider.notifier).toggleAutoUpdateChecking();
                              },
                              value: ref.watch(appUpdateProvider).maybeWhen(
                                    orElse: () => false,
                                    data: (data) => data.isAutoUpdateChecking,
                                  ),
                            );
                          },
                        ),
                        if (timeShiftManager.deviceModel != "MAWABOX")
                          _SettingItem(
                            title: S.of(context).checkForUpdates,
                            subtitle: S.of(context).checkForNewVersion,
                            icon: ref.watch(manualUpdateNotifierProvider).isLoading
                                ? const SizedBox(
                                    width: 35,
                                    height: 35,
                                    child: CircularProgressIndicator(),
                                  )
                                : const Icon(Icons.system_update, size: 35),
                            onTap: ref.watch(manualUpdateNotifierProvider).isLoading
                                ? null
                                : () async {
                                    await ref.read(connectivityProvider.notifier).checkInternetConnection();
                                    ref.watch(connectivityProvider).maybeWhen(
                                      orElse: () {
                                        showCheckInternetDialog(
                                          context: context,
                                          onRetry: () {
                                            AppRouter.pop();
                                          },
                                          title: checkInternet,
                                          content: S.of(context).checkInternetUpdate,
                                        );
                                      },
                                      data: (isConnectedToInternet) async {
                                        if (isConnectedToInternet == ConnectivityStatus.disconnected) {
                                          showCheckInternetDialog(
                                            context: context,
                                            onRetry: () {
                                              AppRouter.pop();
                                            },
                                            title: checkInternet,
                                            content: S.of(context).checkInternetUpdate,
                                          );
                                        } else if (kIsSideloadFlavor) {
                                          // Sideload flavor: always use S3 + package manager install
                                          var softwareFuture = await PackageInfo.fromPlatform();
                                          ref
                                              .read(manualUpdateNotifierProvider.notifier)
                                              .checkForUpdates(softwareFuture.version);
                                        } else {
                                          // Googleplay flavor: rooted → S3 + su install, otherwise → Play Store
                                          final isDeviceRooted = ref.read(onBoardingProvider).maybeWhen(
                                                orElse: () => false,
                                                data: (value) => value.isRootedDevice,
                                              );
                                          if (isDeviceRooted) {
                                            var softwareFuture = await PackageInfo.fromPlatform();
                                            ref
                                                .read(manualUpdateNotifierProvider.notifier)
                                                .checkForUpdates(softwareFuture.version);
                                          } else {
                                            ref.read(appUpdateProvider.notifier).openStore();
                                          }
                                        }
                                      },
                                    );
                                  },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            autofocus: true,
            leading: Icon(widget.icon, size: 35),
            title: Text(widget.title),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Theme(
              data: Theme.of(context).copyWith(
                cardTheme: CardTheme(
                  elevation: 0,
                  color: Colors.transparent,
                  margin: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                ),
              ),
              child: Column(children: widget.children),
            ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
  }) : super(key: key);

  final String title;
  final String? subtitle;
  final Widget? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        autofocus: true,
        leading: icon ?? SizedBox(),
        trailing: Icon(Icons.arrow_forward_ios),
        title: Text(title),
        subtitle: subtitle != null
            ? Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10))
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _SettingSwitchItem extends StatelessWidget {
  const _SettingSwitchItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.value = false,
    this.icon,
    this.onChanged,
  }) : super(key: key);

  final String title;
  final String? subtitle;
  final Widget? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        autofocus: true,
        secondary: icon ?? SizedBox(),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!, maxLines: 2, overflow: TextOverflow.clip) : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingDropdownItem<T> extends StatelessWidget {
  const _SettingDropdownItem({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemLabelBuilder,
  }) : super(key: key);

  final String title;
  final String? subtitle;
  final Widget? icon;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemLabelBuilder;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        autofocus: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        leading: icon ?? SizedBox(),
        title: Text(title),
        subtitle: subtitle != null
            ? Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10))
            : null,
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            underline: SizedBox(),
            borderRadius: BorderRadius.circular(20),
            onChanged: onChanged,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabelBuilder(item)),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
