// App-wide tunables — change these and rebuild.

/// How many minutes before a meeting starts the plane fly-over appears.
/// e.g. 5 → plane flies when a meeting is within 5 minutes of starting.
const int kAlertLeadMinutes = 2;

/// How often the app downloads the calendar from Google (network call).
/// Alerts are still checked locally every 20s against the cached list,
/// so a longer poll interval saves resources without late alerts.
const int kCalendarPollSeconds = 120;
