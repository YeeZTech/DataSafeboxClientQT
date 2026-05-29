import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme

Item {
    id: emptyRoot
    width: parent ? parent.width : 200
    height: 30

    property string message: qsTr("No Data")

    Column {
        anchors.centerIn: parent
        spacing: 3

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16
            height: 16
            source: "qrc:/icons/icon-empty-state.svg"
            sourceSize: Qt.size(16, 16)
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: emptyRoot.message
            font.pixelSize: 11
            color: Theme.Colors.textCounter
        }
    }
}
