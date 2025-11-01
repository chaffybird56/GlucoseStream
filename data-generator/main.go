package main

import (
    "bufio"
    "encoding/json"
    "flag"
    "fmt"
    "math"
    "math/rand"
    "os"
    "time"

    "github.com/google/uuid"
)

type GlucoseEvent struct {
    EventID   string  `json:"event_id"`
    PatientID string  `json:"patient_id"`
    SessionID string  `json:"session_id"`
    EventTime string  `json:"event_time"`
    MgDL      float64 `json:"mg_dL"`
    Source    string  `json:"source"`
}

func circadianBase(t time.Time) float64 {
    // Model: base glucose varies by hour with mild sinusoidal pattern
    hour := float64(t.Hour())
    return 110 + 15*math.Sin((hour/24.0)*2*math.Pi)
}

func main() {
    var (
        patient = flag.String("patient", "p1", "hashed patient id")
        minutes = flag.Int("minutes", 1440, "number of minutes to simulate")
        jitter  = flag.Float64("jitter", 12.0, "random jitter stddev")
        outPath = flag.String("out", "", "output file (default stdout)")
    )
    flag.Parse()

    rand.Seed(time.Now().UnixNano())
    sessionID := uuid.NewString()
    start := time.Now().UTC().Add(-time.Duration(*minutes) * time.Minute)

    var w *bufio.Writer
    if *outPath == "" {
        w = bufio.NewWriter(os.Stdout)
    } else {
        f, err := os.Create(*outPath)
        if err != nil { panic(err) }
        defer f.Close()
        w = bufio.NewWriter(f)
    }
    enc := json.NewEncoder(w)

    for i := 0; i < *minutes; i++ {
        ts := start.Add(time.Duration(i) * time.Minute)
        base := circadianBase(ts)
        noise := rand.NormFloat64() * *jitter
        mg := math.Max(40, math.Min(350, base+noise))
        ev := GlucoseEvent{
            EventID:   uuid.NewString(),
            PatientID: *patient,
            SessionID: sessionID,
            EventTime: ts.Format(time.RFC3339),
            MgDL:      math.Round(mg*10) / 10,
            Source:    "sensor",
        }
        if err := enc.Encode(ev); err != nil { panic(err) }
    }
    w.Flush()
    fmt.Fprintf(os.Stderr, "generated %d minutes for patient %s\n", *minutes, *patient)
}


