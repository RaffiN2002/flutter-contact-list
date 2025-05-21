// account_settings.dart
import 'dart:io'; // Required for File operations when picking images

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore database operations
import 'package:image_picker/image_picker.dart'; // For picking images from gallery

// NEW: Import the cloudinary_public package
import 'package:cloudinary_public/cloudinary_public.dart';

// Removed FirebaseStorage as we're using CloudinaryPublic for PFP upload
// Removed previous modular Cloudinary imports (cloudinary_flutter, cloudinary_url_gen, cloudinary_api)

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Removed final FirebaseStorage _storage; // No longer needed for PFP upload

  // NEW: CloudinaryPublic instance
  // REPLACE 'YOUR_CLOUD_NAME' and 'YOUR_UPLOAD_PRESET' with your actual Cloudinary credentials
  final cloudinary = CloudinaryPublic(
    'dodhpqiu7', // Your Cloud Name (from Cloudinary Dashboard)
    'firebase_pfp_upload', // Your Unsigned Upload Preset (from Cloudinary Settings -> Upload)
    cache: false, // Set to true if you want to cache upload responses
  );

  // Text controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Variables to hold profile data
  String _email = ''; // Will be populated from Firebase Auth
  String _profileImageUrl = ''; // Will be populated from Firestore (accountPFP)
  String _role = ''; // For accountRole from Firestore

  bool _isLoading = true; // State to manage loading indicator
  // State variables to control edit mode for name and phone number
  bool _isNameEditing = false;
  bool _isPhoneEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData(); // Load data when the widget is initialized
  }

  @override
  void dispose() {
    // Dispose controllers when the widget is removed to prevent memory leaks
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Function to fetch profile data from Firestore
  // It retrieves the document for the current user's UID from 'user_profile' collection.
  Future<Map<String, dynamic>?> getProfileData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint("getProfileData: No current user logged in. Cannot fetch profile.");
        return null;
      }

      final DocumentSnapshot profileDoc = await _firestore
          .collection('user_profile')
          .doc(currentUser.uid)
          .get();

      if (profileDoc.exists) {
        debugPrint("getProfileData: Profile document found for UID: ${currentUser.uid}");
        return profileDoc.data() as Map<String, dynamic>?;
      } else {
        debugPrint("getProfileData: Profile document NOT found for UID: ${currentUser.uid}");
        return null;
      }
    } catch (e) {
      debugPrint("getProfileData: Error fetching profile data: $e");
      return null;
    }
  }

  // Loads profile data and populates text controllers and image URL.
  // It uses the field names 'accountName', 'accountPhoneNum', 'accountPFP', 'accountRole' from Firestore.
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      _email = currentUser.email ?? 'N/A'; // Get email from Firebase Authentication

      final profileData = await getProfileData();
      if (profileData != null) {
        _nameController.text = profileData['accountName'] ?? ''; // Populate name
        _phoneController.text = profileData['accountPhoneNum'] ?? ''; // Populate phone number
        _profileImageUrl = profileData['accountPFP'] ?? ''; // Populate profile picture URL
        _role = profileData['accountRole'] ?? 'User'; // Populate role from Firestore
      } else {
        _nameController.text = '';
        _phoneController.text = '';
        _profileImageUrl = '';
        _role = 'User'; // Default role if no profile data
      }
    }
    setState(() {
      _isLoading = false; // Stop loading
    });
  }

  // Updates profile data in Firestore.
  // Only 'accountName' and 'accountPhoneNum' are updated.
  // This function is ONLY called by the "Save Changes" button.
  Future<void> _updateProfileData() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("updateProfileData: No current user logged in.");
      _showMessage('Error: No user logged in.');
      return;
    }

    try {
      await _firestore.collection('user_profile').doc(currentUser.uid).set(
        {
          'accountName': _nameController.text.trim(), // Update name
          'accountPhoneNum': _phoneController.text.trim(), // Update phone number
        },
        SetOptions(merge: true), // Use merge to update only the specified fields without overwriting others
      );
      _showMessage('Profile updated successfully!');
      debugPrint("Profile updated successfully for UID: ${currentUser.uid}");

      // After successful save, return to home
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      _showMessage('Failed to update profile: $e');
      debugPrint("Failed to update profile: $e");
    } finally {
      // Ensure editing modes are off after saving attempt
      setState(() {
        _isNameEditing = false;
        _isPhoneEditing = false;
        // Optionally unfocus any active text field
        FocusScope.of(context).unfocus();
      });
    }
  }

  // Allows user to pick an image from gallery, uploads it to Cloudinary (using cloudinary_public),
  // and saves the download URL to the 'accountPFP' field in Firestore.
  Future<void> _pickAndUploadProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      debugPrint("No image selected.");
      return;
    }

    final file = File(image.path);
    final int fileSizeInBytes = await file.length();
    if (fileSizeInBytes > 10 * 1024 * 1024) { // 10MB limit check
      _showMessage('Image size exceeds 10MB limit. Please choose a smaller image.');
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator during upload
    });

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("No current user logged in. Cannot upload profile picture.");
      _showMessage('Error: No user logged in.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // CloudinaryPublic upload logic
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image, // Correct enum for cloudinary_public
          folder: 'profile_pictures/${currentUser.uid}', // Optional: Organize in user-specific folders
        ),
      );

      final imageUrl = response.secureUrl; // Get the secure URL from the response

      // Save the URL to Firestore (accountPFP)
      await _firestore.collection('user_profile').doc(currentUser.uid).set(
        {
          'accountPFP': imageUrl, // Save to accountPFP in Firestore
        },
        SetOptions(merge: true), // Use merge to update only this field
      );

      setState(() {
        _profileImageUrl = imageUrl; // Update UI with new image URL
        _isLoading = false; // Hide loading indicator
      });
      _showMessage('Profile picture updated!');
      debugPrint("Profile picture updated to: $imageUrl");
    } catch (e) {
      _showMessage('Failed to upload profile picture: $e');
      debugPrint("Failed to upload profile picture: $e");
    } finally {
      setState(() {
        _isLoading = false; // Ensure loading indicator is hidden
      });
    }
  }

  // Helper function to display a SnackBar message to the user
  void _showMessage(String message) {
    if (!mounted) return; // Check if the widget is still in the tree
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.lightBlue, // App bar color changed to light blue
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/home"); // Navigate back to home
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading indicator when data is being fetched/updated
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Section with editable picture
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadProfilePicture, // Tap to edit profile picture
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      // Display network image if URL exists, otherwise show camera icon
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
                        ? _nameController.text // Display current name
                        : 'Your Name', // Placeholder if name is empty
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _phoneController.text.isNotEmpty
                        ? _phoneController.text // Display current phone number
                        : 'Add your phone number', // Placeholder if phone number is empty
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Display the role from Firestore
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

            // Email Field (Non-editable)
            _buildInfoField(
              label: 'Email',
              value: _email, // Email from Firebase Auth
            ),
            const SizedBox(height: 24),

            // Name Field (Editable controlled by _isNameEditing)
            _buildEditableField(
              label: 'Name',
              controller: _nameController,
              isEditing: _isNameEditing,
              onTapEdit: () {
                setState(() {
                  _isNameEditing = !_isNameEditing; // Toggle edit mode
                  // If entering edit mode, focus the text field
                  if (_isNameEditing) {
                    FocusScope.of(context).requestFocus(FocusNode());
                  } else {
                    // If exiting edit mode, unfocus
                    FocusScope.of(context).unfocus();
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            // Phone Number Field (Editable controlled by _isPhoneEditing)
            _buildEditableField(
              label: 'Add your phone number',
              controller: _phoneController,
              keyboardType: TextInputType.phone, // Set keyboard type for phone numbers
              isEditing: _isPhoneEditing,
              onTapEdit: () {
                setState(() {
                  _isPhoneEditing = !_isPhoneEditing; // Toggle edit mode
                  // If entering edit mode, focus the text field
                  if (_isPhoneEditing) {
                    FocusScope.of(context).requestFocus(FocusNode());
                  } else {
                    // If exiting edit mode, unfocus
                    FocusScope.of(context).unfocus();
                  }
                });
              },
            ),
            const SizedBox(height: 24),

            // Save Changes Button (always visible)
            Center(
              child: ElevatedButton(
                onPressed: _updateProfileData, // Save all changes on button press
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, // White background
                  foregroundColor: Colors.blue, // Blue text color
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // More square-ish with rounded edges
                    side: const BorderSide(color: Colors.blue), // Blue outline
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

  // Helper widget to build a non-editable information field
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
        const Divider(), // Visual separator
      ],
    );
  }

  // Helper widget to build an editable text field with an edit/check icon
  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    required bool isEditing, // Parameter to control edit state
    required VoidCallback onTapEdit, // Callback for pencil/check icon tap
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
                readOnly: !isEditing, // TextField is read-only unless isEditing is true
                enabled: isEditing, // TextField is enabled only if isEditing is true
                decoration: InputDecoration(
                  border: isEditing ? const UnderlineInputBorder() : InputBorder.none, // Show underline only when editing
                  contentPadding: EdgeInsets.zero, // Reduce padding
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                // Remove onSubmitted to prevent automatic saving on enter key press
              ),
            ),
            IconButton(
              icon: Icon(isEditing ? Icons.check : Icons.edit, color: Colors.grey), // Change icon based on edit mode
              onPressed: () {
                onTapEdit(); // Toggle edit mode on icon tap
              },
            ),
          ],
        ),
        const Divider(), // Visual separator
      ],
    );
  }
}