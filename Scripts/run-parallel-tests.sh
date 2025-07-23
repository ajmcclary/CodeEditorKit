#!/bin/bash
# Script to run tests with smart parallelization

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Running CodeEditorPlugin Tests with Smart Parallelization${NC}"
echo "================================================"

# Function to run tests and capture timing
run_tests() {
    local testplan=$1
    local description=$2
    
    echo -e "\n${YELLOW}$description${NC}"
    
    # Record start time
    start_time=$(date +%s)
    
    # Run tests
    if [ "$USE_XCODEBUILD" = "1" ]; then
        xcodebuild test \
            -scheme CodeEditorPlugin \
            -testPlan "$testplan" \
            -destination 'platform=macOS' \
            -parallel-testing-enabled YES \
            -maximum-concurrent-test-device-destinations 4 \
            -quiet | xcpretty
    else
        swift test \
            --parallel \
            --num-workers auto
    fi
    
    # Record end time
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo -e "${GREEN}Completed in ${duration} seconds${NC}"
}

# Check if we should use xcodebuild or swift test
if [ -f "CodeEditorPlugin-SmartParallel.xctestplan" ]; then
    echo "Using smart parallel test plan..."
    USE_XCODEBUILD=1
    run_tests "CodeEditorPlugin-SmartParallel" "Running tests with smart parallelization"
else
    echo "Using swift test with parallel execution..."
    USE_XCODEBUILD=0
    run_tests "" "Running all tests in parallel"
fi

echo -e "\n${GREEN}All tests completed!${NC}"

# Generate performance report if requested
if [ "$GENERATE_REPORT" = "1" ]; then
    echo -e "\n${YELLOW}Generating performance report...${NC}"
    swift test --filter PerformanceRegressionTests 2>&1 | tee performance-report.txt
fi