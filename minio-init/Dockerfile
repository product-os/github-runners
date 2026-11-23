# https://github.com/product-os/minio-init
FROM ghcr.io/product-os/minio-init:0.1.8@sha256:825b8236fb8418412d1e8a4dd0299bc7cffc826b06904cf21e8a8bcca99fe9be

# Install our custom ansible settings
COPY config/ /config/

CMD ["--inventory", "/config/inventory.ini"]
