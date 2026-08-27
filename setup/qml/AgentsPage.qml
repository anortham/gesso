import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Page {
  id: page

  title: "Agents"

  ColumnLayout {
    anchors.fill: parent

    Controls.Label {
      Layout.fillWidth: true
      text: "Agents"
      font.bold: true
    }

    Controls.Label {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: "Coding agents are not in this build."
    }

    Controls.Label {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      text: "A later update adds the agent command."
    }
  }
}
