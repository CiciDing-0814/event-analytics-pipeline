import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

datasource = glueContext.create_dynamic_frame.from_options(
    connection_type="s3",
    connection_options={"paths": ["s3://cici-event-raw-data-bucket/events.csv"]},
    format="csv",
    format_options={"withHeader": True}
)

filtered = Filter.apply(frame=datasource, f=lambda x: x["event_type"] != "UNKNOWN")

glueContext.write_dynamic_frame.from_options(
    frame=filtered,
    connection_type="s3",
    connection_options={"path": "s3://cici-event-processed-data-bucket/batch/"},
    format="parquet"
)

job.commit()
