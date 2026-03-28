class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters.');
    }

    await Future.delayed(const Duration(milliseconds: 900));
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedName.length < 2) {
      throw const AuthException('Please enter your full name.');
    }
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw const AuthException('Please enter a valid email address.');
    }
    if (password.length < 8) {
      throw const AuthException('Password must be at least 8 characters.');
    }

    await Future.delayed(const Duration(milliseconds: 1000));
  }
}
