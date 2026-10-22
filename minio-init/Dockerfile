# https://github.com/product-os/minio-init
FROM ghcr.io/product-os/minio-init:0.1.1@sha256:0886beaf8784913c0d396beec6dac56259f54c4cacaa85d9acfafbf8e8f68f1c

# Install our custom ansible settings
COPY config/ /config/

CMD ["--inventory", "/config/inventory.ini"]
