variable "configs" {
  type = object({
    repositories = list(object({
        name = string
        image_tag_mutability = optional(string)
        enable_image_scanning = optional(bool)
        exclusion_filters = optional(list(object({
            filter_type = string
            filter = string
        })))
    }))
  })
}