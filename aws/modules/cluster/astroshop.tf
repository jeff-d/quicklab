resource "local_file" "astroshop_values" {
  content = templatefile(
    "${path.module}/astroshop-values.tftpl",
    {
      FULLNAMEOVERRIDE = var.fullnameoverride
      RUMURL           = var.sumo_cluster_rum_traces_url
      ACCESSID         = var.sumo_accessid
      ACCESSKEY        = var.sumo_accesskey
      CLUSTERNAME      = aws_eks_cluster.this.name
      PROJECT          = var.project
      ENVIRONMENT      = var.environment
      APPLICATION      = "${var.prefix}-${var.uid}-astroshop"
    }
  )
  filename        = "${path.module}/sumo-opentelemetry-demo/values.yaml"
  file_permission = "0600"
}

resource "local_file" "frontend_template" {
  content = templatefile(
    "${path.module}/sumo-opentelemetry-demo/frontend.tftpl",
    {
      PROJECT     = var.project
      ENVIRONMENT = var.environment
      APPLICATION = "${var.prefix}-${var.uid}-astroshop"
    }
  )
  filename        = "${path.module}/sumo-opentelemetry-demo/templates/frontend.yaml"
  file_permission = "0600"
}
