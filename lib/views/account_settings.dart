import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloudinary_public/cloudinary_public.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final cloudinary = CloudinaryPublic(
    'dodhpqiu7',
    'firebase_pfp_upload',
    cache: false,
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _email = '';
  String _profileImageUrl = '';
  String _role = '';

  bool _isLoading = true;
  bool _isNameEditing = false;
  bool _isPhoneEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
    setState(() {
      _isLoading = true;
    });
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _email = currentUser.email ?? 'N/A';

      final profileData = await getProfileData();
      if (profileData != null) {
        _nameController.text = profileData['accountName'] ?? '';
        _phoneController.text = profileData['accountPhoneNum'] ?? '';
        _profileImageUrl = profileData['accountPFP'] ?? '';
        _role = profileData['accountRole'] ?? 'User';
      } else {
        _nameController.text = '';
        _phoneController.text = '';
        _profileImageUrl = '';
        _role = 'User';
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateProfileData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showMessage('Error: No user logged in.');
      return;
    }

    try {
      await _firestore.collection('user_profile').doc(currentUser.uid).set(
        {
          'accountName': _nameController.text.trim(),
          'accountPhoneNum': _phoneController.text.trim(),
        },
        SetOptions(merge: true),
      );
      _showMessage('Profile updated successfully!');

      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      _showMessage('Failed to update profile: $e');
    } finally {
      setState(() {
        _isNameEditing = false;
        _isPhoneEditing = false;
        FocusScope.of(context).unfocus();
      });
    }
  }

  Future<void> _pickAndUploadProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      return;
    }

    final file = File(image.path);
    final int fileSizeInBytes = await file.length();
    if (fileSizeInBytes > 10 * 1024 * 1024) {
      _showMessage('Image size exceeds 10MB limit. Please choose a smaller image.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showMessage('Error: No user logged in.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'profile_pictures/${currentUser.uid}',
        ),
      );

      final imageUrl = response.secureUrl;

      await _firestore.collection('user_profile').doc(currentUser.uid).set(
        {
          'accountPFP': imageUrl,
        },
        SetOptions(merge: true),
      );

      setState(() {
        _profileImageUrl = imageUrl;
        _isLoading = false;
      });
      _showMessage('Profile picture updated!');
    } catch (e) {
      _showMessage('Failed to upload profile picture: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.lightBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/home");
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadProfilePicture,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _profileImageUrl.isNotEmpty
                          ? NetworkImage(_profileImageUrl)
                          : null,
                      child: _profileImageUrl.isEmpty
                          ? Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Colors.grey[600],
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : 'Your Name',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _phoneController.text.isNotEmpty
                        ? _phoneController.text
                        : 'Add your phone number',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role : $_role',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),

            _buildInfoField(
              label: 'Email',
              value: _email,
            ),
            const SizedBox(height: 24),

            _buildEditableField(
              label: 'Name',
              controller: _nameController,
              isEditing: _isNameEditing,
              onTapEdit: () {
                setState(() {
                  _isNameEditing = !_isNameEditing;
                  if (_isNameEditing) {
                    FocusScope.of(context).requestFocus(FocusNode());
                  } else {
                    FocusScope.of(context).unfocus();
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            _buildEditableField(
              label: 'Add your phone number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              isEditing: _isPhoneEditing,
              onTapEdit: () {
                setState(() {
                  _isPhoneEditing = !_isPhoneEditing;
                  if (_isPhoneEditing) {
                    FocusScope.of(context).requestFocus(FocusNode());
                  } else {
                    FocusScope.of(context).unfocus();
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            Center(
              child: ElevatedButton(
                onPressed: _updateProfileData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    required bool isEditing,
    required VoidCallback onTapEdit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                readOnly: !isEditing,
                enabled: isEditing,
                decoration: InputDecoration(
                  border: isEditing ? const UnderlineInputBorder() : InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(isEditing ? Icons.check : Icons.edit, color: Colors.grey),
              onPressed: () {
                onTapEdit();
              },
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}