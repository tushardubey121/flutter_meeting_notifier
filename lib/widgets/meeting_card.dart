import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meeting.dart';

class MeetingCard extends StatelessWidget {
  final Meeting meeting;

  const MeetingCard({super.key, required this.meeting});

  @override
  Widget build(BuildContext context) {
    final isUrgent = meeting.isStartingSoon;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isUrgent
            ? const Color(0xFF0D47A1).withOpacity(0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent
              ? const Color(0xFF1565C0).withOpacity(0.4)
              : theme.dividerColor.withOpacity(0.3),
          width: isUrgent ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Time column
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    meeting.formattedTime,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isUrgent
                          ? const Color(0xFF1565C0)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isUrgent)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'SOON',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 40, color: theme.dividerColor),
            const SizedBox(width: 12),

            // Meeting details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meeting.timeUntilLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUrgent
                          ? const Color(0xFF1565C0)
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  if (meeting.attendees.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '${meeting.attendees.length} attendees',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Join button
            if (meeting.hasMeetLink)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(meeting.meetLink!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.videocam_rounded, size: 14),
                  label: const Text('Join', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFF1565C0)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
