provider "aws" {
  version = "~> 1.11"
  region  = "ca-central-1"
}

variable "domain_name" {
  type = "string"
}

variable "acm_arn" {
  type = "string"
}

resource "aws_s3_bucket" "my-website" {
  bucket = "${var.domain_name}-site"
  acl    = "public-read"
  policy = "${file("s3_public.json")}"
}

resource "aws_s3_bucket" "apex" {
  bucket = "${var.domain_name}-redirect"
  acl    = "public-read"

  website {
    redirect_all_requests_to = "https://www.example.com"
  }
}

resource "aws_cloudfront_distribution" "my-website" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = "${aws_s3_bucket.my-website.bucket_domain_name}"
    origin_id   = "myWebsiteS3"
  }

  aliases = ["www.${var.domain_name}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    target_origin_id = "myWebsiteS3"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 7200
    max_ttl                = 86400
  }

  viewer_certificate {
    acm_certificate_arn = "${var.acm_arn}"
  }
}

resource "aws_cloudfront_distribution" "my-website-apex" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = "${aws_s3_bucket.apex.website_domain}"
    origin_id   = "myWebsiteS3Apex"
  }

  aliases = ["${var.domain_name}"]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    target_origin_id = "myWebsiteS3Apex"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 7200
    max_ttl                = 86400
  }

  viewer_certificate {
    acm_certificate_arn = "${var.acm_arn}"
  }
}

data "aws_route53_zone" "myzone" {
  name = "${var.domain_name}"
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.myzone.zone_id}"
  name    = "test.deployawebsite.com"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.my-website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.my-website.hosted_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "apex" {
  zone_id = "${data.aws_route53_zone.myzone.zone_id}"
  name    = "${var.domain_name}"
  type    = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.my-website-apex.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.my-website-apex.hosted_zone_id}"
    evaluate_target_health = true
  }
}
