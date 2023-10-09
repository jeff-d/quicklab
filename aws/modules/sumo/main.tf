# Hosted Collector
resource "sumologic_collector" "this" {
  name        = "${var.prefix}-${var.uid}"
  description = "A hosted collector for QuickLab related telemetry."
  category    = "${var.prefix}/${var.uid}/aws/${data.aws_region.current.name}"
}

# Folder
# https://help.sumologic.com/docs/get-started/library/#personal-folder
resource "sumologic_folder" "this" {
  name        = "${var.prefix}-${var.uid}"
  description = "Sumo Logic App Catalog Apps installed via terraform"
  parent_id   = data.sumologic_personal_folder.this["sumo"].id
}

# Fields
# https://help.sumologic.com/docs/manage/fields/
resource "sumologic_field" "tags" {
  for_each = toset(local.fields.tags)

  field_name = each.key
  data_type  = "String"
  state      = "Enabled"
}
