#!/usr/bin/env python3
"""
SnapChallan AI Processing Service

This service handles:
1. License plate recognition using YOLO and OCR
2. Traffic violation detection
3. Vehicle type classification
4. Image quality assessment
"""

import asyncio
import logging
import os
import cv2
import numpy as np
import redis
import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict

import torch
from ultralytics import YOLO
import easyocr
from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Configuration
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
MODEL_PATH = os.getenv('MODEL_PATH', './models/yolov8n.pt')
CONFIDENCE_THRESHOLD = float(os.getenv('CONFIDENCE_THRESHOLD', '0.7'))
MEDIA_DIR = Path(os.getenv('MEDIA_DIR', './media'))

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Data classes
@dataclass
class DetectionResult:
    class_name: str
    confidence: float
    bbox: List[float]  # [x1, y1, x2, y2]

@dataclass
class LicensePlateResult:
    text: str
    confidence: float
    bbox: List[float]
    
@dataclass
class AIAnalysisResult:
    license_plates: List[LicensePlateResult]
    vehicles: List[DetectionResult]
    persons: List[DetectionResult]
    traffic_signs: List[DetectionResult]
    violations_detected: List[str]
    image_quality_score: float
    processing_time: float
    timestamp: str

class AIProcessor:
    def __init__(self):
        """Initialize AI models and services"""
        self.device = 'cuda' if torch.cuda.is_available() else 'cpu'
        logger.info(f"Using device: {self.device}")
        
        # Load YOLO model
        try:
            self.yolo_model = YOLO(MODEL_PATH)
            self.yolo_model.to(self.device)
            logger.info("YOLO model loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load YOLO model: {e}")
            raise
        
        # Initialize OCR reader
        try:
            self.ocr_reader = easyocr.Reader(['en'], gpu=torch.cuda.is_available())
            logger.info("OCR reader initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize OCR reader: {e}")
            raise
        
        # Redis connection
        try:
            self.redis_client = redis.from_url(REDIS_URL)
            self.redis_client.ping()
            logger.info("Redis connection established")
        except Exception as e:
            logger.error(f"Failed to connect to Redis: {e}")
            raise
        
        # Class mappings for Indian traffic scenarios
        self.vehicle_classes = {
            'car', 'truck', 'bus', 'motorcycle', 'bicycle', 
            'auto-rickshaw', 'van', 'suv', 'taxi'
        }
        
        self.traffic_sign_classes = {
            'stop sign', 'traffic light', 'speed limit', 'no entry',
            'one way', 'parking', 'pedestrian crossing'
        }
        
        # Violation patterns
        self.violation_patterns = {
            'wrong_way': self.detect_wrong_way_driving,
            'helmet_violation': self.detect_helmet_violation,
            'triple_riding': self.detect_triple_riding,
            'mobile_usage': self.detect_mobile_usage,
            'seatbelt_violation': self.detect_seatbelt_violation,
            'signal_jump': self.detect_signal_jump,
            'speeding': self.detect_speeding,
            'wrong_parking': self.detect_wrong_parking
        }

    async def process_image(self, image_path: str) -> AIAnalysisResult:
        """Process image for traffic violations and license plates"""
        start_time = datetime.now()
        
        try:
            # Load and validate image
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not load image: {image_path}")
            
            # Calculate image quality score
            quality_score = self.calculate_image_quality(image)
            
            # YOLO detection
            yolo_results = self.yolo_model(image, conf=CONFIDENCE_THRESHOLD)
            
            # Extract detections
            vehicles = []
            persons = []
            traffic_signs = []
            
            for result in yolo_results:
                boxes = result.boxes
                if boxes is not None:
                    for box in boxes:
                        class_id = int(box.cls[0])
                        class_name = self.yolo_model.names[class_id]
                        confidence = float(box.conf[0])
                        bbox = box.xyxy[0].tolist()
                        
                        detection = DetectionResult(class_name, confidence, bbox)
                        
                        if class_name in self.vehicle_classes:
                            vehicles.append(detection)
                        elif class_name == 'person':
                            persons.append(detection)
                        elif class_name in self.traffic_sign_classes:
                            traffic_signs.append(detection)
            
            # License plate detection and OCR
            license_plates = await self.detect_license_plates(image, vehicles)
            
            # Violation detection
            violations_detected = await self.detect_violations(
                image, vehicles, persons, traffic_signs
            )
            
            processing_time = (datetime.now() - start_time).total_seconds()
            
            result = AIAnalysisResult(
                license_plates=license_plates,
                vehicles=vehicles,
                persons=persons,
                traffic_signs=traffic_signs,
                violations_detected=violations_detected,
                image_quality_score=quality_score,
                processing_time=processing_time,
                timestamp=datetime.now().isoformat()
            )
            
            logger.info(f"Image processed in {processing_time:.2f}s")
            return result
            
        except Exception as e:
            logger.error(f"Error processing image {image_path}: {e}")
            raise
    
    async def detect_license_plates(self, image: np.ndarray, vehicles: List[DetectionResult]) -> List[LicensePlateResult]:
        """Detect and read license plates from vehicles"""
        license_plates = []
        
        for vehicle in vehicles:
            try:
                # Extract vehicle region
                x1, y1, x2, y2 = [int(coord) for coord in vehicle.bbox]
                vehicle_region = image[y1:y2, x1:x2]
                
                # Enhance image for better OCR
                enhanced = self.enhance_for_ocr(vehicle_region)
                
                # OCR detection
                ocr_results = self.ocr_reader.readtext(enhanced)
                
                for (bbox, text, confidence) in ocr_results:
                    # Filter for license plate patterns
                    if self.is_license_plate_text(text) and confidence > 0.5:
                        # Convert relative bbox to absolute coordinates
                        abs_bbox = self.relative_to_absolute_bbox(bbox, x1, y1)
                        
                        license_plate = LicensePlateResult(
                            text=self.clean_license_plate_text(text),
                            confidence=confidence,
                            bbox=abs_bbox
                        )
                        license_plates.append(license_plate)
                        
            except Exception as e:
                logger.warning(f"Error detecting license plate in vehicle: {e}")
                continue
        
        return license_plates
    
    def enhance_for_ocr(self, image: np.ndarray) -> np.ndarray:
        """Enhance image quality for better OCR results"""
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Apply CLAHE (Contrast Limited Adaptive Histogram Equalization)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        enhanced = clahe.apply(gray)
        
        # Denoise
        denoised = cv2.medianBlur(enhanced, 3)
        
        # Sharpen
        kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
        sharpened = cv2.filter2D(denoised, -1, kernel)
        
        return sharpened
    
    def is_license_plate_text(self, text: str) -> bool:
        """Check if text matches Indian license plate patterns"""
        import re
        
        # Clean text
        text = re.sub(r'[^A-Z0-9]', '', text.upper())
        
        # Indian license plate patterns
        patterns = [
            r'^[A-Z]{2}\d{2}[A-Z]{1,2}\d{4}$',  # Standard format: XX00XX0000
            r'^[A-Z]{2}\d{2}[A-Z]{1,2}\d{1,4}$',  # Partial numbers
            r'^[A-Z]{1,2}\d{1,4}[A-Z]{0,2}\d{0,4}$'  # Flexible pattern
        ]
        
        return any(re.match(pattern, text) for pattern in patterns) and len(text) >= 6
    
    def clean_license_plate_text(self, text: str) -> str:
        """Clean and format license plate text"""
        import re
        
        # Remove special characters and spaces
        cleaned = re.sub(r'[^A-Z0-9]', '', text.upper())
        
        # Add standard formatting
        if len(cleaned) >= 10:
            # Format as XX00XX0000
            return f"{cleaned[:2]}{cleaned[2:4]}{cleaned[4:6]}{cleaned[6:10]}"
        
        return cleaned
    
    def relative_to_absolute_bbox(self, relative_bbox: List, offset_x: int, offset_y: int) -> List[float]:
        """Convert relative bounding box to absolute coordinates"""
        # EasyOCR returns bbox as [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]
        x_coords = [point[0] for point in relative_bbox]
        y_coords = [point[1] for point in relative_bbox]
        
        return [
            min(x_coords) + offset_x,
            min(y_coords) + offset_y,
            max(x_coords) + offset_x,
            max(y_coords) + offset_y
        ]
    
    def calculate_image_quality(self, image: np.ndarray) -> float:
        """Calculate image quality score based on various metrics"""
        # Convert to grayscale for analysis
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Calculate sharpness using Laplacian variance
        laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
        sharpness_score = min(laplacian_var / 1000, 1.0)  # Normalize
        
        # Calculate brightness
        brightness = np.mean(gray) / 255
        brightness_score = 1.0 - abs(brightness - 0.5) * 2  # Optimal at 0.5
        
        # Calculate contrast
        contrast = gray.std() / 255
        contrast_score = min(contrast * 2, 1.0)  # Normalize
        
        # Combined quality score
        quality_score = (sharpness_score * 0.5 + brightness_score * 0.3 + contrast_score * 0.2)
        
        return round(quality_score, 2)
    
    async def detect_violations(self, image: np.ndarray, vehicles: List[DetectionResult], 
                               persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> List[str]:
        """Detect traffic violations in the image"""
        violations = []
        
        for violation_type, detector in self.violation_patterns.items():
            try:
                if await detector(image, vehicles, persons, traffic_signs):
                    violations.append(violation_type)
            except Exception as e:
                logger.warning(f"Error in {violation_type} detection: {e}")
        
        return violations
    
    # Violation detection methods
    async def detect_helmet_violation(self, image: np.ndarray, vehicles: List[DetectionResult], 
                                     persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect riders without helmets on motorcycles"""
        motorcycles = [v for v in vehicles if 'motorcycle' in v.class_name.lower()]
        
        for motorcycle in motorcycles:
            # Find persons near the motorcycle
            nearby_persons = self.find_nearby_objects(motorcycle, persons, threshold=50)
            
            # Check if any person appears to be without helmet
            for person in nearby_persons:
                # Use head detection and helmet classification
                # This is a simplified version - in production, use a trained helmet detection model
                x1, y1, x2, y2 = [int(coord) for coord in person.bbox]
                person_region = image[y1:y2, x1:x2]
                
                # Analyze head region (top 30% of person bbox)
                head_region = person_region[:int(person_region.shape[0] * 0.3)]
                
                # Simple heuristic: check for helmet-like shapes/colors
                # In production, use a proper helmet detection model
                if self.analyze_helmet_presence(head_region):
                    continue
                else:
                    return True
        
        return False
    
    async def detect_triple_riding(self, image: np.ndarray, vehicles: List[DetectionResult], 
                                  persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect more than 2 people on a motorcycle"""
        motorcycles = [v for v in vehicles if 'motorcycle' in v.class_name.lower()]
        
        for motorcycle in motorcycles:
            # Count persons on/near the motorcycle
            nearby_persons = self.find_nearby_objects(motorcycle, persons, threshold=30)
            
            if len(nearby_persons) > 2:
                return True
        
        return False
    
    async def detect_wrong_way_driving(self, image: np.ndarray, vehicles: List[DetectionResult], 
                                      persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect vehicles going in wrong direction"""
        # This requires more sophisticated analysis of traffic flow
        # For now, return False - implement based on lane detection and traffic flow analysis
        return False
    
    async def detect_mobile_usage(self, image: np.ndarray, vehicles: List[DetectionResult], 
                                 persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect mobile phone usage while driving"""
        # This requires facial analysis and hand gesture recognition
        # Placeholder implementation
        return False
    
    async def detect_seatbelt_violation(self, image: np.ndarray, vehicles: List[DetectionResult], 
                                       persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect seatbelt violations in cars"""
        cars = [v for v in vehicles if v.class_name.lower() in ['car', 'taxi', 'suv']]
        
        for car in cars:
            # Analyze interior region for seatbelt presence
            # This requires interior detection and seatbelt classification
            # Placeholder implementation
            pass
        
        return False
    
    async def detect_signal_jump(self, image: np.ndarray, vehicles: List[DetectionResult], 
                                persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect vehicles crossing red traffic lights"""
        traffic_lights = [t for t in traffic_signs if 'traffic light' in t.class_name.lower()]
        
        # Analyze traffic light state and vehicle positions
        # This requires traffic light state detection and intersection analysis
        return False
    
    async def detect_speeding(self, image: np.ndarray, vehicles: List[DetectionResult], 
                             persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect speeding violations"""
        # Requires motion analysis from video or speed limit sign detection
        return False
    
    async def detect_wrong_parking(self, image: np.ndarray, vehicles: List[DetectionResult], 
                                  persons: List[DetectionResult], traffic_signs: List[DetectionResult]) -> bool:
        """Detect wrong parking violations"""
        # Analyze parking zones and vehicle positions
        return False
    
    def find_nearby_objects(self, reference_obj: DetectionResult, objects: List[DetectionResult], 
                           threshold: int = 50) -> List[DetectionResult]:
        """Find objects near a reference object"""
        ref_center = self.get_bbox_center(reference_obj.bbox)
        nearby = []
        
        for obj in objects:
            obj_center = self.get_bbox_center(obj.bbox)
            distance = self.calculate_distance(ref_center, obj_center)
            
            if distance <= threshold:
                nearby.append(obj)
        
        return nearby
    
    def get_bbox_center(self, bbox: List[float]) -> Tuple[float, float]:
        """Get center point of bounding box"""
        x1, y1, x2, y2 = bbox
        return ((x1 + x2) / 2, (y1 + y2) / 2)
    
    def calculate_distance(self, point1: Tuple[float, float], point2: Tuple[float, float]) -> float:
        """Calculate Euclidean distance between two points"""
        return np.sqrt((point1[0] - point2[0])**2 + (point1[1] - point2[1])**2)
    
    def analyze_helmet_presence(self, head_region: np.ndarray) -> bool:
        """Analyze if helmet is present in head region"""
        # Simplified helmet detection - in production use trained model
        # Check for dark/bright patterns typical of helmets
        
        if head_region.size == 0:
            return False
        
        # Convert to HSV for better color analysis
        hsv = cv2.cvtColor(head_region, cv2.COLOR_BGR2HSV)
        
        # Define helmet color ranges (black, white, bright colors)
        helmet_masks = []
        
        # Black helmet
        lower_black = np.array([0, 0, 0])
        upper_black = np.array([180, 255, 50])
        helmet_masks.append(cv2.inRange(hsv, lower_black, upper_black))
        
        # White helmet
        lower_white = np.array([0, 0, 200])
        upper_white = np.array([180, 30, 255])
        helmet_masks.append(cv2.inRange(hsv, lower_white, upper_white))
        
        # Bright colored helmets
        bright_colors = [
            ([0, 50, 50], [10, 255, 255]),    # Red
            ([100, 50, 50], [130, 255, 255]), # Blue
            ([25, 50, 50], [35, 255, 255]),   # Yellow
        ]
        
        for lower, upper in bright_colors:
            helmet_masks.append(cv2.inRange(hsv, np.array(lower), np.array(upper)))
        
        # Combine all masks
        combined_mask = np.zeros_like(helmet_masks[0])
        for mask in helmet_masks:
            combined_mask = cv2.bitwise_or(combined_mask, mask)
        
        # Calculate helmet coverage
        helmet_coverage = np.sum(combined_mask > 0) / combined_mask.size
        
        # Threshold for helmet presence
        return helmet_coverage > 0.3  # 30% coverage indicates helmet

# FastAPI Application
app = FastAPI(title="SnapChallan AI Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global AI processor instance
ai_processor = None

@app.on_event("startup")
async def startup_event():
    global ai_processor
    ai_processor = AIProcessor()
    logger.info("AI Service started successfully")

@app.get("/health/")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.post("/process/")
async def process_violation_image(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    violation_id: str = None
):
    """Process uploaded image for violations and license plates"""
    try:
        # Validate file type
        if not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Save uploaded file
        MEDIA_DIR.mkdir(exist_ok=True)
        file_path = MEDIA_DIR / f"{violation_id}_{file.filename}"
        
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Process image
        result = await ai_processor.process_image(str(file_path))
        
        # Store result in Redis if violation_id provided
        if violation_id:
            background_tasks.add_task(
                store_ai_result, violation_id, asdict(result)
            )
        
        return {
            "success": True,
            "result": asdict(result),
            "message": "Image processed successfully"
        }
        
    except Exception as e:
        logger.error(f"Error processing image: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/result/{violation_id}")
async def get_ai_result(violation_id: str):
    """Get AI processing result for a violation"""
    try:
        result = ai_processor.redis_client.get(f"ai_result:{violation_id}")
        if result:
            return {"success": True, "result": json.loads(result)}
        else:
            raise HTTPException(status_code=404, detail="Result not found")
    except Exception as e:
        logger.error(f"Error fetching AI result: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def store_ai_result(violation_id: str, result: dict):
    """Store AI result in Redis"""
    try:
        ai_processor.redis_client.setex(
            f"ai_result:{violation_id}",
            3600,  # 1 hour TTL
            json.dumps(result)
        )
        logger.info(f"AI result stored for violation {violation_id}")
    except Exception as e:
        logger.error(f"Error storing AI result: {e}")

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        workers=1
    )
