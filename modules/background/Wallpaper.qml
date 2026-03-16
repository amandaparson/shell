pragma ComponentBehavior: Bound

import qs.components
import qs.components.images
import qs.components.filedialog
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

Item {
    id: root

    property string source: Wallpapers.current
    property Image current: one
    property bool ready: false

    Component.onCompleted: {
        if (source) Qt.callLater(() => one.update());
    }

    onSourceChanged: {
        if (!source) {
            current = null;
        } else if (!one.path) {
            one.path = source;
            transitionProgress = 0;
        } else if (source === one.path) {
            debounceTimer.stop();
            initialDelayTimer.stop();
            pendingWallpaper = "";
        } else {
            pendingWallpaper = source;
            if (transitioning || debounceTimer.running) {
                debounceTimer.restart();
            } else if (initialDelayTimer.running) {
                initialDelayTimer.restart();
            } else {
                initialDelayTimer.start();
            }
        }
    }

    Timer {
        id: initialDelayTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (pendingWallpaper && pendingWallpaper !== one.path && pendingWallpaper === source) {
                changeWallpaper();
            }
        }
    }

    Timer {
        id: debounceTimer
        interval: 1100
        repeat: false
        onTriggered: {
            if (pendingWallpaper && pendingWallpaper !== one.path && pendingWallpaper === source) {
                changeWallpaper();
            }
        }
    }

    Timer {
        id: autoRandomTimer
        interval: 300000
        running: false
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            Quickshell.execDetached(["caelestia", "wallpaper", "--random"]);
        }
    }

    Timer {
        id: timeBasedTimer
        interval: 60000
        running: false
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (Config.background && Config.background.timeBasedWallpaper === true) {
                const scheduledWallpaper = getScheduledWallpaper();
                
                if (scheduledWallpaper) {
                    // Expand ~ to home directory
                    let expandedPath = scheduledWallpaper;
                    if (scheduledWallpaper.startsWith("~/")) {
                        expandedPath = Quickshell.env("HOME") + scheduledWallpaper.substring(1);
                    }
                    
                    if (expandedPath !== one.path) {
                        console.log("Time-based wallpaper change:", expandedPath);
                        Quickshell.execDetached(["caelestia", "wallpaper", "-f", expandedPath]);
                    }
                }
            }
        }
    }
    
    Timer {
        id: minuteAlignTimer
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            // Check schedule immediately when aligned to minute
            if (Config.background && Config.background.timeBasedWallpaper === true) {
                const scheduledWallpaper = getScheduledWallpaper();
                
                if (scheduledWallpaper) {
                    let expandedPath = scheduledWallpaper;
                    if (scheduledWallpaper.startsWith("~/")) {
                        expandedPath = Quickshell.env("HOME") + scheduledWallpaper.substring(1);
                    }
                    
                    if (expandedPath !== one.path) {
                        console.log("Time-based wallpaper change (startup):", expandedPath);
                        Quickshell.execDetached(["caelestia", "wallpaper", "-f", expandedPath]);
                    }
                }
            }
            timeBasedTimer.running = true;
        }
    }

    Timer {
        running: true
        interval: 0
        onTriggered: root.ready = true
    }

    Loader {
        anchors.fill: parent

        active: root.ready && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Appearance.spacing.large

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.extraLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Appearance.font.size.extraLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Appearance.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Appearance.padding.small * 2

                        radius: Appearance.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary

                            function onClicked(): void {
                                dialog.open();
                            }
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font.pointSize: Appearance.font.size.large
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: shaderLoader
        anchors.fill: parent
        active: true

        sourceComponent: {
            switch (root.activeTransitionType) {
            case "wipe":
                return wipeShaderComponent;
            case "disc":
                return discShaderComponent;
            case "stripes":
                return stripesShaderComponent;
            case "fade":
            default:
                return fadeShaderComponent;
            }
        }
    }

    Component {
        id: fadeShaderComponent
        ShaderEffect {
            anchors.fill: parent

            property variant source1: one
            property variant source2: two
            property real progress: root.transitionProgress
            property real fillMode: 1.0
            property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
            property real imageWidth1: source1.sourceSize.width || source1.implicitWidth
            property real imageHeight1: source1.sourceSize.height || source1.implicitHeight
            property real imageWidth2: source2.sourceSize.width || source2.implicitWidth
            property real imageHeight2: source2.sourceSize.height || source2.implicitHeight
            property real screenWidth: width
            property real screenHeight: height

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/wp_fade.frag.qsb")
        }
    }

    Component {
        id: wipeShaderComponent
        ShaderEffect {
            anchors.fill: parent

            property variant source1: one
            property variant source2: two
            property real progress: root.transitionProgress
            property real smoothness: 0.05
            property real direction: root.wipeDirection
            property real fillMode: 1.0
            property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
            property real imageWidth1: source1.sourceSize.width || source1.implicitWidth
            property real imageHeight1: source1.sourceSize.height || source1.implicitHeight
            property real imageWidth2: source2.sourceSize.width || source2.implicitWidth
            property real imageHeight2: source2.sourceSize.height || source2.implicitHeight
            property real screenWidth: width
            property real screenHeight: height

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/wp_wipe.frag.qsb")
        }
    }

    Component {
        id: discShaderComponent
        ShaderEffect {
            anchors.fill: parent

            property variant source1: one
            property variant source2: two
            property real progress: root.transitionProgress
            property real smoothness: 0.05
            property real aspectRatio: width / height
            property real centerX: root.discCenterX
            property real centerY: root.discCenterY
            property real fillMode: 1.0
            property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
            property real imageWidth1: source1.sourceSize.width || source1.implicitWidth
            property real imageHeight1: source1.sourceSize.height || source1.implicitHeight
            property real imageWidth2: source2.sourceSize.width || source2.implicitWidth
            property real imageHeight2: source2.sourceSize.height || source2.implicitHeight
            property real screenWidth: width
            property real screenHeight: height

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/wp_disc.frag.qsb")
        }
    }

    Component {
        id: stripesShaderComponent
        ShaderEffect {
            anchors.fill: parent

            property variant source1: one
            property variant source2: two
            property real progress: root.transitionProgress
            property real smoothness: 0.05
            property real aspectRatio: width / height
            property real stripeCount: root.stripesCount
            property real angle: root.stripesAngle
            property real fillMode: 1.0
            property vector4d fillColor: Qt.vector4d(0, 0, 0, 1)
            property real imageWidth1: source1.sourceSize.width || source1.implicitWidth
            property real imageHeight1: source1.sourceSize.height || source1.implicitHeight
            property real imageWidth2: source2.sourceSize.width || source2.implicitWidth
            property real imageHeight2: source2.sourceSize.height || source2.implicitHeight
            property real screenWidth: width
            property real screenHeight: height

            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/assets/shaders/wp_stripes.frag.qsb")
        }
    }

    NumberAnimation {
        id: transitionAnimation
        target: root
        property: "transitionProgress"
        from: 0.0
        to: 1.0
        duration: Config.background.transitionDuration ?? 1000
        easing.type: Easing.InOutCubic
        onFinished: {
            one.path = two.path;
            Qt.callLater(() => {
                two.path = "";
            });
        }
    }

    Img {
        id: one
    }

    Img {
        id: two
    }

    component Img: CachingImage {
        id: img

        anchors.fill: parent
        visible: false
        smooth: true
        cache: false
        asynchronous: true
    }
}
