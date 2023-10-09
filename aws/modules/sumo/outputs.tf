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
