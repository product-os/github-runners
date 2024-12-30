# https://github.com/product-os/minio-init
FROM ghcr.io/product-os/minio-init:0.0.7

# Install our custom ansible settings
COPY config/ /config/

CMD ["--inventory", "/config/inventory.ini"]
