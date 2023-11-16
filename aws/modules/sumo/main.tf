# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


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
  for_each = var.create_tag_fields ? toset(local.fields.tags) : toset([])

  field_name = each.key
  data_type  = "String"
  state      = "Enabled"
}
