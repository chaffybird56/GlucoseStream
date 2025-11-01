package main

import (
    "context"
    "encoding/json"
    "errors"
    "fmt"
    "os"
    "strconv"
    "time"

    "github.com/aws/aws-lambda-go/lambda"
    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/athena"
    aTypes "github.com/aws/aws-sdk-go-v2/service/athena/types"
)

type Result struct {
    Status  string `json:"status"`
    Message string `json:"message"`
    Checks  map[string]int `json:"checks"`
}

var (
    athenaClient *athena.Client
    workgroup    string
    outputLoc    string
    glueDB       string
)

func init() {
    cfg, err := config.LoadDefaultConfig(context.Background())
    if err != nil { panic(err) }
    athenaClient = athena.NewFromConfig(cfg)
    workgroup = os.Getenv("ATHENA_WORKGROUP")
    outputLoc = os.Getenv("ATHENA_OUTPUT")
    glueDB = os.Getenv("GLUE_DB")
}

func runQuery(ctx context.Context, q string) (string, error) {
    startOut, err := athenaClient.StartQueryExecution(ctx, &athena.StartQueryExecutionInput{
        QueryString: aws.String(q),
        WorkGroup:   aws.String(workgroup),
        ResultConfiguration: &aTypes.ResultConfiguration{
            OutputLocation: aws.String(outputLoc),
        },
        QueryExecutionContext: &aTypes.QueryExecutionContext{Database: aws.String(glueDB)},
    })
    if err != nil { return "", err }

    // Wait for completion
    for {
        time.Sleep(2 * time.Second)
        exe, err := athenaClient.GetQueryExecution(ctx, &athena.GetQueryExecutionInput{QueryExecutionId: startOut.QueryExecutionId})
        if err != nil { return "", err }
        state := exe.QueryExecution.Status.State
        switch state {
        case aTypes.QueryExecutionStateSucceeded:
            // fetch first cell
            res, err := athenaClient.GetQueryResults(ctx, &athena.GetQueryResultsInput{QueryExecutionId: startOut.QueryExecutionId})
            if err != nil { return "", err }
            if len(res.ResultSet.Rows) < 2 || len(res.ResultSet.Rows[1].Data) < 1 {
                return "0", nil
            }
            return aws.ToString(res.ResultSet.Rows[1].Data[0].VarCharValue), nil
        case aTypes.QueryExecutionStateFailed, aTypes.QueryExecutionStateCancelled:
            return "", errors.New("athena query failed")
        case aTypes.QueryExecutionStateRunning, aTypes.QueryExecutionStateQueued:
            continue
        default:
            continue
        }
    }
}

func handler(ctx context.Context) (Result, error) {
    if workgroup == "" || outputLoc == "" || glueDB == "" {
        return Result{Status: "error", Message: "missing env", Checks: map[string]int{}}, nil
    }
    checks := map[string]string{
        "invalid_ts": fmt.Sprintf("SELECT COUNT(*) FROM %s.raw_glucose_events WHERE event_time IS NULL", glueDB),
        "out_of_range": fmt.Sprintf("SELECT COUNT(*) FROM %s.raw_glucose_events WHERE mg_dL < 40 OR mg_dL > 400", glueDB),
        "dup_count": fmt.Sprintf("SELECT COUNT(*) FROM (SELECT event_id FROM %s.raw_glucose_events GROUP BY event_id HAVING COUNT(*) > 1)", glueDB),
    }

    results := map[string]int{}
    var totalFailures int
    for name, q := range checks {
        s, err := runQuery(ctx, q)
        if err != nil { return Result{Status: "error", Message: err.Error(), Checks: results}, err }
        n, _ := strconv.Atoi(s)
        results[name] = n
        // thresholds
        if name == "invalid_ts" && n > 0 { totalFailures++ }
        if name == "out_of_range" && n > 0 { totalFailures++ }
        if name == "dup_count" && n > 0 { totalFailures++ }
    }

    if totalFailures > 0 {
        b, _ := json.Marshal(results)
        return Result{Status: "failed", Message: string(b), Checks: results}, errors.New("dq checks failed")
    }
    return Result{Status: "ok", Message: "dq passed", Checks: results}, nil
}

func main() { lambda.Start(handler) }


