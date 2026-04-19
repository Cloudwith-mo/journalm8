#!/bin/bash

# OCR Quality Assessment Script
# Compares extracted OCR text against expected content from journal images

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "  OCR QUALITY ASSESSMENT"
echo "=========================================="
echo ""

# Expected key phrases from each image
declare -A EXPECTED_PHRASES_190=(
    ["phrase1"]="Fear, doubt, & insecurity"
    ["phrase2"]="Told my mom how excited"
    ["phrase3"]="upcoming interview"
    ["phrase4"]="over-prepared"
    ["phrase5"]="NOTHING - absolutely nothing"
)

declare -A EXPECTED_PHRASES_191=(
    ["phrase1"]="The heart is a vessel"
    ["phrase2"]="Must be emptied before it can be filled"
    ["phrase3"]="improve my life"
    ["phrase4"]="releasing & letting go"
    ["phrase5"]="social media"
)

declare -A EXPECTED_PHRASES_200=(
    ["phrase1"]="bigger challenge"
    ["phrase2"]="stable income"
    ["phrase3"]="Everything in this life is a sign"
    ["phrase4"]="dunya is a hologram"
    ["phrase5"]="Cloud Engineering"
)

check_ocr_quality() {
    local file=$1
    local image_name=$2
    shift 2
    local -n phrases=$1
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ File not found: $file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Checking: $image_name${NC}"
    echo "File: $file"
    echo ""
    
    local content=$(cat "$file")
    local total_phrases=${#phrases[@]}
    local found_phrases=0
    
    for key in "${!phrases[@]}"; do
        local phrase="${phrases[$key]}"
        # Case-insensitive partial match
        if echo "$content" | grep -qi "${phrase:0:15}"; then
            echo -e "${GREEN}✓${NC} Found: \"$phrase\""
            found_phrases=$((found_phrases + 1))
        else
            echo -e "${RED}✗${NC} Missing: \"$phrase\""
        fi
    done
    
    echo ""
    local accuracy=$((found_phrases * 100 / total_phrases))
    echo "Phrase Match Rate: $found_phrases/$total_phrases ($accuracy%)"
    
    # Character and line counts
    local char_count=$(echo "$content" | wc -c | tr -d ' ')
    local line_count=$(echo "$content" | wc -l | tr -d ' ')
    local word_count=$(echo "$content" | wc -w | tr -d ' ')
    
    echo "Character Count: $char_count"
    echo "Line Count: $line_count"
    echo "Word Count: $word_count"
    echo ""
    
    if [ $accuracy -ge 80 ]; then
        echo -e "${GREEN}✓ PASS: OCR quality is acceptable ($accuracy% phrase match)${NC}"
    elif [ $accuracy -ge 60 ]; then
        echo -e "${YELLOW}⚠ WARNING: OCR quality is marginal ($accuracy% phrase match)${NC}"
    else
        echo -e "${RED}✗ FAIL: OCR quality is poor ($accuracy% phrase match)${NC}"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
    
    return 0
}

# Check each OCR output file
check_ocr_quality "ocr_output_IMG_0190_small2.jpg.txt" "IMG_0190_small2.jpg" EXPECTED_PHRASES_190
check_ocr_quality "ocr_output_IMG_0191_small2.jpg.txt" "IMG_0191_small2.jpg" EXPECTED_PHRASES_191
check_ocr_quality "ocr_output_IMG_0200_small2.jpg.txt" "IMG_0200_small2.jpg" EXPECTED_PHRASES_200

echo "=========================================="
echo "  ASSESSMENT COMPLETE"
echo "=========================================="
echo ""
echo "Manual Review Required:"
echo "1. Read each OCR output file"
echo "2. Compare against actual journal images"
echo "3. Assess overall readability and coherence"
echo "4. Verify handwriting recognition quality"
echo "5. Check for any major missing sections"
echo ""
echo "Final Decision:"
echo "  - If text is readable and >85% accurate: GO"
echo "  - If text is poor or <85% accurate: NO-GO"
