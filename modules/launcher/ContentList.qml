pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils

Item {
    id: root

    required property var content
    required property DrawerVisibilities visibilities
    required property var panels
    required property real maxHeight
    required property StyledTextField search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: search.text.startsWith(`${Config.launcher.actionPrefix}wallpaper `)
    readonly property bool showClipboard: search.text.startsWith(`${Config.launcher.actionPrefix}clipboard `)
    readonly property bool showEmoji: search.text.startsWith(`${Config.launcher.actionPrefix}emoji `)
    readonly property var currentList: {
        if (showWallpapers)
            return wallpaperList.item;
        if (showClipboard)
            return clipboardList.item;
        if (showEmoji)
            return emojiList.item;
        return appList.item;
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    clip: true
    state: {
        if (showWallpapers)
            return "wallpapers";
        if (showClipboard)
            return "clipboard";
        if (showEmoji)
            return "emoji";
        return "apps";
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.implicitWidth: Config.launcher.sizes.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight)
                appList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                root.implicitWidth: Math.max(Config.launcher.sizes.itemWidth * 1.2, wallpaperList.implicitWidth, folderBar.implicitWidth)
                root.implicitHeight: Config.launcher.sizes.wallpaperHeight + (folderBar.active ? folderBar.implicitHeight + Appearance.spacing.normal : 0)
                wallpaperList.active: true
                folderBar.active: Config.launcher.folderSelection
            }
        },
        State {
            name: "clipboard"

            PropertyChanges {
                root.implicitWidth: Config.launcher.sizes.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, clipboardList.implicitHeight > 0 ? clipboardList.implicitHeight : empty.implicitHeight)
                clipboardList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "emoji"

            PropertyChanges {
                root.implicitWidth: Config.launcher.sizes.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, emojiList.implicitHeight > 0 ? emojiList.implicitHeight : empty.implicitHeight)
                emojiList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        }
    ]

    Behavior on state {
        enabled: !root.content.loadedWithInitialText

        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.anim.durations.small
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.small
            }
        }
    }

    Loader {
        id: appList

        active: false

        anchors.fill: parent

        sourceComponent: AppList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Loader {
        id: folderBar

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: FolderBar {
        }
    }

    Loader {
        id: wallpaperList

        active: false

        anchors.top: folderBar.bottom
        anchors.topMargin: Appearance.spacing.normal
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: WallpaperList {
            search: root.search
            visibilities: root.visibilities
            panels: root.panels
            content: root.content
        }
    }

    Loader {
        id: clipboardList

        active: false

        anchors.fill: parent

        sourceComponent: ClipboardList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Loader {
        id: emojiList

        active: false

        anchors.fill: parent

        sourceComponent: EmojiList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Row {
        id: empty

        opacity: root.currentList?.count === 0 ? 1 : 0
        scale: root.currentList?.count === 0 ? 1 : 0.5

        spacing: Appearance.spacing.normal
        padding: Appearance.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.state === "emoji" ? 50 : 0

        MaterialIcon {
            text: {
                if (root.state === "wallpapers")
                    return "wallpaper_slideshow";
                if (root.state === "clipboard")
                    return "content_paste";
                if (root.state === "emoji")
                    return "sentiment_satisfied";
                return "manage_search";
            }
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: {
                    if (root.state === "wallpapers")
                        return qsTr("No wallpapers found");
                    if (root.state === "clipboard")
                        return qsTr("No clipboard history");
                    if (root.state === "emoji")
                        return qsTr("No emojis found");
                    return qsTr("No results");
                }
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.larger
                font.weight: 500
            }

            StyledText {
                text: {
                    if (root.state === "wallpapers" && Wallpapers.list.length === 0)
                        return qsTr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir));
                    if (root.state === "clipboard")
                        return qsTr("Copy something to populate clipboard history");
                    if (root.state === "emoji")
                        return qsTr("Try searching for an emoji");
                    return qsTr("Try searching for something else");
                }
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Appearance.font.size.normal
            }
        }

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.visibilities.launcher

        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
        }
    }

    Behavior on implicitHeight {
        enabled: root.visibilities.launcher && !root.content.loadedWithInitialText

        Anim {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
        }
    }
}
