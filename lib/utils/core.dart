import 'package:flutter/cupertino.dart';

import '../l10n/generated/app_localizations.dart';

extension ContextExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
