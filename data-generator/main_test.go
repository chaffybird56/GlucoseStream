package main

import (
    "math"
    "testing"
    "time"
)

func TestCircadianBaseReasonableRange(t *testing.T) {
    // Check multiple hours in a day
    for h := 0; h < 24; h += 3 {
        ts := time.Date(2025, 10, 1, h, 0, 0, 0, time.UTC)
        v := circadianBase(ts)
        if v < 80 || v > 140 {
            t.Fatalf("circadian base out of expected range at hour %d: %.2f", h, v)
        }
    }
}

func TestCircadianBaseSmoothness(t *testing.T) {
    // Consecutive hours should not jump by more than ~40 mg/dL
    prev := circadianBase(time.Date(2025, 10, 1, 0, 0, 0, 0, time.UTC))
    for h := 1; h < 24; h++ {
        cur := circadianBase(time.Date(2025, 10, 1, h, 0, 0, 0, time.UTC))
        if math.Abs(cur-prev) > 40 {
            t.Fatalf("excessive jump between hours %d-%d: prev=%.2f cur=%.2f", h-1, h, prev, cur)
        }
        prev = cur
    }
}


