class UserModel {
  final int userId;
  final String email;
  final String? nickname;
  final String? profileImageUrl;

  const UserModel({
    required this.userId,
    required this.email,
    this.nickname,
    this.profileImageUrl,
  });

  bool get hasNickname => nickname != null && nickname!.isNotEmpty;

  UserModel copyWith({
    int? userId,
    String? email,
    String? nickname,
    String? profileImageUrl,
  }) =>
      UserModel(
        userId: userId ?? this.userId,
        email: email ?? this.email,
        nickname: nickname ?? this.nickname,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      );

  // POST /auth/google 응답: { accessToken, refreshToken, userId }
  // 유저 상세 정보는 별도 GET /users/me 로 가져옴 (명세 추후 확인 필요)
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        userId: json['userId'] as int,
        email: json['email'] as String? ?? '',
        nickname: json['nickname'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
      };
}
