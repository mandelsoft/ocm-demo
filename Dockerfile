FROM --platform=$BUILDPLATFORM golang:1.19 AS builder
ARG COMMIT EFFECTIVE_VERSION GIT_TREE_STATE
ARG TARGETOS TARGETARCH

WORKDIR /go/src/github.com/open-component-model/ocm/
COPY go.* ./
COPY echoserver/cmd .
#COPY go/pkg pkg
RUN --mount=type=cache,target=/root/.cache/go-build go get -d ./...
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
        go build -o /main -ldflags "-s -w \
	-X main.gitVersion=$EFFECTIVE_VERSION \
	-X main.gitTreeState=$GIT_TREE_STATE \
	-X main.gitCommit=$COMMIT \
	-X main.buildDate=$(date -u +%FT%T%z)" \
	.

###################################################################################
FROM alpine

COPY --from=builder /main /echoserver
ENTRYPOINT [ "/echoserver" ]
