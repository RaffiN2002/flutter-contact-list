import 'dart:async';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String _accountName = "";
  String _accountEmail = "";
  String _profileImageUrl = "";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _pollTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndStartPolling();
    _loadProfileData();
  }

  Future<void> _requestPermissionsAndStartPolling() async {
    final phoneGranted = await Permission.phone.request().isGranted;
    if (phoneGranted) {
      await _saveNewCallLogs();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 10),
            (_) => _saveNewCallLogs(),
      );
    } else {
      debugPrint('Phone permission denied');
    }
  }

  Future<int> _getLastSavedTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lastSavedTimestamp') ?? 0;
  }

  Future<void> _setLastSavedTimestamp(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSavedTimestamp', timestamp);
  }

  Future<void> _saveNewCallLogs() async {
    try {
      final Iterable<CallLogEntry> entries = await CallLog.get();
      final userId = _auth.currentUser?.uid ?? "unknown";
      final lastSaved = await _getLastSavedTimestamp();
      int maxTimestamp = lastSaved;

      for (var entry in entries) {
        final timestamp = entry.timestamp ?? 0;

        if (entry.callType == CallType.incoming && timestamp > lastSaved) {
          final timestampObj = Timestamp.fromMillisecondsSinceEpoch(timestamp);

          final existing = await FirebaseFirestore.instance
              .collection('call_logs')
              .where('timestamp', isEqualTo: timestampObj)
              .where('receiverUserId', isEqualTo: userId)
              .limit(1)
              .get();

          if (existing.docs.isEmpty) {
            await FirebaseFirestore.instance.collection('call_logs').add({
              'phoneNumber': entry.number ?? '',
              'callType': 'incoming',
              'timestamp': timestampObj,
              'receiverUserId': userId,
              'duration': entry.duration ?? 0,
              'userId': userId,
              'name': entry.name ?? '',
            });

            if (timestamp > maxTimestamp) {
              maxTimestamp = timestamp;
            }
          } else {
            debugPrint("Duplicate call log found — skipping save.");
          }
        }
      }

      if (maxTimestamp > lastSaved) {
        await _setLastSavedTimestamp(maxTimestamp);
      }
    } catch (e) {
      debugPrint('Error saving call logs: $e');
    }
  }

  void _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  Future<Map<String, dynamic>?> getProfileData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return null;
      }

      final DocumentSnapshot profileDoc = await _firestore
          .collection('user_profile')
          .doc(currentUser.uid)
          .get();

      if (profileDoc.exists) {
        return profileDoc.data() as Map<String, dynamic>?;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadProfileData() async {
    try {
      final Map<String, dynamic>? profileData = await getProfileData();
      if (mounted) {
        setState(() {
          if (profileData != null) {
            _accountName = profileData['accountName'] ?? "User Name Not Set";
            _accountEmail = profileData['accountEmail'] ?? "Email Not Set";
            _profileImageUrl = profileData['accountPFP'] ?? '';
          } else {
            _accountName = "Guest User";
            _accountEmail = _auth.currentUser?.email ?? "No Email (Logged Out)";
            _profileImageUrl = '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error in _loadProfileData: $e");
      if (mounted) {
        setState(() {
          _accountName = "Error";
          _accountEmail = "Failed to load profile data.";
          _profileImageUrl = '';
          _isLoading = false;
        });
      }
    }
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
              accountName: Text(_isLoading ? "Loading..." : _accountName),
              accountEmail: Text(_isLoading ? "Loading..." : _accountEmail),
              currentAccountPicture: _profileImageUrl.isNotEmpty
                  ? CircleAvatar(
                backgroundImage: NetworkImage(_profileImageUrl),
                backgroundColor: Colors.white,
              )
                  : CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Account Settings"),
              onTap: () {Navigator.pushReplacementNamed(context, "/accountSettings");},
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Contacts"),
        backgroundColor: Colors.lightBlue,
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
                final docSnapshot = docs[index];
                final data = docSnapshot.data() as Map<String, dynamic>?;

                if (data == null) {
                  return const ListTile(title: Text('No data'));
                }

                final phoneNumber = data['phoneNumber'] ?? 'Unknown';
                final callType = data['callType'] ?? 'unknown';
                final timestampRaw = data['timestamp'];
                DateTime timestamp = (timestampRaw is Timestamp)
                    ? timestampRaw.toDate()
                    : DateTime.now();
                final duration = data['duration'] ?? 0;
                final name = data['name'] ?? '';

                return ListTile(
                  leading: Icon(
                    callType == 'incoming'
                        ? Icons.call_received
                        : callType == 'outgoing'
                        ? Icons.call_made
                        : Icons.call_missed,
                    color: callType == 'missed' ? Colors.red : Colors.green,
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      Text(phoneNumber),
                    ],
                  ),
                  subtitle: Text(
                    '${callType[0].toUpperCase()}${callType.substring(1)} • ${timestamp
                        .toLocal()} • Duration: ${duration}s',
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