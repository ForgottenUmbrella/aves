import 'package:aves/model/settings/enums/enums.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves_map/aves_map.dart';
import 'package:flutter/widgets.dart';

extension ExtraAccessibilityAnimationsName on AccessibilityAnimations {
  String getName(BuildContext context) {
    switch (this) {
      case AccessibilityAnimations.system:
        return context.l10n.settingsSystemDefault;
      case AccessibilityAnimations.disabled:
        return context.l10n.accessibilityAnimationsRemove;
      case AccessibilityAnimations.enabled:
        return context.l10n.accessibilityAnimationsKeep;
    }
  }
}

extension ExtraAccessibilityTimeoutName on AccessibilityTimeout {
  String getName(BuildContext context) {
    switch (this) {
      case AccessibilityTimeout.system:
        return context.l10n.settingsSystemDefault;
      case AccessibilityTimeout.s1:
        return context.l10n.timeSeconds(1);
      case AccessibilityTimeout.s3:
        return context.l10n.timeSeconds(3);
      case AccessibilityTimeout.s5:
        return context.l10n.timeSeconds(5);
      case AccessibilityTimeout.s10:
        return context.l10n.timeSeconds(10);
      case AccessibilityTimeout.s30:
        return context.l10n.timeSeconds(30);
    }
  }
}

extension ExtraAvesThemeBrightnessName on AvesThemeBrightness {
  String getName(BuildContext context) {
    switch (this) {
      case AvesThemeBrightness.system:
        return context.l10n.settingsSystemDefault;
      case AvesThemeBrightness.light:
        return context.l10n.themeBrightnessLight;
      case AvesThemeBrightness.dark:
        return context.l10n.themeBrightnessDark;
      case AvesThemeBrightness.black:
        return context.l10n.themeBrightnessBlack;
    }
  }
}

extension ExtraCoordinateFormatName on CoordinateFormat {
  String getName(BuildContext context) {
    switch (this) {
      case CoordinateFormat.dms:
        return context.l10n.coordinateFormatDms;
      case CoordinateFormat.decimal:
        return context.l10n.coordinateFormatDecimal;
    }
  }
}

extension ExtraDisplayRefreshRateModeName on DisplayRefreshRateMode {
  String getName(BuildContext context) {
    switch (this) {
      case DisplayRefreshRateMode.auto:
        return context.l10n.settingsSystemDefault;
      case DisplayRefreshRateMode.highest:
        return context.l10n.displayRefreshRatePreferHighest;
      case DisplayRefreshRateMode.lowest:
        return context.l10n.displayRefreshRatePreferLowest;
    }
  }
}

extension ExtraEntryMapStyleName on EntryMapStyle {
  String getName(BuildContext context) {
    switch (this) {
      case EntryMapStyle.googleNormal:
        return context.l10n.mapStyleGoogleNormal;
      case EntryMapStyle.googleHybrid:
        return context.l10n.mapStyleGoogleHybrid;
      case EntryMapStyle.googleTerrain:
        return context.l10n.mapStyleGoogleTerrain;
      case EntryMapStyle.hmsNormal:
        return context.l10n.mapStyleHuaweiNormal;
      case EntryMapStyle.hmsTerrain:
        return context.l10n.mapStyleHuaweiTerrain;
      case EntryMapStyle.osmHot:
        return context.l10n.mapStyleOsmHot;
      case EntryMapStyle.stamenToner:
        return context.l10n.mapStyleStamenToner;
      case EntryMapStyle.stamenWatercolor:
        return context.l10n.mapStyleStamenWatercolor;
    }
  }
}

extension ExtraHomePageSettingName on HomePageSetting {
  String getName(BuildContext context) {
    switch (this) {
      case HomePageSetting.collection:
        return context.l10n.drawerCollectionAll;
      case HomePageSetting.albums:
        return context.l10n.drawerAlbumPage;
    }
  }
}

extension ExtraKeepScreenOnName on KeepScreenOn {
  String getName(BuildContext context) {
    switch (this) {
      case KeepScreenOn.never:
        return context.l10n.keepScreenOnNever;
      case KeepScreenOn.videoPlayback:
        return context.l10n.keepScreenOnVideoPlayback;
      case KeepScreenOn.viewerOnly:
        return context.l10n.keepScreenOnViewerOnly;
      case KeepScreenOn.always:
        return context.l10n.keepScreenOnAlways;
    }
  }
}

extension ExtraSlideshowVideoPlaybackName on SlideshowVideoPlayback {
  String getName(BuildContext context) {
    switch (this) {
      case SlideshowVideoPlayback.skip:
        return context.l10n.videoPlaybackSkip;
      case SlideshowVideoPlayback.playMuted:
        return context.l10n.videoPlaybackMuted;
      case SlideshowVideoPlayback.playWithSound:
        return context.l10n.videoPlaybackWithSound;
    }
  }
}

