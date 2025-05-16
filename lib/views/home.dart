import 'dart:async';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contact_list/controllers/auth_services.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _pollTimer;
  int _lastSavedTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndStartPolling();
  }

  Future<void> _requestPermissionsAndStartPolling() async {
    final phoneGranted = await Permission.phone.request().isGranted;
    if (phoneGranted) {
      // Immediately save existing calls
      await _saveNewCallLogs();

      // Poll every 30 seconds
      _pollTimer = Timer.periodic(
        const Duration(seconds: 10),
            (_) => _saveNewCallLogs(),
      );
    } else {
      debugPrint('Phone permission denied');
    }
  }

  Future<void> _saveNewCallLogs() async {
    try {
      final Iterable<CallLogEntry> entries = await CallLog.get();
      final userId = _auth.currentUser?.uid ?? "unknown";

      for (var entry in entries) {
        final timestamp = entry.timestamp ?? 0;

        // Only process incoming calls newer than last saved timestamp
        if (entry.callType == CallType.incoming && timestamp > _lastSavedTimestamp) {
          final timestampObj = Timestamp.fromMillisecondsSinceEpoch(timestamp);

          // Check if a call log with the same timestamp and receiverUserId already exists
          final existing = await FirebaseFirestore.instance
              .collection('call_logs')
              .where('timestamp', isEqualTo: timestampObj)
              .where('receiverUserId', isEqualTo: userId)
              .limit(1)
              .get();

          if (existing.docs.isEmpty) {
            // Save new call log if no duplicate found
            await FirebaseFirestore.instance.collection('call_logs').add({
              'phoneNumber': entry.number ?? '',
              'callType': 'incoming',
              'timestamp': timestampObj,
              'receiverUserId': userId,
              'duration': entry.duration ?? 0,
              'userId': userId,
            });

            // Update last saved timestamp
            if (timestamp > _lastSavedTimestamp) {
              _lastSavedTimestamp = timestamp;
            }
          } else {
            debugPrint("Duplicate call log found — skipping save.");
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving call logs: $e');
    }
  }


  void _logout() async {
    await _auth.signOut();
    // TODO: Navigate to login screen after logout
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Test User"),
              accountEmail: const Text("testuser@example.com"),
              currentAccountPicture: CircleAvatar(
                backgroundImage: AssetImage("assets/jaundice.jpg"),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Account Settings"),
              onTap: () {}, // Add navigation if needed
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: () async {
                await AuthService().logout();
                Navigator.pushReplacementNamed(context, "/login");
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Contacts"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('call_logs')
            .where('receiverUserId', isEqualTo: _auth.currentUser?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No call logs found."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              try {
                if (index >= docs.length) {
                  return const SizedBox.shrink();
                }

                final docSnapshot = docs[index];
                final data = docSnapshot.data() as Map<String, dynamic>?;

                if (data == null) {
                  return const ListTile(title: Text('No data'));
                }

                final phoneNumber = data['phoneNumber'] ?? 'Unknown';
                final callType = data['callType'] ?? 'unknown';
                final timestampRaw = data['timestamp'];
                DateTime timestamp;

                if (timestampRaw is Timestamp) {
                  timestamp = timestampRaw.toDate();
                } else {
                  timestamp = DateTime.now(); // fallback if timestamp missing or invalid
                }

                final duration = data['duration'] ?? 0;

                return ListTile(
                  leading: Icon(
                    callType == 'incoming'
                        ? Icons.call_received
                        : callType == 'outgoing'
                        ? Icons.call_made
                        : Icons.call_missed,
                    color: callType == 'missed' ? Colors.red : Colors.green,
                  ),
                  title: Text(phoneNumber),
                  subtitle: Text(
                    '${callType[0].toUpperCase()}${callType.substring(1)} • ${timestamp.toLocal()} • Duration: ${duration}s',
                  ),
                );
              } catch (e, stack) {
                debugPrint('Error building list item: $e\n$stack');
                return const ListTile(title: Text('Error loading item'));
              }
            },
          );
        },
      ),
    );
  }
}