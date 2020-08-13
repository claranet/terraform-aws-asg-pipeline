variable "name" {
  type = string
}

variable "targets" {
  type = list(map(any))
}
