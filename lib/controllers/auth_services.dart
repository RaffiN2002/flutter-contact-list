import 'package:firebase_auth/firebase_auth.dart';

class AuthService{
  Future <String> loginWithEmail(String email, String password) async{
    try{
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      return "Login Successful";
    } on FirebaseAuthException catch(e){
      return e.message.toString();
    }
  }

  Future logout() async{
    await FirebaseAuth.instance.signOut();
  }

  Future <bool> isLoggedIn() async{
    var user = FirebaseAuth.instance.currentUser;
    return user != null;
  }

  Future<String> createAccountWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      return "Account Created";
    } on FirebaseAuthException catch (e) {
      return e.message.toString();
    }
  }
}