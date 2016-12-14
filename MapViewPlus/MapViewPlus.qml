import QtQuick 2.6
import QtQuick.Controls 1.4
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2
import QtLocation 5.3
import QtPositioning 5.3
import QtGraphicalEffects 1.0
//------------------------------------------------------------------------------
import ArcGIS.AppFramework 1.0
import ArcGIS.AppFramework.Controls 1.0
//------------------------------------------------------------------------------
import "../Portal"
//------------------------------------------------------------------------------

Item {

    // PROPERTIES //////////////////////////////////////////////////////////////

    id: mapViewPlus

    property Portal mapViewPlusPortal

    // Configurable Properties -------------------------------------------------

    property string drawnExtentOutlineColor: "#de2900"
    property string drawingExtentFillColor: "#10de2900"
    property int mapSpatialReference: 4326
    property double mapDefaultLat: 0
    property double mapDefaultLong: 0
    property var mapDefaultCenter: {"lat": mapDefaultLat, "long": mapDefaultLong }
    property int mapDefaultZoomLevel: 5
    property var mapTileService: null

    // Internal Properties -----------------------------------------------------

    property bool drawing: false
    property var drawingStartCoord: {'x': null, 'y': null}
    property var drawingEndCoord: {'x': null, 'y': null}
    property var pathCoordinates: []
    property var topLeft: null
    property var bottomRight: null
    property bool userDrawnExtent: false
    property bool cursorIsOffMap: true
    property bool allowMapToPan: false
    property bool mapTileServiceUsesToken: true

    property string geometryType: ""
    property bool drawEnvelope: geometryType === "envelope" ? true : false
    property bool drawMultipath: geometryType === "multipath" ? true : false

    readonly property alias map: previewMap.map
    readonly property alias clearExtentButton: clearExtentBtn

    signal drawingStarted()
    signal drawingFinished()
    signal drawingCleared()
    signal zoomLevelChanged(var level)
    signal positionChanged(var position)

    // SIGNAL IMPLEMENTATION ///////////////////////////////////////////////////

    onDrawingStarted: {
        drawing = true;
        resetProperties();
        clearDrawingCanvas();

        if(clearExtentMapItem.visible){
            clearExtentBtn.clicked();
        }
        else if(previewMap.map.mapItems.length > 0){
            clearMap();
        }
        else{
        }
    }

    //--------------------------------------------------------------------------

    onDrawingCleared: {
        if(!drawing){
            resetProperties();
        }
    }

    //--------------------------------------------------------------------------

    onDrawingFinished: {
        drawing = false;
        clearDrawingCanvas();
        drawingMenu.drawingRequestComplete();
    }

    // UI //////////////////////////////////////////////////////////////////////

    MapDrawingMenu{
        id: drawingMenu
        anchors.top: parent.top
        anchors.topMargin: 10 * AppFramework.displayScaleFactor
        anchors.horizontalCenter: parent.horizontalCenter
        z: previewMap.z + 3
        enabled: (drawing) ? false : true
        drawingExists: userDrawnExtent

        onDrawingRequest: {
            drawingStarted();
            geometryType = g;
        }
    }

    DropShadow {
           anchors.fill: drawingMenu
           horizontalOffset: 0
           verticalOffset: 0
           radius: 4
           samples: 8
           color: "#80000000"
           source: drawingMenu
           z: previewMap.z + 3
           visible: !drawing
    }

    Rectangle{
        id: mapZoomTools
        width: 30 * AppFramework.displayScaleFactor
        height: (width * 2) + 1
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 10 * AppFramework.displayScaleFactor
        anchors.rightMargin: 10 * AppFramework.displayScaleFactor
        z: previewMap.z + 3
        radius: 5 * AppFramework.displayScaleFactor
        color: "transparent"

        ColumnLayout{
            anchors.fill: parent
            spacing: 1

            Button{
                id: mapZoomIn
                Layout.fillHeight: true
                Layout.fillWidth: true
                tooltip: qsTr("Zoom In")
                style: ButtonStyle {
                    background: Rectangle {
                        anchors.fill: parent
                        color: (control.enabled) ? ( (control.pressed) ? "#bddbee" : "#fff" ) : "#eee"
                        border.width: (control.enabled) ? app.info.properties.mainButtonBorderWidth : 0
                        border.color: (control.enabled) ? app.info.properties.mainButtonBorderColor : "#ddd"
                        radius: 3 * AppFramework.displayScaleFactor
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        font.pointSize: config.smallFontSizePoint
                        color: app.info.properties.mainButtonBorderColor
                        font.family: icons.name
                        text: icons.plus_sign
                    }
                }

                onClicked: {
                    if(map.zoomLevel < map.maximumZoomLevel){
                        map.zoomLevel = Math.floor(map.zoomLevel) + 1;
                    }
                }
            }
            Button{
                id: mapZoomOut
                Layout.fillHeight: true
                Layout.fillWidth: true
                tooltip: qsTr("Zoom Out")

                style: ButtonStyle {
                    background: Rectangle {
                        anchors.fill: parent
                        color: (control.enabled) ? ( (control.pressed) ? "#bddbee" : "#fff" ) : "#eee"
                        border.width: (control.enabled) ? app.info.properties.mainButtonBorderWidth : 0
                        border.color: (control.enabled) ? app.info.properties.mainButtonBorderColor : "#ddd"
                        radius: 3 * AppFramework.displayScaleFactor
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"

                    Text{
                        anchors.centerIn: parent
                        font.pointSize: config.smallFontSizePoint
                        color: app.info.properties.mainButtonBorderColor
                        font.family: icons.name
                        text: icons.minus_sign
                    }
                }
                onClicked: {
                    if(map.zoomLevel > 0){
                        map.zoomLevel = Math.ceil(map.zoomLevel) - 1;
                    }
                }
            }
        }
    }

    DropShadow {
           anchors.fill: mapZoomTools
           horizontalOffset: 0
           verticalOffset: 0
           radius: 4
           samples: 8
           color: "#80000000"
           source: mapZoomTools
           z: previewMap.z + 3
    }

    //--------------------------------------------------------------------------

    MouseArea {
        id: multipathDrawingMouseArea
        enabled: (drawing && drawMultipath) ? true : false
        focus: (drawing && drawMultipath) ? true : false
        visible: (drawing && drawMultipath) ? true : false
        clip: true
        anchors.fill: parent
        z: previewMap.z + 3
        cursorShape: (drawing && !allowMapToPan) ? Qt.CrossCursor : Qt.ArrowCursor
        hoverEnabled: true
        property var lastKnownPosition: null
        property bool endDrawingByDoubleClick: false
        property bool mapWasPanned: false;
        signal mapPanningFinished()
        signal mapPanningStarted()

        onEntered: {
            cursorIsOffMap = false;
        }
        onExited: {
            cursorIsOffMap = true;
        }

        onPressed: {
            /*
            if(mouse.button === Qt.RightButton){
                if(pathCoordinates.length > 1){
                    addMultipathToMap("final");
                }
            }
            */

            if(mouse.modifiers === Qt.ShiftModifier){
                mouse.accepted = false;
                allowMapToPan = true;
                multipathDrawingMouseArea.cursorShape = Qt.OpenHandCursor;
                clearDrawingCanvas();
            }

        }

        onMapPanningStarted: {
            mapWasPanned = true;
            multipathDrawingMouseArea.cursorShape = Qt.ClosedHandCursor;
        }

        onMapPanningFinished: {
            allowMapToPan = false;
            mapWasPanned = true;
            multipathDrawingMouseArea.cursorShape = Qt.CrossCursor;
        }

        onPressAndHold: {
        }

        onReleased: {
            mouse.accepted = true;

            if(!endDrawingByDoubleClick){
                var asCoord = screenPositionToLatLong(mouse);
                pathCoordinates.push({"screen": {"x": mouse.x, "y": mouse.y}, "asCoords": {"longitude": asCoord.longitude, "latitude": asCoord.latitude }});
                if(pathCoordinates.length > 1){
                    addMultipathToMap("draft");
                }
            }
            else{
                pathCoordinates.pop();
                if(mapViewPlus.pathCoordinates.length <= 1){
                    clearDrawingCanvas();
                    previewMap.map.clearMapItems();
                    drawingFinished();
                }else{
                    addMultipathToMap("final");
                }
                endDrawingByDoubleClick = false;
            }
        }

        onPositionChanged: { 
            var lastKnownPosition; //= {"x": mouse.x, "y": mouse.y, "lat": z, "long": z};

            if(!mapWasPanned){
                if(pathCoordinates.length > 0){
                    drawHelperLine(mouse.x, mouse.y);
                }
                if(mouse !== null){
                    var asCoord = screenPositionToLatLong(mouse);
                    mapViewPlus.positionChanged({"screen": {"x": mouse.x, "y": mouse.y}, "asCoords": {"longitude": asCoord.longitude, "latitude": asCoord.latitude }});
                    lastKnownPosition = {"screen": {"x": mouse.x, "y": mouse.y}, "asCoords": {"longitude": asCoord.longitude, "latitude": asCoord.latitude }};
                }
            }
            else{
                mapWasPanned = false;
            }
        }

        onDoubleClicked: {
            mouse.accepted = false;
            endDrawingByDoubleClick = true;
        }

        Keys.onPressed: {
            if(event.key === Qt.Key_Return || event.key === Qt.Key_Enter){
                addMultipathToMap("final");
            }
            if(event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace){
                mapViewPlus.pathCoordinates.pop();
                if(mapViewPlus.pathCoordinates.length === 0){
                    clearDrawingCanvas();
                    previewMap.map.clearMapItems();
                }
                else{
                    addMultipathToMap("draft");
                    if(lastKnownPosition !== null){
                        drawHelperLine(lastKnownPosition.screen.x, lastKnownPosition.screen.y);
                    }
                }
            }
            if(event.key === Qt.Key_Shift){
                multipathDrawingMouseArea.cursorShape = Qt.OpenHandCursor;
            }
        }

        Keys.onReleased: {
            if(event.key === Qt.Key_Shift){
                multipathDrawingMouseArea.cursorShape = Qt.CrossCursor;
            }
        }

        function drawHelperLine(inX, inY){
            var lastCollectedPath = pathCoordinates[pathCoordinates.length-1];
            var lcpAsPoint = latLongToScreenPosition(lastCollectedPath.asCoords);
            clearDrawingCanvas();
            mapDrawCanvas.getContext('2d').beginPath();
            mapDrawCanvas.getContext('2d').lineWidth = "1";
            mapDrawCanvas.getContext('2d').strokeStyle = drawnExtentOutlineColor;
            //mapDrawCanvas.getContext('2d').moveTo(lastCollectedPath['screen']['x'], lastCollectedPath['screen']['y'])
            mapDrawCanvas.getContext('2d').moveTo(lcpAsPoint.x, lcpAsPoint.y);
            mapDrawCanvas.getContext('2d').lineTo(inX,inY);
            mapDrawCanvas.getContext('2d').stroke();
        }

    }

    //--------------------------------------------------------------------------

    MouseArea {
        id: envelopeDrawingMouseArea
        enabled: (drawing && drawEnvelope) ? true : false
        visible: (drawing && drawEnvelope) ? true : false
        focus: (drawing && drawEnvelope) ? true : false
        clip: true
        anchors.fill: parent
        z: previewMap.z + 2
        cursorShape: (drawing) ? Qt.CrossCursor : Qt.ArrowCursor
        propagateComposedEvents: true

        onPressed: {
            mouse.accepted = true;
            drawingStartCoord.x = mouse.x;
            drawingStartCoord.y = mouse.y;
        }

        onReleased: {
            mouse.accepted = true;
            drawingEndCoord.x = mouse.x;
            drawingEndCoord.y = mouse.y;
            addEnvelopeToMap();
        }

        onPositionChanged: {
            // This most likely needs to be throttled to every 47 milliseconds (24 frames per second)
            mouse.accepted = true;
            var xDif = mouse.x - drawingStartCoord.x;
            var yDif = mouse.y - drawingStartCoord.y;
            mapDrawCanvas.requestPaint();
            mapDrawCanvas.getContext("2d").clearRect(0, 0, mapDrawCanvas.width,mapDrawCanvas.height);
            mapDrawCanvas.getContext("2d").beginPath();
            mapDrawCanvas.getContext("2d").lineWidth = "2";
            mapDrawCanvas.getContext("2d").strokeStyle = drawnExtentOutlineColor;
            mapDrawCanvas.getContext("2d").rect(drawingStartCoord.x,drawingStartCoord.y,xDif, yDif);
            mapDrawCanvas.getContext("2d").stroke();
            if(mouse !== null){
                var asCoord = screenPositionToLatLong(mouse);
                mapViewPlus.positionChanged({"screen": {"x": mouse.x, "y": mouse.y}, "asCoords": {"longitude": asCoord.longitude, "latitude": asCoord.latitude }})
            }
        }

        onDoubleClicked: {
            mouse.accepted = false;
        }
    }

    //--------------------------------------------------------------------------

    Canvas {
        id: mapDrawCanvas
        anchors.fill: parent
        clip: true
        width: parent.width
        height: parent.height
        visible: (drawing) ? true : false
        z: previewMap.z + 1
    }

    //--------------------------------------------------------------------------

    MouseArea {
        id: mapEventCollectorOther
        clip: true
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        preventStealing: true
        z: previewMap.z + 1
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: {
            if(mouse.button === Qt.LeftButton){
                mouse.accepted = false;
            }
        }

        onEntered: {
            cursorIsOffMap = false;
        }

        onPositionChanged: {
            if(mouse !== null){
                var asCoord = screenPositionToLatLong(mouse);
                mapViewPlus.positionChanged({"screen": {"x": mouse.x, "y": mouse.y}, "asCoords": {"longitude": asCoord.longitude, "latitude": asCoord.latitude }})
            }
        }

        onExited: {
            cursorIsOffMap = true;
            mapViewPlus.positionChanged({"x":-1, "y":-1});
        }

        onDoubleClicked: {
            mouse.accepted = true;
            if(mouse !== null && mouse.button === Qt.RightButton){
                var asCoord = screenPositionToLatLong(mouse);
                mapViewPlus.map.center = QtPositioning.coordinate(asCoord.latitude, asCoord.longitude);
                if(mouse.modifiers === Qt.ControlModifier){
                    mapZoomOut.clicked();
                }else{
                    mapZoomIn.clicked();
                }
            }
        }
    }

    //--------------------------------------------------------------------------

    MapView {
        id: previewMap
        portal: mapViewPlusPortal
        anchors.fill: parent
        defaultCenter: mapDefaultCenter
        defaultZoomLevel: mapDefaultZoomLevel
        mapService: mapTileService
        useToken: mapTileServiceUsesToken
        z: 50000

        onZoomLevelChanged: {
            mapViewPlus.zoomLevelChanged(level);
        }

        onMapItemsCleared: {
            mapViewPlus.drawingCleared();
        }

        onMapPanningFinished: {
            if(multipathDrawingMouseArea.enabled){
                multipathDrawingMouseArea.mapPanningFinished();
            }
        }

        onMapPanningStarted: {
            if(multipathDrawingMouseArea.enabled){
                multipathDrawingMouseArea.mapPanningStarted();
            }
        }

    }




    // COMPONENTS //////////////////////////////////////////////////////////////

    MapRectangle {
        id: drawnExtent
        color: drawingExtentFillColor
        border.width: 2 * AppFramework.displayScaleFactor
        border.color: drawnExtentOutlineColor
    }

    MapPolyline{
        id: drawnPolyline
        line.width: 3 * AppFramework.displayScaleFactor
        line.color: drawnExtentOutlineColor
    }

    //--------------------------------------------------------------------------

    MapQuickItem {
        id: clearExtentMapItem
        visible: false
        enabled: false

        sourceItem: Rectangle {
            width: 30 * AppFramework.displayScaleFactor
            height: 30 * AppFramework.displayScaleFactor
            color: "transparent"
            Button {
                id: clearExtentBtn
                anchors.fill: parent
                tooltip: qsTr("Clear Extent")

                style: ButtonStyle {
                    background: Rectangle {
                        anchors.fill: parent
                        color: "#fff"
                        radius: 0

                        Image {
                            source: "images/clear_extent.png"
                            fillMode: Image.PreserveAspectFit
                            width: parent.width - (4 * AppFramework.displayScaleFactor)
                            anchors.centerIn: parent
                        }
                    }
                }
                onClicked: {
                    clearExtentMapItem.visible = false;
                    clearExtentMapItem.enabled = false;
                    mapViewPlus.clearMap();
                }
            }
        }
    }

    // METHODS /////////////////////////////////////////////////////////////////

    function getCurrentGeometry(){
        console.log(geometryType);
        var g;
        if(drawMultipath){
            console.log("drawMultipath ", drawMultipath);
            g = getMutlipathGeometry();
        }
        else if(drawEnvelope){
            console.log("drawEnvelope ", drawEnvelope)
            g = getEnvelopeGeometry();
        }
        else{
            console.log('no geometry');
            g = null;
        }

        return g;

    }

    //--------------------------------------------------------------------------

    function getEnvelopeGeometry() {

        var rect;

        if (userDrawnExtent === true) {
            rect = drawnExtent
        } else {
            rect = QtPositioning.shapeToRectangle(previewMap.map.visibleRegion)
        }

        var xmin = rect.topLeft.longitude
        var ymax = rect.topLeft.latitude
        var xmax = rect.bottomRight.longitude
        var ymin = rect.bottomRight.latitude

        var envelope = {
            xmin: xmin,
            ymin: ymin,
            xmax: xmax,
            ymax: ymax,
            spatialReference: {
                wkid: mapSpatialReference // 4326
            }
        }

        var envelopeGeometry = {
            "geometryType": "esriGeometryEnvelope",
            "geometries" : envelope
        }

        //return extent;
        console.log(JSON.stringify(envelopeGeometry));
        return envelopeGeometry;
    }

    //--------------------------------------------------------------------------

    function getMutlipathGeometry(){

        // This looks convoluted because esri polyline json is composed of multiple nested arrays

        var esriPolyLineObject = {
                "geometryType": "esriGeometryPolyline",
                "geometries" : [{
                    "paths":[[]],
                    "spatialReference": {
                        "wkid": mapSpatialReference
                    }
                }],

            };

           for(var i = 0; i < pathCoordinates.length; i++){
            //esriPolyLineObject.geometries[0]["paths"][0].push([pathCoordinates[i]['asCoords']['longitude'],pathCoordinates[i]['asCoords']['latitude']]);
            esriPolyLineObject.geometries[0].paths[0].push([pathCoordinates[i].asCoords.longitude, pathCoordinates[i].asCoords.latitude]);

        }

        return esriPolyLineObject;
    }

    //--------------------------------------------------------------------------

    function screenPositionToLatLong(screenPoint) {
        return previewMap.map.toCoordinate(Qt.point(parseInt(screenPoint.x,10), parseInt(screenPoint.y, 10)));
    }
    //--------------------------------------------------------------------------

    function latLongToScreenPosition(coord) {
        return previewMap.map.fromCoordinate(QtPositioning.coordinate(coord.latitude, coord.longitude), false);
    }

    //--------------------------------------------------------------------------

    function clearMap() {
        previewMap.map.clearMapItems();
    }

    //--------------------------------------------------------------------------

    function addEnvelopeToMap() {

        _fixDrawnCoordinates();

        userDrawnExtent = true;

        // Convert coords
        topLeft = screenPositionToLatLong(drawingStartCoord);
        bottomRight = screenPositionToLatLong(drawingEndCoord);

        // Clean up canvas
        clearDrawingCanvas();

        // Draw extent
        drawnExtent.topLeft = topLeft;
        drawnExtent.bottomRight = bottomRight;
        previewMap.map.addMapItem(drawnExtent);

        // Add Clear Button
        previewMap.map.addMapItem(clearExtentMapItem)
        clearExtentMapItem.anchorPoint = Qt.point(-3,-3);
        clearExtentMapItem.coordinate = QtPositioning.coordinate(topLeft.latitude, topLeft.longitude); // screenPositionToLatLong({"x": drawingStartCoord.x + drawnExtent.border.width, "y": drawingStartCoord.y + drawnExtent.border.width});
        clearExtentMapItem.visible = true;
        clearExtentMapItem.enabled = true;

        drawingFinished();
    }

    //--------------------------------------------------------------------------

    function addMultipathToMap(typeOfPath){

        clearMap();

        var path = [];
        for(var i = 0; i < pathCoordinates.length; i++){
            path.push(pathCoordinates[i]['asCoords']);
        }

        drawnPolyline.path = path;

        previewMap.map.addMapItem(drawnPolyline);

        if(typeOfPath === "final"){
            userDrawnExtent = true;
            clearDrawingCanvas();

            previewMap.map.addMapItem(clearExtentMapItem)
            clearExtentMapItem.anchorPoint = Qt.point(15,15);
            clearExtentMapItem.coordinate = QtPositioning.coordinate(path[0].latitude, path[0].longitude); //screenPositionToLatLong({"x": pathCoordinates[0].screen.x - 15, "y": pathCoordinates[0].screen.y - 15});
            clearExtentMapItem.visible = true;
            clearExtentMapItem.enabled = true;

            drawingFinished();
        }
    }

    //--------------------------------------------------------------------------

    function _fixDrawnCoordinates() {

        var mapMinX = mapDrawCanvas.x
        var mapMinY = mapDrawCanvas.y
        var mapMaxX = mapDrawCanvas.x + mapDrawCanvas.width
        var mapMaxY = mapDrawCanvas.y + mapDrawCanvas.height

        var newStartX, newStartY, newEndX, newEndY

        var xDif = drawingEndCoord.x - drawingStartCoord.x
        var yDif = drawingEndCoord.y - drawingStartCoord.y
        var xPoz = (xDif > 0) ? true : false
        var yPoz = (yDif > 0) ? true : false

        if (xPoz === true && yPoz === true) {
            console.log('drawing from top left to bottom right, coords are good')
        }
        if (xPoz === true && yPoz === false) {
            // Drawing from bottom left to top right > swap y values
            newStartY = drawingEndCoord.y
            newEndY = drawingStartCoord.y
            drawingStartCoord.y = newStartY
            drawingEndCoord.y = newEndY
        }
        if (xPoz === false && yPoz === true) {
            // Drawing top right to bottom left > swap x values
            newStartX = drawingEndCoord.x
            newEndX = drawingStartCoord.x
            drawingStartCoord.x = newStartX
            drawingEndCoord.x = newEndX
        }
        if (xPoz === false && yPoz === false) {
            // drawing bottom right to top left > swap start and end values for each other
            newStartX = drawingEndCoord.x
            newStartY = drawingEndCoord.y
            newEndX = drawingStartCoord.x
            newEndY = drawingStartCoord.y
            drawingStartCoord.x = newStartX
            drawingStartCoord.y = newStartY
            drawingEndCoord.x = newEndX
            drawingEndCoord.y = newEndY
        }

        // Fix coords if they go beyond map boundaries > snap back to min and max.
        if (drawingStartCoord.x < mapMinX) {
            drawingStartCoord.x = mapMinX
        }
        if (drawingStartCoord.y < mapMinY) {
            drawingStartCoord.y = mapMinY
        }
        if (drawingEndCoord.x > mapMaxX) {
            drawingEndCoord.x = mapMaxX
        }
        if (drawingEndCoord.y > mapMaxY) {
            drawingEndCoord.y = mapMaxY
        }
    }

    //--------------------------------------------------------------------------

    function resetProperties() {
        pathCoordinates = [];
        drawingStartCoord.x = null;
        drawingStartCoord.y = null;
        drawingEndCoord.x = null;
        drawingEndCoord.y = null;
        topLeft = null;
        bottomRight = null;
        userDrawnExtent = false;
        geometryType = "";
    }

    //--------------------------------------------------------------------------

    function clearDrawingCanvas(){
        mapDrawCanvas.requestPaint();
        mapDrawCanvas.getContext("2d").clearRect(0,0,mapDrawCanvas.width, mapDrawCanvas.height);
    }

    // UNIMPLEMENTED ///////////////////////////////////////////////////////////

    Timer {
        id: animationTimer
        interval: 47
        running: false
        repeat: true
        onTriggered: {

        }
    }

    // END /////////////////////////////////////////////////////////////////////
}