output "rum_traces_url" {
  description = "the URL of the RUM Traces Source"
  value       = try(sumologic_http_source.rum_traces["cluster"].url, null)
  # value       = var.create_cluster ? sumologic_http_source.rum_traces["cluster"].url : "n/a"
}
