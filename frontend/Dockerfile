FROM golang:1.19 AS builder
WORKDIR /app
COPY . /app
RUN go mod download && go mod verify
RUN CGO_ENABLED=0 go build -o frontend .

FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/ /app/
EXPOSE 8080
ENTRYPOINT ["/app/frontend"]