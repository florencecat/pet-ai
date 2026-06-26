import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> openPrivacy() async {
    final url = GetIt.instance<ApiService>().privacyUrl;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> openTerms() async {
    final url = GetIt.instance<ApiService>().termsUrl;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
