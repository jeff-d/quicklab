# This file is part of QuickLab, which creates simple, monitored labs.
# https://github.com/jeff-d/quicklab
#
# SPDX-FileCopyrightText: © 2023 Jeffrey M. Deininger <9385180+jeff-d@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later


output "rum_traces_url" {
  description = "the URL of the RUM Traces Source"
  value       = try(sumologic_http_source.rum_traces["cluster"].url, null)
  # value       = var.create_cluster ? sumologic_http_source.rum_traces["cluster"].url : "n/a"
}

output "sumo_fields" {
  description = "A list of existing Sumo Logic Fields"
  value       = local.sumo_fields
}

output "sumo_extraction_rules" {
  description = "A list of existing Sumo Logic Field Extraction Rules"
  value       = local.sumo_extraction_rules
}

output "debug_fer_resp_data" {
  value = jsondecode(data.http.sumo_field_extraction_rules.response_body).data
}
