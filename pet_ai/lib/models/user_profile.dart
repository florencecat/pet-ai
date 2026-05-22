import 'package:uuid/uuid.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String city;
  final bool emailVerified;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.city = '',
    this.emailVerified = false,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? city,
    bool? emailVerified,
  }) => UserProfile(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    city: city ?? this.city,
    emailVerified: emailVerified ?? this.emailVerified,
  );

  factory UserProfile.create({
    required String name,
    required String email,
    String city = '',
  }) => UserProfile(
    id: const Uuid().v4(),
    name: name,
    email: email,
    city: city,
    emailVerified: false,
  );

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    city: json['city'] as String? ?? '',
    emailVerified: json['emailVerified'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'city': city,
    'emailVerified': emailVerified,
  };
}
