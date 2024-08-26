# syntax=docker/dockerfile:1

# BUILDING
# - for Intel:
# $ docker build --platform linux/amd64 . -t hello-weaver
# - for ARM:
# $ docker build --platform linux/arm64 . -t hello-weaver
#
# RUNNING
# $ docker run -it -p 8080:8080 --name demoapp hello-weaver
#
# HOW IT WORKS
# See ref [1]

# this is a multi-stage build, see ref [2]
#  - Code changes often
#  - OS, runtime and rest of system do not
#  - no need to have any build stuff in prod: reduce attack surface and keep the
#    image slim
#  - make the image slimmer yet by doing pure go builds (see ref [1] and
#    using `FROM scratch` as base runtime image
#
# We do the build steps in order of what changes from least to most often.
# Copy the resulting binary to `runtime` docker build:
#  1/ get the runtime OS/build environment and configure it -> result is
#     baseruntime - SKIP BECAUSE WE ARE RUNNING A STATICALLY-LINKED GOLANG
#     BINARY SO THIS IS UNNCESSARY. If any kind of runtime environment config is
#     needed or possibly if the binary isn't statically linked, this step is
#     needed as well.
#  2/ setup the build environment -> result is basebuild
#  3/ use basebuild to build the server -> result is serverbuild
#  4/ copy the server from serverbuild to baseruntime, or `scratch` for
#     statically linked executables -> result is runtime
#  5/ shipit
#
# While steps 3 and 4 needs to happen every time the code changes, steps 1 and 2
# do not. Take advantage of docker caching architecture to leave those stages/
# image layers alone by doing step 3 after 1 and 2.
# Step 3 results in a large docker image (822MB). The binaries we need are a lot
# smaller than 800-odd MB and come out to 49.2MB total, of which 30MB is the
# weaver executable -> step 4 copies just those necessary binaries to
# baseruntime. Go is statically linked so there's no need to copy over any
# libraries.
#
# Refs:
# [1] Dockerfile basics and command reference
#     https://docs.docker.com/engine/reference/builder/
# [2] Multi-stage builds
#     https://docs.docker.com/build/building/multi-stage/
# [3] Laurent Demailly's blogpost
#     https://laurentsv.com/blog/2024/06/25/stop-the-go-and-docker-madness.html
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

# following (step 1) is commented out because we're using scratch image. If
# using alpine though, this should probably be uncommented

#FROM alpine:latest as baseruntime
# add gcompat because
# https://github.com/golang/go/issues/59305#issuecomment-1513728735
# hadolint ignore=DL3018
#RUN apk add --no-cache gcompat

FROM golang:1.23 AS basebuild

RUN mkdir /build
WORKDIR /build

ADD go.mod .
ADD go.sum .
RUN go mod download
RUN go install github.com/ServiceWeaver/weaver/cmd/weaver@latest

FROM basebuild AS serverbuild

ADD . /build
RUN go build .

FROM scratch AS runtime

COPY --from=serverbuild /go/bin/weaver /usr/local/bin/weaver
COPY adder.toml /var/lib/adder/adder.toml
COPY --from=serverbuild /build/adder /usr/local/bin/adder

EXPOSE 8080

CMD ["single", "deploy", "/var/lib/adder/adder.toml"]
ENTRYPOINT ["weaver"]
