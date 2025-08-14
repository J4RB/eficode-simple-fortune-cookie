FROM golang:1.19 AS builder
WORKDIR /app
COPY . /app
RUN go mod download && go mod verify
RUN cd /app && go build -o backend

FROM alpine
WORKDIR /app
COPY --from=builder /app/goapp /app/
ENTRYPOINT ./goapp