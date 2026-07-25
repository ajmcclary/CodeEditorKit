#!/bin/bash
# Script to run tests with smart parallelization

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Running CodeEditorKit Tests with Smart Parallelization${NC}"
echo "================================================"

# Function to run tests and capture timing
run_tests() {
    local description=$1

    echo -e "\n${YELLOW}$description${NC}"

    # Record start time
    start_time=$(date +%s)

    if [[ -n "${NUM_WORKERS:-}" ]]; then
        swift test --parallel --num-workers "$NUM_WORKERS"
    else
        swift test --parallel
    fi

    # Record end time
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo -e "${GREEN}Completed in ${duration} seconds${NC}"
}

echo "Using swift test with parallel execution..."
run_tests "Running all tests in parallel"

echo -e "\n${GREEN}All tests completed!${NC}"

# Generate performance report if requested
if [ "$GENERATE_REPORT" = "1" ]; then
    echo -e "\n${YELLOW}Generating performance report...${NC}"
    swift test --filter PerformanceRegressionTests 2>&1 | tee performance-report.txt
fi
