import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

// Underlined, clickable text link with the shared hover/pressed color behavior.
Text {
    id: root

    property int fontSize: Theme.Typography.body

    signal clicked

    font.pixelSize: fontSize
    font.underline: true
    color: linkArea.pressed ? Qt.darker(Theme.Colors.primary, 1.4) : linkArea.containsMouse ? Theme.Colors.linkHover : Theme.Colors.primary

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    MouseArea {
        id: linkArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
