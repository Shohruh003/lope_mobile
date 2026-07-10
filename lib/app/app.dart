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

    // themeMode preference is kept in place (persists in shared prefs +
    // shows in the picker) but the whole palette is still hard-coded
    // dark via `AppColors.*` constants which the framework can't swap
    // at runtime. Fully honouring light mode needs migrating AppColors
    // to a ThemeExtension — planned separately. Until then, force dark
    // so the UI stays readable.
    final _ = ref.watch(themeModeProvider);
    final darkTheme = buildAppTheme();
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
