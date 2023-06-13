# syntax=docker/dockerfile:1

# https://docs.docker.com/build/building/multi-stage/
FROM golang:1.20 as basebuild

RUN mkdir /build
WORKDIR /build

ADD go.mod .
ADD go.sum .
RUN go mod download

FROM basebuild AS serverbuild

ADD . /build
RUN go build .

FROM alpine:latest as baseruntime
# https://github.com/golang/go/issues/59305#issuecomment-1513728735
RUN apk add gcompat

FROM baseruntime as runtime

COPY --from=serverbuild /build/adder /usr/local/bin/adder

CMD ["/usr/local/bin/adder"] 
