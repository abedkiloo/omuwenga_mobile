import 'permission_set.dart';
import 'persona.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.isSuperuser = false,
  });

  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final bool isSuperuser;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      isSuperuser: json['is_superuser'] == true,
    );
  }

  String get displayName {
    final parts = [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty);
    if (parts.isEmpty) return username;
    return parts.join(' ');
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.profile,
    required this.permissions,
    required this.persona,
  });

  final AuthUser user;
  final UserProfileSnapshot profile;
  final PermissionSet permissions;
  final AppPersona persona;

  factory AuthSession.fromAuthPayload(Map<String, dynamic> json) {
    final userJson = Map<String, dynamic>.from(json['user'] as Map? ?? {});
    final profileJson = json['profile'] is Map
        ? Map<String, dynamic>.from(json['profile'] as Map)
        : null;
    final permissions = PermissionSet.fromJsonList(json['permissions'] as List?);
    final user = AuthUser.fromJson(userJson);
    final profile = UserProfileSnapshot.fromJson(profileJson);
    final persona = resolvePersona(
      profile: profile,
      permissions: permissions,
      isSuperuser: user.isSuperuser || json['is_super_admin'] == true,
    );
    return AuthSession(
      user: user,
      profile: profile,
      permissions: permissions,
      persona: persona,
    );
  }
}
