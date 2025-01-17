import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/props.dart';
import 'package:aves/model/geotiff.dart';
import 'package:aves/model/metadata/catalog.dart';
import 'package:aves/model/video/metadata.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/services/metadata/svg_metadata_service.dart';

extension ExtraAvesEntryCatalog on AvesEntry {
  Future<void> catalog({required bool background, required bool force, required bool persist}) async {
    if (isCatalogued && !force) return;
    if (isSvg) {
      // vector image sizing is not essential, so we should not spend time for it during loading
      // but it is useful anyway (for aspect ratios etc.) so we size them during cataloguing
      final size = await SvgMetadataService.getSize(this);
      if (size != null) {
        final fields = {
          'width': size.width.ceil(),
          'height': size.height.ceil(),
        };
        await applyNewFields(fields, persist: persist);
      }
      catalogMetadata = CatalogMetadata(id: id);
    } else {
      // pre-processing
      if (isVideo && (!isSized || durationMillis == 0)) {
        // exotic video that is not sized during loading
        final fields = await VideoMetadataFormatter.getLoadingMetadata(this);
        await applyNewFields(fields, persist: persist);
      }

      // cataloguing on platform
      catalogMetadata = await metadataFetchService.getCatalogMetadata(this, background: background);

      // post-processing
      if (isVideo && (catalogMetadata?.dateMillis ?? 0) == 0) {
        catalogMetadata = await VideoMetadataFormatter.getCatalogMetadata(this);
      }
      if (isGeotiff && !hasGps) {
        final info = await metadataFetchService.getGeoTiffInfo(this);
        if (info != null) {
          final center = MappedGeoTiff(
            info: info,
            entry: this,
          ).center;
          if (center != null) {
            catalogMetadata = catalogMetadata?.copyWith(
              latitude: center.latitude,
              longitude: center.longitude,
            );
          }
        }
      }
    }
  }
}
