// Based on Esri Shapefile Technical Description
// An Esri White Paper -- July 1998
// https://www.esri.com/library/whitepapers/pdfs/shapefile.pdf


WorkerScript.onMessage = function(shapeFile) {

    // shapeFile should be a jsobject with a path attribute and associated file url
    // ex: { "path": "file:///C:/Users/username/Desktop/myshapefiles/rivers.shp", "coordinate_system": "3587" }

    geoJson["crs"]["properties"]["name"] = shapeFile.coordinate_system;

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) {
            if (xhr.status === 0 || xhr.status === 200){
                shapefileByteArrayToGeoJson(xhr.response);
            }
            else {
                WorkerScript.sendMessage({"error": "There was an error reading the shapefile"});
            }
        }
    };
    xhr.responseType = "arraybuffer";
    xhr.open("GET", shapeFile.path, true);
    xhr.send();

}

var partsArray = [];
var pointsArray = [];

var shapeTypes = [];
shapeTypes[0] = {"esri": "Null Shape", "geojson": null};
shapeTypes[1] = {"esri": "Point", "geojson": "Point"};
shapeTypes[3] = {"esri": "PolyLine", "geojson": "LineString"};
shapeTypes[5] = {"esri": "Polygon", "geojson": "Polygon"};
shapeTypes[8] = {"esri": "MultiPoint", "geojson": "MultiPoint"};
shapeTypes[11] = {"esri": "PointZ", "geojson": null};
shapeTypes[13] = {"esri": "PolyLineZ", "geojson": null};
shapeTypes[15] = {"esri": "PolygonZ", "geojson": null};
shapeTypes[18] = {"esri": "MultiPointZ", "geojson": null};
shapeTypes[21] = {"esri": "PointM", "geojson": null};
shapeTypes[23] = {"esri": "PolyLineM", "geojson": null};
shapeTypes[25] = {"esri": "PolygonM", "geojson": null};
shapeTypes[28] = {"esri": "MultiPointM", "geojson": null};
shapeTypes[31] = {"esri": "MultiPatch", "geojson": null};

var shpHeader = {
    "file_code": {
        "position": 0,
        "type": "int32",
        "bigEndian": true
    },
    "file_length": {
        "position": 24,
        "type": "int32",
        "bigEndian": true
    },
    "version": {
        "position": 28,
        "type": "int32",
        "bigEndian": true
    },
    "shape_type": {
        "position": 32,
        "type": "int32",
        "bigEndian": true
    },
    "xmin": {
        "position": 36,
        "type": "float64",
        "bigEndian": true
    },
    "ymin": {
        "position": 44,
        "type": "float64",
        "bigEndian": true
    },
    "xmax": {
        "position": 52,
        "type": "float64",
        "bigEndian": true
    },
    "ymax": {
        "position": 60,
        "type": "float64",
        "bigEndian": true
    },
    "zmin": {
        "position": 68,
        "type": "float64",
        "bigEndian": true
    },
    "zmax": {
        "position": 76,
        "type": "float64",
        "bigEndian": true
    },
    "mmin": {
        "position": 84,
        "type": "float64",
        "bigEndian": true
    },
    "mmax": {
        "position": 92,
        "type": "float64",
        "bigEndian": true
    }
}

var geoJson = {
    "type": "FeatureCollection",
    "crs": {
        "type" : "name",
        "properties" : {
          "name" : ""
        }
      },
    "features": []
};


function getShapeType(val){
    return shapeTypes[val];
}

function resetFeatures(){
    geoJson.features = [];
    partsArray = [];
    pointsArray = [];
}

