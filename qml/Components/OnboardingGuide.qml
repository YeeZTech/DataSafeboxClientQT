import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.LocalStorage 2.15

/**
 * OnboardingGuide — full-screen step-by-step feature tour overlay.
 *
 * Usage:
 *   OnboardingGuide {
 *       anchors.fill: parent
 *       z: 1000
 *       flickable: myScrollView.contentItem  // optional, enables auto-scroll
 *       steps: [
 *           { title: "功能标题", desc: "说明文字", targetItem: someItem },
 *           ...
 *       ]
 *       // Component.onCompleted: Qt.callLater(showIfNeeded)
 *   }
 */
Item {
    id: root

    // Do NOT fill parent by default — caller must set geometry/anchors.
    visible: false

    // Steps data: array of { title: string, desc: string, targetItem: Item }
    property var steps: []

    // Pass the Flickable (scrollView.contentItem) to enable auto-scroll per step.
    property var flickable: null

    property int currentStep: 0
    readonly property int totalSteps: steps.length

    // Tracks the "不再提示" checkbox state on the last step.
    property bool _neverShowAgain: false

    // -----------------------------------------------------------------------
    // Persistence via LocalStorage (no external QML module needed)
    // -----------------------------------------------------------------------

    function _db() {
        return LocalStorage.openDatabaseSync("datasafebox", "1.0", "App Settings", 100000)
    }

    function _isShown() {
        var result = false
        try {
            _db().transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS onboarding (key TEXT UNIQUE, value TEXT)")
                var rs = tx.executeSql("SELECT value FROM onboarding WHERE key='guide_shown'")
                if (rs.rows.length > 0 && rs.rows.item(0).value === "1") result = true
            })
        } catch(e) {
            console.warn("[OnboardingGuide] read guide_shown failed:", e)
        }
        return result
    }

    function _markShown() {
        try {
            _db().transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS onboarding (key TEXT UNIQUE, value TEXT)")
                tx.executeSql("INSERT OR REPLACE INTO onboarding (key, value) VALUES ('guide_shown', '1')")
            })
        } catch(e) {
            console.warn("[OnboardingGuide] write guide_shown failed:", e)
        }
    }

    // -----------------------------------------------------------------------
    // Public API
    // -----------------------------------------------------------------------

    /** Show the guide if it has not been permanently dismissed. */
    function showIfNeeded() {
        if (_isShown()) return
        if (steps.length === 0) return
        currentStep = 0
        _neverShowAgain = false
        visible = true
        if (flickable) flickable.interactive = false
        _schedulePosition()
    }

    /** Show the guide unconditionally (public API for button clicks). */
    function show() {
        if (steps.length === 0) return
        currentStep = 0
        _neverShowAgain = false
        visible = true
        if (flickable) flickable.interactive = false
        _schedulePosition()
    }

    onVisibleChanged: {
        if (!visible && flickable) flickable.interactive = true
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    function _goTo(idx) {
        currentStep = idx
        _neverShowAgain = false
        _schedulePosition()
    }

    function _schedulePosition() {
        _posTimer.restart()
    }

    function _updateBubble() {
        var step = (steps.length > currentStep) ? steps[currentStep] : null
        if (!step || !step.targetItem) {
            _bx = (root.width  - _bubbleW) / 2
            _by = (root.height - 200)      / 2
            _arrowOnTop   = false
            _arrowOffsetX = _bubbleW / 2
            _spotX = 0; _spotY = 0; _spotW = 0; _spotH = 0
            return
        }

        var bw      = _bubbleW
        var gap     = 8
        var actualH = bubbleBody.height > 0 ? bubbleBody.height : 160
        var forceBelow = (currentStep <= 1)
        var arrowOnTop = forceBelow

        // ── Auto-scroll: bring target fully into view (if a flickable is set
        // AND the target is actually a descendant of the flickable content).
        if (flickable && step.targetItem) {
            var contentRoot = flickable.contentItem ? flickable.contentItem : flickable
            var isDescendant = false
            var pp = step.targetItem.parent
            while (pp) {
                if (pp === contentRoot) { isDescendant = true; break }
                pp = pp.parent
            }
            if (isDescendant) {
                var fpos = step.targetItem.mapToItem(contentRoot, 0, 0)
                var viewportH = flickable.height
                var tH = step.targetItem.height
                var bubbleSpace = actualH + gap + 24
                var desiredTop
                if (arrowOnTop) {
                    desiredTop = 24
                } else {
                    desiredTop = bubbleSpace
                }
                var maxDesiredTop = Math.max(24, viewportH - Math.min(tH, viewportH - 24))
                desiredTop = Math.min(desiredTop, maxDesiredTop)
                var newContentY = fpos.y - desiredTop
                newContentY = Math.max(0, Math.min(Math.max(0, flickable.contentHeight - viewportH), newContentY))
                if (Math.abs(flickable.contentY - newContentY) > 1) {
                    flickable.contentY = newContentY
                }
            }
        }

        var overlayItem = root
        var pos  = step.targetItem.mapToItem(overlayItem, 0, 0)
        var tx   = pos.x + step.targetItem.width  / 2

        // Clamp bubble horizontally.
        var bx = Math.max(12, Math.min(overlayItem.width - bw - 12, tx - bw / 2))

        var by
        if (arrowOnTop) {
            // bubble below target
            by = pos.y + step.targetItem.height + gap
        } else {
            // bubble above target
            by = pos.y - gap - actualH
        }
        by = Math.max(12, Math.min(overlayItem.height - actualH - 12, by))

        // Arrow horizontal offset: align arrow tip with target centre.
        var arrowX = Math.max(16, Math.min(bw - 16, tx - bx))

        _bx           = bx
        _by           = by
        _arrowOnTop   = arrowOnTop
        _arrowOffsetX = arrowX

        // ── Spotlight ─────────────────────────────────────────────────────
        var sPad = 0
        _spotX = Math.round(Math.max(0, pos.x - sPad))
        _spotY = Math.round(Math.max(0, pos.y - sPad))
        _spotW = Math.round(Math.min(overlayItem.width  - _spotX, step.targetItem.width  + 2 * sPad))
        _spotH = Math.round(Math.min(overlayItem.height - _spotY, step.targetItem.height + 2 * sPad))

        // Force Canvas repaint for updated arrow colour/shape.
        arrowTop.requestPaint()
        arrowBottom.requestPaint()
        if (typeof dimMask !== "undefined" && dimMask) dimMask.requestPaint()
    }

    // -----------------------------------------------------------------------
    // Internal state
    // -----------------------------------------------------------------------
    readonly property int _bubbleW: 370
    property real _bx: 200
    property real _by: 200
    property bool _arrowOnTop: true
    property real _arrowOffsetX: 170

    // Spotlight — area that stays bright beneath the overlay
    property real _spotX: 0
    property real _spotY: 0
    property real _spotW: 0
    property real _spotH: 0

    Timer {
        id: _posTimer
        interval: 80
        onTriggered: root._updateBubble()
    }

    // -----------------------------------------------------------------------
    // UI
    // -----------------------------------------------------------------------

    // Full-window event blocker — absorbs all clicks/hovers/wheel while guide is shown.
    Item {
        id: eventBlocker
        anchors.fill: parent
        z: 99998
        // 防止 root.visible=false 后 MouseArea/WheelHandler 仍意外捕获事件
        visible: root.visible
        enabled: root.visible

        // Dim mask with a rounded-rect spotlight cutout — drawn as a single
        // Canvas using even-odd fill so the hole has true rounded corners
        // matching the highlighted control.
        readonly property real _dimAlpha: 0.55
        readonly property color _dimColor: Qt.rgba(0, 0, 0, _dimAlpha)
        readonly property real _spotRadius: 8

        Canvas {
            id: dimMask
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative

            // Repaint when geometry or spot region changes.
            Connections {
                target: root
                function onWidthChanged()  { dimMask.requestPaint() }
                function onHeightChanged() { dimMask.requestPaint() }
                function on_SpotXChanged() { dimMask.requestPaint() }
                function on_SpotYChanged() { dimMask.requestPaint() }
                function on_SpotWChanged() { dimMask.requestPaint() }
                function on_SpotHChanged() { dimMask.requestPaint() }
            }
            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = eventBlocker._dimColor

                ctx.beginPath()
                // Outer rect — clockwise.
                ctx.rect(0, 0, width, height)

                // Inner rounded rect — counter-clockwise, so even-odd fill
                // subtracts it, leaving a transparent rounded "hole".
                var sx = root._spotX, sy = root._spotY
                var sw = root._spotW, sh = root._spotH
                if (sw > 0 && sh > 0) {
                    var r = Math.min(eventBlocker._spotRadius, sw / 2, sh / 2)
                    ctx.moveTo(sx + r, sy)
                    // top-left corner (CCW)
                    ctx.arc(sx + r,        sy + r,        r, -Math.PI / 2, Math.PI,       true)
                    ctx.lineTo(sx, sy + sh - r)
                    // bottom-left corner
                    ctx.arc(sx + r,        sy + sh - r,   r, Math.PI,      Math.PI / 2,   true)
                    ctx.lineTo(sx + sw - r, sy + sh)
                    // bottom-right corner
                    ctx.arc(sx + sw - r,   sy + sh - r,   r, Math.PI / 2,  0,             true)
                    ctx.lineTo(sx + sw, sy + r)
                    // top-right corner
                    ctx.arc(sx + sw - r,   sy + r,        r, 0,           -Math.PI / 2,   true)
                    ctx.closePath()
                }

                ctx.fill("evenodd")
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) { event.accepted = true }
        }
    }

    // Bubble container (animated position).
    Item {
        id: bubbleContainer
        z: 99999
        visible: root.visible
        enabled: root.visible
        x: root._bx
        y: root._by
        width: root._bubbleW

        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // ── Arrow pointing UP (bubble is below the target) ──────────────────
        Canvas {
            id: arrowTop
            visible: root._arrowOnTop
            width: 16
            height: 9
            x: root._arrowOffsetX - width / 2
            y: -height + 1
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "#1a3d6e"
                ctx.beginPath()
                ctx.moveTo(0, height)
                ctx.lineTo(width / 2, 0)
                ctx.lineTo(width, height)
                ctx.closePath()
                ctx.fill()
            }
        }

        // ── Main bubble ──────────────────────────────────────────────────────
        Rectangle {
            id: bubbleBody
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.top:   parent.top
            height:        bubbleCol.implicitHeight + 36
            radius:        12
            color:         "#1a3d6e"

            onHeightChanged: root._schedulePosition()

            // Subtle top-highlight border
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
            }

            Column {
                id: bubbleCol
                anchors {
                    left:    parent.left
                    right:   parent.right
                    top:     parent.top
                    margins: 16
                }
                spacing: 10

                // ── Title row: title left, counter right ──────────────────
                Item {
                    width:  parent.width
                    height: titleText.implicitHeight

                    Text {
                        id: titleText
                        anchors.left:          parent.left
                        anchors.right:         stepCounter.left
                        anchors.rightMargin:   8
                        anchors.verticalCenter: parent.verticalCenter
                        text:            (root.steps.length > root.currentStep) ? (root.steps[root.currentStep].title || "") : ""
                        font.pixelSize:  13
                        font.weight:     Font.Medium
                        color:           "#ffffff"
                        wrapMode:        Text.WordWrap
                    }

                    Text {
                        id: stepCounter
                        anchors.right:         parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:            (root.currentStep + 1) + "/" + root.totalSteps
                        font.pixelSize:  11
                        font.weight:     Font.Medium
                        color:           Qt.rgba(1, 1, 1, 0.45)
                        font.letterSpacing: 0.3
                    }
                }

                // ── Divider ───────────────────────────────────────────────
                Rectangle {
                    width:  parent.width
                    height: 1
                    color:  Qt.rgba(1, 1, 1, 0.1)
                }

                // ── Description ───────────────────────────────────────────
                Text {
                    width:              parent.width
                    text:               (root.steps.length > root.currentStep) ? (root.steps[root.currentStep].desc || "") : ""
                    font.pixelSize:     11
                    color:              Qt.rgba(1, 1, 1, 0.82)
                    wrapMode:           Text.WordWrap
                    lineHeight:         1.55
                    font.letterSpacing: -0.2
                }

                // ── Navigation row ────────────────────────────────────────
                Item {
                    width:  parent.width
                    height: 28

                    Row {
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Rectangle {
                            width:   14
                            height:  14
                            radius:  3
                            anchors.verticalCenter: parent.verticalCenter
                            color:        root._neverShowAgain ? (cbMouseArea.pressed ? "#3a8fc7" : cbMouseArea.containsMouse ? "#5ab0e8" : "#4ca3e0")
                                          : cbMouseArea.pressed ? Qt.rgba(1, 1, 1, 0.15)
                                          : cbMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08)
                                          : "transparent"
                            border.color: root._neverShowAgain ? "transparent"
                                          : cbMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.4)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text:    "✓"
                                font.pixelSize:  9
                                font.weight:     Font.Bold
                                color:   "white"
                                visible: root._neverShowAgain
                            }

                            MouseArea {
                                id: cbMouseArea
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root._neverShowAgain = !root._neverShowAgain
                                }
                            }
                        }

                        Text {
                            text:           qsTr("Don't show again")
                            font.pixelSize: 11
                            color:          cbMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.65)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 120 } }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    root._neverShowAgain = !root._neverShowAgain
                                }
                            }
                        }
                    }

                    // "上一步" ghost button
                    Rectangle {
                        id: prevBtn
                        visible:                root.currentStep > 0
                        anchors.right:          nextBtn.left
                        anchors.rightMargin:    8
                        anchors.verticalCenter: parent.verticalCenter
                        width:   prevBtnLabel.implicitWidth + 18
                        height:  26
                        radius:  6
                        color:   prevBtnArea.pressed ? Qt.rgba(1, 1, 1, 0.15)
                                 : prevBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08)
                                 : "transparent"
                        border.color: prevBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.3)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: prevBtnLabel
                            anchors.centerIn: parent
                            text:           qsTr("Previous")
                            font.pixelSize: 11
                            font.weight:    Font.Medium
                            color:          prevBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 1.0) : Qt.rgba(1, 1, 1, 0.75)
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: prevBtnArea
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked:    root._goTo(root.currentStep - 1)
                        }
                    }

                    // "下一步" / "开始使用" filled button
                    Rectangle {
                        id:      nextBtn
                        anchors.right:         parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width:   nextBtnLabel.implicitWidth + 22
                        height:  26
                        radius:  6
                        color:   nextBtnArea.pressed ? "#c8d8ea"
                                 : nextBtnArea.containsMouse ? "#e8f0f8"
                                 : "#ffffff"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id:             nextBtnLabel
                            anchors.centerIn: parent
                            text:           (root._neverShowAgain || root.currentStep === root.totalSteps - 1) ? qsTr("Get Started") : qsTr("Next")
                            font.pixelSize: 11
                            font.weight:    Font.Medium
                            color:          "#1a3d6e"
                        }

                        MouseArea {
                            id: nextBtnArea
                            anchors.fill: parent
                            cursorShape:  Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                if (!root._neverShowAgain && root.currentStep < root.totalSteps - 1) {
                                    root._goTo(root.currentStep + 1)
                                } else {
                                    if (root._neverShowAgain) root._markShown()
                                    root.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Arrow pointing DOWN (bubble is above the target) ─────────────────
        Canvas {
            id: arrowBottom
            visible: !root._arrowOnTop
            width: 16
            height: 9
            x: root._arrowOffsetX - width / 2
            y: bubbleBody.height - 1
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "#1a3d6e"
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(width / 2, height)
                ctx.lineTo(width, 0)
                ctx.closePath()
                ctx.fill()
            }
        }
    }
}
