# syntax=docker/dockerfile:1

FROM alpine:latest as baseruntime
# https://github.com/golang/go/issues/59305#issuecomment-1513728735
RUN apk add gcompat

# https://docs.docker.com/build/building/multi-stage/
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
