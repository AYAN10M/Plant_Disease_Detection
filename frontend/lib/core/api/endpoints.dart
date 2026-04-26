/// Midori — API endpoint constants.
///
/// Platform notes:
///   Android emulator  → use 10.0.2.2  (maps to host machine localhost)
///   iOS simulator     → use 127.0.0.1
///   Physical device   → use your machine's local IP (e.g. 192.168.x.x)
///   Production        → replace with your deployed server URL
class Endpoints {
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // Plants
  static const String plants = '$baseUrl/plants/';
  static String plantDetail(int id) => '$baseUrl/plants/$id/';

  // Diseases
  static const String diseases = '$baseUrl/diseases/';
  static String diseaseDetail(int id) => '$baseUrl/diseases/$id/';

  // Detection
  static const String detect = '$baseUrl/detections/';

  // Weather — pass ?lat=<float>&lon=<float>
  static const String weather = '$baseUrl/weather/';
}
