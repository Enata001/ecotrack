import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/app_sizes.dart';
import '../../core/models/geo_point_data.dart';

/// Renders the live pickup destination and the collector's live-updating
/// position on a real Google Map, animating the collector marker and
/// camera as new [collectorLocation] values stream in. This replaces
/// FlutterFlow's built-in GoogleMap widget, which can't animate a marker
/// between live-updating points on its own.
class LiveTrackingMap extends StatefulWidget {
  final GeoPointData destination;
  final GeoPointData? collectorLocation;

  const LiveTrackingMap({
    super.key,
    required this.destination,
    required this.collectorLocation,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  late AnimationController _animController;
  LatLng? _animatedCollectorLatLng;
  LatLng? _lastCollectorLatLng;
  LatLng _animFrom = const LatLng(0, 0);
  LatLng _animTo = const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
        setState(() {
          _animatedCollectorLatLng = LatLng(
            _animFrom.latitude +
                (_animTo.latitude - _animFrom.latitude) * _animController.value,
            _animFrom.longitude +
                (_animTo.longitude - _animFrom.longitude) * _animController.value,
          );
        });
      });
    if (widget.collectorLocation != null) {
      _lastCollectorLatLng = _toLatLng(widget.collectorLocation!);
      _animatedCollectorLatLng = _lastCollectorLatLng;
    }
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLocation = widget.collectorLocation;
    if (newLocation == null) return;

    final newLatLng = _toLatLng(newLocation);
    _animFrom = _lastCollectorLatLng ?? newLatLng;
    _animTo = newLatLng;
    _lastCollectorLatLng = newLatLng;

    _animController
      ..reset()
      ..forward();

    _fitBounds(from: newLatLng);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  LatLng _toLatLng(GeoPointData point) => LatLng(point.latitude, point.longitude);

  Future<void> _fitBounds({required LatLng from}) async {
    final controller = _controller;
    if (controller == null) return;

    final destinationLatLng = _toLatLng(widget.destination);
    final southwest = LatLng(
      from.latitude < destinationLatLng.latitude ? from.latitude : destinationLatLng.latitude,
      from.longitude < destinationLatLng.longitude
          ? from.longitude
          : destinationLatLng.longitude,
    );
    final northeast = LatLng(
      from.latitude > destinationLatLng.latitude ? from.latitude : destinationLatLng.latitude,
      from.longitude > destinationLatLng.longitude
          ? from.longitude
          : destinationLatLng.longitude,
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: southwest, northeast: northeast),
        64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinationLatLng = _toLatLng(widget.destination);
    final collectorLatLng = _animatedCollectorLatLng;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('destination'),
        position: destinationLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Pickup location'),
      ),
      if (collectorLatLng != null)
        Marker(
          markerId: const MarkerId('collector'),
          position: collectorLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Collector'),
        ),
    };

    final polylines = <Polyline>{
      if (collectorLatLng != null)
        Polyline(
          polylineId: const PolylineId('collector-to-destination'),
          points: [collectorLatLng, destinationLatLng],
          color: Theme.of(context).colorScheme.primary,
          width: 3,
          patterns: [PatternItem.dash(12), PatternItem.gap(8)],
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: SizedBox(
        height: 280,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: destinationLatLng, zoom: 15),
          markers: markers,
          polylines: polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
            if (collectorLatLng != null) {
              _fitBounds(from: collectorLatLng);
            }
          },
        ),
      ),
    );
  }
}
