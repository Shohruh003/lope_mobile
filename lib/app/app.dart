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

    // Real light/dark mode: buildAppTheme(brightness) returns a
    // ThemeData that registers the matching LopeColors extension, and
    // every screen — shared widgets AND individual features — now
    // reads colours through `context.colors.xxx`. MaterialApp switches
    // between the two themes based on the user's saved preference.
    final mode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.dark;
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
