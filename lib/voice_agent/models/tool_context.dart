class ToolContext {
  final void Function(String route) navigate;
  final String? userId;
  final String? userRole;
  final String? userType;
  final String? displayName;
  final String? profileCity;
  final bool isAdmin;
  final bool isSuperAdmin;

  const ToolContext({
    required this.navigate,
    this.userId,
    this.userRole,
    this.userType,
    this.displayName,
    this.profileCity,
    this.isAdmin = false,
    this.isSuperAdmin = false,
  });
}
