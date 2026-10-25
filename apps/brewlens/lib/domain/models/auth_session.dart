/// جلسة المستخدم. لا اسم عرض (أقل بيانات).
class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['user_id'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {'user_id': userId, 'email': email};
}
