import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:meeting_notifier/config.dart';
import '../models/meeting.dart';
import '../google_client_id.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class CalendarService extends ChangeNotifier {
  static const _scopes = [
    'https://www.googleapis.com/auth/calendar.readonly',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
    clientId: googleClientId,
  );

  GoogleSignInAccount? _currentUser;
  List<Meeting> _upcomingMeetings = [];
  bool _isSignedIn = false;
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;
  Timer? _alertCheckTimer;

  // Notifier for when a meeting is about to start (triggers the plane animation)
  final _notificationController = StreamController<Meeting>.broadcast();
  Stream<Meeting> get onMeetingAlert => _notificationController.stream;

  // Track which meetings we've already notified about
  final Set<String> _notifiedMeetingIds = {};

  bool get isSignedIn => _isSignedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Meeting> get upcomingMeetings => _upcomingMeetings;
  GoogleSignInAccount? get currentUser => _currentUser;

  CalendarService() {
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      _isSignedIn = account != null;
      if (_isSignedIn) {
        fetchMeetings();
        _startPolling();
      } else {
        _stopPolling();
        _upcomingMeetings = [];
      }
      notifyListeners();
    });

    // Try silent sign-in on startup
    _googleSignIn.signInSilently();
  }

  Future<void> signIn() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _googleSignIn.signIn();
    } catch (e) {
      _error = 'Sign in failed: $e';
      debugPrint('Sign in error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _notifiedMeetingIds.clear();
  }

  Future<void> fetchMeetings() async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final authHeaders = await _currentUser!.authHeaders;
      final authClient = GoogleAuthClient(authHeaders);
      final calendarApi = gcal.CalendarApi(authClient);

      final now = DateTime.now();
      final tomorrow = now.add(const Duration(hours: 24));

      final events = await calendarApi.events.list(
        'primary',
        timeMin: now,
        timeMax: tomorrow,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 20,
      );

      final meetings = <Meeting>[];
      if (events.items != null) {
        for (final event in events.items!) {
          // Skip all-day events (no dateTime, only date)
          if (event.start?.dateTime == null) continue;
          // Skip declined events
          final selfRsvp = event.attendees?.where(
            (a) => a.self == true,
          ).firstOrNull;
          if (selfRsvp?.responseStatus == 'declined') continue;

          meetings.add(Meeting.fromGoogleEvent(event));
        }
      }

      _upcomingMeetings = meetings;
      _error = null;

      // Check for meetings starting soon right after fetch
      _checkForAlerts();
    } catch (e) {
      _error = 'Failed to load calendar: $e';
      debugPrint('Calendar fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _alertCheckTimer?.cancel();

    // Network fetch — kept infrequent to save resources.
    _pollTimer = Timer.periodic(const Duration(seconds: kCalendarPollSeconds),
        (_) {
      fetchMeetings();
    });

    // Local alert check against the cached meeting list — pure in-memory
    // comparison, no network — so alerts stay on time despite slow polling.
    _alertCheckTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _checkForAlerts();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _alertCheckTimer?.cancel();
    _alertCheckTimer = null;
  }

  /// Simulates a meeting starting in [kAlertLeadMinutes] minutes — fires the
  /// exact same alert path a real calendar meeting would, so the fly-over
  /// behaves identically.
  void triggerTestAlert() {
    final testMeeting = Meeting(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Weekly Team Standup',
      startTime: DateTime.now().add(const Duration(minutes: kAlertLeadMinutes)),
      endTime:
          DateTime.now().add(const Duration(minutes: kAlertLeadMinutes + 30)),
      meetLink: 'https://meet.google.com/abc-defg-hij',
    );
    _notificationController.add(testMeeting);
  }

  void _checkForAlerts() {
    for (final meeting in _upcomingMeetings) {
      if (meeting.isStartingSoon && !_notifiedMeetingIds.contains(meeting.id)) {
        _notifiedMeetingIds.add(meeting.id);
        _notificationController.add(meeting);
      }
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _notificationController.close();
    super.dispose();
  }
}
