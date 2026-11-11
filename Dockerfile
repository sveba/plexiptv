# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG TARGETOS
ARG TARGETARCH
ARG VERSION
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build \
    -trimpath -ldflags "-s -w ${VERSION:+-X main.version=$VERSION}" \
    -o /out/plexiptv ./cmd/plexiptv \
    && mkdir /out/data

FROM debian:bookworm-slim AS ffmpeg
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && mkdir -p /runtime/usr/bin \
    && cp /usr/bin/ffmpeg /runtime/usr/bin/ \
    && ldd /usr/bin/ffmpeg | awk '/=> \// { print $3 } $1 ~ /^\// { print $1 }' \
       | xargs -r -I '{}' cp -L --parents '{}' /runtime/

FROM gcr.io/distroless/static-debian12:nonroot AS runtime
COPY --from=build /out/plexiptv /plexiptv
COPY --from=build --chown=65532:65532 /out/data /data
EXPOSE 34500/tcp 65001/udp 1900/udp
VOLUME ["/data"]
ENTRYPOINT ["/plexiptv"]
CMD ["-data", "/data"]

FROM runtime AS with-ffmpeg
COPY --from=ffmpeg /runtime/ /

FROM runtime AS plain
