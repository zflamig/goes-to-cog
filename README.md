# Using Lambda to Convert GOES-R Data to COG

This example creates an AWS Lambda for converting GOES-16 & GOES-17 L2 ABI Data to Cloud Optimized Geotiff using GDAL. The AWS Lambda container image is built with AWS CodePipeline storing the image in Amazon ECR and doing continuous deployment of the AWS Lambda function.

The function subscribes to the public Amazon SNS feeds available for the [NOAA GOES data from the Registry of Open Data on AWS](https://registry.opendata.aws/noaa-goes/).

## Docker usage

```
docker build -t gdal .
```

Run the container

```
docker run --rm -p 9000:8080 gdal
```

Test it out

```
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{\'Records\': [{\'Sns\': {\'Message\': \'{"Records":[{"s3":{"bucket":{"name":"noaa-goes16"}},"object":{"key":"ABI-L2-CMIPF/2021/046/20/OR_ABI-L2-CMIPF-M6C04_G16_s20210462000074_e20210462009382_c20210462009443.nc"}}}]}\'}}]}'
```

