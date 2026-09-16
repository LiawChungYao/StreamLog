import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._privateConstructor();

  static final GoogleAuthService instance =
    GoogleAuthService._privateConstructor();


  GoogleSignInAccount? _user;

  GoogleSignInAccount? get user => _user!;

  Future<GoogleSignInAccount> requireUser() async {
    if (_user != null) {
      return _user!;
    }

    final user = await silent_login();

    if (user == null) {
      throw Exception('Not authenticated');
    }

    return user;
  }

  Future<GoogleSignInAuthentication> getAuthentication() async {
    final user = await requireUser();

    return user.authentication;
  }
  
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets',
    ],
  );


  Future<GoogleSignInAccount?> login() async {

    final user = await googleSignIn.signIn();

    return user!;
  }

  Future<GoogleSignInAccount?> silent_login() async {

    final user = await googleSignIn.signInSilently();

    return user!;
  }

}