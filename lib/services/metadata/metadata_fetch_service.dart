import 'package:aves/model/entry.dart';
import 'package:aves/model/metadata/catalog.dart';
import 'package:aves/model/metadata/overlay.dart';
import 'package:aves/model/multipage.dart';
import 'package:aves/model/panorama.dart';
import 'package:aves/services/common/service_policy.dart';
import 'package:aves/services/common/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract class MetadataFetchService {
  // returns Map<Map<Key, Value>> (map of directories, each directory being a map of metadata label and value description)
  Future<Map> getAllMetadata(AvesEntry entry);

  Future<CatalogMetadata?> getCatalogMetadata(AvesEntry entry, {bool background = false});

  Future<OverlayMetadata?> getOverlayMetadata(AvesEntry entry);

  Future<MultiPageInfo?> getMultiPageInfo(AvesEntry entry);

  Future<PanoramaInfo?> getPanoramaInfo(AvesEntry entry);

  Future<bool> hasContentResolverProp(String prop);

  Future<String?> getContentResolverProp(AvesEntry entry, String prop);
}

class PlatformMetadataFetchService implements MetadataFetchService {
  static const platform = MethodChannel('deckers.thibault/aves/metadata_fetch');

  @override
  Future<Map> getAllMetadata(AvesEntry entry) async {
    if (entry.isSvg) return {};

    try {
      final result = await platform.invokeMethod('getAllMetadata', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      });
      if (result != null) return result as Map;
    } on PlatformException catch (e, stack) {
      if (!entry.isMissingAtPath) {
        await reportService.recordError(e, stack);
      }
    }
    return {};
  }

  @override
  Future<CatalogMetadata?> getCatalogMetadata(AvesEntry entry, {bool background = false}) async {
    if (entry.isSvg) return null;

    Future<CatalogMetadata?> call() async {
      try {
        // returns map with:
        // 'mimeType': MIME type as reported by metadata extractors, not Media Store (string)
        // 'dateMillis': date taken in milliseconds since Epoch (long)
        // 'isAnimated': animated gif/webp (bool)
        // 'isFlipped': flipped according to EXIF orientation (bool)
        // 'rotationDegrees': rotation degrees according to EXIF orientation or other metadata (int)
        // 'latitude': latitude (double)
        // 'longitude': longitude (double)
        // 'xmpSubjects': ';' separated XMP subjects (string)
        // 'xmpTitleDescription': XMP title or XMP description (string)
        final result = await platform.invokeMethod('getCatalogMetadata', <String, dynamic>{
          'mimeType': entry.mimeType,
          'uri': entry.uri,
          'path': entry.path,
          'sizeBytes': entry.sizeBytes,
        }) as Map;
        result['contentId'] = entry.contentId;
        return CatalogMetadata.fromMap(result);
      } on PlatformException catch (e, stack) {
        if (!entry.isMissingAtPath) {
          await reportService.recordError(e, stack);
        }
      }
      return null;
    }

    return background
        ? servicePolicy.call(
            call,
            priority: ServiceCallPriority.getMetadata,
          )
        : call();
  }

  @override
  Future<OverlayMetadata?> getOverlayMetadata(AvesEntry entry) async {
    if (entry.isSvg) return null;

    try {
      // returns map with values for: 'aperture' (double), 'exposureTime' (description), 'focalLength' (double), 'iso' (int)
      final result = await platform.invokeMethod('getOverlayMetadata', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      }) as Map;
      return OverlayMetadata.fromMap(result);
    } on PlatformException catch (e, stack) {
      if (!entry.isMissingAtPath) {
        await reportService.recordError(e, stack);
      }
    }
    return null;
  }

  @override
  Future<MultiPageInfo?> getMultiPageInfo(AvesEntry entry) async {
    try {
      final result = await platform.invokeMethod('getMultiPageInfo', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      });
      final pageMaps = ((result as List?) ?? []).cast<Map>();
      if (entry.isMotionPhoto && pageMaps.isNotEmpty) {
        final imagePage = pageMaps[0];
        imagePage['width'] = entry.width;
        imagePage['height'] = entry.height;
        imagePage['rotationDegrees'] = entry.rotationDegrees;
      }
      return MultiPageInfo.fromPageMaps(entry, pageMaps);
    } on PlatformException catch (e, stack) {
      if (!entry.isMissingAtPath) {
        await reportService.recordError(e, stack);
      }
    }
    return null;
  }

  @override
  Future<PanoramaInfo?> getPanoramaInfo(AvesEntry entry) async {
    try {
      // returns map with values for:
      // 'croppedAreaLeft' (int), 'croppedAreaTop' (int), 'croppedAreaWidth' (int), 'croppedAreaHeight' (int),
      // 'fullPanoWidth' (int), 'fullPanoHeight' (int)
      final result = await platform.invokeMethod('getPanoramaInfo', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'sizeBytes': entry.sizeBytes,
      }) as Map;
      return PanoramaInfo.fromMap(result);
    } on PlatformException catch (e, stack) {
      if (!entry.isMissingAtPath) {
        await reportService.recordError(e, stack);
      }
    }
    return null;
  }

  final Map<String, bool> _contentResolverProps = {};

  @override
  Future<bool> hasContentResolverProp(String prop) async {
    var exists = _contentResolverProps[prop];
    if (exists != null) return SynchronousFuture(exists);

    try {
      exists = await platform.invokeMethod('hasContentResolverProp', <String, dynamic>{
        'prop': prop,
      });
    } on PlatformException catch (e, stack) {
      await reportService.recordError(e, stack);
    }
    exists ??= false;
    _contentResolverProps[prop] = exists;
    return exists;
  }

  @override
  Future<String?> getContentResolverProp(AvesEntry entry, String prop) async {
    try {
      return await platform.invokeMethod('getContentResolverProp', <String, dynamic>{
        'mimeType': entry.mimeType,
        'uri': entry.uri,
        'prop': prop,
      });
    } on PlatformException catch (e, stack) {
      if (!entry.isMissingAtPath) {
        await reportService.recordError(e, stack);
      }
    }
    return null;
  }
}