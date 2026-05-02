locals {
  resource_name = "${var.name_prefix}-${var.agent_name}"
  runtime_name  = replace(local.resource_name, "-", "_")
  s3_prefix     = "${var.agent_name}/agent-code.zip"
  build_dir     = "${path.module}/build/${var.agent_name}_build"
  zip_path      = "${local.build_dir}/${var.agent_name}_code.zip"
  source_files  = fileset(var.agent_source_dir, "**/*.{txt,py}")
  source_file_hashes = {
    for f in local.source_files : f => filemd5("${var.agent_source_dir}/${f}")
  }
  source_content_hash = md5(join("", values(local.source_file_hashes)))
}

# ── Build: install deps + zip with source (mirrors toolkit direct_code_deploy) ─

resource "terraform_data" "build_agent_package" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      rm -rf "$BUILD_DIR" "$ZIP_PATH"
      mkdir -p "$BUILD_DIR"
      if [ -f "$SOURCE_DIR/requirements.txt" ]; then
        uv pip install \
          --python-platform aarch64-manylinux2014 \
          --python-version "$PYTHON_RUNTIME" \
          --target "$BUILD_DIR" \
          --only-binary=:all: \
          -r "$SOURCE_DIR/requirements.txt"
      fi
      # Remove caches and test directories to reduce zip size
      find "$BUILD_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
      find "$BUILD_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
      # Copy agent source code into the build directory
      cp -r "$SOURCE_DIR"/. "$BUILD_DIR"/
      rm -rf "$BUILD_DIR/__pycache__" "$BUILD_DIR/.bedrock_agentcore" "$BUILD_DIR/.bedrock_agentcore.yaml" "$BUILD_DIR/.dockerignore" "$BUILD_DIR/bin"
      cd "$BUILD_DIR" && zip -qr "$ZIP_PATH" .
    EOT

    environment = {
      SOURCE_DIR     = var.agent_source_dir
      BUILD_DIR      = local.build_dir
      ZIP_PATH       = abspath(local.zip_path)
      PYTHON_RUNTIME = var.python_runtime_version
    }
  }

  triggers_replace = {
    source_hash = local.source_content_hash
  }
}