import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push_service.dart';
import '../core/theme_mode_provider.dart';
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

    // Foundation is in place — buildAppTheme(Brightness.light) exists
    // and every shared widget (AppCard/Button/Chip/Badge/Skeleton/…)
    // reads through context.colors. But 50+ individual screens still
    // reference AppColors.textPrimary/textBright/border etc. as static
    // const, so flipping to light there would leave dark text on a
    // white scaffold. Screen-by-screen migration lands in follow-up
    // commits; until it's complete, we force dark to guarantee "no
    // bugs" while keeping the toggle preference persistent.
    final _ = ref.watch(themeModeProvider);
    final darkTheme = buildAppTheme(Brightness.dark);
    return MaterialApp.router(
      title: 'Lope Style',
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
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
