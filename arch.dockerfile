# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
# :: GLOBAL
  ARG APP_UID=1000 \
      APP_GID=1000 \
      BUILD_ROOT=/go/beszel \
      BUILD_SRC=henrygd/beszel.git
  ARG BUILD_BIN=/hub

# :: FOREIGN IMAGES
  FROM 11notes/distroless AS distroless
  FROM 11notes/distroless:localhealth AS distroless-localhealth

# ╔═════════════════════════════════════════════════════╗
# ║                       BUILD                         ║
# ╚═════════════════════════════════════════════════════╝
# :: BESZEL
  FROM 11notes/go:1.25 AS build
  ARG APP_VERSION \
      APP_ROOT \
      BUILD_ROOT \
      BUILD_SRC \
      BUILD_BIN

  RUN set -ex; \
    apk --update --no-cache add \
      npm;

  RUN set -ex; \
    eleven git clone ${BUILD_SRC} v${APP_VERSION};

  RUN set -ex; \
    cd ${BUILD_ROOT}; \
    sed -i 's|beszel.AppName + "_data"|"'${APP_ROOT}'/var"|g' ./internal/cmd/hub/hub.go;

  RUN set -ex; \
    cd ${BUILD_ROOT}; \
    npm install --prefix ./internal/site; \
    npm run --prefix ./internal/site build;

  RUN set -ex; \
    cd ${BUILD_ROOT}; \
    eleven go build ${BUILD_BIN} ./internal/cmd/hub;

  RUN set -ex; \
    eleven distroless ${BUILD_BIN};

# :: FILE SYSTEM
  FROM alpine AS file-system
  ARG APP_ROOT

  RUN set -ex; \
    mkdir -p /distroless${APP_ROOT}/var;


# ╔═════════════════════════════════════════════════════╗
# ║                       IMAGE                         ║
# ╚═════════════════════════════════════════════════════╝
# :: HEADER
  FROM scratch

  # :: default arguments
    ARG TARGETPLATFORM \
        TARGETOS \
        TARGETARCH \
        TARGETVARIANT \
        APP_IMAGE \
        APP_NAME \
        APP_VERSION \
        APP_ROOT \
        APP_UID \
        APP_GID \
        APP_NO_CACHE

  # :: default environment
    ENV APP_IMAGE=${APP_IMAGE} \
      APP_NAME=${APP_NAME} \
      APP_VERSION=${APP_VERSION} \
      APP_ROOT=${APP_ROOT}

  # :: multi-stage
    COPY --from=distroless / /
    COPY --from=distroless-localhealth / /
    COPY --from=build /distroless/ /
    COPY --from=file-system --chown=${APP_UID}:${APP_GID} /distroless/ /

# :: PERSISTENT DATA
  VOLUME ["${APP_ROOT}/var"]

# :: MONITORING
  HEALTHCHECK --interval=5s --timeout=2s --start-period=5s \
    CMD ["/usr/local/bin/localhealth", "http://127.0.0.1:8090/", "-I"]

# :: EXECUTE
  USER ${APP_UID}:${APP_GID}
  ENTRYPOINT ["/usr/local/bin/hub"]
  CMD ["serve", "--http=0.0.0.0:8090"]