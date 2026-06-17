import 'package:flutter/material.dart';
import '../../services/lms_api_client.dart';
import 'lms_course_viewer.dart';

class LmsDashboardScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onGoToCbt;
  const LmsDashboardScreen({super.key, required this.onLogout, required this.onGoToCbt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Portal'),
        actions: [
          IconButton(icon: const Icon(Icons.school), tooltip: 'Take Exam (CBT)', onPressed: onGoToCbt),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: onLogout),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: LmsApiClient.get('/student/dashboard').then((r) => Map<String, dynamic>.from(r.data)),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? {};
          final courses = (data['enrolledCourses'] as List<dynamic>?) ?? [];
          final gpa = data['gpa'] ?? 0.0;
          final announcements = (data['recentAnnouncements'] as List<dynamic>?) ?? [];

          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(
              children: [
                _StatCard(label: 'GPA', value: (gpa as num).toStringAsFixed(2), icon: Icons.analytics, color: Colors.blue),
                const SizedBox(width: 12),
                _StatCard(label: 'Courses', value: '${courses.length}', icon: Icons.book, color: Colors.green),
                const SizedBox(width: 12),
                _StatCard(label: 'Alerts', value: '${announcements.length}', icon: Icons.notifications, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 20),
            Text('My Courses', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ...courses.map((c) {
              final cm = c as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: Text(cm['code'] as String? ?? ''),
                  subtitle: Text(cm['title'] as String? ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(ctx, MaterialPageRoute(
                      builder: (_) => LmsCourseViewerScreen(courseId: cm['id'], courseName: cm['title']),
                    ));
                  },
                ),
              );
            }),
            if (announcements.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Recent Announcements', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ...announcements.map((a) {
                final am = a as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.campaign),
                  title: Text(am['title'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(am['content'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  dense: true,
                );
              }),
            ],
          ]);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) => _navigate(context, i, onLogout, onGoToCbt),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.grade), label: 'Grades'),
          NavigationDestination(icon: Icon(Icons.forum), label: 'Forums'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  void _navigate(BuildContext ctx, int idx, VoidCallback logout, VoidCallback cbt) {
    switch (idx) {
      case 1: Navigator.push(ctx, MaterialPageRoute(builder: (_) => _LmsTasksPage())); break;
      case 2: Navigator.push(ctx, MaterialPageRoute(builder: (_) => _LmsGradesPage())); break;
      case 3: Navigator.push(ctx, MaterialPageRoute(builder: (_) => _LmsForumsPage())); break;
      case 4: Navigator.push(ctx, MaterialPageRoute(builder: (_) => LmsMorePage(onLogout: logout, onCbt: cbt))); break;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }
}

class _LmsTasksPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessments')),
      body: FutureBuilder<List<dynamic>>(
        future: LmsApiClient.get('/assignments').then((r) => r.data as List<dynamic>),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: (snap.data ?? []).map((a) {
              final m = a as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.assignment),
                title: Text(m['title'] as String? ?? ''),
                subtitle: Text(m['type'] != null ? 'Quiz' : 'Assignment'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _LmsGradesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grades')),
      body: FutureBuilder<List<dynamic>>(
        future: LmsApiClient.get('/grades').then((r) => (r.data as List<dynamic>?) ?? []),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: (snap.data ?? []).map((g) {
              final m = g as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(child: Text(m['letterGrade'] as String? ?? '-')),
                title: Text('Score: ${m['score']}'),
                subtitle: Text('${m['academicYear']} Sem ${m['semester']} | ${m['type']}'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _LmsForumsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forums')),
      body: FutureBuilder<List<dynamic>>(
        future: LmsApiClient.get('/forums').then((r) => (r.data as List<dynamic>?) ?? []),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: (snap.data ?? []).map((f) {
              final m = f as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.forum),
                title: Text(m['title'] as String? ?? ''),
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(m['title'] as String? ?? '')),
                    body: FutureBuilder<List<dynamic>>(
                      future: LmsApiClient.get('/forums/${m['id']}/posts').then((r) => (r.data as List<dynamic>?) ?? []),
                      builder: (c, s) => ListView(children: (s.data ?? []).map((p) => ListTile(
                        title: Text((p as Map)['content'] ?? '', maxLines: 3),
                        subtitle: Text((p)['authorRole'] as String? ?? ''),
                      )).toList()),
                    ),
                  ),
                )),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class LmsMorePage extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onCbt;
  const LmsMorePage({super.key, required this.onLogout, required this.onCbt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(children: [
        ListTile(leading: const Icon(Icons.calendar_month), title: const Text('Timetable'), onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _LmsTimetablePage()));
        }),
        ListTile(leading: const Icon(Icons.qr_code_scanner), title: const Text('Attendance'), onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _LmsAttendancePage()));
        }),
        ListTile(leading: const Icon(Icons.message), title: const Text('Messages'), onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const _LmsMessagesPage()));
        }),
        ListTile(leading: const Icon(Icons.school), title: const Text('Take Exam (CBT)'), onTap: onCbt),
        const Divider(),
        ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Sign Out', style: TextStyle(color: Colors.red)), onTap: onLogout),
      ]),
    );
  }
}

