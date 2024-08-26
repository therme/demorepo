USER=$(shell id -u -n)
TIMESTAMP=$(shell date -u +%s)
BUILD_HOST=$(shell which hostnamectl && hostnamectl || hostname)
COMMIT=$(shell git rev-list -1 HEAD)
VERSION=$(shell git describe --match 'v*')

.PHONY: clean

# reproducible go builds: https://go.dev/blog/rebuild#conclusion
hello-weaver:
	weaver generate && CGO_ENABLED=0 go build -trimpath \
		-tags '{"user":"$(USER)","timestamp":"$(TIMESTAMP)","build_host":"$(BUILD_HOST)","commit":"$(COMMIT)","version":"$(VERSION)"}' \
		-ldflags="-s -w \
		-X 'main.User=$(USER)' \
		-X 'main.Timestamp=$(TIMESTAMP)' \
		-X 'main.BuildHost=$(BUILD_HOST)' \
		-X 'main.Commit=$(COMMIT)' \
		-X 'main.Version=$(VERSION)'" \
		-o adder .

clean:
	$(RM) -f adder
