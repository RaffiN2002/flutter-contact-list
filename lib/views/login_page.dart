import 'package:flutter/material.dart';
import 'package:flutter_contact_list/controllers/auth_services.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/bg.jpg', // Replace with your image path
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.10, // Adjust top position as needed
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "RadioLog",
                style: GoogleFonts.sora(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: Colors.white), // White color for RadioLog
              ),
            ),
          ),
          Center(
            child: Opacity(opacity: 0.9,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Make the container wrap its content
                  children: [
                    Text("Login",
                        style: GoogleFonts.sora(
                            fontSize: 30, fontWeight: FontWeight.w700)),
                    SizedBox(
                      height: 20,
                    ),
                    TextFormField(
                      validator: (value) =>
                      value!.isEmpty ? "Email cannot be empty" : null,
                      controller: _emailController,
                      obscureText: false,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Email",
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    TextFormField(
                      validator: (value) => value!.isEmpty
                          ? "Password should have at least 8 characters"
                          : null,
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "Password",
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    SizedBox(
                      height: 50,
                      width: double.infinity, // Make the button take full width
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0), // Less round corners
                          ),// Set the background color to blue
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            AuthService()
                                .loginWithEmail(_emailController.text,
                                _passwordController.text)
                                .then((value) {
                              if (value == "Login Successful") {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Login Successful")));
                                Navigator.pushReplacementNamed(context, "/home");
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                    value,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.red.shade400,
                                ));
                              }
                            });
                          }
                        },
                        child: Text(
                          "Login",
                          style: TextStyle(fontSize: 16,color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?"),
                        TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, "/signup");
                            },
                            child: Text("Sign Up"))
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}