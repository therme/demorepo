USER=$(shell id -u -n)
TIME=$(shell date -u +%s)
BUILD_HOST=$(shell which hostnamectl && hostnamectl || hostname)

.PHONY: clean

# reproducible go builds: https://go.dev/blog/rebuild#conclusion
hello-weaver:
	weaver generate && CGO_ENABLED=0 go build -trimpath \
		-tags '{"user":"$(USER)","time":"$(TIME)","build_host":"$(BUILD_HOST)"}' \
	-ldflags="-s -w \
	-X 'main.User=$(USER)' \
	-X 'main.Time=$(TIME)' \
	-X 'main.BuildHost=$(BUILD_HOST)' \
	-o adder .

clean:
	$(RM) -f adder
