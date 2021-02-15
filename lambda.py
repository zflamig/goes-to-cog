import datetime
import os
import re
import json
import boto3
from osgeo import gdal, osr

TARGET_BUCKET = os.environ.get("TARGET_BUCKET", None)

goese_srs = "+proj=geos +lon_0=-75 +h=35786023 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs  +sweep=x"
goesw_srs = "+proj=geos +lon_0=-137 +h=35786023 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs  +sweep=x +over"

def response():
    response = {
        "statusCode": 200,
        "headers": {
            # 'Content-Length': len(encoded),
        },
        "isBase64Encoded": True,
        # "body": encoded
    }
    return response


def lambdaHandler(event, context):

    sns_message = json.loads(event["Records"][0]["Sns"]["Message"])
    s3_event = sns_message["Records"][0]["s3"]

    bucket = s3_event["bucket"]["name"]
    key = s3_event["object"]["key"]
    print("Handling", key)

    # Only process level 2 ABI full disks right now
    if not key.startswith("ABI-L2-CMIPF"):
        return response()

    netcdf = key

    if TARGET_BUCKET is None:
        print("No target bucket configured, not uploading to S3")

    dst_srs = osr.SpatialReference()
    dst_srs.ImportFromEPSG(4326)

    src_srs = osr.SpatialReference()

    n = re.search(
        "^([\w|-]+)\/\d+\/\d+\/\d+\/OR_ABI-L2-CMIP([C|F|M]\d?)-M\dC(\d+)_G1[6|7]_s(\d{4})(\d{3})(\d{2})(\d{2})(\d{2})",
        netcdf,
    )
    date = datetime.datetime(
        int(n.group(4)), 1, 1, int(n.group(6)), int(n.group(7)), int(n.group(8))
    ) + datetime.timedelta(int(n.group(5)) - 1)

    realdate = date.strftime("%Y-%m-%d-%H-%M")

    sector = n.group(2)
    channel = n.group(3)

    target_prefix = ""
    s3path = "/vsicurl/https://{}.s3.amazonaws.com/{}"

    if "_G16_" in netcdf:
        print("Processing GOES-16 file", realdate)
        src_srs.ImportFromProj4(goese_srs)
        target_prefix = "GOES16"
    elif "_G17_" in netcdf:
        print("Processing GOES-17 file", realdate)
        src_srs.ImportFromProj4(goesw_srs)
        target_prefix = "GOES17"

    filename = "{}.tif".format(channel, realdate)
    path = 'NETCDF:{}:CMI'.format(s3path.format(bucket, netcdf))
    ds = gdal.Open(path)
    ds = gdal.Translate(
        "/vsimem/tmp.tif",
        ds,
        unscale=True,
        outputType=gdal.GDT_Float32,
        outputSRS=src_srs,
    )
    ds = gdal.Warp(
        "/tmp/" + filename,
        ds,
        srcSRS=src_srs,
        dstSRS=dst_srs,
        format="COG",
        dstNodata=-9999,
        multithread=True,
        warpOptions=["SOURCE_EXTRA=1000"],
        creationOptions=["COMPRESS=DEFLATE"],
    )
    ds = None
    if TARGET_BUCKET is not None:
        boto3.client("s3").upload_file(
            "/tmp/" + filename,
            TARGET_BUCKET,
            "{}/{}/{}/{}".format(target_prefix, sector, channel, filename),
        )
        os.remove("/tmp/" + filename)

    return response()