class _LmsTimetablePage extends StatelessWidget {
  const _LmsTimetablePage();
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Timetable')),
      body: FutureBuilder<List<dynamic>>(
        future: LmsApiClient.get('/timetable').then((r) => (r.data as List<dynamic>?) ?? []),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final Map<int, List<dynamic>> grouped = {};
          for (final e in (snap.data ?? [])) { final m = e as Map<String, dynamic>; grouped.putIfAbsent(m['dayOfWeek'] as int? ?? 0, () => []).add(m); }
          return ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(7, (i) {
              final entries = grouped[i + 1] ?? [];
              return SizedBox(
                width: 130,
                child: Card(
                  child: Column(children: [
                    Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Theme.of(ctx).colorScheme.primaryContainer,
                      child: Text(_days[i], style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ...entries.map((e) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${e['startTime']}-${e['endTime']}', style: const TextStyle(fontSize: 11)),
                        Text(e['type'] as String? ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(e['room'] as String? ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ]),
                    )),
                  ]),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _LmsAttendancePage extends StatelessWidget {
  const _LmsAttendancePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: FutureBuilder<List<dynamic>>(
        future: LmsApiClient.get('/attendance/sessions').then((r) => (r.data as List<dynamic>?) ?? []),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR to Check In'),
                onPressed: () => _scanQr(context),
              ),
            ),
            ...(snap.data ?? []).map((s) => ListTile(
              leading: const Icon(Icons.event),
              title: Text((s as Map)['date']?.toString() ?? ''),
              subtitle: Text('${s['startTime'] ?? ''}'),
              trailing: FilledButton.tonal(
                onPressed: () async {
                  try {
                    await LmsApiClient.post('/attendance/sessions/${s['id']}/checkin',
                      data: {'checkInMethod': 'qr'});
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Checked in!')));
                  } catch (_) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Check-in failed')));
                  }
                },
                child: const Text('Check In'),
              ),
            )),
          ]);
        },
      ),
    );
  }

  void _scanQr(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('QR Check-in'),
        content: const TextField(decoration: InputDecoration(labelText: 'Paste QR code value')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () { Navigator.pop(c); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Check-in submitted'))); }, child: const Text('Submit')),
        ],
      ),
    );
  }
}

class _LmsMessagesPage extends StatelessWidget {
  const _LmsMessagesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<dynamic>>(
        future: LmsApiClient.get('/messages').then((r) => (r.data as List<dynamic>?) ?? []),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New Message'),
                onPressed: () => _newMessage(ctx),
              ),
            ),
            ...(snap.data ?? []).map((m) => ListTile(
              leading: const Icon(Icons.message),
              title: Text((m as Map)['content']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(m['createdAt']?.toString() ?? ''),
              trailing: !(m['isRead'] as bool? ?? true) ? const Icon(Icons.circle, size: 8, color: Colors.blue) : null,
            )),
          ]);
        },
      ),
    );
  }

  void _newMessage(BuildContext ctx) {
    final recipientCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('New Message'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: recipientCtrl, decoration: const InputDecoration(labelText: 'Recipient ID')),
          const SizedBox(height: 8),
          TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Message'), maxLines: 3),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            try {
              await LmsApiClient.post('/messages', data: {'recipientId': recipientCtrl.text, 'content': contentCtrl.text});
              Navigator.pop(c);
            } catch (_) {}
          }, child: const Text('Send')),
        ],
      ),
    );
  }
}
