import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_notifier/models/meeting.dart';
import 'package:meeting_notifier/widgets/meeting_card.dart';

void main() {
  test('formattedTime uses 12-hour clock', () {
    final meeting = Meeting(
      id: '1',
      title: 'Standup',
      startTime: DateTime(2026, 8, 25, 14, 5),
      endTime: DateTime(2026, 8, 25, 14, 30),
    );
    expect(meeting.formattedTime, '2:05 PM');
  });

  testWidgets('MeetingCard shows title and Join when a Meet link exists',
      (tester) async {
    final meeting = Meeting(
      id: '1',
      title: 'Weekly Team Standup',
      startTime: DateTime.now().add(const Duration(minutes: 30)),
      endTime: DateTime.now().add(const Duration(minutes: 60)),
      meetLink: 'https://meet.google.com/abc-defg-hij',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MeetingCard(meeting: meeting)),
      ),
    );

    expect(find.text('Weekly Team Standup'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
  });
}
