import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'duration.dart';

abstract class DurationPickerMaterialLocalizations
    extends MaterialLocalizations {
  /// The text-to-speech announcement made when a time picker invoked using
  /// [showTimePicker] is set to the second picker mode.
  String get timePickerSecondModeAnnouncement;

  /// The format used to lay out the duration picker.
  ///
  /// The documentation for [DurationFormat] enum values provides details on
  /// each supported layout.
  DurationFormat durationFormat();

  /// Formats [Duration.hour] in the given duration according to the value
  /// of [DurationFormat].
  String formatDurationHour(Duration duration);

  /// Formats [Duration.minute] in the given duration according to the value
  /// of [durationFormat].
  String formatDurationMinute(Duration duration);

  /// Formats [Duration.second] in the given duration according to the value
  /// of [durationFormat].
  String formatDurationSecond(Duration duration);

  /// Formats [duration] according to the value of [durationFormat].
  String formatDuration(Duration duration);

  /// Label used in the header of the duration picker dialog created with
  /// [showDurationPicker] when in [DurationPickerEntryMode.dial].
  String get durationPickerDialHelpText;

  /// Label used in the header of the duration picker dialog created with
  /// [showDurationPicker] when in [DurationPickerEntryMode.input].
  String get durationPickerInputHelpText;

  /// Label used below the second text field of the time picker dialog created
  /// with [showTimePicker] when in [TimePickerEntryMode.input].
  String get timePickerSecondLabel;

  /// The `MaterialLocalizations` from the closest [Localizations] instance
  /// that encloses the given context.
  ///
  /// If no [MaterialLocalizations] are available in the given `context`, this
  /// method throws an exception.
  ///
  /// This method is just a convenient shorthand for:
  /// `Localizations.of<MaterialLocalizations>(context, MaterialLocalizations)!`.
  ///
  /// References to the localized resources defined by this class are typically
  /// written in terms of this method. For example:
  ///
  /// ```dart
  /// tooltip: MaterialLocalizations.of(context).backButtonTooltip,
  /// ```
  static DurationPickerMaterialLocalizations of(BuildContext context) {
    return Localizations.of<DurationPickerMaterialLocalizations>(
        context, DurationPickerMaterialLocalizations)!;
  }
}

class _DurationPickerMaterialLocalizationsDelegate
    extends LocalizationsDelegate<DurationPickerMaterialLocalizations> {
  const _DurationPickerMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<DurationPickerMaterialLocalizations> load(Locale locale) =>
      DefaultDurationPickerMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_DurationPickerMaterialLocalizationsDelegate old) => false;

  @override
  String toString() =>
      'DefaultDurationPickerMaterialLocalizations.delegate(en_US)';
}

class DefaultDurationPickerMaterialLocalizations
    extends DefaultMaterialLocalizations
    implements DurationPickerMaterialLocalizations {
  /// Constructs an object that defines the material widgets' localized strings
  /// for US English (only).
  ///
  /// [LocalizationsDelegate] implementations typically call the static [load]
  /// function, rather than constructing this class directly.
  const DefaultDurationPickerMaterialLocalizations();

  /// A [LocalizationsDelegate] that uses [DefaultMaterialLocalizations.load]
  /// to create an instance of this class.
  ///
  /// [MaterialApp] automatically adds this value to [MaterialApp.localizationsDelegates].
  static const LocalizationsDelegate<DurationPickerMaterialLocalizations>
      delegate = _DurationPickerMaterialLocalizationsDelegate();

  @override
  String formatDurationHour(Duration duration) {
    return _formatTwoDigitZeroPad(duration.hour);
  }

  @override
  String formatDurationMinute(Duration duration) {
    final int minute = duration.minute;
    return minute < 10 ? '0$minute' : minute.toString();
  }

  @override
  String formatDurationSecond(Duration duration) {
    final int second = duration.second;
    return second < 10 ? '0$second' : second.toString();
  }

  @override
  String get durationPickerDialHelpText => 'Select duration';

  @override
  String get durationPickerInputHelpText => 'Enter duration';

  @override
  String get timePickerSecondLabel => 'Second';

  @override
  String formatDuration(Duration duration) {
    final StringBuffer buffer = StringBuffer();

    // Add hour:minute.
    buffer
      ..write(formatDurationHour(duration))
      ..write(':')
      ..write(formatDurationMinute(duration));

    return '$buffer';
  }

  @override
  String get timePickerSecondModeAnnouncement => 'Select seconds';

  @override
  DurationFormat durationFormat() {
    return DurationFormat.HH_colon_mm;
  }

  /// Formats [number] using two digits, assuming it's in the 0-99 inclusive
  /// range. Not designed to format values outside this range.
  String _formatTwoDigitZeroPad(int number) {
    assert(0 <= number && number < 100);

    if (number < 10) {
      return '0$number';
    }

    return '$number';
  }

  /// Creates an object that provides US English resource values for the material
  /// library widgets.
  ///
  /// The [locale] parameter is ignored.
  ///
  /// This method is typically used to create a [LocalizationsDelegate].
  /// The [MaterialApp] does so by default.
  static Future<DurationPickerMaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<DurationPickerMaterialLocalizations>(
        const DefaultDurationPickerMaterialLocalizations());
  }
}
