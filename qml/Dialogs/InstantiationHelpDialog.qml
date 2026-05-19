import QtQuick 2.15
import QtQuick.Controls 2.15
import "." as Theme

Popup {
    id: root
    width: 520
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    x: parent ? (parent.width  - width)  / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0
    padding: 0
    background: null

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    // ── Dialog shell ─────────────────────────────────────────────────────────
    Rectangle {
        width:  root.width
        height: contentCol.implicitHeight
        radius: 10
        color:  "#ffffff"
        clip:   true

        // Keep popup height in sync
        onHeightChanged: root.height = height

        Column {
            id: contentCol
            width: parent.width
            spacing: 0

            // ── Header ───────────────────────────────────────────────────────
            Rectangle {
                width:  parent.width
                height: 52
                color:  "transparent"

                // bottom divider
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: "#e8edf3"
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Security Domain Instantiation")
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    color: "#1d293d"
                }

                // × close button
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 6
                    color: closeArea.containsMouse ? "#f0f4f8" : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 20
                        color: "#8a9bb0"
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // ── Scrollable body ───────────────────────────────────────────────
            ScrollView {
                width:  parent.width
                height: Math.min(bodyCol.implicitHeight + 32, 520)
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                clip: true

                Column {
                    id: bodyCol
                    width:  root.width - 48
                    x: 24
                    y: 16
                    spacing: 16

                    // ── Info banner ───────────────────────────────────────────
                    Rectangle {
                        width:  parent.width
                        height: bannerRow.implicitHeight + 16
                        radius: 6
                        color:  "#f0f6ff"
                        border.color: "#cce0f5"
                        border.width: 1

                        Row {
                            id: bannerRow
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin:  12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "›"
                                font.pixelSize: 14
                                color: "#3b7ec8"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: parent.width - 28
                                text: qsTr("Security domain instantiation is implemented in the Linux CLI client.")
                                font.pixelSize: 13
                                color: "#1e4d8c"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // ── Section 1 ─────────────────────────────────────────────
                    Text {
                        text: qsTr("1. Install the CLI client")
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#1d293d"
                    }

                    Rectangle {
                        width:  parent.width
                        height: codeText1.implicitHeight + 24
                        radius: 6
                        color:  "#1e2d3d"

                        Text {
                            id: codeText1
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            anchors.top:    parent.top
                            anchors.margins: 12
                            text: "# Add APT source\necho 'deb [trusted=yes] https://repo.yeez.tech stable main' | sudo tee /etc/apt/sources.list.d/yeez-tech.list >/dev/null\n\n# Update package index\nsudo apt update\n\n# Install client\nsudo apt install -y datasafebox-cmd-cli"
                            font.family: "Consolas, Courier New, monospace"
                            font.pixelSize: 12
                            color: "#e8edf3"
                            wrapMode: Text.WrapAnywhere
                            lineHeight: 1.6
                        }
                    }

                    // ── Section 2 ─────────────────────────────────────────────
                    Text {
                        text: qsTr("2. Security domain usage workflow")
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: "#1d293d"
                    }

                    Rectangle {
                        width:  parent.width
                        height: codeText2.implicitHeight + 24
                        radius: 6
                        color:  "#1e2d3d"

                        Text {
                            id: codeText2
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            anchors.top:    parent.top
                            anchors.margins: 12
                            text: "# Step 1: Login\ndv auth login\n\n# Step 2: List visible security domains\ndv domain list\n\n# Step 3: Apply for instance creation\ndv instance create \"trade-domain-001\" -n \"instance-wangfang-01\" --disk \"/data/safebox\"\n\n# Step 4: Start authorized instance\ndv instance start instance-wangfang-01 --force"
                            font.family: "Consolas, Courier New, monospace"
                            font.pixelSize: 12
                            color: "#e8edf3"
                            wrapMode: Text.WrapAnywhere
                            lineHeight: 1.6
                        }
                    }

                    // spacer before footer
                    Item { width: 1; height: 4 }
                }
            }

            // ── Footer ───────────────────────────────────────────────────────
            Rectangle {
                width:  parent.width
                height: 64
                color:  "transparent"

                // top divider
                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: "#e8edf3"
                }

                Row {
                    anchors.right:         parent.right
                    anchors.rightMargin:   24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    // 查看完整文档
                    Rectangle {
                        width:  docBtnLabel.implicitWidth + 28
                        height: 36
                        radius: 6
                        color:  docArea.pressed ? "#d4e4f1"
                                : docArea.containsMouse ? "#e8f2fa"
                                : "#ffffff"
                        border.color: docArea.containsMouse ? "#3b7ec8" : "#cad5e2"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: docBtnLabel
                            anchors.centerIn: parent
                            text: qsTr("View full documentation")
                            font.pixelSize: 13
                            color: docArea.containsMouse ? "#1e5a8e" : "#45556c"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: docArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.openUrlExternally("https://help.yeez.tech/docs/dsbox-cli-userguide")
                        }
                    }

                    // 知道了
                }
            }
        }
    }
}