function shapefileByteArrayToGeoJson(byteArray) {

    resetFeatures();

    var geoJsonFeature = {};

    var shpDataArray = new DataView(byteArray);

    // A byteLength less than 101 means there is no geometry.-------------------
    if (shpDataArray.byteLength < 101){
        try {
            throw new Error("This shapefile contains no geometry");
        }
        catch(e) {
            WorkerScript.sendMessage({"error": e});
        }
        finally {
            return;
        }
    }

    var shapeValue = shpDataArray.getInt32(shpHeader.shape_type.position, shpHeader.shape_type.bigEndian);

    // only supporting MultilineString, Polygon --------------------------------
    if (shapeValue !== 3 && shapeValue !== 5) {

        try {
            throw new Error("This tool currently only supports polygons and polylines.");
        }
        catch(e) {
            WorkerScript.sendMessage({"error": e});
        }
        finally {
            return;
        }
    }

    var shapeType = shapeTypes[shapeValue];

    if (shapeType !== undefined && shapeType !== null && shapeType !== 0 && shapeType.geojson !== null) {

        geoJsonFeature["type"] = "Feature";
        geoJsonFeature["properties"] = {};
        geoJsonFeature["bbox"] = [];
        geoJsonFeature["shapefile_related"] = {};
        geoJsonFeature["geometry"] = {
            "type": shapeType.geojson,
            "coordinates": []
        }

//        if (shapeValue === 5){
//            geoJsonFeature["geometry"]["coordinates"][0] = [];
//        }

        var boundingBoxXMin = shpDataArray.getFloat64(shpHeader.xmin.position, shpHeader.xmin.bigEndian);
        geoJsonFeature["bbox"][0] = boundingBoxXMin;

        var boundingBoxYMin = shpDataArray.getFloat64(shpHeader.ymin.position, shpHeader.ymin.bigEndian);
        geoJsonFeature["bbox"][1] = boundingBoxYMin;

        var boundingBoxXMax = shpDataArray.getFloat64(shpHeader.xmax.position, shpHeader.xmax.bigEndian);
        geoJsonFeature["bbox"][2] = boundingBoxXMax;

        var boundingBoxYMax = shpDataArray.getFloat64(shpHeader.ymax.position, shpHeader.ymax.bigEndian);
        geoJsonFeature["bbox"][3] = boundingBoxYMax;

        if (geoJson["crs"]["properties"]["name"] === "") {
            geoJson["crs"]["properties"]["name"] = establishSpatialReference(boundingBoxXMin, boundingBoxXMin, boundingBoxXMax, boundingBoxYMax);
        }

        geoJsonFeature["shapefile_related"]["RecordNumber"] = shpDataArray.getInt32(100);
        geoJsonFeature["shapefile_related"]["Content Length"] = shpDataArray.getInt32(104);
        geoJsonFeature["shapefile_related"]["ShapeType"] = shpDataArray.getInt32(108, true);
        geoJsonFeature["shapefile_related"]["box"] = [shpDataArray.getFloat64(112, true), shpDataArray.getFloat64(120, true), shpDataArray.getFloat64(128, true), shpDataArray.getFloat64(136, true)];
        geoJsonFeature["shapefile_related"]["numParts"] = shpDataArray.getInt32(144, true);
        geoJsonFeature["shapefile_related"]["numPoints"] = shpDataArray.getInt32(148, true);
//        geoJsonFeature["shapefile_related"]["Parts"] = shpDataArray.getInt32(152, true);
//        geoJsonFeature["shapefile_related"]["X"] = (152 + 4 * geoJsonFeature["shapefile_related"]["numParts"]);

        console.log(JSON.stringify(geoJsonFeature));

        // over 100 parts? then not gonna process currently -----------------
        if (geoJsonFeature["shapefile_related"]["numParts"] > 100) {
            try {
                throw new Error("This tool only supports shapefiles with less than 100 parts.");
            }
            catch(e) {
                WorkerScript.sendMessage({"error": e});
            }
            finally {
                return;
            }
        }

        if (geoJsonFeature["shapefile_related"]["numParts"] > 0) {

            try {

                var cursor = 152, x = 0;

                for (x = 0; x < geoJsonFeature["shapefile_related"]["numParts"]; x++) {
                    var pointLocation = shpDataArray.getInt32(cursor, true);
                    partsArray.push(pointLocation);
                    cursor += 4;
                }

                console.log("partsArray.length: ", partsArray.length);

                var nP = geoJsonFeature["shapefile_related"]["numPoints"] * 2;

                for (x = 0; x < nP; x++) {
                    var point = shpDataArray.getFloat64(cursor, true);
                    pointsArray.push(point);
                    cursor += 8;
                }

                console.log("pointsArray.length: ", pointsArray.length);

                for (x = 0; x < partsArray.length; x++) {

                    if (shapeValue === 5) {
                       geoJsonFeature["geometry"].coordinates[x] = [];
                    }

                    var pointStart = partsArray[x] * 2; // e.g. [0,320,333]

                    console.log("--------------------- x: ", x)
                    console.log("pointStart: ", pointStart);

                    var lastPoint = (x === partsArray.length - 1) ? pointsArray.length : partsArray[x+1] * 2;
                    console.log("lastPoint: ", lastPoint)

                    var numberOfPoints = lastPoint - pointStart;
                    console.log("numberOfPoints: ", numberOfPoints)

                    var coordinate = [];

                    for (var pointCounter = pointStart; pointCounter < lastPoint; pointCounter++) {
                        // 0 : 0 --> pointsArray[0] to pointsArray[319]
                        // 1 : pointsArray[320] ->
                        console.log("step: %1, pointCounter: %2, coord:%3, cLength:%4".arg(x).arg(pointCounter).arg(pointsArray[pointCounter]).arg(geoJsonFeature["geometry"].coordinates[x].length));

                        coordinate.push(pointsArray[pointCounter]);

                        if (coordinate.length === 2) {

                            if (shapeValue === 5) {
                                geoJsonFeature["geometry"].coordinates[x].push(coordinate);
                            }
                            else if (shapeValue === 3) {
                                geoJsonFeature["geometry"].coordinates.push(coordinate);
                            }
                            else {

                            }
                            coordinate = [];
                        }
                    }
                }
            }
            catch(e) {
                WorkerScript.sendMessage({"error": e});
            }
        }
    }

    geoJson.features.push(geoJsonFeature);

    console.log(JSON.stringify(geoJson));

    WorkerScript.sendMessage({"geojson": geoJson});

    return geoJson;

}

function establishSpatialReference(minx, miny, maxx, maxy){
    console.log("establishSpatialReference")

    // the shape file .prj file was other than 3857 or 4326, so attempt
    // to see if it is lat / lon or web mercator type values.

    // its highly unlikely a web mercator projection will fall within
    // the following parameters,

    if (minx > 180
        || minx < -180
        || maxx > 180
        || maxx < -180
        || miny > 90
        || miny < -90
        || maxy > 90
        || maxy < -90) {

        return "3857";
    }
    else {
        return "4326";
    }
}
