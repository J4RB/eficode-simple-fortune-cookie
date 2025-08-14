FROM golang:1.19 AS builder
WORKDIR /app
COPY . /app
RUN go mod download && go mod verify
RUN CGO_ENABLED=0 go build -o backend .

FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/backend /app/backend
EXPOSE 9000
ENTRYPOINT ["/app/backend"]