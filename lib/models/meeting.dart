import '../config.dart';

class Meeting {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? meetLink;
  final List<String> attendees;

  Meeting({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.meetLink,
    this.attendees = const [],
  });

  bool get hasMeetLink => meetLink != null && meetLink!.isNotEmpty;

  Duration get timeUntilStart => startTime.difference(DateTime.now());

  // True when the meeting starts within the configured lead time
  // (kAlertLeadMinutes in lib/config.dart) — this triggers the fly-over.
  bool get isStartingSoon {
    final diff = timeUntilStart;
    return diff.inSeconds >= 0 && diff.inMinutes <= kAlertLeadMinutes;
  }

  bool get isStartingVeryySoon {
    final diff = timeUntilStart;
    return diff.inSeconds >= 0 && diff.inMinutes <= 1;
  }

  String get formattedTime {
    final h = startTime.hour;
    final m = startTime.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:$m $period';
  }

  String get timeUntilLabel {
    final diff = timeUntilStart;
    if (diff.inMinutes <= 0) return 'Starting now!';
    if (diff.inMinutes == 1) return 'In 1 minute';
    return 'In ${diff.inMinutes} minutes';
  }

  factory Meeting.fromGoogleEvent(dynamic event) {
    String? meetLink;

    final conferenceData = event.conferenceData;
    if (conferenceData != null) {
      final entryPoints = conferenceData.entryPoints;
      if (entryPoints != null) {
        for (final ep in entryPoints) {
          if (ep.entryPointType == 'video') {
            meetLink = ep.uri;
            break;
          }
        }
      }
    }

    if (meetLink == null) {
      final location = event.location ?? '';
      final description = event.description ?? '';
      final combined = '$location $description';
      final meetRegex = RegExp(r'https://meet\.google\.com/[a-z-]+');
      final match = meetRegex.firstMatch(combined);
      if (match != null) meetLink = match.group(0);
    }

    final startStr = event.start?.dateTime?.toIso8601String() ??
        '${event.start?.date}T00:00:00';
    final endStr = event.end?.dateTime?.toIso8601String() ??
        '${event.end?.date}T23:59:59';

    final attendees = <String>[];
    if (event.attendees != null) {
      for (final a in event.attendees!) {
        if (a.email != null) attendees.add(a.email!);
      }
    }

    return Meeting(
      id: event.id ?? '',
      title: event.summary ?? 'Untitled meeting',
      startTime: DateTime.parse(startStr).toLocal(),
      endTime: DateTime.parse(endStr).toLocal(),
      meetLink: meetLink,
      attendees: attendees,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'meetLink': meetLink,
        'attendees': attendees,
      };

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        id: json['id'] as String,
        title: json['title'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        meetLink: json['meetLink'] as String?,
        attendees: (json['attendees'] as List<dynamic>).cast<String>(),
      );
}
