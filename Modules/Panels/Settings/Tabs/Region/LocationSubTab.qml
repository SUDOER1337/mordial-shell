import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.Location
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Language
  NComboBox {
    Layout.fillWidth: true
    label: "Application language"
    description: "Select the language used in the application's interface."
    defaultValue: Settings.getDefaultValue("general.language")
    model: [
      {
        "key": "",
        "name": "Automatic" + " (" + I18n.systemDetectedLangCode + ")"
      }
    ].concat(I18n.availableLanguages.map(function (langCode) {
      return {
        "key": langCode,
        "name": langCode
      };
    }))
    currentKey: Settings.data.general.language
    settingsPath: "general.language"
    onSelected: key => {
                  // Need to change language on next frame using "callLater" or it will pull the rug below our feet: the NComboBox would be rebuilt immediately before it can close properly.
                  Qt.callLater(() => {
                                 Settings.data.general.language = key;
                                 if (key === "") {
                                   I18n.detectLanguage(); // Re-detect system language if "Automatic" is selected
                                 } else {
                                   I18n.setLanguage(key); // Set specific language
                                 }
                               });
                }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Location
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    // Auto-locate
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NToggle {
        Layout.fillWidth: true
        label: "Auto-locate"
        description: "Automatically detect your location periodically using your IP address."
        checked: Settings.data.location.autoLocate
        onToggled: checked => Settings.data.location.autoLocate = checked
        defaultValue: Settings.getDefaultValue("location.autoLocate")
      }

      NButton {
        text: "Locate now"
        icon: "current-location"
        enabled: !LocationService.isFetchingWeather
        onClicked: LocationService.geolocateAndApply()
      }
    }

    NTextInput {
      visible: !Settings.data.location.autoLocate
      Layout.maximumWidth: root.width / 2
      label: "Search for a location"
      description: "e.g. Toronto, ON"
      text: Settings.data.location.name
      placeholderText: "Enter the location name"
      onEditingFinished: {
        // Verify the location has really changed to avoid extra resets
        var newLocation = text.trim();
        if (newLocation != Settings.data.location.name) {
          Settings.data.location.name = newLocation;
          LocationService.resetWeather();
        }
      }
    }

    NText {
      text: LocationService.coordinatesReady ? LocationService.stableName + " (" + LocationService.displayCoordinates + ")" : ""
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      font.italic: true
    }
  }

  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NToggle {
      label: "Enable weather"
      description: "Show weather information throughout the interface and fetch weather data. When disabled, all weather elements will be hidden and no network requests will be made."
      checked: Settings.data.location.weatherEnabled
      onToggled: checked => Settings.data.location.weatherEnabled = checked
      defaultValue: Settings.getDefaultValue("location.weatherEnabled")
    }

    NToggle {
      label: "Display temperature in Fahrenheit (°F)"
      description: "Display temperature in Fahrenheit instead of Celsius."
      checked: Settings.data.location.useFahrenheit
      onToggled: checked => Settings.data.location.useFahrenheit = checked
      enabled: Settings.data.location.weatherEnabled
    }

    NToggle {
      label: "Display weather effects"
      description: "Show additional visual effects (like rain, snow, or lightning) on the weather card."
      checked: Settings.data.location.weatherShowEffects
      onToggled: checked => Settings.data.location.weatherShowEffects = checked
      enabled: Settings.data.location.weatherEnabled
    }

    NToggle {
      label: "Always show Talia weather emojis"
      description: "Always use Talia emojis instead of tabler icons."
      checked: Settings.data.location.weatherTaliaMascotAlways
      onToggled: checked => Settings.data.location.weatherTaliaMascotAlways = checked
      enabled: Settings.data.location.weatherEnabled
      defaultValue: Settings.getDefaultValue("location.weatherTaliaMascotAlways")
    }

    NToggle {
      label: "Hide city name"
      description: "Hide the city name from weather displays throughout the interface."
      checked: Settings.data.location.hideWeatherCityName
      onToggled: checked => Settings.data.location.hideWeatherCityName = checked
      enabled: Settings.data.location.weatherEnabled
    }

    NToggle {
      label: "Hide timezone"
      description: "Hide the timezone abbreviation from weather displays throughout the interface."
      checked: Settings.data.location.hideWeatherTimezone
      onToggled: checked => Settings.data.location.hideWeatherTimezone = checked
      enabled: Settings.data.location.weatherEnabled
    }
  }
}
