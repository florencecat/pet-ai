class ApiService {
  final String apiUrl;
  final String aiUrl;

  final String termsUrl;
  final String privacyUrl;

  final String usersRoute = 'users';
  final String petsRoute = 'pets';
  final String eventsRoute = 'events';

  ApiService({
    required this.apiUrl,
    required this.aiUrl,
    required this.termsUrl,
    required this.privacyUrl,
  });
}
