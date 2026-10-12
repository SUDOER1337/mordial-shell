// File: SaturationSubTab.qml
// Saturation control tab with per-slot sliders.
// Each slider adjusts the saturation multiplier for its color slot.

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Helper to map slot name → representative Color.* property
  function colorForSlot(slot) {
    switch (slot) {
    case "primary":
      return Color.mPrimary;
    case "secondary":
      return Color.mSecondary;
    case "tertiary":
      return Color.mTertiary;
    case "error":
      return Color.mError;
    case "surface":
      return Color.mSurfaceVariant;
    case "background":
      return Color.mBackground;
    case "outline":
      return Color.mOutline;
    default:
      return Color.mOnSurface;
    }
  }

  // Helper to get the saturation setting for a slot
  function satFor(slot) {
    return Settings.data.colorSchemes.saturation[slot];
  }

  // Default saturation for each slot
  function defaultSatFor(slot) {
    var defaults = Settings.getDefaultValue("colorSchemes.saturation");
    return defaults ? defaults[slot] : 1.0;
  }

  // Reset all sliders to defaults
  function resetAll() {
    var slots = ColorSaturation.slotNames;
    for (var i = 0; i < slots.length; i++) {
      var s = slots[i];
      Settings.data.colorSchemes.saturation[s] = defaultSatFor(s);
    }
  }

  NHeader {
    label: "Saturation"
    description: "Adjust color intensity per category. Lower values produce more muted, neutral tones."
    Layout.fillWidth: true
  }

  // -- Presets --
  Flow {
    Layout.fillWidth: true
    spacing: Style.marginS

    Repeater {
      model: ColorSaturation.presets

      NButton {
        text: modelData.name
        icon: modelData.icon || "adjust"
        onClicked: {
          var vals = modelData.values;
          var slots = ColorSaturation.slotNames;
          for (var i = 0; i < slots.length; i++) {
            var s = slots[i];
            if (vals[s] !== undefined)
              Settings.data.colorSchemes.saturation[s] = vals[s];
          }
        }
      }
    }

    NButton {
      text: "Reset All"
      icon: "restore"
      onClicked: resetAll()
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // -- Group: Accents --
  NLabel {
    label: "Accents"
    description: "Primary, secondary, tertiary, and error colors"
    Layout.fillWidth: true
  }

  Repeater {
    model: ["primary", "secondary", "tertiary", "error"]

    NSaturationSlider {
      slotName: modelData.charAt(0).toUpperCase() + modelData.slice(1)
      slotColor: root.colorForSlot(modelData)
      saturationValue: root.satFor(modelData)
      defaultSaturation: root.defaultSatFor(modelData)
      Layout.fillWidth: true

      onSaturationChanged: value => {
                             Settings.data.colorSchemes.saturation[modelData] = value;
                           }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
  }

  // -- Group: Neutrals --
  NLabel {
    label: "Neutrals"
    description: "Surface, background, and outline colors"
    Layout.fillWidth: true
  }

  Repeater {
    model: ["surface", "background", "outline"]

    NSaturationSlider {
      slotName: modelData.charAt(0).toUpperCase() + modelData.slice(1)
      slotColor: root.colorForSlot(modelData)
      saturationValue: root.satFor(modelData)
      defaultSaturation: root.defaultSatFor(modelData)
      Layout.fillWidth: true

      onSaturationChanged: value => {
                             Settings.data.colorSchemes.saturation[modelData] = value;
                           }
    }
  }
}
