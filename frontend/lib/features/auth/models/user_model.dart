class UserModel {
  final int id;
  final String email;
  final String name;
  final String? profilePic;
  final String? location;
  final String createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.profilePic,
    this.location,
    required this.createdAt,
  });

  // JSON → UserModel (from Django response)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      profilePic: json['profile_pic'],
      location: json['location'],
      createdAt: json['created_at'],
    );
  }
}
