import QtQuick
import QtQuick.Layouts

// Pure UI: the window supplies existing services; no duplicate state or commands.
Rectangle {
    id: deck
    required property var source
    property var media: null
    property var resources: null
    property var notifications: []
    property string clockText: "00:00"
    property string dateText: ""
    property bool notificationPage: false
    signal routeRequested(string route)
    signal searchRequested(string query)
    signal closeRequested()
    signal dismissRequested(string key)
    width: 1100; height: 670
    radius: 18
    color: "#191c24"
    border.color: "#596170"; border.width: 2

    component Label: Text {
        color: "#c6ccd8"; font.family: "monospace"; font.pixelSize: 12
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }
    component Divider: Rectangle { color: "#303541"; implicitHeight: 1; Layout.fillWidth: true }
    component Card: Rectangle { color: "#0c1018"; border.color: "#303541"; radius: 5 }

    Repeater {
        model: 4
        Rectangle {
            required property int index
            x: index % 2 === 0 ? 13 : deck.width - 25
            y: index < 2 ? 13 : deck.height - 25
            width: 12; height: 12; radius: 6; color: "#080b10"; border.color: "#656c78"
            Rectangle { anchors.centerIn: parent; width: 7; height: 1; rotation: 35; color: "#727a89" }
        }
    }
    Label { x: 42; y: 18; text: "S E K A I P O P"; color: "#a4adbd" }
    Label { anchors.right: parent.right; anchors.rightMargin: 43; y: 18; text: "CYBERDECK / SKP-01"; color: "#8994a6" }

    Card {
        x: 32; y: 48; width: 1036; height: 420
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 13
            RowLayout {
                Label { text: deck.source.userName + "@" + (deck.source.hostName || "umbriel"); Layout.fillWidth: true }
                Label { text: deck.source.networkDetail; color: "#91b3d2"; Layout.maximumWidth: 270 }
                DeckButton { text: "CLOSE ×"; implicitWidth: 88; implicitHeight: 27; onClicked: deck.closeRequested() }
            }
            RowLayout {
                spacing: 8
                Repeater {
                    model: [{text:"DASHBOARD", route:"quick"}, {text:"APPS", route:"apps"}, {text:"WALLPAPERS", route:"wallpapers"}, {text:"NOTIFICATIONS", route:"notifications"}, {text:"SETTINGS", route:"settings"}]
                    DeckButton {
                        required property var modelData
                        text: modelData.text; Layout.fillWidth: true
                        selected: deck.notificationPage ? modelData.route === "notifications" : modelData.route === "quick"
                        onClicked: {
                            if (modelData.route === "quick" || modelData.route === "notifications") deck.notificationPage = modelData.route === "notifications"
                            else deck.routeRequested(modelData.route)
                        }
                    }
                }
            }
            Divider {}
            RowLayout {
                visible: !deck.notificationPage
                Layout.fillHeight: true; Layout.fillWidth: true; spacing: 24
                ColumnLayout {
                    Layout.preferredWidth: 255; Layout.fillHeight: true; spacing: 14
                    Label { text: deck.clockText; font.pixelSize: 46; color: "#e0d5e4" }
                    Label { text: deck.dateText.toUpperCase(); color: "#cd96b9" }
                    Divider {}
                    Label { text: "SYSTEM / LIVE"; color: "#91b3d2" }
                    Label { text: "CPU  " + (deck.resources ? Math.round(deck.resources.cpuPercent) + "%" : "—") }
                    Rectangle {
                        Layout.fillWidth: true; height: 4; color: "#303541"
                        Rectangle { width: parent.width * (deck.resources ? Math.max(0, Math.min(100, deck.resources.cpuPercent)) / 100 : 0); height: 4; color: "#91b3d2" }
                    }
                    Label { text: "RAM  " + (deck.resources ? deck.resources.memUsedLabel + " / " + deck.resources.memTotalLabel + " GiB" : "—") }
                    Rectangle {
                        Layout.fillWidth: true; height: 4; color: "#303541"
                        Rectangle { width: parent.width * (deck.resources ? Math.max(0, Math.min(100, deck.resources.memPercent)) / 100 : 0); height: 4; color: "#cd96b9" }
                    }
                    Item { Layout.fillHeight: true }
                }
                Rectangle { Layout.fillHeight: true; width: 1; color: "#303541" }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 13
                    Label { text: "QUICK CONTROLS"; color: "#cd96b9" }
                    GridLayout {
                        columns: 2; Layout.fillWidth: true; columnSpacing: 8; rowSpacing: 8
                        DeckButton { text: "Wi-Fi"; selected: deck.source.networkOn; Layout.fillWidth: true; onClicked: deck.source.toggleNetwork() }
                        DeckButton { text: "Bluetooth"; selected: deck.source.bluetoothOn; Layout.fillWidth: true; onClicked: deck.source.toggleBluetooth() }
                        DeckButton { text: "Quiet"; selected: !deck.source.notificationsOn; Layout.fillWidth: true; onClicked: deck.source.toggleNotifications() }
                        DeckButton { text: "Night light"; selected: deck.source.nightLightOn; Layout.fillWidth: true; onClicked: deck.source.toggleNightLight() }
                    }
                    DeckSlider { label: "VOLUME"; value: deck.source.speakerVolume; Layout.fillWidth: true; onMoved: value => deck.source.setSpeakerVolume(value) }
                    DeckSlider { label: "BRIGHTNESS"; value: deck.source.brightness; accent: "#91b3d2"; Layout.fillWidth: true; onMoved: value => deck.source.setBrightness(value) }
                    Item { Layout.fillHeight: true }
                }
                Rectangle { Layout.fillHeight: true; width: 1; color: "#303541" }
                ColumnLayout {
                    Layout.preferredWidth: 270; Layout.fillHeight: true; spacing: 12
                    Label { text: "NOW PLAYING"; color: "#cd96b9" }
                    RowLayout {
                        Image { source: deck.media ? deck.media.artUrl : ""; Layout.preferredWidth: 66; Layout.preferredHeight: 66; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: deck.media && deck.media.present ? deck.media.title : "No media playing"; Layout.fillWidth: true }
                            Label { text: deck.media ? deck.media.artist : ""; color: "#8994a6"; Layout.fillWidth: true }
                        }
                    }
                    RowLayout {
                        DeckButton { text: "PREV"; enabled: !!deck.media && deck.media.present; Layout.fillWidth: true; onClicked: deck.media.previous() }
                        DeckButton { text: deck.media && deck.media.playing ? "PAUSE" : "PLAY"; enabled: !!deck.media && deck.media.present; Layout.fillWidth: true; onClicked: deck.media.togglePlaying() }
                        DeckButton { text: "NEXT"; enabled: !!deck.media && deck.media.present; Layout.fillWidth: true; onClicked: deck.media.next() }
                    }
                    Divider {}
                    Label { text: "NOTIFICATIONS / " + deck.notifications.length; color: "#cd96b9" }
                    Label { text: deck.notifications.length ? String(deck.notifications[0].summary || "Notification") : "All caught up"; Layout.fillWidth: true; maximumLineCount: 2; wrapMode: Text.WordWrap }
                    DeckButton { text: "VIEW ALL"; onClicked: deck.notificationPage = true }
                    Item { Layout.fillHeight: true }
                }
            }
            ListView {
                visible: deck.notificationPage
                Layout.fillHeight: true; Layout.fillWidth: true; clip: true; spacing: 8
                model: deck.notifications
                delegate: Card {
                    required property var modelData
                    width: ListView.view.width; height: 82
                    Column {
                        x: 14; y: 12; width: parent.width - 120; spacing: 7
                        Label { width: parent.width; text: String(modelData.summary || "Notification"); color: "#dca6c7" }
                        Label { width: parent.width; text: String(modelData.body || "").replace(/<[^>]*>/g, " ") }
                    }
                    DeckButton { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "DISMISS"; implicitWidth: 85; onClicked: deck.dismissRequested(String(modelData.key)) }
                }
                Label { anchors.centerIn: parent; visible: deck.notifications.length === 0; text: "All caught up" }
            }
        }
    }
    Label { x: 44; y: 478; text: "CONNECTED / UMBRIEL"; color: "#8195ac"; font.pixelSize: 10 }
    Rectangle { x: 1028; y: 481; width: 6; height: 6; radius: 3; color: "#91b3d2" }
    Rectangle {
        x: 32; y: 501; width: 858; height: 32; color: "#0c1018"; radius: 4; border.color: "#303541"
        TextInput {
            id: search
            anchors.fill: parent; anchors.margins: 8; color: "#e0c3d7"; font.family: "monospace"; font.pixelSize: 13
            clip: true; selectByMouse: true
            onAccepted: { if (text.trim()) deck.searchRequested(text.trim()) }
            Text { visible: !search.text && !search.activeFocus; text: "Type to find an app, then press Enter…"; color: "#738094"; font: search.font }
        }
    }
    Column {
        x: 32; y: 544; spacing: 5
        Repeater {
            model: ["Q W E R T Y U I O P", "A S D F G H J K L", "Z X C V B N M"]
            Row {
                required property string modelData
                spacing: 5
                Repeater {
                    model: modelData.split(" ")
                    DeckButton { required property string modelData; text: modelData; width: 70; height: 30; onClicked: { search.insert(search.cursorPosition, modelData.toLowerCase()); search.forceActiveFocus() } }
                }
                DeckButton {
                    text: parent.modelData.startsWith("Q") ? "⌫" : parent.modelData.startsWith("A") ? "SPACE" : "ENTER"
                    width: 70; height: 30
                    onClicked: {
                        if (text === "⌫") { if (search.cursorPosition > 0) search.remove(search.cursorPosition - 1, search.cursorPosition) }
                        else if (text === "SPACE") search.insert(search.cursorPosition, " ")
                        else if (search.text.trim()) deck.searchRequested(search.text.trim())
                        search.forceActiveFocus()
                    }
                }
            }
        }
    }
    Column {
        x: 922; y: 501; spacing: 7
        Repeater {
            model: [{text:"APPS",route:"apps"}, {text:"SETTINGS",route:"settings"}, {text:"LOCK",route:"lock"}, {text:"POWER",route:"power"}]
            DeckButton { required property var modelData; text: modelData.text; width: 143; height: 33; onClicked: deck.routeRequested(modelData.route) }
        }
    }
}
