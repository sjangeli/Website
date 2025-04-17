# Specify the provider
provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for Website Hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = "steveangeli.com"

  tags = {
    Name        = "WebsiteBucket"
    Environment = "Production"
  }
}

resource "aws_s3_object" "website_files" {
  for_each = {
    "about.html"       = "./about.html"
    "error.html"       = "./error.html"
    "index.html"       = "./index.html"
    "resume.html"      = "./resume.html"
    "invoke-api.js"    = "./invoke-api.js"
    "styles.css"       = "./styles.css"
    "site.webmanifest" = "./site.webmanifest"
  }

  bucket       = aws_s3_bucket.website_bucket.id
  key          = each.key
  source       = each.value
  acl          = "private"
  content_type = (
    each.key == "styles.css" ? "text/css" :
    each.key == "index.html" ? "text/html" :
    each.key == "about.html" ? "text/html" :
    each.key == "resume.html" ? "text/html" :
    each.key == "error.html" ? "text/html" :
    each.key == "invoke-api.js" ? "application/javascript" :
    each.key == "site.webmanifest" ? "application/manifest+json" :
    null
  )
  etag = filemd5(each.value)
}

data "local_file" "images" {
  for_each = fileset("./images", "**")

  filename = "./images/${each.value}"
}

resource "aws_s3_object" "images" {
  for_each = data.local_file.images

  bucket = aws_s3_bucket.website_bucket.id
  key    = "images/${each.key}" # Upload to the images/ directory in S3
  source = data.local_file.images[each.key].filename
  acl    = "private"
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowCloudFrontAccess",
        "Effect": "Allow",
        "Principal": {
          "Service": "cloudfront.amazonaws.com"
        },
        "Action": "s3:GetObject",
        "Resource": "${aws_s3_bucket.website_bucket.arn}/*",
        "Condition": {
          "StringEquals": {
            "AWS:SourceArn": "arn:aws:cloudfront::593793034365:distribution/${aws_cloudfront_distribution.website_distribution.id}"
          }
        }
      }
    ]
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress = true
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.id}"
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn      = "arn:aws:acm:us-east-1:593793034365:certificate/30cfdfe3-c940-4e2a-96d7-6eb2dd75bdcf"
    ssl_support_method        = "sni-only"
    minimum_protocol_version  = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  price_class = "PriceClass_100"
  
  aliases = ["steveangeli.com", "www.steveangeli.com"]

  tags = {
    Name        = "WebsiteDistribution"
    Environment = "Production"
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "WebsiteOAC"
  description                       = "Origin Access Control for CloudFront to access S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# API Gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "VisitorCountUpdater"
  description = "API Gateway for website visitor counter"
}

resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "visitor-counter"
}

resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
    depends_on = [aws_api_gateway_method.options_method]
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_resource.id
  http_method             = aws_api_gateway_method.options_method.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}" # Ensure statusCode is defined as an integer
  }

  depends_on = [aws_api_gateway_method.options_method]
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code   = "${aws_api_gateway_method_response.options_method_response.status_code}"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  }

  depends_on = [aws_api_gateway_method_response.options_method_response]
}

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "get_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
    }
  depends_on = [aws_api_gateway_method.get_method]
}

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_resource.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id

  depends_on = [
    aws_api_gateway_method.get_method,
    aws_api_gateway_method.options_method,
    aws_api_gateway_integration.get_integration
  ]
}

resource "aws_api_gateway_stage" "api_stage" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = "prod"
}

output "api_gateway_url" {
  value = aws_api_gateway_stage.api_stage.invoke_url
  description = "The base URL for the API Gateway stage"
}

# Lambda Function
resource "aws_lambda_function" "lambda_function" {
  function_name = "steveangeli_WebsiteCounter" 
  runtime       = "python3.13"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"

  filename         = "lambda_function.py.zip" 
  source_code_hash = filebase64sha256("lambda_function.py.zip")

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.visitor_counter_table.name
    }
  }

  tags = {
    Name        = "VisitorCounterLambda"
    Environment = "Production"
  }
}

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "steveangeli_WebsiteCounter-role-kq9x7khv"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "dynamodb_access_policy" {
  name        = "steveangeli_WebsiteCounter_DynamoDBAccessPolicy"
  description = "IAM policy for Lambda to access DynamoDB table"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",    
          "dynamodb:UpdateItem",  
        ],
        Effect   = "Allow",
        Resource = "arn:aws:dynamodb:us-east-1:593793034365:table/MyTable",
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_access_policy.arn
}

# DynamoDB Table
resource "aws_dynamodb_table" "visitor_counter_table" {
  name           = "MyTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name        = "VisitorCounterTable"
    Environment = "Production"
  }
}


data "aws_dynamodb_table_item" "existing_item" {
    count = aws_dynamodb_table.visitor_counter_table.arn != null ? 1 : 0
    table_name = aws_dynamodb_table.visitor_counter_table.name
    key = jsonencode({
        "id" = {
            "S" = "0"
        }
    })
    depends_on = [aws_dynamodb_table.visitor_counter_table]
}

locals {
    item_exists = try(data.aws_dynamodb_table_item.existing_item[0].item, null) != null
}

resource "aws_dynamodb_table_item" "initial_item" {
  count = local.item_exists ? 0 : 1
  table_name = aws_dynamodb_table.visitor_counter_table.name
  hash_key   = aws_dynamodb_table.visitor_counter_table.hash_key


  item = jsonencode({
    "id" = {
      "S" = "0"
      },
      "count" = {
        "N" = "0"
        }
        })

    depends_on = [
        aws_dynamodb_table.visitor_counter_table
    ]

    lifecycle {
      create_before_destroy = true
    }
}

# Route53 Zone
resource "aws_route53_zone" "hosted_zone" {
  name = "steveangeli.com"
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "steveangeli.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website_distribution.domain_name
    zone_id                = "Z2FDTNDATAQYW2"              # CloudFront's hosted zone ID (static value for all CloudFront distributions)
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "www.steveangeli.com"
  type    = "CNAME"
  ttl     = 300
  records = ["steveangeli.com"]
}