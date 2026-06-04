import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../services/calendar_service.dart';
import '../services/overlay_service.dart';
import '../models/meeting.dart';
import '../widgets/meeting_card.dart';
import '../widgets/plane_notification.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<Meeting>? _alertSub;
  Timer? _refreshTimer;

  // Overlay state — when true the window becomes a transparent always-on-top
  // strip across the top of the screen showing the plane animation.
  // The width stays null until the native side reports the real screen width,
  // so the animation is never built with a guessed width.
  bool _isOverlayMode = false;
  Meeting? _activeMeeting;
  double? _overlayScreenWidth;

  @override
  void initState() {
    super.initState();
    _setupAlertListener();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isOverlayMode) setState(() {});
    });
  }

  void _setupAlertListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<CalendarService>();
      _alertSub = service.onMeetingAlert.listen((meeting) {
        _showPlaneNotification(meeting);
      });
    });
  }

  Future<void> _showPlaneNotification(Meeting meeting) async {
    if (_isOverlayMode) return;

    // Flutter must render transparently BEFORE the native window goes
    // borderless, otherwise a white flash covers the screen.
    setState(() {
      _isOverlayMode = true;
      _activeMeeting = meeting;
      _overlayScreenWidth = null;
    });

    // Let the transparent frame paint, then flip the native window into a
    // transparent always-on-top strip (shown without stealing focus).
    await WidgetsBinding.instance.endOfFrame;
    final overlayWidth = await OverlayService.enterOverlay();

    if (mounted) {
      // Now that the real width is known, build and start the animation.
      setState(() => _overlayScreenWidth = overlayWidth);
    }
  }

  Future<void> _dismissOverlay() async {
    if (!_isOverlayMode) return;

    // Restore the native window (it goes back to hidden if it was hidden)
    await OverlayService.exitOverlay();

    if (mounted) {
      setState(() {
        _isOverlayMode = false;
        _activeMeeting = null;
      });
    }
  }

  void _testAnimation(CalendarService service) {
    // Fires the same alert stream a real meeting would — identical behavior.
    service.triggerTestAlert();
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _refreshTimer?.cancel();
    // Ensure window is restored if widget is disposed mid-animation
    if (_isOverlayMode) _dismissOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Transparent overlay mode: render only the plane animation.
    // Until the native side reports the screen width, paint nothing —
    // a fully transparent frame (prevents any flash of the normal UI).
    if (_isOverlayMode && _activeMeeting != null) {
      return Material(
        color: Colors.transparent,
        child: _overlayScreenWidth == null
            ? const SizedBox.expand()
            : PlaneNotificationOverlay(
                meeting: _activeMeeting!,
                screenWidth: _overlayScreenWidth!,
                onDismiss: _dismissOverlay,
              ),
      );
    }

    return Consumer<CalendarService>(
      builder: (context, service, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            title: const Row(
              children: [
                Text('✈', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text(
                  'Meeting Notifier',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            actions: [
              if (service.isSignedIn) ...[
                Tooltip(
                  message: 'Test fly-over animation',
                  child: IconButton(
                    icon: const Icon(Icons.airplanemode_active_rounded,
                        color: Color(0xFF1565C0)),
                    onPressed: () => _testAnimation(service),
                  ),
                ),
                Tooltip(
                  message: 'Refresh calendar',
                  child: IconButton(
                    icon: service.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded,
                            color: Color(0xFF555555)),
                    onPressed: service.isLoading ? null : service.fetchMeetings,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _showSignOutDialog(context, service),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF1565C0),
                      child: Text(
                        (service.currentUser?.displayName ?? 'U')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFE8E8E8)),
            ),
          ),
          body: service.isSignedIn
              ? _buildMeetingsList(service)
              : _buildSignInScreen(service),
        );
      },
    );
  }

  Widget _buildSignInScreen(CalendarService service) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✈', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          const Text(
            'Meeting Notifier',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get fly-over alerts $kAlertLeadMinutes minutes before every meeting',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          if (service.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  service.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: service.isLoading ? null : service.signIn,
            icon: service.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded),
            label:
                Text(service.isLoading ? 'Signing in...' : 'Sign in with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingsList(CalendarService service) {
    final meetings = service.upcomingMeetings;

    if (service.isLoading && meetings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (service.error != null && meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(service.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: service.fetchMeetings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (meetings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No upcoming meetings today',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your free time! ✌️',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => _testAnimation(service),
              icon: const Icon(Icons.airplanemode_active_rounded),
              label: const Text('Test fly-over animation'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: service.fetchMeetings,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                children: [
                  Text(
                    "Today's meetings",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${meetings.length} event${meetings.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => MeetingCard(meeting: meetings[index]),
              childCount: meetings.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton.icon(
                  onPressed: () => _testAnimation(service),
                  icon: const Icon(Icons.airplanemode_active_rounded, size: 16),
                  label: const Text('Test fly-over animation',
                      style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, CalendarService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account'),
        content: Text(
          'Signed in as\n${service.currentUser?.email ?? ''}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              service.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
