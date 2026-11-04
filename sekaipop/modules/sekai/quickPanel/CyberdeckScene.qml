import QtQuick
import QtQuick3D
import QtQuick3D.AssetUtils

Item {
    id: scene
    required property var source
    property var media: null
    property var resources: null
    property var notifications: []
    property string clockText: "00:00"
    property string dateText: ""
    readonly property Item faceItem: face
    property real pitch: 18
    property real yaw: -16
    readonly property bool modelReady: chassis.status === RuntimeLoader.Success
    readonly property string modelError: chassis.errorString
    signal routeRequested(string route)
    signal searchRequested(string query)
    signal closeRequested()
    signal dismissRequested(string key)
    width: 1240; height: 820

    View3D {
        id: viewport
        anchors.fill: parent
        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }
        PerspectiveCamera {
            id: camera
            z: 1520
            clipNear: 10; clipFar: 5000
            fieldOfView: 34
        }
        camera: camera
        DirectionalLight { eulerRotation: Qt.vector3d(-35, -30, 0); brightness: 1.2; ambientColor: "#646b7e" }
        DirectionalLight { eulerRotation: Qt.vector3d(25, 145, 0); color: "#91b4d4"; brightness: 0.7 }
        Node {
            id: assembly
            eulerRotation: Qt.vector3d(scene.pitch, scene.yaw, -2)
            RuntimeLoader {
                id: chassis
                source: "../../../assets/models/cyberdeck/cyberdeck.obj"
                onStatusChanged: { if (status === RuntimeLoader.Error) console.warn("Cyberdeck model: " + errorString) }
            }
            // Qt delivers pointer events in the embedded item's own coordinates,
            // including dragging and text selection, through the camera transform.
            Node {
                id: surface
                x: -550; y: 335; z: 20
                CyberdeckFace {
                    id: face
                    objectName: "deckFace"
                    modelMode: true
                    layer.enabled: true // required for the search/list clipping in 3D
                    layer.smooth: true
                    layer.mipmap: true
                    layer.textureSize: Qt.size(2200, 1340)
                    source: scene.source
                    media: scene.media
                    resources: scene.resources
                    notifications: scene.notifications
                    clockText: scene.clockText
                    dateText: scene.dateText
                    onRouteRequested: route => scene.routeRequested(route)
                    onSearchRequested: query => scene.searchRequested(query)
                    onCloseRequested: scene.closeRequested()
                    onDismissRequested: key => scene.dismissRequested(key)
                }
            }
        }
    }
    // Also used by the interaction test to project a screen point through the
    // exact same model/camera transform as the renderer.
    function screenPoint(x, y) {
        return viewport.mapFrom3DScene(surface.mapPositionToScene(Qt.vector3d(x, -y, 0)))
    }
}
