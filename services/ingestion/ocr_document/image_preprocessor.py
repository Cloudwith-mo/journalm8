"""
Image preprocessing for improved OCR quality.
Conservative enhancements only - don't distort the original.
"""
import io
from typing import BinaryIO
from PIL import Image, ImageEnhance, ImageOps


def preprocess_image(image_bytes: bytes) -> bytes:
    """
    Apply conservative preprocessing to improve OCR:
    1. Convert to grayscale
    2. Auto-contrast enhancement
    3. Slight sharpening
    
    Returns: preprocessed image as bytes
    """
    try:
        # Load image
        img = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if needed (handle RGBA, etc.)
        if img.mode not in ('RGB', 'L'):
            img = img.convert('RGB')
        
        # Convert to grayscale for better OCR
        img = ImageOps.grayscale(img)
        
        # Auto-contrast to improve text visibility
        img = ImageOps.autocontrast(img, cutoff=2)
        
        # Slight sharpening
        enhancer = ImageEnhance.Sharpness(img)
        img = enhancer.enhance(1.2)
        
        # Save to bytes
        output = io.BytesIO()
        img.save(output, format='JPEG', quality=95)
        return output.getvalue()
        
    except Exception as e:
        # If preprocessing fails, return original
        print(f"Image preprocessing failed: {e}. Using original image.")
        return image_bytes


def should_preprocess(content_type: str) -> bool:
    """Determine if image should be preprocessed."""
    # Only preprocess JPEG and PNG images
    return content_type in ['image/jpeg', 'image/png']
