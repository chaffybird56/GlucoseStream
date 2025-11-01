package main

import (
    "context"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "strings"
    "time"

    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/s3"
    "github.com/google/uuid"
)

type GlucoseEvent struct {
    EventID   string  `json:"event_id"`
    PatientID string  `json:"patient_id"`
    SessionID string  `json:"session_id"`
    EventTime string  `json:"event_time"` // ISO8601
    MgDL      float64 `json:"mg_dL"`
    Source    string  `json:"source"`
}

type Response struct {
    Status  string `json:"status"`
    Message string `json:"message"`
    Count   int    `json:"count"`
}

var (
    s3Client *s3.Client
    rawBucket string
)

func init() {
    cfg, err := config.LoadDefaultConfig(context.Background())
    if err != nil {
        panic(err)
    }
    s3Client = s3.NewFromConfig(cfg)
    rawBucket = os.Getenv("RAW_BUCKET")
}

func putObject(ctx context.Context, key string, body []byte) error {
    _, err := s3Client.PutObject(ctx, &s3.PutObjectInput{
        Bucket: aws.String(rawBucket),
        Key:    aws.String(key),
        Body:   strings.NewReader(string(body)),
    })
    return err
}

func keyForEvent(t time.Time) string {
    return filepath.ToSlash(fmt.Sprintf("events/%04d/%02d/%02d/%02d/%s.json",
        t.Year(), t.Month(), t.Day(), t.Hour(), uuid.NewString()))
}

func handle(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
    if rawBucket == "" {
        return events.APIGatewayProxyResponse{StatusCode: 500, Body: `{"error":"RAW_BUCKET not set"}`}, nil
    }

    body := req.Body
    if body == "" {
        // Support direct Lambda invoke with body in requestContext if needed
        body = "{}"
    }

    // Try to parse array or single event
    var arr []GlucoseEvent
    if strings.HasPrefix(strings.TrimSpace(body), "[") {
        if err := json.Unmarshal([]byte(body), &arr); err != nil {
            return events.APIGatewayProxyResponse{StatusCode: 400, Body: fmt.Sprintf(`{"error":"%s"}`, err.Error())}, nil
        }
    } else {
        var e GlucoseEvent
        if err := json.Unmarshal([]byte(body), &e); err != nil {
            return events.APIGatewayProxyResponse{StatusCode: 400, Body: fmt.Sprintf(`{"error":"%s"}`, err.Error())}, nil
        }
        arr = []GlucoseEvent{e}
    }

    // Write as JSON lines file per batch
    now := time.Now().UTC()
    key := keyForEvent(now)
    var b strings.Builder
    enc := json.NewEncoder(&b)
    for i := range arr {
        if arr[i].EventID == "" {
            arr[i].EventID = uuid.NewString()
        }
        if arr[i].EventTime == "" {
            arr[i].EventTime = now.Format(time.RFC3339)
        }
        if err := enc.Encode(arr[i]); err != nil {
            return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf(`{"error":"%s"}`, err.Error())}, nil
        }
    }
    if err := putObject(ctx, key, []byte(b.String())); err != nil {
        return events.APIGatewayProxyResponse{StatusCode: 500, Body: fmt.Sprintf(`{"error":"%s"}`, err.Error())}, nil
    }

    resp := Response{Status: "ok", Message: "ingested", Count: len(arr)}
    rb, _ := json.Marshal(resp)
    return events.APIGatewayProxyResponse{StatusCode: 200, Body: string(rb)}, nil
}

func main() { lambda.Start(handle) }


