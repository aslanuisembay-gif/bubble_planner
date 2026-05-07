import 'package:flutter/material.dart';

import 'settings_sheet.dart';

/// Настройки из любого экрана (в т.ч. поверх [Navigator.push]).
void showPlannerSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => const SettingsSheet(),
  );
}
