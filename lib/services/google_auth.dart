import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._privateConstructor();

  static final GoogleAuthService instance =
      GoogleAuthService._privateConstructor();

  GoogleSignInAccount? _user;

  GoogleSignInAccount? get user => _user;

  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
      'https://www.googleapis.com/auth/spreadsheets',
    ],
  );

  Future<GoogleSignInAccount> requireUser() async {
    if (_user != null) {
      return _user!;
    }

    final user = await silentLogin();

    if (user == null) {
      throw Exception('Not authenticated');
    }

    return user;
  }

  Future<GoogleSignInAuthentication> getAuthentication() async {
    final user = await requireUser();

    return user.authentication;
  }

  Future<GoogleSignInAccount?> login() async {
    final user = await googleSignIn.signIn();

    _user = user;

    return user;
  }

  Future<GoogleSignInAccount?> silentLogin() async {
    final user = await googleSignIn.signInSilently();

    _user = user;

    return user;
  }

  Future<void> logout() async {
    await googleSignIn.signOut();
    _user = null;
  }
}