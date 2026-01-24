#!/bin/bash

# GlucoseStream Quick Demo Script
# Generates sample data and demonstrates the system

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🩺 GlucoseStream Quick Demo"
echo "=========================="
echo

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v go &> /dev/null; then
    echo "⚠️  Go is not installed. Install from https://go.dev/dl/"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "⚠️  Python 3 is not installed"
    exit 1
fi

echo -e "${GREEN}✓${NC} Prerequisites met"
echo

# Step 1: Generate sample data
echo "Step 1: Generating sample glucose data..."
echo "------------------------------------------"

cd "$(dirname "$0")/.."

# Generate 1 day of data for patient p1
echo "Generating 24 hours of glucose readings for patient 'p1'..."
cd data-generator
go run . -patient p1 -minutes 1440 -out ../data/sample/demo_events.jsonl

if [ -f ../data/sample/demo_events.jsonl ]; then
    line_count=$(wc -l < ../data/sample/demo_events.jsonl)
    echo -e "${GREEN}✓${NC} Generated $line_count glucose events"
    echo "   File: data/sample/demo_events.jsonl"
else
    echo "✗ Failed to generate data"
    exit 1
fi

echo

# Step 2: Show sample data
echo "Step 2: Sample Data Preview"
echo "---------------------------"
echo "First 3 events:"
head -n 3 ../data/sample/demo_events.jsonl | while read line; do
    echo "$line" | python3 -m json.tool 2>/dev/null || echo "$line"
done
echo

# Step 3: Flask Dashboard Demo
echo "Step 3: Flask Dashboard Demo"
echo "------------------------------"
echo "To view the dashboard:"
echo "  1. Set up AWS credentials (if using AWS backend)"
echo "  2. Or use local mode (modify app.py for local data)"
echo
echo "Start the dashboard:"
echo -e "  ${BLUE}cd flask-dashboard${NC}"
echo -e "  ${BLUE}python3 -m venv .venv${NC}"
echo -e "  ${BLUE}source .venv/bin/activate${NC}"
echo -e "  ${BLUE}pip install -r requirements.txt${NC}"
echo -e "  ${BLUE}FLASK_APP=app.py flask run${NC}"
echo
echo "Then visit: http://localhost:5000"
echo "Enter patient ID: p1"
echo

# Step 4: Data Statistics
echo "Step 4: Data Statistics"
echo "------------------------"
cd ../data-generator
echo "Analyzing generated data..."
python3 << 'EOF'
import json
import sys

events = []
with open('../data/sample/demo_events.jsonl', 'r') as f:
    for line in f:
        events.append(json.loads(line))

if events:
    glucose_values = [e['mg_dL'] for e in events]
    print(f"Total events: {len(events)}")
    print(f"Glucose range: {min(glucose_values):.1f} - {max(glucose_values):.1f} mg/dL")
    print(f"Average glucose: {sum(glucose_values)/len(glucose_values):.1f} mg/dL")
    
    # Time in range (70-180 mg/dL)
    in_range = sum(1 for g in glucose_values if 70 <= g <= 180)
    tir = (in_range / len(glucose_values)) * 100
    print(f"Time in Range (70-180): {tir:.1f}%")
    
    # Show first and last timestamps
    print(f"First reading: {events[0]['event_time']}")
    print(f"Last reading: {events[-1]['event_time']}")
else:
    print("No events found")
    sys.exit(1)
EOF

echo
echo "=========================="
echo -e "${GREEN}✓${NC} Quick demo completed!"
echo
echo "Next steps:"
echo "  1. Review the generated data in data/sample/demo_events.jsonl"
echo "  2. Set up AWS infrastructure (see README.md)"
echo "  3. Ingest data using the Lambda function"
echo "  4. Run transformations via Step Functions"
echo "  5. View results in the Flask dashboard or QuickSight"
echo
