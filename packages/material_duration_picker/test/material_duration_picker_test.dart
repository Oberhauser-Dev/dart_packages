import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_duration_picker/material_duration_picker.dart';

void main() {
  testWidgets('Duration Picker App', (WidgetTester tester) async {
    const widget = MaterialApp(
      localizationsDelegates: [
        DefaultDurationPickerMaterialLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      locale: Locale('en'),
      home: DurationPickerDialog(),
    );
    await tester.pumpWidget(widget);
  });
}
