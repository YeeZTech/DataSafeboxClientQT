import QtQuick 2.15
import DataSafebox.Theme 1.0 as Theme
import DataSafebox.Components 1.0

Item {
    id: root

    // Destinations for the footer links. Empty by default — wired from the
    // host (main.qml) once the real URLs are available. Clicking a link with
    // an empty URL is a safe no-op.
    property url userAgreementUrl: ""
    property url historyVersionUrl: ""

    signal checkUpdateRequested

    Rectangle {
        anchors.fill: parent
        color: Theme.Colors.backgroundWhite
    }

    // ── Header ────────────────────────────────────────────────
    Rectangle {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        color: Theme.Colors.backgroundWhite

        SelectableText {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("About")
            font.pixelSize: 24
            font.weight: Font.Medium
            color: Theme.Colors.textPrimary
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#e6e6e6"
        }
    }

    // ── Centered identity block ───────────────────────────────
    // Vertical rhythm mirrors the design: the logo box bottom meets the title
    // top (0 gap), then 49px between the tops of title → version → button
    // (24px fixed line boxes + 25px spacers).
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -8
        spacing: 0

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/icons/SafeLogoRounded.svg"
            sourceSize.width: 200
            sourceSize.height: 200
            width: 200
            height: 200
            fillMode: Image.PreserveAspectFit
            smooth: true
            antialiasing: true
        }

        // 24px line box (matches the design leading) with the label centered
        Item {
            width: titleLabel.implicitWidth
            height: 24
            anchors.horizontalCenter: parent.horizontalCenter

            SelectableText {
                id: titleLabel
                anchors.centerIn: parent
                text: qsTr("DataSafeBox Console")
                font.pixelSize: 24
                font.weight: Font.DemiBold
                color: Theme.Colors.primary
            }
        }

        Item {
            width: 1
            height: 25
        }

        Item {
            width: versionLabel.implicitWidth
            height: 24
            anchors.horizontalCenter: parent.horizontalCenter

            SelectableText {
                id: versionLabel
                anchors.centerIn: parent
                text: qsTr("Current Version: ") + UpdateManager.currentVersion
                font.pixelSize: 20
                font.weight: Font.Medium
                color: "#0f172b"
            }
        }

        Item {
            width: 1
            height: 25
        }

        PrimaryButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Check for Updates")
            fontWeight: Font.Medium
            onClicked: root.checkUpdateRequested()
        }
    }

    // ── Footer: legal links + copyright ───────────────────────
    Column {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        spacing: 10

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            LinkText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("User Agreement")
                fontSize: 12
                onClicked: {
                    if (root.userAgreementUrl.toString() !== "")
                        Qt.openUrlExternally(root.userAgreementUrl);
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 16
                color: "#d9d9d9"
            }

            LinkText {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Version History")
                fontSize: 12
                onClicked: {
                    if (root.historyVersionUrl.toString() !== "")
                        Qt.openUrlExternally(root.historyVersionUrl);
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 20
            lineHeightMode: Text.FixedHeight
            font.pixelSize: 12
            color: "#73000000"
            text: "Copyright © YeeZTech 北京熠智科技有限公司 版权所有" + "\n" + "京公网安备11010802038645号 | 京ICP备20022436号-3 | 京EDI证京B2-20220639号" + "\n" + "区块链备案号：京网信备1101082276223860002X号"
        }
    }
}
