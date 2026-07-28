import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/tr.dart';
import '../theme/typography.dart';

/// One-shot Riverpod provider that reads the app's version + build
/// number out of PackageInfo. Cached for the lifetime of the process
/// so both profile screens share a single native call instead of each
/// firing their own.
final _packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// 'Versiya 1.8.0' label used at the bottom of the customer + barber
/// profile screens. Reads the version from pubspec at runtime so a
/// release bump only requires editing pubspec, not chasing hardcoded
/// strings across the codebase (previous copy was stuck on 1.0.0 long
/// after the app shipped 1.8.0).
class AppVersionLabel extends ConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(_packageInfoProvider);
    // Guard against a rare failure path where package_info_plus can't
    // resolve the native version (e.g. missing plugin registration on
    // some obscure build) — render nothing rather than a stale value.
    final version = info.maybeWhen(
      data: (i) => i.version,
      orElse: () => null,
    );
    if (version == null) return const SizedBox.shrink();
    return Text(
      tr(ref, 'profile.versionLabel', 'Versiya {{v}}', {'v': version}),
      style: AppText.caption,
    );
  }
}
