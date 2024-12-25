# syntax=docker/dockerfile:1

# ====== BUILDING ======
# - for Intel:
# $ docker build --platform linux/amd64 . -t hello-weaver
# - for ARM:
# $ docker build --platform linux/arm64 . -t hello-weaver
#
# ====== RUNNING ======
# $ docker run -it -p 8080:8080 --name demoapp hello-weaver
#
# ===== OVERVIEW  =====
# See ref [1] for a high-level overview, and ref [2] for details on specific
# commands
#
# Basic principles:
#  - Code changes often
#  - OS, runtime and rest of system do not
#  - no need to have any build stuff in prod -> reduce attack surface and keep
#    the image slim by excluding all the build tools from the final shipped
#    image. This is accomplished via a multi-stage build process (see ref [3]
#    for more on those)
#  - make the image slimmer yet by doing pure go builds (see ref [1] and
#    using `FROM scratch` as base runtime image)
#
# In order to take maximum advantage of the docker image cache, we do the build
# steps in order of what changes from least to most often.
# We finish by copying the resulting binary to `runtime` docker build. Here's
# a more detailed list of steps:
#  1/ configure the runtime OS/runtime SDK -> result is
#     baseruntime - SKIP BECAUSE WE ARE RUNNING A STATICALLY-LINKED GOLANG
#     BINARY SO THIS IS UNNCESSARY. We will use `scratch` here instead.
#     If any kind of runtime config is needed or if the binary isn't statically
#     linked, this step is needed as well. Also see ref [4]
#  2/ setup the build environment -> result is basebuild
#  3/ use basebuild to build the server -> result is serverbuild
#  4/ copy the server from serverbuild to baseruntime, or in this case to
#     `scratch` since it's a statically linked executables -> result is runtime
#  5/ shipit
#
# While steps 3 and 4 needs to happen every time the code changes, steps 1 and 2
# do not.
# Step 3 results in a large docker image (822MB). The binaries we need are a lot
# smaller than 800-odd MB and come out to 49.2MB total, of which 30MB is the
# weaver executable -> step 4 copies just those necessary binaries to
# baseruntime. Go is statically linked so there's no need to copy over any
# libraries.
#
# ====== PITFALLS ======
# - Making https calls from your app? You'll need a CA bundle. If you're using
#   `FROM SCRATCH` as your baseruntme and you have a go application, you can solve
#   this with the following blank import in your application code:
#   ```
#   import _ "golang.org/x/crypto/x509roots/fallback"
#   ```
# - Does your webapp load and serve static content? You may possibly want to
#   copy a /etc/mime.types from the build layer - see ref [5]
#
# ===== REFERENCES =====
# [1] Laurent Demailly's blogpost
#     https://laurentsv.com/blog/2024/06/25/stop-the-go-and-docker-madness.html
# [2] Dockerfile basics and command reference
#     https://docs.docker.com/engine/reference/builder/
# [3] Multi-stage builds
#     https://docs.docker.com/build/building/multi-stage/
# [4] Distroless docker images, for when shipping a statically-linked binary
#     isn't possible
#     https://github.com/GoogleContainerTools/distroless
# [5] On mimetypes and serving static content from a webserver
#     https://xeiaso.net/blog/2024/fixing-rss-mailcap/
#
#
# TIPS FOR DEBUGGING THE BUILD
# 1/ Use dive https://github.com/wagoodman/dive
# Also see https://github.com/wagoodman/dive/issues/453#issuecomment-1573395382
#
# 2/ run the command:
# $ DOCKER_BUILDKIT=0 docker build --platform $PLATFORM . -t hello-weaver
# search for the last successful relevant stage "successfully built HASH"
# comment out CMD and ENTRYPOINT at the bottom of the file, run
# $ docker run --rm HASH --name demoapp COMMAND

# 3/ optional: add bash to the list of runtime dependencies, rebuild the image,
# run it and $ docker exec -it demoapp /bin/bash

# We use the docker registry in AWS for retention of our old docker builds. If
# something breaks, we can revert to an old container version.

FROM golang:1.23 AS basebuild

WORKDIR /build

COPY go.mod go.sum ./
# reproducible go builds: https://go.dev/blog/rebuild#conclusion
RUN CGO_ENABLED=0 go install \
    -trimpath github.com/ServiceWeaver/weaver/cmd/weaver@latest
# Don't redownload the weaver command just because a single dependency version
# was bumped -> keep it in its own layer
# hadolint ignore=DL3059
RUN CGO_ENABLED=0 go mod download

FROM basebuild AS serverbuild

COPY . /build
RUN weaver generate && make

FROM scratch AS runtime

COPY --from=serverbuild /go/bin/weaver /usr/local/bin/weaver
COPY adder.toml /var/lib/adder/adder.toml
COPY --from=serverbuild /build/adder /usr/local/bin/adder

EXPOSE 8080

CMD ["single", "deploy", "/var/lib/adder/adder.toml"]
ENTRYPOINT ["weaver"]
