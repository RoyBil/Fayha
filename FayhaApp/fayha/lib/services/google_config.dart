/// Single Google Cloud API key shared by the Bus Routes feature:
///   * Directions API — generates real-road polylines when admins
///     create or edit a route.
///   * Places API     — autocomplete search for stop locations
///     (universities, landmarks, cafés, …).
///
/// Leave [apiKey] as an empty string in dev: the app degrades
/// gracefully — routes fall back to straight lines between waypoints
/// and the Places search sheet shows a "needs API key" hint.
///
/// To enable: paste a key here, then in Google Cloud Console enable
/// "Directions API" + "Places API" on the same project.
class GoogleConfig {
  static const String apiKey = '';
}
