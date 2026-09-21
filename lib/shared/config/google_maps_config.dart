/// Google Maps Platform credentials.
///
/// Kept in one file so the key can be found and rotated without hunting
/// through call sites, the same way `catalog_firebase.dart` holds the
/// Firebase options.
///
/// **This key is only authorised for the Geocoding API.** Static Maps and
/// Places both return REQUEST_DENIED, so the map picker still draws
/// OpenStreetMap tiles through `flutter_map` — see `location_picker_page.dart`.
/// Enabling "Maps SDK for Android" on this key is what would allow swapping
/// those tiles for Google's.
///
/// **On keeping it safe:** a key shipped inside an app can be extracted from
/// the APK — that is true of every mobile Maps key, and Google's guidance
/// accepts it. The important part is that the damage is bounded, because
/// Android package-name restrictions do *not* apply to the Geocoding **web
/// service**; only IP restrictions do, and an app has no fixed IP. So the
/// protection that actually works here is a quota cap:
///
///   Cloud Console → APIs & Services → Geocoding API → Quotas
///   → set a daily request limit
///
/// Without that, a leaked key can be used until the billing account stops it.
library;

const String googleGeocodingApiKey = 'AIzaSyBuNeSp9nFFImMvMPiV7UQMh_ykbiwsZN0';
