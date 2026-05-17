import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine

// 客服聊天弹窗：可拖动、可缩放、无右边框、仅底部阴影
Popup {
    id: root

    // ── 尺寸约束 ──────────────────────────────────────────────
    readonly property int minW: 320
    readonly property int maxW: 580
    readonly property int minH: 400
    readonly property int maxH: 780

    width:  376
    height: 600
    padding: 0
    modal: false
    focus: false
    closePolicy: Popup.CloseOnEscape

    // 淡入 + 向上滑入
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { property: "y"; from: root.y + 14; to: root.y; duration: 220; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InQuad }
    }

    function buildHtml() {
        var baseUrl = AppConfig.customerServiceUrl()
        var token   = AppConfig.customerServiceToken()
        return '<!DOCTYPE html><html><head>' +
               '<meta charset="utf-8">' +
               '<meta name="viewport" content="width=device-width,initial-scale=1">' +
               '<style>html,body{margin:0;padding:0;width:100%;height:100%;overflow:hidden;}</style>' +
               '</head><body>' +
               '<scr' + 'ipt>' +
               '(function(d,t){' +
                   'var B="' + baseUrl + '";' +
                   'var g=d.createElement(t),s=d.getElementsByTagName(t)[0];' +
                   'g.src=B+"/packs/js/sdk.js";g.defer=true;' +
                   's.parentNode.insertBefore(g,s);' +
                   'g.onload=function(){' +
                       'window.chatwootSDK.run({websiteToken:"' + token + '",baseUrl:B});' +
                       'window.addEventListener("chatwoot:ready",function(){' +
                           'window.$chatwoot.toggle("open");' +
                       '});' +
                   '};' +
               '})(document,"script");' +
               '<' + '/script>' +
               '</body></html>'
    }

    onOpened: webView.loadHtml(buildHtml(), AppConfig.customerServiceUrl())
    onClosed: { webView.stop(); webView.url = "about:blank" }

    // ── 背景：极轻轮廓阴影 + 清晰边框 ──────────────────────
    background: Item {
        Rectangle {
            z: -2
            x: -2;  y: -2
            width: parent.width + 4;  height: parent.height + 4
            radius: 14;  color: "#0a000000"
        }
        Rectangle {
            z: -1
            x: -1;  y: -1
            width: parent.width + 2;  height: parent.height + 2
            radius: 13;  color: "#0d000000"
        }

        // 主圆角白框 + 清晰边框
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "white"
            border.color: "#a8b8c8"
            border.width: 1
        }
    }

    // ── 内容层 ────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // ── 标题栏（可拖动）──────────────────────────────────
        Rectangle {
            id: titleBar
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: parent.right
            height: 42
            color: "#0f4c81"
            radius: 12

            // 遮住下半圆角，与 WebView 无缝衔接
            Rectangle {
                anchors.left: parent.left;  anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 12;  color: "#0f4c81"
            }

            // 拖动手柄（z=0，在关闭按钮之下）
            MouseArea {
                id: dragArea
                anchors.fill: parent
                z: 0
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.SizeAllCursor

                property real pressGX: 0;  property real pressGY: 0
                property real popupX0: 0;  property real popupY0: 0

                onPressed: {
                    var gp = mapToGlobal(mouseX, mouseY)
                    pressGX = gp.x;  pressGY = gp.y
                    popupX0 = root.x;  popupY0 = root.y
                }
                onPositionChanged: {
                    if (!pressed) return
                    var gp = mapToGlobal(mouseX, mouseY)
                    root.x = popupX0 + (gp.x - pressGX)
                    root.y = popupY0 + (gp.y - pressGY)
                }
            }

            // 左：图标 + 标题
            Row {
                anchors.left: parent.left;  anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8;  z: 1

                Image {
                    width: 16;  height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    source: Qt.resolvedUrl("icons/icon-customer-service-white.svg")
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "联系客服"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.letterSpacing: 0.3
                }
            }

            // 右：关闭按钮（z=1，覆盖拖动层）
            Rectangle {
                z: 1
                anchors.right: parent.right;  anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 28;  height: 28;  radius: 14
                color: closeBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 13 }

                MouseArea {
                    id: closeBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        // ── Chatwoot 聊天内容 ─────────────────────────────────
        WebEngineView {
            id: webView
            anchors.top:    titleBar.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 13  // 必须 >= radius(12)，让底边圆角区域完整露出

            profile: WebEngineProfile {
                storageName: "CustomerSupport"
                offTheRecord: false
                httpUserAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            }
            onCertificateError: function(error) {
                // 仅在测试环境忽略自签名/无效证书；正式环境拒绝以防中间人攻击
                if (typeof AppConfig !== "undefined" && AppConfig.isTestEnv && AppConfig.isTestEnv()) {
                    error.ignoreCertificateError()
                } else {
                    error.rejectCertificate()
                }
            }
        }

        // ── 底边缩放（上下拉伸高度）────────────────────────────
        MouseArea {
            x: 0;  y: parent.height - 8
            width: parent.width - 18;  height: 8
            cursorShape: Qt.SizeVerCursor
            z: 20

            property real pressGY: 0;  property real h0: 0
            onPressed: { pressGY = mapToGlobal(0, mouseY).y;  h0 = root.height }
            onPositionChanged: {
                if (!pressed) return
                var gy = mapToGlobal(0, mouseY).y
                root.height = Math.max(root.minH, Math.min(root.maxH, h0 + (gy - pressGY)))
            }
        }

        // ── 右边缩放（左右拉伸宽度）────────────────────────────
        MouseArea {
            x: parent.width - 6;  y: titleBar.height
            width: 6;  height: parent.height - titleBar.height - 18
            cursorShape: Qt.SizeHorCursor
            z: 20

            property real pressGX: 0;  property real w0: 0
            onPressed: { pressGX = mapToGlobal(mouseX, 0).x;  w0 = root.width }
            onPositionChanged: {
                if (!pressed) return
                var gx = mapToGlobal(mouseX, 0).x
                root.width = Math.max(root.minW, Math.min(root.maxW, w0 + (gx - pressGX)))
            }
        }

        // ── 右下角缩放手柄（同时调整宽高）──────────────────────
        Item {
            x: parent.width - 18;  y: parent.height - 18
            width: 18;  height: 18
            z: 30

            // 网格点装饰（右下角 L 形排列）
            Repeater {
                model: [
                    {px: 14, py: 4},
                    {px: 14, py: 9}, {px: 9,  py: 9},
                    {px: 14, py: 14},{px: 9,  py: 14},{px: 4, py: 14}
                ]
                Rectangle {
                    x: modelData.px - 1;  y: modelData.py - 1
                    width: 2;  height: 2;  radius: 1
                    color: "#b0bec5"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeFDiagCursor

                property real pGX: 0;  property real pGY: 0
                property real w0: 0;   property real h0: 0

                onPressed: {
                    var gp = mapToGlobal(mouseX, mouseY)
                    pGX = gp.x;  pGY = gp.y
                    w0 = root.width;  h0 = root.height
                }
                onPositionChanged: {
                    if (!pressed) return
                    var gp = mapToGlobal(mouseX, mouseY)
                    root.width  = Math.max(root.minW, Math.min(root.maxW, w0 + (gp.x - pGX)))
                    root.height = Math.max(root.minH, Math.min(root.maxH, h0 + (gp.y - pGY)))
                }
            }
        }
    }
}
