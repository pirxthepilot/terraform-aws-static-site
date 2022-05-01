#######################################
# Instance name
#######################################
variable "name" {}

#######################################
# Input parameters
#######################################
variable "domain" {
  description = "Domain name"
}

variable "subdomains" {
  description = "List of subdomains to set up. Everything here will be redirected to the apex domain."
  type        = list(any)
  default     = []
}

variable "route53_zone_id" {
  description = "Zone ID of domain"
}

variable "cache_ttl" {
  description = "Default cache behavior - TTL values"
  type = object({
    min     = number
    default = number
    max     = number
  })
  default = {
    min     = 0
    default = 3600
    max     = 86400
  }
}

variable "price_class" {
  description = "Cloudfront distribution price class"
  default     = "PriceClass_100"
}

variable "html_404" {
  description = "Path to 404 HTML page"
  default     = "/404.html"
}

variable "block_ofac_countries" {
  description = "Whether or not to block OFAC sanctioned countries"
  default     = false
}

variable "ofac_countries" {
  description = "OFAC countries list"
  default     = ["BY", "CU", "IR", "KP", "RU", "SY"]
}