extension ExtraSubtitlePositionName on SubtitlePosition {
  String getName(BuildContext context) {
    switch (this) {
      case SubtitlePosition.top:
        return context.l10n.subtitlePositionTop;
      case SubtitlePosition.bottom:
        return context.l10n.subtitlePositionBottom;
    }
  }
}

extension ExtraThumbnailOverlayLocationIconName on ThumbnailOverlayLocationIcon {
  String getName(BuildContext context) {
    switch (this) {
      case ThumbnailOverlayLocationIcon.located:
        return context.l10n.filterLocatedLabel;
      case ThumbnailOverlayLocationIcon.unlocated:
        return context.l10n.filterNoLocationLabel;
      case ThumbnailOverlayLocationIcon.none:
        return context.l10n.settingsDisabled;
    }
  }
}

extension ExtraThumbnailOverlayTagIconName on ThumbnailOverlayTagIcon {
  String getName(BuildContext context) {
    switch (this) {
      case ThumbnailOverlayTagIcon.tagged:
        return context.l10n.filterTaggedLabel;
      case ThumbnailOverlayTagIcon.untagged:
        return context.l10n.filterNoTagLabel;
      case ThumbnailOverlayTagIcon.none:
        return context.l10n.settingsDisabled;
    }
  }
}

extension ExtraUnitSystemName on UnitSystem {
  String getName(BuildContext context) {
    switch (this) {
      case UnitSystem.metric:
        return context.l10n.unitSystemMetric;
      case UnitSystem.imperial:
        return context.l10n.unitSystemImperial;
    }
  }
}

extension ExtraVideoAutoPlayModeName on VideoAutoPlayMode {
  String getName(BuildContext context) {
    switch (this) {
      case VideoAutoPlayMode.disabled:
        return context.l10n.settingsDisabled;
      case VideoAutoPlayMode.playMuted:
        return context.l10n.videoPlaybackMuted;
      case VideoAutoPlayMode.playWithSound:
        return context.l10n.videoPlaybackWithSound;
    }
  }
}

extension ExtraVideoBackgroundModeName on VideoBackgroundMode {
  String getName(BuildContext context) {
    switch (this) {
      case VideoBackgroundMode.disabled:
        return context.l10n.settingsDisabled;
      case VideoBackgroundMode.pip:
        return context.l10n.settingsVideoEnablePip;
    }
  }
}

extension ExtraVideoControlsName on VideoControls {
  String getName(BuildContext context) {
    switch (this) {
      case VideoControls.play:
        return context.l10n.videoControlsPlay;
      case VideoControls.playSeek:
        return context.l10n.videoControlsPlaySeek;
      case VideoControls.playOutside:
        return context.l10n.videoControlsPlayOutside;
      case VideoControls.none:
        return context.l10n.videoControlsNone;
    }
  }
}

extension ExtraVideoLoopModeName on VideoLoopMode {
  String getName(BuildContext context) {
    switch (this) {
      case VideoLoopMode.never:
        return context.l10n.videoLoopModeNever;
      case VideoLoopMode.shortOnly:
        return context.l10n.videoLoopModeShortOnly;
      case VideoLoopMode.always:
        return context.l10n.videoLoopModeAlways;
    }
  }
}

extension ExtraViewerTransitionName on ViewerTransition {
  String getName(BuildContext context) {
    switch (this) {
      case ViewerTransition.slide:
        return context.l10n.viewerTransitionSlide;
      case ViewerTransition.parallax:
        return context.l10n.viewerTransitionParallax;
      case ViewerTransition.fade:
        return context.l10n.viewerTransitionFade;
      case ViewerTransition.zoomIn:
        return context.l10n.viewerTransitionZoomIn;
      case ViewerTransition.none:
        return context.l10n.viewerTransitionNone;
    }
  }
}

extension ExtraWidgetDisplayedItemName on WidgetDisplayedItem {
  String getName(BuildContext context) {
    switch (this) {
      case WidgetDisplayedItem.random:
        return context.l10n.widgetDisplayedItemRandom;
      case WidgetDisplayedItem.mostRecent:
        return context.l10n.widgetDisplayedItemMostRecent;
    }
  }
}

extension ExtraWidgetOpenPageName on WidgetOpenPage {
  String getName(BuildContext context) {
    switch (this) {
      case WidgetOpenPage.home:
        return context.l10n.widgetOpenPageHome;
      case WidgetOpenPage.collection:
        return context.l10n.widgetOpenPageCollection;
      case WidgetOpenPage.viewer:
        return context.l10n.widgetOpenPageViewer;
    }
  }
}
