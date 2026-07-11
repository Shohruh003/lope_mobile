import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push_service.dart';
import '../core/theme_mode_provider.dart';
import '../shared/theme/typography.dart';
import 'router.dart';
import 'theme.dart';

class LopeApp extends ConsumerStatefulWidget {
  const LopeApp({super.key});

  @override
  ConsumerState<LopeApp> createState() => _LopeAppState();
}

class _LopeAppState extends ConsumerState<LopeApp> {
  bool _pushInited = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Fire-and-forget FCM bootstrap on the first build. Wrapped in a guard so
    // it only runs once across rebuilds and only after the router is ready
    // (because push_service needs it for deep-linking).
    if (!_pushInited) {
      _pushInited = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(pushServiceProvider).initIfPossible(router: router);
      });
    }

    // Real light/dark mode: buildAppTheme(brightness) returns a
    // ThemeData that registers the matching LopeColors extension, and
    // every screen — shared widgets AND individual features — reads
    // colours through `context.colors.xxx`. AppText's static getters
    // pull from the same palette via a runtime brightness switch so
    // titles/subtitles/captions don't need context to theme correctly.
    final mode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.dark;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveBrightness = switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => systemBrightness,
    };
    AppText.brightness = effectiveBrightness;
    return MaterialApp.router(
      title: 'Lope Style',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('uz'),
        Locale('ru'),
        Locale('en'),
      ],
    );
  }
}
