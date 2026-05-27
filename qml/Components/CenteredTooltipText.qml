import QtQuick 2.15
import QtQuick.Window 2.15

// 表格单元格文本：超出列宽时省略，悬停弹出气泡显示完整内容
Item {
    id: root

    property string value: ""
    property color textColor: "#0f172b"
    property int textPixelSize: 14
    property int textWeight: Font.Normal
    property int leftMargin: 6
    property int rightMargin: 6
    property int tooltipMaxWidth: 400
    property int elide: Text.ElideMiddle
    // 固定字符计数截断：设为 > 0 时使用字符宽度计数截断（汉字=2，ASCII=1）
    // 超出 beforeChars+afterChars 时显示 head…tail，否则显示完整文本
    property int beforeChars: 0
    property int afterChars: 0

    // 气泡不得超出此 Item 边界（通常是所在卡片）；为空时退化到窗口边界
    property Item boundsItem: null

    // 计算字符串的「显示宽度」：汉字及其他全角字符=2，其余=1
    function _charUnits(s) {
        var w = 0;
        for (var i = 0; i < s.length; i++)
            w += (s.charCodeAt(i) > 127) ? 2 : 1;
        return w;
    }

    // 固定字符计数中间截断
    function _fixedMiddleTruncate(s, before, after) {
        if (_charUnits(s) <= before + after)
            return s;
        var w = 0, i = 0;
        while (i < s.length) {
            var cw = s.charCodeAt(i) > 127 ? 2 : 1;
            if (w + cw > before)
                break;
            w += cw;
            i++;
        }
        var head = s.substring(0, i);
        w = 0;
        var j = s.length - 1;
        while (j >= 0) {
            var cw2 = s.charCodeAt(j) > 127 ? 2 : 1;
            if (w + cw2 > after)
                break;
            w += cw2;
            j--;
        }
        return head + "\u2026" + s.substring(j + 1);
    }

    FontMetrics {
        id: fm
        font.pixelSize: root.textPixelSize
        font.weight: root.textWeight
    }

    // 右侧保留一汉字间距，避免内容贴近下一列
    readonly property real _rightGap: Math.ceil(fm.advanceWidth("宽"))
    readonly property real _availWidth: Math.max(0, width - leftMargin - rightMargin - _rightGap)
    readonly property bool _useFixedTruncate: beforeChars > 0 && afterChars > 0
    readonly property string _displayText: _useFixedTruncate ? _fixedMiddleTruncate(value, beforeChars, afterChars) : value
    readonly property bool truncated: value.length > 0 && (_useFixedTruncate ? _charUnits(value) > beforeChars + afterChars : fm.advanceWidth(value) > _availWidth)
    readonly property bool showTooltip: hoverArea.containsMouse && truncated

    // 省略号在 root 坐标系中的 local X，用于 tooltip 三角对准
    readonly property real _ellipsisLocalX: {
        if (!truncated)
            return width * 0.5;
        if (_useFixedTruncate) {
            // 固定中间截断：计算 head（前 beforeChars 显示单位）的像素宽度
            var s = value;
            var w = 0, i = 0;
            while (i < s.length) {
                var cw = s.charCodeAt(i) > 127 ? 2 : 1;
                if (w + cw > beforeChars)
                    break;
                w += cw;
                i++;
            }
            var head = s.substring(0, i);
            return leftMargin + fm.advanceWidth(head) + fm.advanceWidth("\u2026") * 0.5;
        }
        // ElideRight：省略号在文本末尾
        if (elide === Text.ElideRight)
            return leftMargin + _availWidth - fm.advanceWidth("...") * 0.5;
        // 其余（ElideMiddle 等）：居中
        return width * 0.5;
    }

    implicitHeight: Math.max(24, label.implicitHeight)

    Text {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: root.leftMargin
        anchors.verticalCenter: parent.verticalCenter
        width: root._availWidth
        text: root._displayText
        font.pixelSize: root.textPixelSize
        font.weight: root.textWeight
        color: root.textColor
        elide: root._useFixedTruncate ? Text.ElideNone : root.elide
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: hoverArea
        anchors.fill: label
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
    }

    // 弹出气泡 overlay 锚到顶层窗口，避免被父控件 clip 遮挡
    Loader {
        id: tooltipLoader
        active: root.showTooltip
        sourceComponent: tooltipOverlay
        onLoaded: {
            var win = root.Window.window;
            if (win && item) {
                item.parent = win.contentItem;
            }
        }
    }

    Component {
        id: tooltipOverlay

        Item {
            id: overlay
            z: 99999
            width: bubble.width
            height: bubble.height + arrowSize

            // cell 左上角在窗口坐标系中的位置
            property point cellTopLeft: {
                var win = root.Window.window;
                if (!win)
                    return Qt.point(0, 0);
                return root.mapToItem(win.contentItem, 0, 0);
            }

            // 省略号中心的 X 锚点（窗口坐标系）
            property real anchorX: {
                var win = root.Window.window;
                if (!win)
                    return 0;
                var pt = root.mapToItem(win.contentItem, root._ellipsisLocalX, 0);
                return pt.x;
            }

            readonly property real arrowSize: 6
            readonly property real winW: root.Window.window ? root.Window.window.width : 800
            readonly property real winH: root.Window.window ? root.Window.window.height : 600

            // 约束矩形：优先 boundsItem，否则整个窗口
            readonly property rect boundsRect: {
                var win = root.Window.window;
                if (!win)
                    return Qt.rect(0, 0, winW, winH);
                if (root.boundsItem) {
                    var tl = root.boundsItem.mapToItem(win.contentItem, 0, 0);
                    return Qt.rect(tl.x, tl.y, root.boundsItem.width, root.boundsItem.height);
                }
                return Qt.rect(0, 0, winW, winH);
            }

            // 气泡尺寸：按内容撑开，上限 tooltipMaxWidth
            readonly property real bubbleW: Math.min(root.tooltipMaxWidth, bubbleText.implicitWidth + 18)
            readonly property real bubbleH: bubbleText.implicitHeight + 16

            // 水平：省略号居中展开，越界时在 boundsRect 内收栏
            readonly property real _idealX: anchorX - bubbleW * 0.5
            readonly property real _minX: boundsRect.x + 4
            readonly property real _maxX: boundsRect.x + boundsRect.width - bubbleW - 4
            readonly property real bubbleXInWin: Math.max(_minX, Math.min(_idealX, Math.max(_minX, _maxX)))

            // 三角 X（相对 overlay）：对准省略号中心，clamp 在气泡两端
            readonly property real arrowX: Math.max(4, Math.min(anchorX - bubbleXInWin - arrowSize, bubbleW - arrowSize * 2 - 4))

            // 垂直：默认在 cell 上方；上方超出 boundsRect 顶边时翻转到下方
            readonly property bool flipDown: (cellTopLeft.y - bubbleH - arrowSize) < (boundsRect.y + 4)
            readonly property real bubbleY: flipDown ? arrowSize : 0
            readonly property real arrowY: flipDown ? 0 : bubbleH

            x: bubbleXInWin
            y: (flipDown ? (cellTopLeft.y + root.height) : (cellTopLeft.y - bubbleH - arrowSize)) + 5

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            // 气泡主体
            Rectangle {
                id: bubble
                x: 0
                y: overlay.bubbleY
                width: overlay.bubbleW
                height: overlay.bubbleH
                color: "#1e5a8e"
                radius: 4

                Text {
                    id: bubbleText
                    anchors {
                        left: parent.left
                        leftMargin: 9
                        right: parent.right
                        rightMargin: 9
                        top: parent.top
                        topMargin: 8
                    }
                    text: root.value
                    color: "white"
                    font.pixelSize: 13
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 999
                }
            }

            // 小三角
            Canvas {
                id: arrowCanvas
                width: overlay.arrowSize * 2
                height: overlay.arrowSize
                x: overlay.arrowX
                y: overlay.arrowY

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "#1e5a8e";
                    ctx.beginPath();
                    if (overlay.flipDown) {
                        ctx.moveTo(width * 0.5, 0);
                        ctx.lineTo(0, height);
                        ctx.lineTo(width, height);
                    } else {
                        ctx.moveTo(0, 0);
                        ctx.lineTo(width * 0.5, height);
                        ctx.lineTo(width, 0);
                    }
                    ctx.closePath();
                    ctx.fill();
                }

                Component.onCompleted: requestPaint()
            }
        }
    }
}
