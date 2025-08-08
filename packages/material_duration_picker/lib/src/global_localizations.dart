import 'dart:collection';

import 'package:flutter/material.dart';

import 'localizations.dart';

final Set<String> kMaterialDurationPickerSupportedLanguages =
    HashSet<String>.from(const <String>['en', 'de']);

abstract class GlobalMaterialDurationPickerLocalizations
    extends DefaultMaterialDurationPickerLocalizations
    implements MaterialDurationPickerLocalizations {
  static const LocalizationsDelegate<MaterialDurationPickerLocalizations> delegate =
      _MaterialLocalizationsDelegate();

  @override
  String toString() =>
      'GlobalMaterialDurationPickerLocalizations.delegate(${kMaterialDurationPickerSupportedLanguages.length} locales)';
}

class _MaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialDurationPickerLocalizations> {
  const _MaterialLocalizationsDelegate();

  static final Map<Locale, Future<MaterialDurationPickerLocalizations>> _loadedTranslations =
      <Locale, Future<MaterialDurationPickerLocalizations>>{};

  @override
  Future<MaterialDurationPickerLocalizations> load(Locale locale) async {
    assert(isSupported(locale));

    return _loadedTranslations.putIfAbsent(locale, () async {
      return switch (locale.languageCode) {
        'de' => MaterialDurationPickerLocalizationDe(),
        _ => const DefaultMaterialDurationPickerLocalizations(),
      };
    });
  }

  @override
  bool shouldReload(_MaterialLocalizationsDelegate old) => false;

  @override
  bool isSupported(Locale locale) {
    // Act like it would support every language, so the package is still usable in other languages.
    // This can be changed as soon as the majority is translated, so we can fill the gaps.
    return true;
    // return kMaterialDurationPickerSupportedLanguages.contains(locale.languageCode);
  }
}

class MaterialDurationPickerLocalizationDe extends DefaultMaterialDurationPickerLocalizations {
  @override
  String get durationPickerDialHelpText => 'Zeitdauer auswählen';

  @override
  String get durationPickerInputHelpText => 'Zeitdauer eingeben';

  @override
  String get timePickerSecondLabel => 'Sekunde';

  @override
  String get timePickerSecondModeAnnouncement => 'Sekunden auswählen';
}
