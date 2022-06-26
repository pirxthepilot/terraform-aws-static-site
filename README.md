# terraform-aws-static-site

Terraform module for a single static site using AWS S3 and Cloudfront

## Features

* Deploys almost everything needed to create a static website
* Main URL uses the apex domain (e.g. https://example.com)
* Multiple subdomain support - redirects to the apex domain
* No need to make your S3 bucket publicly accessible - only Cloudfront can access it via Origin Access Identity (OAI) 
* URL rewrite function that appends index.html to the URI. Without this, Cloudfront is only able to render the top level `index.html` of your site (in other words, you can access `https://example.com` but not e.g. `https://example.com/foo`).


## Description

This module creates these AWS resources for your static website:

* S3 bucket
* Requisite IAM and bucket access policies
* S3 Origin Access Identity (OAI)
* Route53 DNS records
* TLS certificates (including DNS verification)
* Cloudfront distribution
* Cloudfront function for redirect and rewrite rules

This module DOES NOT deploy

* Your domain's Route53 zone - you will have to manually configure this and obtain the zone ID to use with this module.
* Your static site source files - see [Uploading files to S3](#uploading-files-to-s3)


## Usage

In the terraform project `main.tf`:

```
module "my_site" {
  source = "github.com/pirxthepilot/terraform-aws-static-site?ref=v0.0.1"
  name   = "my_site"

  domain               = "example.com"
  subdomains           = ["www"]
  route53_zone_id      = var.your_zone_id
  block_ofac_countries = true

  cache_ttl = {
    min     = 0
    default = 14400
    max     = 86400
  }
}
```

It is highly recommended that you pin to a specific tag or commit ID by including `?ref=<tag_or_commit>` in the `source` declaration. Otherwise, future changes to this repo might break your site's deployment. 

Inputs:

* `source` - path to this module relative to your project directory
* `name` - a name for your deployment
* `domain` - your site's domain (e.g. `example.com`)
* `subdomains` (optional) - a list of subdomains to configure. Note that all subdomains will just redirect to the apex domain URL. Default is `[]` (no subdomain).
* `route53_zone_id` - Route53 zone ID of your domain
* `block_ofac_countries` (optional) - whether or not to block OFAC sanctioned countries. Default is `false`.
* `cache_ttl` (optional) - Cloudfront cache TTL values. See [variables.tf](./variables.tf) for default values.

Run from your terraform project:

```
teraform fmt
terraform init
terraform plan
```

Review the plan, and  if everything looks good, proceed to apply:

```
terraform apply
```

### Using a cloned copy of the repo

Alternatively, if you want to use the module but need to make custom changes, you can simply clone it to your local:

```
git clone https://github.com/pirxthepilot/terraform-aws-static-site.git ./modules/terraform-aws-static-site
```

then reference the cloned directory in your module declaration:

```
  source = "./modules/terraform-aws-static-site"
```


## Uploading files to S3

After deploy, you can upload your static files to the newly-created S3 bucket via AWS Console or `aws-cli`:

```
aws s3 cp public s3://example.com/ --recursive
```

assuming your static files are in the `./public` directory.

To update the files:

```
aws s3 rm s3://example.com --recursive
aws s3 cp public s3://example.com/ --recursive
```

To invalidate files, refreshing the Cloudfront cache:

```
aws cloudfront create-invalidation \
    --distribution-id EDFDVBD6EXAMPLE \
    --paths "/*"
```


## References

* https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution
* https://www.milanvit.net/post/terraform-recipes-cloudfront-distribution-from-s3-bucket/
* https://gist.github.com/danihodovic/a51eb0d9d4b29649c2d094f4251827dd
* https://medium.com/@Markus.Hanslik/setting-up-an-ssl-certificate-using-aws-and-terraform-198c6fb90743
* https://stackoverflow.com/questions/31017105/how-do-you-set-a-default-root-object-for-subdirectories-for-a-statically-hosted
* https://github.com/aws-samples/amazon-cloudfront-functions/tree/main/url-rewrite-single-page-apps
