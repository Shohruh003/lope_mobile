// Custom Flutter Web bootstrap. Overrides the default template so we
// don't get Flutter's built-in blue LinearProgressIndicator at the top
// of the page — the branded #lope-splash element in index.html covers
// the loading gap instead.
//
// Keep the template placeholders as-is; `flutter build web` replaces
// them at build time.

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  // Passing onEntrypointLoaded tells the loader "I'll drive the UI
  // myself", which suppresses the default blue progress bar.
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
