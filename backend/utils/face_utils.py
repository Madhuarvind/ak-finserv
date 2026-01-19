import cv2
import numpy as np
import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image


# Initialize MobileNetV2 as a feature extractor
# We use a pre-trained model and remove the classifier to get embeddings
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = models.mobilenet_v2(pretrained=True)
model.classifier = torch.nn.Identity()  # Remove the last layer
model.to(device)
model.eval()

# Face Detector
# We now use MTCNN for much better reliability on hosting/low light
from facenet_pytorch import MTCNN
mtcnn = MTCNN(keep_all=False, device=device, min_face_size=40)

# Fallback Face Detector (Haar Cascade)
face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

# Image Transforms for MobileNet
transform = transforms.Compose(
    [
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ]
)


def generate_face_embedding(image_bytes):
    """
    1. Detect face using OpenCV.
    2. Crop and preprocess face.
    3. Generate 1280-d embedding using MobileNetV2.
    """
    import time

    start_time = time.time()
    try:
        # Load image
        print("DEBUG: Face Utils - START [0.00s]")
        img_array = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        if img is None:
            print("DEBUG: Face Utils - Invalid image data")
            return None, "Invalid image data"

        print(
            f"DEBUG: Face Utils - Decoded size {img.shape} [{time.time() - start_time:.2f}s]"
        )

        # Performance: Resize large images before face detection
        height, width = img.shape[:2]
        if width > 600:
            scale = 600 / width
            img = cv2.resize(img, (int(width * scale), int(height * scale)))
            print(
                f"DEBUG: Face Utils - Resized to {img.shape} for detection [{time.time() - start_time:.2f}s]"
            )

        # 1. MTCNN Face Detection (Robust)
        print("DEBUG: Face Utils - Searching for face using MTCNN...")
        # mtcnn.detect returns boxes as [[x1, y1, x2, y2]]
        boxes, probs = mtcnn.detect(img)
        
        face_img = None
        
        if boxes is not None and len(boxes) > 0:
            print(f"DEBUG: Face Utils - MTCNN found {len(boxes)} faces. Prob: {probs[0]:.2f}")
            # Get the largest box or the first one if only one
            box = boxes[0] # mtcnn normally sorts by prob or size
            x1, y1, x2, y2 = map(int, box)
            # Ensure coordinates are within bounds
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(img.shape[1], x2), min(img.shape[0], y2)
            face_img = img[y1:y2, x1:x2]
        else:
            print("DEBUG: Face Utils - MTCNN failed. Trying Haar Cascade Fallback...")
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            faces = face_cascade.detectMultiScale(gray, 1.1, 5, minSize=(40, 40))
            print(f"DEBUG: Face Utils - Haar found: {len(faces)}")
            
            if len(faces) > 0:
                # Take the largest face
                x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
                face_img = img[y : y + h, x : x + w]

        if face_img is None or face_img.size == 0:
            return None, f"No face detected (Cloud AI Buffer: {width}x{height})"

        # Convert to PIL for Torchvision
        face_rgb = cv2.cvtColor(face_img, cv2.COLOR_BGR2RGB)
        pil_img = Image.fromarray(face_rgb)

        # Preprocess and generate embedding
        print("DEBUG: Face Utils - Running MobileNet ...")
        input_tensor = transform(pil_img).unsqueeze(0).to(device)

        with torch.no_grad():
            embedding = model(input_tensor)

        # Convert to list for JSON storage
        embedding_list = embedding.cpu().numpy().flatten().tolist()
        total_time = time.time() - start_time
        print(f"DEBUG: Face Utils - MobileNet Done [{time.time() - start_time:.2f}s]")
        print(
            f"DEBUG: Face Utils - SUCCESS - Embedding Len: {len(embedding_list)} TotalTime: {total_time:.2f}s"
        )
        return embedding_list, None

    except Exception as e:
        print(
            f"DEBUG: Face Utils - FATAL ERROR: {str(e)} [{time.time() - start_time:.2f}s]"
        )
        return None, str(e)


def compare_embeddings(emb1, emb2):
    """Cosine Similarity comparison"""
    a = np.array(emb1)
    b = np.array(emb2)
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
