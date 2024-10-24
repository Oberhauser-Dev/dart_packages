# Material Duration Picker

A duration picker using the material (M3) design guidelines of the [time picker](https://m2.material.io/components/time-pickers).

## Features

![duration_picker.gif](docs/images/duration_picker.gif)

## Getting started

```shell
dart pub add material_duration_picker
```

## Usage

Add the default localization delegate (the global delegate is not support yet):

```dart
import 'package:material_duration_picker/material_duration_picker.dart';

MaterialApp(
  localizationsDelegates: const [
    DefaultDurationPickerMaterialLocalizations.delegate,
  ],
  // ...
),
```

```dart
IconButton(
  icon: const Icon(Icons.timelapse),
  onPressed: () {
    showDurationPicker(
      context: context,
      initialDuration: Duration.zero,
    );
  },
),

DurationPickerDialog(
  durationPickerMode: DurationPickerMode.hm,
  initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
),

DurationPickerDialog(
  durationPickerMode: DurationPickerMode.hms,
  initialEntryMode: DurationPickerEntryMode.input,
  initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
),
```

## Additional information

The package was meant to be integrated directly in the Material Widget Library.
This implementation is kept in sync with the changes of the Flutter [time_picker](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/time_picker.dart).
In case the Material and/or Flutter team decides to include it, the package is kept in sync with the Flutter Pull-Request.

- Flutter issue: https://github.com/flutter/flutter/issues/144536
- Flutter feature branch: https://github.com/Gustl22/flutter/tree/144536-duration-picker
- Flutter PR (closed, just as ref): https://github.com/flutter/flutter/pull/145698
- Material Components: https://github.com/material-components/material-components-android/issues/2218
