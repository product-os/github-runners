# https://github.com/product-os/minio-init
FROM ghcr.io/product-os/minio-init:0.1.5@sha256:b6d21006e23d673d6a5250b353980e9d47c3b8383a13914fc1f0d61170d790ba

# Install our custom ansible settings
COPY config/ /config/

CMD ["--inventory", "/config/inventory.ini"]
