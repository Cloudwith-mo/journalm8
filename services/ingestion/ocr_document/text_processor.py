"""
Conservative OCR post-processing for JournalM8.
Only applies safe, auditable fixes for recurring OCR errors.
"""
import re
from typing import Dict, List


# Conservative substitutions - only obvious, recurring OCR errors
SAFE_SUBSTITUTIONS = [
    # Common symbol misreads
    (r'\b7\b', '&'),           # "7" often misread for "&"
    (r'\b\{\b', '&'),          # "{" often misread for "&"
    (r'\b\}\b', '&'),          # "}" often misread for "&"
    
    # Common contractions
    (r'\bIm\b', "I'm"),
    (r'\bIve\b', "I've"),
    (r'\bId\b', "I'd"),
    (r'\bIll\b', "I'll"),
    (r'\bdont\b', "don't"),
    (r'\bcant\b', "can't"),
    (r'\bwont\b', "won't"),
    (r'\bdidnt\b', "didn't"),
    
    # Common word-level errors (very conservative)
    (r'\bml\b', 'me'),
    (r'\bther\b', 'that'),
]


def normalize_whitespace(text: str) -> str:
    """Normalize excessive whitespace and line breaks."""
    # Replace multiple spaces with single space
    text = re.sub(r' +', ' ', text)
    # Replace more than 2 consecutive newlines with 2
    text = re.sub(r'\n{3,}', '\n\n', text)
    # Remove trailing whitespace from lines
    text = '\n'.join(line.rstrip() for line in text.split('\n'))
    return text.strip()


def apply_safe_substitutions(text: str) -> tuple[str, List[str]]:
    """
    Apply only safe, conservative substitutions.
    Returns: (corrected_text, list_of_fixes_applied)
    """
    fixes_applied = []
    corrected = text
    
    for pattern, replacement in SAFE_SUBSTITUTIONS:
        matches = re.findall(pattern, corrected, flags=re.IGNORECASE)
        if matches:
            corrected = re.sub(pattern, replacement, corrected, flags=re.IGNORECASE)
            fixes_applied.append(f"{pattern} → {replacement} ({len(matches)} times)")
    
    return corrected, fixes_applied


def calculate_review_status(confidence: float, line_count: int) -> str:
    """
    Determine if entry needs manual review.
    Conservative thresholds - mark for review if uncertain.
    """
    if confidence >= 90 and line_count > 0:
        return "READY"
    elif confidence >= 75 and line_count > 0:
        return "NEEDS_REVIEW"
    else:
        return "NEEDS_REVIEW"


def process_ocr_text(raw_text: str, confidence: float, line_count: int) -> Dict[str, any]:
    """
    Main processing pipeline:
    1. Normalize whitespace
    2. Apply safe substitutions
    3. Calculate review status
    4. Return both raw and corrected versions
    """
    # Step 1: Normalize
    normalized = normalize_whitespace(raw_text)
    
    # Step 2: Apply safe fixes
    corrected, fixes = apply_safe_substitutions(normalized)
    
    # Step 3: Determine status
    review_status = calculate_review_status(confidence, line_count)
    
    return {
        "rawText": raw_text,
        "correctedText": corrected,
        "reviewStatus": review_status,
        "fixesApplied": fixes,
        "fixCount": len(fixes),
    }
