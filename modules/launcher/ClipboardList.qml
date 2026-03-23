pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "items"
import "services"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config

StyledListView {
    id: root

    required property StyledTextField search
    required property PersistentProperties visibilities

    property string activeCategory: "all"
    property bool showClearConfirmation: false
    property var hoveredItem: null
    property string lastInteraction: "keyboard"

    property bool isCategoryChange: false
    property int deletedItemIndex: -1
    property string previousCategory: "all"
    property var pendingModelUpdate: null

    function filterAndSortItems(): var {
        const pattern = new RegExp("^" + Config.launcher.actionPrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + "clipboard\\s*", "i");
        const query = root.search.text.replace(pattern, "").trim();
        let items = Clipboard.history; // qmllint disable missing-property

        if (root.activeCategory === "images") {
            items = items.filter(item => item.isImage);
        } else if (root.activeCategory === "misc") {
            items = items.filter(item => !item.isImage);
        }

        if (query) {
            const lowerQuery = query.toLowerCase();
            items = items.filter(item => item.content.toLowerCase().includes(lowerQuery));
        }

        items.sort((a, b) => {
            if (a.isPinned && !b.isPinned)
                return -1;
            if (!a.isPinned && b.isPinned)
                return 1;
            return a.index - b.index;
        });

        return items;
    }

    function updateModel(): void {
        model.values = root.filterAndSortItems();
    }

    spacing: Appearance.spacing.small

    orientation: Qt.Vertical

    implicitHeight: {
        if (count === 0)
            return 0;
        const itemsToShow = Math.min(Config.launcher.maxShown, count);
        const baseHeight = (Config.launcher.sizes.itemHeight + spacing) * itemsToShow;
        return baseHeight + (itemsToShow > 0 ? Appearance.spacing.smaller : 0);
    }

    preferredHighlightBegin: 0

    preferredHighlightEnd: height

    highlightRangeMode: ListView.ApplyRange

    onCurrentIndexChanged: {
        if (root.lastInteraction !== "hover") {
            root.lastInteraction = "keyboard";
        }
    }

    onContentYChanged: {
        // Clear hover when list scrolls to prevent accidental hover changes
        root.hoveredItem = null;
    }

    Component.onCompleted: {
        Clipboard.refresh(); // qmllint disable missing-property
        updateModel();
    }

    highlightFollowsCurrentItem: false

    delegate: clipboardItem

    model: ScriptModel {
        id: model

        onValuesChanged: {
            if (root.deletedItemIndex >= 0) {
                if (root.deletedItemIndex <= root.currentIndex) {
                    root.currentIndex = Math.max(0, root.currentIndex - 1);
                }
                root.deletedItemIndex = -1;
            }
        }
    }

    highlight: StyledRect {
        radius: Appearance.rounding.normal
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {
                duration: Appearance.anim.durations.expressiveDefaultSpatial
                easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
            }
        }
    }

    HoverHandler {
        id: listHoverHandler

        onHoveredChanged: {
            if (!hovered) {
                root.hoveredItem = null;
            }
        }
    }

    Component {
        id: clipboardItem

        ClipboardItem {
            visibilities: root.visibilities
        }
    }

    Connections {
        function onHistoryChanged(): void {
            root.updateModel();
        }

        target: Clipboard // qmllint disable incompatible-type
    }

    Connections {
        function onTextChanged(): void {
            root.updateModel();
        }

        target: root.search
    }

    Connections {
        function onActiveCategoryChanged(): void {
            if (root.previousCategory !== root.activeCategory && root.search.text.startsWith(Config.launcher.actionPrefix + "clipboard")) {
                if (categoryChangeAnimation.running) {
                    categoryChangeAnimation.stop();
                    root.opacity = 1;
                    root.scale = 1;
                }

                root.pendingModelUpdate = root.filterAndSortItems();
                root.isCategoryChange = true;
                categoryChangeAnimation.start();
            }
            root.previousCategory = root.activeCategory;
        }
    }

    SequentialAnimation {
        id: categoryChangeAnimation

        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 0
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standardAccel
            }
            Anim {
                target: root
                property: "scale"
                to: 0.95
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.emphasizedAccel
            }
        }

        ScriptAction {
            script: {
                // Update model while invisible
                if (root.pendingModelUpdate !== null) {
                    model.values = root.pendingModelUpdate;
                    root.pendingModelUpdate = null;
                    // Only reset to top when switching categories
                    if (root.isCategoryChange) {
                        root.currentIndex = 0;
                        root.positionViewAtBeginning();
                        root.isCategoryChange = false;
                    }
                }
            }
        }

        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                to: 1
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.standardDecel
            }
            Anim {
                target: root
                property: "scale"
                to: 1
                duration: Appearance.anim.durations.small
                easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
            }
        }
    }

    // Confirmation dialog overlay
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3scrim, 0.5)
        visible: root.showClearConfirmation
        z: 1000

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.normal
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.showClearConfirmation = false
        }

        StyledRect {
            anchors.centerIn: parent
            width: Math.min(400, parent.width - Appearance.padding.large * 2)
            height: confirmContent.implicitHeight + Appearance.padding.large * 2
            color: Colours.palette.m3surfaceContainer
            radius: Appearance.rounding.large

            opacity: root.showClearConfirmation ? 1 : 0
            scale: root.showClearConfirmation ? 1 : 0.8

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.normal
                    easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
                }
            }

            Behavior on scale {
                Anim {
                    duration: Appearance.anim.durations.normal
                    easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
                }
            }

            ColumnLayout {
                id: confirmContent

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Appearance.padding.large
                spacing: Appearance.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (root.activeCategory === "all") {
                            return qsTr("Clear all clipboard items?");
                        } else if (root.activeCategory === "images") {
                            return qsTr("Clear image items?");
                        } else {
                            return qsTr("Clear misc items?");
                        }
                    }
                    font.pointSize: Appearance.font.size.larger
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Non-pinned items in this category will be deleted. Pinned items are preserved.")
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Appearance.spacing.normal
                    spacing: Appearance.spacing.normal

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: qsTr("Cancel")
                        type: TextButton.Text
                        onClicked: root.showClearConfirmation = false
                    }

                    TextButton {
                        text: qsTr("Clear All")
                        type: TextButton.Filled
                        onClicked: {
                            root.showClearConfirmation = false;
                            Clipboard.clearAll(root.activeCategory); // qmllint disable missing-property
                        }
                    }
                }
            }
        }
    }
}
