# Check if a program is provided
if (($args.Count -eq 1 -and ($args[0] -eq "-h" -or $args[0] -eq "--help")) -or $args.Count -eq 0) {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [-full] '<command_to_run_program>'"
    Write-Host "Example: $($MyInvocation.MyCommand.Name) -full './program'"
    exit 1
}

# Check for the -full argument
$testFull = $false
if ($args.Count -eq 2 -and $args[0] -eq "-full") {
    $testFull = $true
    $program = $args[1]
} elseif ($args.Count -eq 1) {
    $program = $args[0]
} else {
    Write-Host "Error: Invalid arguments provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [-full] '<command_to_run_program>'"
    exit 1
}

# Define test names, test cases, and expected outputs
$testNames = @(
    "piped_input",
    "empty",
    "empty_no_newline",
    "only_header",
    "missing_header",
    "missing_ean_column",
    "too_many_fields",
    "too_few_fields",
    "all_valid",
    "with_gtin_8_and_12",
    "empty_lines",
    "leading_zeros",
    "ean_column_moved",
    "emoji",
    "missing_ean",
    "too_long_ean",
    "too_short_ean",
    "with_garbage",
    "wrong_checksum",
    "quoted_fields",
    "misquoted_fields",
    "mixed_5k"
)

$testCases = @(
    "echo 'ean' | $program",
    "echo '' | $program",
    "Write-Output '' | $program",
    "echo 'ean,price,quantity,brand,color' | $program",
    "Get-Content tests/missing_header.csv | $program",
    "Get-Content tests/missing_ean_column.csv | $program",
    "Get-Content tests/too_many_fields.csv | $program",
    "Get-Content tests/too_few_fields.csv | $program",
    "Get-Content tests/all_valid.csv | $program",
    "Get-Content tests/with_gtin_8_and_12.csv | $program",
    "Get-Content tests/empty_lines.csv | $program",
    "Get-Content tests/leading_zeros.csv | $program",
    "Get-Content tests/ean_column_moved.csv | $program",
    "Get-Content tests/emoji.csv | $program",
    "Get-Content tests/missing_ean.csv | $program",
    "Get-Content tests/too_long_ean.csv | $program",
    "Get-Content tests/too_short_ean.csv | $program",
    "Get-Content tests/with_garbage.csv | $program",
    "Get-Content tests/wrong_checksum.csv | $program",
    "Get-Content tests/quoted_fields.csv | $program",
    "Get-Content tests/misquoted_fields.csv | $program",
    "(Invoke-WebRequest -URI https://stockly-public-assets.s3.eu-west-1.amazonaws.com/peer-programming-mixed.csv).Content | $program"
)

$expectedOutputs = @(
    "0 0",
    "0 0",
    "0 0",
    "0 0",
    "10 0",
    "0 0",
    "10 0",
    "10 0",
    "10 0",
    "10 0",
    "10 0",
    "10 0",
    "10 0",
    "10 0",
    "9 1",
    "9 1",
    "9 1",
    "6 4",
    "8 2",
    "10 0",
    "5 1",
    "4975 18"
)

if ($testFull) {
    $testNames += "17GiB"
    $testCases += "curl.exe https://stockly-public-assets.s3.eu-west-1.amazonaws.com/peer-programming-big.csv | $program"
    $expectedOutputs += "185784746 960294"
}

# Validate array lengths
if (($testNames.Count -ne $testCases.Count) -or ($testCases.Count -ne $expectedOutputs.Count)) {
    Write-Host "Error: Array lengths do not match"
    exit 1
}

$nbTests = $testCases.Count
$nbSuccess = 0
$nbFailure = 0

Write-Host "Running tests on program: $program"

for ($i = 0; $i -lt $testCases.Count; $i++) {
    $testName = $testNames[$i]
    $testCmd = $testCases[$i]
    $expected = $expectedOutputs[$i]

    Write-Host "Running test: [$testName]"

    try {
        $actualOutput = Invoke-Expression $testCmd | Out-String
        $actualOutput = $actualOutput.Trim()
    }
    catch {
        $actualOutput = ""
    }

    if ($actualOutput -eq $expected) {
        Write-Host "PASSED ✅" -ForegroundColor Green
        $nbSuccess++
    } else {
        Write-Host "FAILED ❌" -ForegroundColor Red
        Write-Host "  Expected: '$expected'"
        Write-Host "  Got:      '$actualOutput'"
        $nbFailure++
    }
}

# Summary
Write-Host "Summary:"
Write-Host "  Total tests: $nbTests"
Write-Host "  Passed: $nbSuccess"
Write-Host "  Failed: $nbFailure"
