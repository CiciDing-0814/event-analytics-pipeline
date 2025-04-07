from awsglue.context import GlueContext
from pyspark.context import SparkContext
from awsglue.utils import getResolvedOptions
from awsglue.job import Job

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init("streaming-etl-job", {})

stream_df = glueContext.create_data_frame.from_catalog(
    database="default",
    table_name="kinesis_table"
)

filtered_df = stream_df.filter("event_type != 'UNKNOWN'")

filtered_df.writeStream \
    .format("parquet") \
    .option("path", "s3://cici-event-processed-data-bucket/streaming/") \
    .option("checkpointLocation", "s3://cici-event-processed-data-bucket/checkpoints/") \
    .start() \
    .awaitTermination()
