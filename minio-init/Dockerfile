# https://github.com/product-os/minio-init
FROM ghcr.io/product-os/minio-init:0.1.0@sha256:ca2ec82fd98c789efa14c03e8afd24106b52ed1ca5468cf0467c50246445d486

# Install our custom ansible settings
COPY config/ /config/

CMD ["--inventory", "/config/inventory.ini"]
