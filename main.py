import sys

def calculate_ean_checksum(digits: list[int]) -> int:
    """
    Calculate the EAN-13 checksum for the first 12 digits.
    """
    assert len(digits) == 12
    total_sum = 0
    for index, digit in enumerate(digits):
        if index % 2 == 0:
            total_sum += digit * 1
        else:
            total_sum += digit * 3
    total_sum = total_sum % 10
    if total_sum == 0:
        return 0
    return 10 - total_sum


def ean_is_valid(ean_code: str) -> bool:
    """
    An EAN value is considered valid if:
    - It follows the GTIN-13 specification
    - Or it can be padded with leading zeros 0 to a valid GTIN-13
    """
    # TODO what should I do with empty string ?
    if len(ean_code) < 13:
        ean_code = ean_code.zfill(13)
        return ean_is_valid(ean_code)
    if len(ean_code) != 13 or not ean_code.isdigit():
        return False
    assert len(ean_code) == 13

    digits = [int(d) for d in ean_code]
    checksum = digits[-1]
    calculated_checksum = calculate_ean_checksum(digits[:-1])

    return checksum == calculated_checksum


def test_ean_is_valid():
    # TODO add test with 0 padding
    valid_eans = [
        "4065418448246",
        "4065418448345",
        "00",
    ]
    for valid_ean in valid_eans:
        assert ean_is_valid(valid_ean), f"EAN {valid_ean} should be valid"

    invalid_eans = [
        # changed checksum
        "4065418448247",
        "4065418448344",
        "01",
        # too long
        "104065418448247",
    ]
    for invalid_ean in invalid_eans:
        assert not ean_is_valid(invalid_ean), f"EAN {invalid_ean} should be invalid"

def get_ean_column_index(line: str, delimiter: str, ean_column_name) -> int | None:
    ean_column_index = None
    splitted_header = line.split(delimiter)
    for index, column_name in enumerate(splitted_header):
        if column_name.strip() != ean_column_name:
            continue
        if ean_column_index is None:
            ean_column_index = index
        else:
            # multiple ean columns found -> invalid file
            return None
    if ean_column_index is not None:
        return ean_column_index
    # no ean column was found: If the header is missing, the EAN must be in the first column and the first row must start with a valid EAN → see invalid file otherwise
    assert len(splitted_header) > 0, line # empty string will give [""]
    if ean_is_valid(splitted_header[0].strip()):
        return 0
    return None

def test_get_ean_column_index():
    header_line = "name, ean, price"
    assert get_ean_column_index(header_line, delimiter=",", ean_column_name="ean") == 1

    header_line = "name, ean, ean, price"
    assert get_ean_column_index(header_line, delimiter=",", ean_column_name="ean") is None

    header_line = "name, code, price"
    assert get_ean_column_index(header_line, delimiter=",", ean_column_name="ean") is None

    header_line = "4065418448246, name, price"
    assert get_ean_column_index(header_line, delimiter=",", ean_column_name="ean") == 0

    header_line = ""
    assert get_ean_column_index(header_line, delimiter=",", ean_column_name="ean") == 0

    header_line = "4065418448247, name"
    assert get_ean_column_index(header_line, delimiter=",", ean_column_name="ean") is None

def line_is_valid(line: str, delimiter: str, ean_column_index: int) -> bool:
    columns = line.split(delimiter)
    if ean_column_index >= len(columns):
        return False
    ean_code = columns[ean_column_index].strip().replace('"', '')
    return ean_is_valid(ean_code)

def process_stdin(delimiter: str = ",", ean_column_name: str = "ean"):
    def _exit_on_invalid():
        print("0 0")
        sys.exit(0)
    
    first_line = True
    ean_column_index = None
    valid_count = 0
    invalid_count = 0
    if sys.stdin is None:
        _exit_on_invalid()
    for line in sys.stdin: # TODO handle wrong encoding
        if 'Exit' == line.rstrip():
            break
        # TODO handle Quoted fields can contain line returns (\n) and what would be considered as a field separator outside of the quoted string
        if first_line:
            ean_column_index = get_ean_column_index(line, delimiter=delimiter, ean_column_name=ean_column_name)
            if ean_column_index is None:
                _exit_on_invalid()
            first_line = False
            continue
        assert not first_line
        assert ean_column_index is not None
        if line_is_valid(line, delimiter=delimiter, ean_column_index=ean_column_index):
            valid_count += 1
        else:
            invalid_count += 1
            
    print(f"{valid_count} {invalid_count}")

if __name__ == "__main__":
    # test_ean_is_valid()
    # test_get_ean_column_index()
    # print("All tests passed.")
    process_stdin()
