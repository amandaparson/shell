pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels
    required property real maxHeight
    property string initialSearchText: ""

    readonly property int padding: Appearance.padding.large
    readonly property int rounding: Appearance.rounding.large
    readonly property alias search: search
    readonly property alias list: list
    readonly property bool showClipboardNav: list.showClipboard
    property bool loadedWithInitialText: false

    implicitWidth: list.width + padding * 2
    implicitHeight: searchWrapper.implicitHeight + list.implicitHeight + clipboardNav.height + (showClipboardNav ? padding : 0) + padding * 2

    Component.onCompleted: {
        LauncherIpc.register(root.screen, root);
        if (initialSearchText) {
            loadedWithInitialText = true;
            search.text = initialSearchText;
            Qt.callLater(() => {
                loadedWithInitialText = false;
            });
        }
    }

    StyledRect {
        id: clipboardNav

        property real targetHeight: root.showClipboardNav ? Math.max(tabsRow.height, tabsRow.implicitHeight) + Appearance.padding.small + Appearance.padding.normal : 0

        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Appearance.rounding.normal

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding

        visible: height > 0
        height: targetHeight
        implicitHeight: targetHeight
        clip: true
        opacity: height / Math.max(1, targetHeight)

        Behavior on height {
            enabled: !root.loadedWithInitialText

            Anim {
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.emphasized
            }
        }

        RowLayout {
            id: navContent

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal
            anchors.topMargin: clipboardNav.targetHeight > 0 ? Appearance.padding.small : 0
            anchors.bottomMargin: clipboardNav.targetHeight > 0 ? Appearance.padding.smaller : 0
            spacing: Appearance.spacing.small

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: Appearance.anim.durations.normal
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Appearance.anim.curves.emphasized
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: tabsRow.height

                StyledRect {
                    id: activeIndicator

                    property Item activeTab: {
                        for (let i = 0; i < tabsRepeater.count; i++) {
                            const tab = tabsRepeater.itemAt(i);
                            if (tab && tab.isActive) { // qmllint disable missing-property
                                return tab;
                            }
                        }
                        return null;
                    }

                    visible: activeTab !== null
                    color: Colours.palette.m3primary
                    radius: 10

                    x: activeTab ? activeTab.x : 0
                    y: activeTab ? activeTab.y : 0
                    width: activeTab ? activeTab.width : 0
                    height: activeTab ? activeTab.height : 0

                    Behavior on x {
                        Anim {
                            duration: Appearance.anim.durations.normal
                            easing.bezierCurve: Appearance.anim.curves.emphasized
                        }
                    }

                    Behavior on width {
                        Anim {
                            duration: Appearance.anim.durations.normal
                            easing.bezierCurve: Appearance.anim.curves.emphasized
                        }
                    }
                }

                Row {
                    id: tabsRow

                    spacing: Appearance.spacing.small

                    Repeater {
                        id: tabsRepeater

                        model: [
                            {
                                id: "all",
                                name: qsTr("All"),
                                icon: "apps"
                            },
                            {
                                id: "images",
                                name: qsTr("Images"),
                                icon: "image"
                            },
                            {
                                id: "misc",
                                name: qsTr("Misc"),
                                icon: "description"
                            }
                        ]

                        delegate: Item {
                            id: categoryTab

                            required property var modelData
                            required property int index

                            property bool isActive: list.showClipboard && list.currentList?.activeCategory === modelData.id

                            implicitWidth: tabContent.width + Appearance.padding.normal * 2
                            implicitHeight: tabContent.height + Appearance.padding.smaller * 2

                            StateLayer {
                                function onClicked(): void {
                                    if (list.currentList) {
                                        list.currentList.activeCategory = categoryTab.modelData.id;
                                    }
                                }

                                anchors.fill: parent
                                radius: 6
                            }

                            Row {
                                id: tabContent

                                anchors.centerIn: parent
                                spacing: Appearance.spacing.smaller

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: categoryTab.modelData.icon
                                    font.pointSize: Appearance.font.size.small
                                    color: categoryTab.isActive ? Colours.palette.m3surface : Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: categoryTab.modelData.name
                                    font.pointSize: Appearance.font.size.small
                                    color: categoryTab.isActive ? Colours.palette.m3surface : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.preferredWidth: countText.implicitWidth
                Layout.preferredHeight: countText.implicitHeight

                StyledText {
                    id: countText

                    anchors.centerIn: parent
                    text: list.currentList ? qsTr("%n item(s)", "", list.currentList.count) : ""
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurfaceVariant
                    opacity: list.currentList?.count > 0 ? 1 : 0

                    Behavior on opacity {
                        Anim {
                            duration: Appearance.anim.durations.small
                            easing.bezierCurve: Appearance.anim.curves.standard
                        }
                    }
                }
            }

            IconButton {
                icon: "delete_sweep"
                type: IconButton.Text
                radius: Appearance.rounding.small
                padding: Appearance.padding.small
                disabled: !list.currentList || list.currentList.count === 0
                onClicked: {
                    if (list.currentList && list.currentList.count > 0) {
                        list.currentList.showClearConfirmation = true;
                    }
                }
            }
        }
    }

    ContentList {
        id: list

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clipboardNav.bottom
        anchors.bottom: searchWrapper.top
        anchors.topMargin: root.showClipboardNav ? root.padding : 0
        anchors.bottomMargin: root.padding

        content: root
        visibilities: root.visibilities
        panels: root.panels
        maxHeight: root.maxHeight - searchWrapper.implicitHeight - clipboardNav.height - (root.showClipboardNav ? root.padding : 0) - root.padding * 3
        search: search
        padding: root.padding
        rounding: root.rounding
    }

    StyledRect {
        id: searchWrapper

        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Appearance.rounding.full

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight, clearIcon.implicitHeight)

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "search"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledTextField {
            id: search

            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Appearance.spacing.small
            anchors.rightMargin: Appearance.spacing.small

            topPadding: Appearance.padding.larger
            bottomPadding: Appearance.padding.larger

            placeholderText: qsTr("Type \"%1\" for commands").arg(Config.launcher.actionPrefix)

            onAccepted: {
                const currentItem = list.currentList?.currentItem;
                if (currentItem) {
                    if (list.showWallpapers) {
                        if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                            Wallpapers.previewColourLock = true;
                        Wallpapers.setWallpaper(currentItem.modelData.path);
                        root.visibilities.launcher = false;
                    } else if (list.showClipboard) {
                        Clipboard.copyToClipboard(currentItem.modelData);
                        root.visibilities.launcher = false;
                    } else if (list.showEmoji) {
                        Emojis.copyEmoji(currentItem.modelData);
                        root.visibilities.launcher = false;
                    } else if (text.startsWith(Config.launcher.actionPrefix)) {
                        if (text.startsWith(`${Config.launcher.actionPrefix}calc `))
                            currentItem.onClicked();
                        else
                            currentItem.modelData.onClicked(list.currentList);
                    } else {
                        Apps.launch(currentItem.modelData);
                        root.visibilities.launcher = false;
                    }
                }
            }

            Keys.onUpPressed: event => {
                if (event.modifiers & Qt.ShiftModifier && list.showWallpapers) {
                    if (!Config.launcher.folderSelection) return;
                    
                    if (Config.launcher.folderWrapAround) {
                        const len = Wallpapers.folders.length;
                        Wallpapers.currentFolderIndex = (Wallpapers.currentFolderIndex - 1 + len) % len;
                    } else {
                        Wallpapers.currentFolderIndex = Math.max(0, Wallpapers.currentFolderIndex - 1);
                    }
                } else {
                    list.currentList?.decrementCurrentIndex();
                }
            }
            Keys.onDownPressed: event => {
                if (event.modifiers & Qt.ShiftModifier && list.showWallpapers) {
                    if (!Config.launcher.folderSelection) return;

                    if (Config.launcher.folderWrapAround) {
                        const len = Wallpapers.folders.length;
                        Wallpapers.currentFolderIndex = (Wallpapers.currentFolderIndex + 1) % len;
                    } else {
                        Wallpapers.currentFolderIndex = Math.min(Wallpapers.folders.length - 1, Wallpapers.currentFolderIndex + 1);
                    }
                } else {
                    list.currentList?.incrementCurrentIndex();
                }
            }

            Keys.onLeftPressed: event => {
                if (list.showEmoji && list.currentList && list.currentList.moveLeft) {
                    list.currentList.moveLeft();
                    event.accepted = true;
                }
            }

            Keys.onRightPressed: event => {
                if (list.showEmoji && list.currentList && list.currentList.moveRight) {
                    list.currentList.moveRight();
                    event.accepted = true;
                }
            }

            Keys.onEscapePressed: root.visibilities.launcher = false

            Keys.onPressed: event => {
                if (!Config.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J) {
                        list.currentList?.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        list.currentList?.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                function onLauncherChanged(): void {
                    if (!root.visibilities.launcher)
                        search.text = "";
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session)
                        search.forceActiveFocus();
                }

                target: root.visibilities
            }
        }

        MaterialIcon {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.padding

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            text: "close"
            color: Colours.palette.m3onSurfaceVariant

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.small
                }
            }
        }
    }
}
