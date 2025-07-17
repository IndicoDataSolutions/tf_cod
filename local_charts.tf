resource "null_resource" "local_charts" {
  count = var.use_local_helm_charts ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      if [ -d "charts" ]; then
        echo "Untarring charts from charts directory..."
        for chart_file in charts/*.tgz; do
          if [ -f "$chart_file" ]; then
            echo "Untarring $chart_file..."
            tar -xzf "$chart_file"
          fi
        done
        echo "Finished untarring charts"
      else
        echo "Charts directory not found"
      fi
    EOT
  }
}