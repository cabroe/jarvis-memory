FROM golang:alpine AS builder

WORKDIR /app
COPY go.mod ./
# Copy go.sum only if it exists
COPY go.sum* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o jarvis-memory ./cmd/jarvis-memory

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/jarvis-memory .

# Expose API port
EXPOSE 8080
CMD ["./jarvis-memory"]
