import cv2
import paho.mqtt.client as mqtt
import base64
import numpy as np
import time
import os
import sys
import warnings

# Suppress deprecation warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# MQTT settings
broker = os.getenv('MQTT_BROKER')
port = os.getenv('MQTT_PORT')
processing_interval = 5

if not broker or not port:
    print("Error: MQTT_BROKER and MQTT_PORT environment variables must be set.", file=sys.stderr)
    sys.exit(1)

port = int(port)
subscribe_topic = "camera/stream"
publish_topic = "camera/objects"

# Load YOLO
try:
    net = cv2.dnn.readNet("yolov3.weights", "yolov3.cfg")
    layer_names = net.getLayerNames()
    output_layers = [layer_names[i - 1] for i in net.getUnconnectedOutLayers()]
    classes = []
    with open("coco.names", "r") as f:
        classes = [line.strip() for line in f.readlines()]
    print("YOLO model loaded successfully.", file=sys.stderr)
except Exception as e:
    print(f"Error loading YOLO model: {e}", file=sys.stderr)
    sys.exit(1)

# Initialize MQTT client
def on_connect(client, userdata, flags, rc):
    print("Connected with result code " + str(rc), file=sys.stderr)
    client.subscribe(subscribe_topic)

last_processed_time = 0

def on_message(client, userdata, msg):
    global last_processed_time
    current_time = time.time()
    if current_time - last_processed_time < processing_interval:
        return

    last_processed_time = current_time

    print("Message received on topic " + msg.topic, file=sys.stderr)

    # Decode the image
    try:
        jpg_original = base64.b64decode(msg.payload)
        jpg_as_np = np.frombuffer(jpg_original, dtype=np.uint8)
        frame = cv2.imdecode(jpg_as_np, flags=1)
        print("Image decoded successfully.", file=sys.stderr)
    except Exception as e:
        print(f"Error decoding image: {e}", file=sys.stderr)
        return

    # Detect objects
    try:
        height, width, channels = frame.shape
        blob = cv2.dnn.blobFromImage(frame, 0.00392, (416, 416), (0, 0, 0), True, crop=False)
        net.setInput(blob)
        outs = net.forward(output_layers)
        print("Object detection performed successfully.", file=sys.stderr)
    except Exception as e:
        print(f"Error during object detection: {e}", file=sys.stderr)
        return

    # Process detections
    class_ids = []
    confidences = []
    boxes = []
    for out in outs:
        for detection in out:
            scores = detection[5:]
            class_id = np.argmax(scores)
            confidence = scores[class_id]
            if confidence > 0.5:
                # Object detected
                center_x = int(detection[0] * width)
                center_y = int(detection[1] * height)
                w = int(detection[2] * width)
                h = int(detection[3] * height)
                # Rectangle coordinates
                x = int(center_x - w / 2)
                y = int(center_y - h / 2)
                boxes.append([x, y, w, h])
                confidences.append(float(confidence))
                class_ids.append(class_id)

    indexes = cv2.dnn.NMSBoxes(boxes, confidences, 0.5, 0.4)
    detected_objects = []
    for i in range(len(boxes)):
        if i in indexes:
            label = str(classes[class_ids[i]])
            detected_objects.append(label)

    # Debugging: Print detected objects
    print("Detected objects:", detected_objects, file=sys.stderr)

    # Publish detected objects
    if detected_objects:
        message = ', '.join(detected_objects)
        result = client.publish(publish_topic, message)
        status = result.rc
        if status == 0:
            print(f"Sent `{message}` to topic `{publish_topic}`", file=sys.stderr)
        else:
            print(f"Failed to send message to topic {publish_topic}", file=sys.stderr)

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

try:
    client.connect(broker, port, 60)
    print("Connected to MQTT broker.", file=sys.stderr)
except Exception as e:
    print(f"Error connecting to MQTT broker: {e}", file=sys.stderr)
    sys.exit(1)

client.loop_forever()