FROM golang:1.11.5 as base

ENV GO111MODULE on

RUN apt update && apt install -y git
#RUN apk --no-cache add gcc g++ make ca-certificates git
RUN mkdir /weaver
WORKDIR /weaver

ADD go.mod .
ADD go.sum .
RUN go mod download

FROM base AS weaver_base

ADD . /weaver
RUN make setup
RUN make build

FROM alpine:latest

COPY --from=weaver_base /weaver/out/weaver-server /usr/local/bin/weaver

ENTRYPOINT ["weaver", "start"] 
