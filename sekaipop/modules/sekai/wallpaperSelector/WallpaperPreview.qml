import QtQuick

// Image shared by gallery, viewer and wheel. Engine folders are never decoded
// as pictures; missing preview formats are tried in the service's preferred order.
Image {
    id: root
    property var previewEntry: null
    property url fallbackSource: ""
    property bool loadEnabled: true
    property int previewIndex: 0
    property int previewGeneration: 0
    readonly property bool enginePreview: !!previewEntry && previewEntry.engine === true
    readonly property var previewPaths: enginePreview
        ? (previewEntry.previewCandidates || (previewEntry.previewPath ? [previewEntry.previewPath] : [])) : []
    readonly property string previewPath: enginePreview && previewIndex < previewPaths.length
        ? previewPaths[previewIndex] : ""

    function resetPreview() {
        root.previewGeneration++
        root.previewIndex = 0
    }
    onPreviewPathsChanged: root.resetPreview()
    onLoadEnabledChanged: root.resetPreview()

    source: !loadEnabled ? "" : (enginePreview
        ? (previewPath === "" ? "" : "file://" + previewPath.split("/").map(encodeURIComponent).join("/"))
        : fallbackSource)

    onStatusChanged: {
        if (!root.loadEnabled || !root.enginePreview || status !== Image.Error)
            return
        const generation = root.previewGeneration
        const failedIndex = root.previewIndex
        // An old asynchronous failure must not advance a reused delegate's new item.
        Qt.callLater(() => {
            if (root.previewGeneration === generation && root.previewIndex === failedIndex
                    && root.status === Image.Error && root.previewIndex < root.previewPaths.length)
                root.previewIndex++
        })
    }
}
