import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_contact_list/views/account_settings.dart';
import 'package:flutter_contact_list/views/home.dart';
import 'firebase_options.dart';
import 'views/login_page.dart';
import 'views/sign_up_page.dart';


import 'package:cloudinary_url_gen/cloudinary.dart'; // For the Cloudinary object

const String CLOUD_NAME = 'dodhpqiu7';
const String UPLOAD_PRESET = 'firebase_pfp_upload';

final Cloudinary cloudinary = Cloudinary.fromCloudName(
  cloudName: CLOUD_NAME,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
      ),
      routes: {
        "/": (context) => LoginPage(),
        "/home": (context) => Homepage(),
        "/login": (context) => LoginPage(),
        "/signup": (context) => SignUpPage(),
        "/accountSettings": (context) => AccountSettingsPage(),
      },
    );
  }
}
