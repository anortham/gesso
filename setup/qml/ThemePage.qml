import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
  id: page

  title: "Theme"

  property var themes: []
  property var themeNames: []
  property string currentTheme: "unset"
  property string selectedTheme: ""
  property string wallpaperMode: "keep"
  property string customWallpaperPath: ""
  property string statusText: ""
  property string errorText: ""
  property string diagnosticText: ""
  property bool busy: false
  property bool loadingThemes: false

  readonly property var selectedThemeData: {
    for (var i = 0; i < page.themes.length; i++) {
      if (page.themes[i].id === page.selectedTheme) {
        return page.themes[i]
      }
    }
    return null
  }

  readonly property bool selectedThemeHasWallpaper: page.selectedThemeData ? (page.selectedThemeData.has_wallpaper === true) : false

  onSelectedThemeHasWallpaperChanged: {
    if (!page.selectedThemeHasWallpaper && page.wallpaperMode === "theme") {
      page.wallpaperMode = "keep"
    }
  }

  Component.onCompleted: loadThemes()

  function loadThemes() {
    page.loadingThemes = true
    gessoCli.runQueryAsync(["theme", "list", "--json"], function(listResult) {
      page.loadingThemes = false
      if (listResult.exitCode != 0) {
        page.errorText = "Could not load theme list."
        page.diagnosticText = listResult.stderr
        page.themes = []
        page.themeNames = []
        return
      }

      try {
        page.themes = JSON.parse(listResult.stdout)
      } catch (e) {
        page.errorText = "Could not parse theme list."
        page.diagnosticText = listResult.stdout
        page.themes = []
        page.themeNames = []
        return
      }

      var names = []
      for (var i = 0; i < page.themes.length; i++) {
        names.push(page.themes[i].id)
      }
      page.themeNames = names

      gessoCli.runQueryAsync(["theme", "current"], function(currentResult) {
        if (currentResult.exitCode == 0) {
          var cur = currentResult.stdout.trim()
          page.currentTheme = cur.length > 0 ? cur : "unset"
        } else {
          page.currentTheme = "unset"
        }

        if (page.themeNames.indexOf(page.selectedTheme) < 0) {
          if (page.themeNames.indexOf(page.currentTheme) >= 0) {
            page.selectedTheme = page.currentTheme
          } else if (page.themeNames.length > 0) {
            page.selectedTheme = page.themeNames[0]
          } else {
            page.selectedTheme = ""
          }
        }
      })
    })
  }

  function applySelected() {
    if (page.busy || gessoCli.busy) {
      return
    }
    if (!page.selectedTheme || page.selectedTheme.length === 0) {
      return
    }
    if (page.wallpaperMode === "custom" && page.customWallpaperPath.trim().length === 0) {
      page.errorText = "Please enter a path for the custom wallpaper."
      page.diagnosticText = ""
      return
    }

    page.errorText = ""
    page.diagnosticText = ""
    page.statusText = ""
    page.busy = true

    var args = ["theme", "set", page.selectedTheme]
    if (page.wallpaperMode === "keep") {
      args.push("--wallpaper", "keep")
    } else if (page.wallpaperMode === "theme") {
      args.push("--wallpaper", "theme")
    } else if (page.wallpaperMode === "custom") {
      args.push("--wallpaper", page.customWallpaperPath.trim())
    }

    gessoCli.runAsync(args, function(result) {
      page.busy = false
      if (result.exitCode != 0) {
        page.errorText = "Failed to apply theme."
        page.diagnosticText = result.stderr
        return
      }
      page.statusText = "Theme applied successfully."
      page.loadThemes()
    })
  }

  function undoTheme() {
    if (page.busy || gessoCli.busy) {
      return
    }

    page.errorText = ""
    page.diagnosticText = ""
    page.statusText = ""
    page.busy = true

    gessoCli.runAsync(["theme", "undo"], function(result) {
      page.busy = false
      if (result.exitCode != 0) {
        page.errorText = "Failed to undo theme."
        page.diagnosticText = result.stderr
        return
      }
      page.statusText = "Theme reverted to previous."
      page.loadThemes()
    })
  }

  function restoreDefaults() {
    if (page.busy || gessoCli.busy) {
      return
    }

    page.errorText = ""
    page.diagnosticText = ""
    page.statusText = ""
    page.busy = true

    gessoCli.runAsync(["theme", "restore"], function(result) {
      page.busy = false
      if (result.exitCode != 0) {
        page.errorText = "Failed to restore defaults."
        page.diagnosticText = result.stderr
        return
      }
      page.statusText = "Restored baseline default theme."
      page.loadThemes()
    })
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Kirigami.Units.smallSpacing

    Kirigami.InlineMessage {
      id: errorMessage
      Layout.fillWidth: true
      visible: page.errorText.length > 0
      type: Kirigami.MessageType.Error
      text: page.errorText
      showCloseButton: true
      onVisibleChanged: {
        if (!visible) {
          page.errorText = ""
          page.diagnosticText = ""
          errorMessage.showDetails = false
        }
      }

      property bool showDetails: false

      actions: [
        Kirigami.Action {
          text: errorMessage.showDetails ? "Hide Diagnostics" : "Show Diagnostics"
          icon.name: errorMessage.showDetails ? "arrow-up" : "arrow-down"
          visible: page.diagnosticText.length > 0
          onTriggered: errorMessage.showDetails = !errorMessage.showDetails
        }
      ]
    }

    Controls.ScrollView {
      Layout.fillWidth: true
      Layout.preferredHeight: 80
      visible: errorMessage.visible && errorMessage.showDetails && page.diagnosticText.length > 0
      clip: true

      Controls.TextArea {
        readOnly: true
        text: page.diagnosticText
        font.family: "monospace"
        font.pointSize: 9
        wrapMode: Text.Wrap
      }
    }

    Kirigami.InlineMessage {
      id: statusMessage
      Layout.fillWidth: true
      visible: page.statusText.length > 0
      type: Kirigami.MessageType.Positive
      text: page.statusText
      showCloseButton: true
      onVisibleChanged: {
        if (!visible) {
          page.statusText = ""
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true

      Controls.Label {
        text: "Current: " + page.currentTheme
        font.bold: true
      }

      Item {
        Layout.fillWidth: true
      }

      Controls.BusyIndicator {
        running: page.loadingThemes
        visible: running
        implicitWidth: 20
        implicitHeight: 20
      }
    }

    GridView {
      id: themeGrid
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      cellWidth: width > 0 ? Math.max(180, Math.floor(width / Math.max(1, Math.floor(width / 220)))) : 220
      cellHeight: 155
      model: page.themes

      delegate: Item {
        width: themeGrid.cellWidth
        height: themeGrid.cellHeight

        Kirigami.AbstractCard {
          id: card
          anchors.fill: parent
          anchors.margins: Kirigami.Units.smallSpacing
          highlighted: page.selectedTheme === modelData.id
          hoverEnabled: true
          enabled: !page.busy && !gessoCli.busy

          onClicked: {
            page.selectedTheme = modelData.id
          }

          contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
              Layout.fillWidth: true

              Controls.Label {
                text: modelData.name || modelData.id
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Rectangle {
                radius: 3
                color: modelData.mode === "dark" ? "#2a2e32" : "#e0e0e0"
                implicitWidth: modeText.implicitWidth + 8
                implicitHeight: modeText.implicitHeight + 4

                Controls.Label {
                  id: modeText
                  anchors.centerIn: parent
                  text: modelData.mode || ""
                  font.pointSize: 8
                  color: modelData.mode === "dark" ? "#eff0f1" : "#232629"
                }
              }

              Kirigami.Icon {
                visible: page.selectedTheme === modelData.id
                source: "dialog-ok"
                implicitWidth: 16
                implicitHeight: 16
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: 4
              color: modelData.background || "#1a1b26"
              border.color: page.selectedTheme === modelData.id ? (modelData.accent || Kirigami.Theme.highlightColor) : (modelData.selection || "#31363b")
              border.width: page.selectedTheme === modelData.id ? 2 : 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing

                Controls.Label {
                  text: "Aa"
                  font.bold: true
                  font.pointSize: 14
                  color: modelData.foreground || "#ffffff"
                }

                Item {
                  Layout.fillWidth: true
                }

                Rectangle {
                  width: 16
                  height: 16
                  radius: 8
                  color: modelData.accent || "#7aa2f7"
                  border.color: modelData.foreground || "#ffffff"
                  border.width: 1
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 4

              Repeater {
                model: modelData.palette || []
                delegate: Rectangle {
                  width: 10
                  height: 10
                  radius: 5
                  color: modelData
                }
              }

              Item {
                Layout.fillWidth: true
              }

              Kirigami.Icon {
                visible: modelData.has_wallpaper === true
                source: "preferences-desktop-wallpaper"
                implicitWidth: 14
                implicitHeight: 14
              }
            }
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Kirigami.Units.smallSpacing

      Controls.Label {
        text: "Wallpaper"
        font.bold: true
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Controls.ButtonGroup {
          id: wallpaperButtonGroup
        }

        Controls.RadioButton {
          id: wpKeepRadio
          text: "Keep Current Wallpaper"
          checked: page.wallpaperMode === "keep"
          Controls.ButtonGroup.group: wallpaperButtonGroup
          onToggled: {
            if (checked) {
              page.wallpaperMode = "keep"
            }
          }
        }

        Controls.RadioButton {
          id: wpThemeRadio
          text: "Use Theme Wallpaper"
          enabled: page.selectedThemeHasWallpaper
          checked: page.wallpaperMode === "theme"
          Controls.ButtonGroup.group: wallpaperButtonGroup
          onToggled: {
            if (checked) {
              page.wallpaperMode = "theme"
            }
          }
        }

        Controls.RadioButton {
          id: wpCustomRadio
          text: "Custom Image..."
          checked: page.wallpaperMode === "custom"
          Controls.ButtonGroup.group: wallpaperButtonGroup
          onToggled: {
            if (checked) {
              page.wallpaperMode = "custom"
            }
          }
        }

        Item {
          Layout.fillWidth: true
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: page.wallpaperMode === "custom"
        spacing: Kirigami.Units.smallSpacing

        Controls.Label {
          text: "Image Path:"
        }

        Controls.TextField {
          id: customWallpaperField
          Layout.fillWidth: true
          placeholderText: "/path/to/wallpaper.jpg"
          text: page.customWallpaperPath
          onTextChanged: page.customWallpaperPath = text
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Kirigami.Units.smallSpacing

      Controls.Button {
        text: "Undo"
        icon.name: "edit-undo"
        enabled: !page.busy && !gessoCli.busy
        onClicked: page.undoTheme()
      }

      Controls.Button {
        text: "Restore Defaults"
        icon.name: "edit-reset"
        enabled: !page.busy && !gessoCli.busy
        onClicked: page.restoreDefaults()
      }

      Item {
        Layout.fillWidth: true
      }

      Controls.BusyIndicator {
        running: page.busy || gessoCli.busy
        visible: running
        implicitWidth: 24
        implicitHeight: 24
      }

      Controls.Button {
        text: "Apply Theme"
        icon.name: "dialog-ok-apply"
        highlighted: true
        enabled: page.themes.length > 0 && page.selectedTheme.length > 0 && !page.busy && !gessoCli.busy
        onClicked: page.applySelected()
      }
    }
  }
}
