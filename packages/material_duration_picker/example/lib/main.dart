import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:material_duration_picker/material_duration_picker.dart';

void main() => runApp(const DurationPickerApp());

class DurationPickerApp extends StatelessWidget {
  const DurationPickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialDurationPickerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('de'), Locale('it')],
      home: const Home(),
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.timelapse),
                  onPressed: () {
                    showDurationPicker(
                      durationPickerMode: DurationPickerMode.ms,
                      context: context,
                      initialDuration: Duration.zero,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.timelapse),
                  onPressed: () {
                    showDurationPicker(
                      durationPickerMode: DurationPickerMode.hms,
                      context: context,
                      initialDuration: Duration.zero,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.timelapse),
                  onPressed: () {
                    showDurationPicker(
                      durationPickerMode: DurationPickerMode.ms,
                      context: context,
                      initialDuration: Duration.zero,
                    );
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () {
                    showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: () {
                    showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 1));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.date_range),
                  onPressed: () {
                    showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 1));
                  },
                ),
              ],
            ),
            const Divider(),
            const DurationPickerDialog(
              durationPickerMode: DurationPickerMode.hm,
              initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
            ),
            const DurationPickerDialog(
              durationPickerMode: DurationPickerMode.hm,
              initialEntryMode: DurationPickerEntryMode.input,
              initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
            ),
            const DurationPickerDialog(
              durationPickerMode: DurationPickerMode.hms,
              initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
            ),
            const DurationPickerDialog(
              durationPickerMode: DurationPickerMode.hms,
              initialEntryMode: DurationPickerEntryMode.input,
              initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
            ),
            const DurationPickerDialog(
              durationPickerMode: DurationPickerMode.ms,
              initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
            ),
            const DurationPickerDialog(
              durationPickerMode: DurationPickerMode.ms,
              initialEntryMode: DurationPickerEntryMode.input,
              initialDuration: Duration(hours: 1, minutes: 30, seconds: 45),
            ),
            const Divider(),
            CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hms,
              onTimerDurationChanged: (Duration value) {
                developer.log(value.toString());
              },
            ),
            const Divider(),
            TimePickerDialog(
              initialTime: TimeOfDay.now(),
            ),
            TimePickerDialog(
              initialEntryMode: TimePickerEntryMode.input,
              initialTime: TimeOfDay.now(),
            ),
          ],
        ),
      ),
    );
  }
}
