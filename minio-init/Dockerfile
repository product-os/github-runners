# https://github.com/product-os/minio-init
FROM ghcr.io/product-os/minio-init:0.1.7@sha256:0039fe5b508d8ba551105b44a6425b6d85434c68661675b39793882ef2d607f3

# Install our custom ansible settings
COPY config/ /config/

CMD ["--inventory", "/config/inventory.ini"]
