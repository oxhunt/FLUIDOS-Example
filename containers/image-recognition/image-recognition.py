import cv2
import paho.mqtt.client as mqtt
import base64
import numpy as np
import time
import os
import sys
import warnings
import logging

logging.basicConfig(level=logging.INFO)


# Suppress deprecation warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# MQTT settings
broker = os.getenv('MQTT_BROKER')
port = os.getenv('MQTT_PORT')
processing_interval = 5

if not broker or not port:
    logging.error("Error: MQTT_BROKER and MQTT_PORT environment variables must be set.")
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
    logging.error("YOLO model loaded successfully.")
except Exception as e:
    logging.error(f"Error loading YOLO model: {e}")
    sys.exit(1)

# Initialize MQTT client
def on_connect(client, userdata, flags, rc):
    logging.info("Connected with result code " + str(rc))
    client.subscribe(subscribe_topic)

last_processed_time = 0

def on_message(client, userdata, msg):
    global last_processed_time
    current_time = time.time()
    if current_time - last_processed_time < processing_interval:
        return

    last_processed_time = current_time

    logging.info("Message received on topic " + msg.topic)

    # Decode the image
    try:
        jpg_original = base64.b64decode(msg.payload)
        jpg_as_np = np.frombuffer(jpg_original, dtype=np.uint8)
        frame = cv2.imdecode(jpg_as_np, flags=1)
        logging.debug("Image decoded successfully.")
    except Exception as e:
        logging.error(f"Error decoding image: {e}")
        return

    # Detect objects
    try:
        height, width, channels = frame.shape
        blob = cv2.dnn.blobFromImage(frame, 0.00392, (416, 416), (0, 0, 0), True, crop=False)
        net.setInput(blob)
        outs = net.forward(output_layers)
        logging.debug("Object detection performed successfully.")
    except Exception as e:
        logging.error(f"Error during object detection: {e}")
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
    logging.info(f"Detected objects: {detected_objects}")

    # Publish detected objects
    if detected_objects:
        message = ', '.join(detected_objects)
        result = client.publish(publish_topic, message)
        status = result.rc
        if status == 0:
            logging.info(f"Sent `{message}` to topic `{publish_topic}`")
        else:
            logging.error(f"Failed to send message to topic {publish_topic}")


if __name__ == "__main__":
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    success=False
    while not success:
        try:
            client.connect(broker, port, 60)
            logging.info("Connected to MQTT broker.")
            success=True
        except Exception as e:
            logging.error(f"Error connecting to MQTT broker: {e}")
            sleep(5)

    client.loop_forever()