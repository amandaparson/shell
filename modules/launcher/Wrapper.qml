pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.config

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels

    readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled
    property int contentHeight
    property string pendingSearchText: ""
    property bool _showAnimRetarget: false

    readonly property var currentClipboardItem: {
        const list = content.item?.list?.currentList; // qmllint disable missing-property
        if (!list)
            return null;

        // Use last interaction type to determine priority
        if (list.lastInteraction === "hover" && list.hoveredItem) {
            return list.hoveredItem;
        }
        return list.currentItem;
    }

    readonly property bool showingClipboard: content.item?.list?.showClipboard ?? false // qmllint disable missing-property

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 - Appearance.spacing.large;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    Component.onCompleted: LauncherWrappers.register(root.screen, root)

    onMaxHeightChanged: timer.start()

    visible: height > 0
    implicitHeight: 0
    implicitWidth: content.implicitWidth

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            timer.stop();
            hideAnim.stop();
            if (pendingSearchText) {
                content.active = false;
                content.active = Qt.binding(() => root.shouldBeActive || root.visible);
            } else {
                showAnim.start();
            }
        } else {
            retargetTimer.stop();
            root._showAnimRetarget = false;
            showAnim.stop();
            hideAnim.start();
        }
    }

    SequentialAnimation {
        id: showAnim

        Anim {
            target: root
            property: "implicitHeight"
            to: root.contentHeight
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
        ScriptAction {
            script: {
                root._showAnimRetarget = false;
                root.implicitHeight = Qt.binding(() => content.implicitHeight);
            }
        }
    }

    Timer {
        id: retargetTimer

        interval: 40
        onTriggered: {
            if (showAnim.running) {
                showAnim.stop();
            }
            showAnim.start();
        }
    }

    Connections {
        function onImplicitHeightChanged(): void {
            const h = Math.min(root.maxHeight, content.implicitHeight);
            if (h !== root.contentHeight && h > 0) {
                root.contentHeight = h;
                retargetTimer.restart();
            }
        }

        target: content
        enabled: root._showAnimRetarget
    }

    SequentialAnimation {
        id: hideAnim

        ScriptAction {
            script: root.implicitHeight = root.implicitHeight
        }
        Anim {
            target: root
            property: "implicitHeight"
            to: 0
            easing.bezierCurve: Appearance.anim.curves.emphasized
        }
    }

    Connections {
        function onEnabledChanged(): void {
            timer.start();
        }

        function onMaxShownChanged(): void {
            timer.start();
        }

        target: Config.launcher
    }

    Connections {
        function onValuesChanged(): void {
            if (DesktopEntries.applications.values.length < Config.launcher.maxShown)
                timer.start();
        }

        target: DesktopEntries.applications
    }

    Timer {
        id: timer

        interval: Appearance.anim.durations.extraLarge
        onRunningChanged: {
            if (running && !root.shouldBeActive) {
                content.visible = false;
                content.active = true;
            } else {
                root.contentHeight = Math.min(root.maxHeight, content.implicitHeight);
                content.active = Qt.binding(() => root.shouldBeActive || root.visible);
                content.visible = true;
                if (showAnim.running) {
                    showAnim.stop();
                    showAnim.start();
                }
            }
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        visible: false
        active: false
        Component.onCompleted: timer.start()

        sourceComponent: Content {
            screen: root.screen
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight
            initialSearchText: root.pendingSearchText

            Component.onCompleted: {
                const hadSearchText = root.pendingSearchText !== "";
                root.pendingSearchText = "";
                root.contentHeight = Math.min(root.maxHeight, implicitHeight);
                if (root.shouldBeActive) {
                    if (hadSearchText) {
                        // IPC: defer start so async clipboard data + layout settle first
                        root._showAnimRetarget = true;
                        retargetTimer.start();
                    } else {
                        if (showAnim.running) {
                            showAnim.stop();
                        }
                        showAnim.start();
                    }
                }
            }
        }
    }
}
