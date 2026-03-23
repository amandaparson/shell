pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.config

StyledRect {
    id: root

    required property var clipboardList

    readonly property var categoryList: [
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

    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
    radius: Appearance.rounding.normal

    implicitHeight: navContent.height + Appearance.padding.small + Appearance.padding.normal

    RowLayout {
        id: navContent

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal
        anchors.topMargin: Appearance.padding.small
        anchors.bottomMargin: Appearance.padding.smaller
        spacing: Appearance.spacing.small

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: tabsRow.height

            // Sliding indicator background
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

                    model: root.categoryList

                    delegate: Item {
                        id: tabDelegate

                        required property var modelData
                        required property int index

                        property bool isActive: root.clipboardList?.activeCategory === tabDelegate.modelData.id

                        implicitWidth: tabContent.width + Appearance.padding.normal * 2
                        implicitHeight: tabContent.height + Appearance.padding.smaller * 2

                        StateLayer {
                            function onClicked(): void {
                                if (root.clipboardList) {
                                    root.clipboardList.activeCategory = tabDelegate.modelData.id;
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
                                text: tabDelegate.modelData.icon
                                font.pointSize: Appearance.font.size.small
                                color: tabDelegate.isActive ? Colours.palette.m3surface : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tabDelegate.modelData.name
                                font.pointSize: Appearance.font.size.small
                                color: tabDelegate.isActive ? Colours.palette.m3surface : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            text: root.clipboardList ? qsTr("%1 items").arg(root.clipboardList.count) : ""
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
            opacity: root.clipboardList?.count > 0 ? 1 : 0

            Behavior on opacity {
                Anim {
                    duration: Appearance.anim.durations.small
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }
    }
}
