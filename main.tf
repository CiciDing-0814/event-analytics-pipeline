# ---------------------------
# AWS ETL Pipeline Project
# ---------------------------

provider "aws" {
  region = "ap-southeast-2" # Sydney region
}

# ---------------------------
# S3 Bucket for Raw & Processed Data
# ---------------------------
resource "aws_s3_bucket" "raw_data" {
  bucket = "cici-event-raw-data-bucket"
  force_destroy = true
}

resource "aws_s3_bucket" "processed_data" {
  bucket = "cici-event-processed-data-bucket"
  force_destroy = true
}

# ---------------------------
# Kinesis Stream for Real-Time Events
# ---------------------------
resource "aws_kinesis_stream" "event_stream" {
  name             = "cici-event-stream"
  shard_count      = 1
  retention_period = 24
}

# ---------------------------
# Firehose Delivery Stream (to S3)
# ---------------------------
resource "aws_kinesis_firehose_delivery_stream" "event_firehose" {
  name        = "cici-firehose-to-s3"
  destination = "s3"

  s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.raw_data.arn
    buffer_size        = 5
    buffer_interval    = 300
    compression_format = "UNCOMPRESSED"
  }
}

# ---------------------------
# IAM Role for Firehose
# ---------------------------
resource "aws_iam_role" "firehose_role" {
  name = "firehose_delivery_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_policy" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# ---------------------------
# Lambda for Real-Time Alerting
# ---------------------------
resource "aws_lambda_function" "alert_lambda" {
  filename         = "lambda_function_payload.zip"
  function_name    = "cici-realtime-alert"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---------------------------
# Glue Job (Batch ETL)
# ---------------------------
resource "aws_glue_job" "batch_etl" {
  name     = "cici-glue-batch-job"
  role_arn = aws_iam_role.glue_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.raw_data.bucket}/scripts/batch_etl.py"
    python_version  = "3"
  }
  glue_version = "4.0"
  max_capacity = 2.0
}

# ---------------------------
# Glue Job (Streaming ETL)
# ---------------------------
resource "aws_glue_job" "streaming_etl" {
  name     = "cici-glue-streaming-job"
  role_arn = aws_iam_role.glue_role.arn
  command {
    name            = "gluestreaming"
    script_location = "s3://${aws_s3_bucket.raw_data.bucket}/scripts/streaming_etl.py"
    python_version  = "3"
  }
  glue_version = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"
}

# ---------------------------
# IAM Role for Glue
# ---------------------------
resource "aws_iam_role" "glue_role" {
  name = "glue_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_policy" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
