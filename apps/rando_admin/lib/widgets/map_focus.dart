import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A request to recenter the overview map, e.g. from the "Voir sur la carte"
/// action of the Signalements/Éléments screens. [nonce] always changes so
/// listeners react even when asked to focus the exact same point twice.
class MapFocusRequest {
  MapFocusRequest(this.point, this.nonce, {this.title});
  final LatLng point;
  final int nonce;
  final String? title;
}

class MapFocusController extends ChangeNotifier {
  MapFocusRequest? request;
  int _nonce = 0;

  void focusOn(LatLng point, {String? title}) {
    _nonce++;
    request = MapFocusRequest(point, _nonce, title: title);
    notifyListeners();
  }
}
