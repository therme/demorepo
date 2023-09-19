# syntax=docker/dockerfile:1

# BUILDING
# - on Intel:
# $ docker build --platform linux/amd64 . -t hello-weaver
# - on ARM:
# $ docker build --platform linux/arm64 . -t hello-weaver
#
# RUNNING
# $ docker run -it -p 8080:8080 --name demoapp hello-weaver
#
# HOW IT WORKS
# Dockerfile ref
# https://docs.docker.com/engine/reference/builder/

# this is a multi-stage build
# https://docs.docker.com/build/building/multi-stage/
#  - Code changes often
#  - OS and rest of system does not
#  - no need to have any build stuff in prod: reduce attack surface and keep the
#    image slim
#
# -> We do the build steps in order of what changes from least to most often.
# Copy the resulting binary to `runtime` docker build:
#  1/ get the runtime OS and configure it -> result in baseruntime
#  2/ setup the build environment -> result is basebuild
#  3/ use basebuild to build the server -> result is serverbuild
#  4/ copy the server from serverbuild to baseruntime -> result is runtime
#  5/ shipit
# While step 3 needs to happen every time the code changes, steps 1 and 2
# do not. Take advantage of docker caching architecture to leave those stages/
# image layers alone by doing step 3 after 1 and 2.
# Step 3 results in a large docker image (822MB). The binaries we need are a lot
# smaller than 800-odd MB and come out to 64.3MB total -> step 4 copies just
# those binaries to baseruntime
#
# TIPS FOR DEBUGGING THE BUILD
# 1/ run the command:
# $ DOCKER_BUILDKIT=0 docker build --platform $PLATFORM . -t hello-weaver
# search for the last successful relevant stage "successfully built HASH"
# comment out CMD and ENTRYPOINT at the bottom of the file, run
# $ docker run --rm HASH --name demoapp COMMAND

# 2/ optional: add bash to the list of runtime dependencies, rebuild the image, run
# it and $ docker exec -it demoapp /bin/bash

FROM alpine:latest as baseruntime
# add gcompat because
# https://github.com/golang/go/issues/59305#issuecomment-1513728735
RUN apk add gcompat

FROM golang:1.21 as basebuild

RUN mkdir /build
WORKDIR /build

ADD go.mod .
ADD go.sum .
RUN go mod download
RUN go install github.com/ServiceWeaver/weaver/cmd/weaver@latest

FROM basebuild AS serverbuild

ADD . /build
RUN go build .

FROM baseruntime as runtime

COPY --from=serverbuild /go/bin/weaver /usr/local/bin/weaver
COPY adder.toml /var/lib/adder/adder.toml
COPY --from=serverbuild /build/adder /usr/local/bin/adder

EXPOSE 8080

CMD ["single", "deploy", "/var/lib/adder/adder.toml"]
ENTRYPOINT ["weaver"]
