import 'dart:async';
import 'dart:html' as html;

const _scriptId = 'plogo-google-maps-sdk';
Completer<void>? _loader;

Future<void> ensureGoogleMapsLoaded(String apiKey) {
  if (apiKey.isEmpty) {
    return Future.error(
      StateError('GOOGLE_MAPS_API_KEY manquante pour le build web.'),
    );
  }

  final existingScript = html.document.getElementById(_scriptId);
  if (existingScript != null && _loader == null) {
    // Le script est déjà présent (ex: hot reload). Considérer comme chargé.
    return Future.value();
  }

  final completer = _loader ??= Completer<void>();
  if (completer.isCompleted) {
    return completer.future;
  }

  final script = html.ScriptElement()
    ..id = _scriptId
    ..type = 'text/javascript'
    ..async = true
    ..defer = true
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=$apiKey&libraries=places';

  script.onError.listen((event) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError(
          'Impossible de charger le SDK Google Maps (clé invalide ou domaine non autorisé).',
        ),
      );
      _loader = null;
    }
  });

  script.onLoad.listen((event) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });

  html.document.head?.append(script);
  return completer.future;
}
