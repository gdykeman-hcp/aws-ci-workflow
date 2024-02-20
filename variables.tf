variable "org" {
  description = "name of organization"
}

variable "vpc_vars" {
  description = "vpc related vars"
}

variable "instances" {
  description = "Instances to include."
}

variable "rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    proto       = string
    cidr_blocks = list(string)
  }))
}

variable "toggle" {
}