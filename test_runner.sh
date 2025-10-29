#!/usr/bin/env bash
set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Unicode symbols
CHECK_MARK="✅"
CROSS_MARK="❌"
ROCKET="🚀"
GEAR="⚙️"

usage() {
    echo -e "${BOLD}${CYAN}Test Runner for EAN Validation Program${NC}"
    echo -e "${DIM}────────────────────────────────────────${NC}"
    echo -e "${BOLD}Usage:${NC} $0 [--full] '<command_to_run_program>'"
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  $0 'python main.py'"
    echo -e "  $0 --full './my_program'"
    echo -e "  $0 'cargo run'"
    echo ""
    echo -e "${BOLD}Options:${NC}"
    echo -e "  --full    Run all tests including the large 17GiB dataset"
    echo -e "  --help    Show this help message"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}${BOLD}Error:${NC} Missing required dependencies: ${missing_deps[*]}"
        echo -e "${DIM}Please install them using your package manager, e.g.:${NC}"
        echo -e "${DIM}  Ubuntu/Debian: sudo apt install ${missing_deps[*]}${NC}"
        echo -e "${DIM}  macOS: brew install ${missing_deps[*]}${NC}"
        exit 1
    fi
}

# Check if a program is provided
if [[ $# -gt 0 && ("$1" == "--help" || "$1" == "-h") ]]; then
    usage
    exit 0
fi

# Check dependencies first
check_dependencies


if [ $# -eq 2 ] && [ "$1" == "--full" ]; then
    TEST_FULL=true
    shift
else
    TEST_FULL=false
fi

if [[ $# -eq 0 || ($# -eq 1 && "$1" == "--full")]]; then
    echo -e "${RED}${BOLD}Error:${NC} No command provided."
    echo ""
    usage
    exit 1
fi

# Validate that the program command is not empty
if [[ -z "$1" ]]; then
    echo -e "${RED}${BOLD}Error:${NC} Command cannot be empty."
    echo ""
    usage
    exit 1
fi

# Program or command to run (e.g., "./program")
PROGRAM="$1"

# Define test names, test cases, and expected outputs
declare -a TEST_NAMES=(
    "closed_stdin"
    "piped_input"
    "empty"
    "empty_no_newline"
    "only_header"
    "random"
    "missing_header"
    "missing_ean_column"
    "too_many_fields"
    "too_few_fields"
    "all_valid"
    "with_gtin_8_and_12"
    "empty_lines"
    "leading_zeros"
    "ean_column_moved"
    "emoji"
    "missing_ean"
    "too_long_ean"
    "too_short_ean"
    "with_garbage"
    "wrong_checksum"
    "quoted_fields"
    "misquoted_fields"
    "mixed_5k"
)

declare -a TEST_CASES=(
    "$PROGRAM <&-"
    "echo 'ean' | $PROGRAM"
    "echo '' | $PROGRAM"
    "echo -n '' | $PROGRAM"
    "echo 'ean,price,quantity,brand,color' | $PROGRAM"
    "cat /dev/urandom | head -c 1000 | $PROGRAM"
    "cat tests/missing_header.csv | $PROGRAM"
    "cat tests/missing_ean_column.csv | $PROGRAM"
    "cat tests/too_many_fields.csv | $PROGRAM"
    "cat tests/too_few_fields.csv | $PROGRAM"
    "cat tests/all_valid.csv | $PROGRAM"
    "cat tests/with_gtin_8_and_12.csv | $PROGRAM"
    "cat tests/empty_lines.csv | $PROGRAM"
    "cat tests/leading_zeros.csv | $PROGRAM"
    "cat tests/ean_column_moved.csv | $PROGRAM"
    "cat tests/emoji.csv | $PROGRAM"
    "cat tests/missing_ean.csv | $PROGRAM"
    "cat tests/too_long_ean.csv | $PROGRAM"
    "cat tests/too_short_ean.csv | $PROGRAM"
    "cat tests/with_garbage.csv | $PROGRAM"
    "cat tests/wrong_checksum.csv | $PROGRAM"
    "cat tests/quoted_fields.csv | $PROGRAM"
    "cat tests/misquoted_fields.csv | $PROGRAM"
    "curl https://stockly-public-assets.s3.eu-west-1.amazonaws.com/peer-programming-mixed.csv | $PROGRAM"
)

declare -a EXPECTED_OUTPUTS=(
    "0 0"
    "0 0"
    "0 0"
    "0 0"
    "0 0"
    "0 0"
    "10 0"
    "0 0"
    "10 0"
    "10 0"
    "10 0"
    "10 0"
    "10 0"
    "10 0"
    "10 0"
    "10 0"
    "9 1"
    "9 1"
    "9 1"
    "6 4"
    "8 2"
    "10 0"
    "5 1"
    "4976 17"
)

if [ "$TEST_FULL" = true ]; then
    TEST_NAMES+=("17GiB")
    TEST_CASES+=("curl https://stockly-public-assets.s3.eu-west-1.amazonaws.com/peer-programming-big.csv | $PROGRAM")
    EXPECTED_OUTPUTS+=("185794877 950163")
fi

# Check array lengths
if [ ${#TEST_NAMES[@]} -ne ${#TEST_CASES[@]} ] || [ ${#TEST_CASES[@]} -ne ${#EXPECTED_OUTPUTS[@]} ]; then
    echo -e "${RED}${BOLD}Internal Error:${NC} Test configuration mismatch"
    echo -e "${DIM}  Test names: ${#TEST_NAMES[@]}, Test cases: ${#TEST_CASES[@]}, Expected outputs: ${#EXPECTED_OUTPUTS[@]}${NC}"
    exit 1
fi

# Check if we're running on Linux for timing features
IS_LINUX=false
if [[ "$(uname)" == "Linux" ]]; then
    IS_LINUX=true
fi

# Function to format time elapsed (in milliseconds)
format_time() {
    local milliseconds=$1
    local seconds=$((milliseconds / 1000))
    local ms=$((milliseconds % 1000))
    
    if [ $seconds -lt 60 ]; then
        if [ $seconds -eq 0 ]; then
            printf "%dms" "$ms"
        else
            printf "%d.%03ds" "$seconds" "$ms"
        fi
    elif [ $seconds -lt 3600 ]; then
        printf "%dm %ds" $((seconds / 60)) $((seconds % 60))
    else
        printf "%dh %dm %ds" $((seconds / 3600)) $(((seconds % 3600) / 60)) $((seconds % 60))
    fi
}

# Temporary file for storing program output
TMP_OUT=$(mktemp)
TMP_ERR=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$TMP_OUT" "$TMP_ERR"
}
trap cleanup EXIT

NB_TESTS=${#TEST_CASES[@]}
NB_SUCCESS=0
NB_FAILURE=0

# Initialize timing only on Linux
if [ "$IS_LINUX" = true ]; then
    START_TIME=$(date +%s%3N)  # milliseconds since epoch
fi

# Header
echo -e "${BOLD}${CYAN}${ROCKET} Starting Test Suite${NC}"
echo -e "${DIM}────────────────────────────────────────${NC}"
echo -e "${BOLD}Program:${NC} $PROGRAM"
echo -e "${BOLD}Total tests:${NC} $NB_TESTS"
if [ "$TEST_FULL" = true ]; then
    echo -e "${YELLOW}${BOLD}Warning:${NC} Running in full mode - this includes a 17GiB dataset and may take considerable time"
fi
echo ""

# Run each test case
for i in "${!TEST_CASES[@]}"; do
    TEST_NAME="${TEST_NAMES[$i]}"
    TEST_CMD="${TEST_CASES[$i]}"
    EXPECTED="${EXPECTED_OUTPUTS[$i]}"
    
    echo ""
    
    # Test header with timing
    echo -e "${BOLD}${BLUE}[$((i + 1))/$NB_TESTS]${NC} ${BOLD}$TEST_NAME${NC}"
    
    # Show command being run (truncated if too long)
    if [[ ${#TEST_CMD} -gt 80 ]]; then
        echo -e "${DIM}  Command: ${TEST_CMD:0:77}...${NC}"
    else
        echo -e "${DIM}  Command: $TEST_CMD${NC}"
    fi
    
    # Time the test execution (Linux only)
    if [ "$IS_LINUX" = true ]; then
        TEST_START=$(date +%s%3N)  # milliseconds since epoch
    fi
    
    # Execute the command with better error handling
    if bash -c "$TEST_CMD" > "$TMP_OUT" 2> "$TMP_ERR"; then
        ACTUAL_OUTPUT=$(cat "$TMP_OUT")
        ERROR_OUTPUT=$(cat "$TMP_ERR")
        
        # Calculate test duration (Linux only)
        if [ "$IS_LINUX" = true ]; then
            TEST_END=$(date +%s%3N)
            TEST_DURATION=$((TEST_END - TEST_START))
            TIMING_INFO=" ${DIM}($(format_time $TEST_DURATION))${NC}"
        else
            TIMING_INFO=""
        fi
        
        # Compare actual output with expected output
        if [[ "$ACTUAL_OUTPUT" == "$EXPECTED" ]]; then
            echo -e "  ${GREEN}${BOLD}${CHECK_MARK} PASSED${NC}${TIMING_INFO}"
            NB_SUCCESS=$((NB_SUCCESS+1))
        else
            echo -e "  ${RED}${BOLD}${CROSS_MARK} FAILED${NC}${TIMING_INFO}"
            echo -e "    ${BOLD}Expected:${NC} '${GREEN}$EXPECTED${NC}'"
            echo -e "    ${BOLD}Got:${NC}      '${RED}$ACTUAL_OUTPUT${NC}'"
            if [[ -n "$ERROR_OUTPUT" ]]; then
                echo -e "    ${BOLD}Stderr:${NC}   ${YELLOW}$ERROR_OUTPUT${NC}"
            fi
            NB_FAILURE=$((NB_FAILURE+1))
        fi
    else
        # Capture exit code before any other commands
        EXIT_CODE=$?
        
        # Calculate test duration (Linux only)
        if [ "$IS_LINUX" = true ]; then
            TEST_END=$(date +%s%3N)
            TEST_DURATION=$((TEST_END - TEST_START))
            TIMING_INFO=" ${DIM}($(format_time $TEST_DURATION))${NC}"
        else
            TIMING_INFO=""
        fi
        
        ERROR_OUTPUT=$(cat "$TMP_ERR")
        echo -e "  ${RED}${BOLD}${CROSS_MARK} CRASHED${NC}${TIMING_INFO}"
        echo -e "    ${BOLD}Exit code:${NC} $EXIT_CODE"
        if [[ -n "$ERROR_OUTPUT" ]]; then
            echo -e "    ${BOLD}Error:${NC}     ${RED}$ERROR_OUTPUT${NC}"
        fi
        NB_FAILURE=$((NB_FAILURE+1))
    fi
done

echo ""

# Calculate total duration (Linux only)
if [ "$IS_LINUX" = true ]; then
    END_TIME=$(date +%s%3N)
    TOTAL_DURATION=$((END_TIME - START_TIME))
fi

# Print summary with enhanced formatting
echo ""
echo -e "${BOLD}${CYAN}${GEAR} Test Results Summary${NC}"
echo -e "${DIM}────────────────────────────────────────${NC}"

if [ $NB_FAILURE -eq 0 ]; then
    echo -e "${GREEN}${BOLD}${CHECK_MARK} All tests passed!${NC}"
else
    echo -e "${RED}${BOLD}${CROSS_MARK} Some tests failed${NC}"
fi

echo -e "${BOLD}Total tests:${NC}   $NB_TESTS"
echo -e "${BOLD}Passed:${NC}       ${GREEN}$NB_SUCCESS${NC}"
echo -e "${BOLD}Failed:${NC}       ${RED}$NB_FAILURE${NC}"
echo -e "${BOLD}Success rate:${NC}  $(( NB_SUCCESS * 100 / NB_TESTS ))%"

# Show total time only on Linux
if [ "$IS_LINUX" = true ]; then
    echo -e "${BOLD}Total time:${NC}   $(format_time $TOTAL_DURATION)"
fi

# Exit with appropriate code
if [ $NB_FAILURE -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}${ROCKET} All tests completed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}${BOLD}${CROSS_MARK} Tests completed with failures${NC}"
    exit 1
fi
