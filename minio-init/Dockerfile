# https://github.com/product-os/minio-init
FROM ghcr.io/product-os/minio-init:0.1.2@sha256:d8e8c682ff69def91610d2b85f9882144562d969e89d6c2f7ff22416863f214d

# Install our custom ansible settings
COPY config/ /config/

CMD ["--inventory", "/config/inventory.ini"]
