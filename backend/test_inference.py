#!/usr/bin/env python3
"""
Quick test script to verify the ML inference pipeline is working.
Run from backend directory: python test_inference.py
"""
import os
import sys
import requests
from pathlib import Path

# Test the health endpoint
print("\n" + "="*60)
print("Testing Health Endpoint")
print("="*60)

try:
    response = requests.get("http://localhost:8000/api/detections/health/", timeout=5)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"\n✓ Server is reachable")
        print(f"✓ Model ready: {data.get('model_ready', False)}")
        print(f"✓ Model: {data.get('model', 'Unknown')}")
    else:
        print(f"\n✗ Unexpected status code: {response.status_code}")
except Exception as e:
    print(f"\n✗ Error connecting to server: {e}")
    sys.exit(1)

# Test the detection endpoint with a dummy image
print("\n" + "="*60)
print("Testing Detection Endpoint")
print("="*60)

# Create a minimal test image (224x224 RGB with green channel emphasis for plant detection)
try:
    from PIL import Image
    import numpy as np
    
    # Create a simple test image with green emphasis
    test_image = np.zeros((224, 224, 3), dtype=np.uint8)
    test_image[:, :, 1] = 150  # Green channel
    test_image[:, :, 0] = 100  # Red channel
    test_image[:, :, 2] = 100  # Blue channel
    
    img = Image.fromarray(test_image)
    test_image_path = Path(__file__).parent / "test_image.jpg"
    img.save(str(test_image_path))
    print(f"Created test image: {test_image_path}")
    
    # Send detection request
    with open(str(test_image_path), 'rb') as f:
        files = {'image': f}
        response = requests.post(
            "http://localhost:8000/api/detections/",
            files=files,
            timeout=30
        )
    
    print(f"\nStatus: {response.status_code}")
    if response.status_code == 200:
        result = response.json()
        print(f"\n✓ Detection successful!")
        print(f"  - Disease ID: {result.get('disease_id')}")
        print(f"  - Disease: {result.get('disease_name')}")
        print(f"  - Confidence: {result.get('confidence', 0)*100:.1f}%")
        print(f"  - Is Plant: {result.get('is_plant')}")
        
        # Check confidence is not 0%
        confidence = result.get('confidence', 0)
        if confidence > 0.1:
            print(f"\n✓ Confidence is properly scaled (not 0%)!")
        else:
            print(f"\n✗ WARNING: Confidence is too low ({confidence*100:.1f}%)")
    else:
        print(f"✗ Error: {response.status_code}")
        print(f"Response: {response.text}")
    
    # Clean up
    test_image_path.unlink()
    
except Exception as e:
    print(f"\n✗ Error during detection test: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\n" + "="*60)
print("All tests completed!")
print("="*60 + "\n")
