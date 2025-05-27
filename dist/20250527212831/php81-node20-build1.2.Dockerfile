FROM syneidon/laravel:php81-nonode-build1.1

USER appuser

ENV NODE_MAJOR=20
ENV NODE_DIR=/home/appuser/node
ENV PATH="$NODE_DIR/bin:$PATH"

RUN set -eux; \
  case "$NODE_MAJOR" in \
    14) NODE_FULL="14.21.3" ;; \
    16) NODE_FULL="16.20.2" ;; \
    18) NODE_FULL="18.18.2" ;; \
    20) NODE_FULL="20.11.1" ;; \
    *) echo "❌ Unsupported NODE_MAJOR: $NODE_MAJOR" && exit 1 ;; \
  esac; \
  mkdir -p "$NODE_DIR"; \
  curl -fsSL "https://nodejs.org/dist/v$NODE_FULL/node-v$NODE_FULL-linux-x64.tar.xz" -o node.tar.xz; \
  tar -xf node.tar.xz --strip-components=1 -C "$NODE_DIR"; \
  rm node.tar.xz; \
  node --version; \
  npm --version

CMD ["apache2-foreground"]
