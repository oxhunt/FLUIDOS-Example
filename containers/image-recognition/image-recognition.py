import cv2
import paho.mqtt.client as mqtt
import base64
import numpy as np
import time
import os
import sys
import warnings
import logging
import json

from ultralytics import YOLO


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
publish_topic2 = "camera/outputimage"

# Load YOLO
try:
    # Load the model
    model = YOLO("/yolomodel.pt")  # load a pretrained mode

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
    
    # Load YOLO
    # Decode the image to cv2 format
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
        results = model(frame)
        logging.debug("Object detection performed successfully.")
    except Exception as e:
        logging.error(f"Error during object detection: {e}")
        return
    
    #logging.info(f"Results: {results}")
    
    # send the results to the MQTT topic
    # output image as ndarray
    
    json_results=[]
    
    for r in results:
        json_res=r.tojson()
        json_results.append(json_res)
        
        #sending image
        result = client.publish(publish_topic, json_res)
        
        status = result.rc
        if status == 0:
            logging.info(f"Sent json to topic `{publish_topic}`", json_res)
        else:
            logging.error(f"Failed to send message to topic {publish_topic}")
        
        img_output=r.plot()
        
        # encode the image as JPEG
        _, buffer = cv2.imencode('.jpg', img_output)
        jpg_as_text = base64.b64encode(buffer).decode('utf-8')
        
        #sending image
        result = client.publish(publish_topic2, jpg_as_text)
        
        status = result.rc
        if status == 0:
            logging.info(f"Sent `labeled image` to topic `{publish_topic2}`")
        else:
            logging.error(f"Failed to send message to topic {publish_topic2}")
        
        
     
#boxes: ultralytics.engine.results.Boxes object
#keypoints: None
#masks: None
#names: {0: 'person', 1: 'bicycle', 2: 'car', 3: 'motorcycle', 4: 'airplane', 5: 'bus', 6: 'train', 7: 'truck', 8: 'boat', 9: 'traffic light', 10: 'fire hydrant', 11: 'stop sign', 12: 'parking meter', 13: 'bench', 14: 'bird', 15: 'cat', 16: 'dog', 17: 'horse', 18: 'sheep', 19: 'cow', 20: 'elephant', 21: 'bear', 22: 'zebra', 23: 'giraffe', 24: 'backpack', 25: 'umbrella', 26: 'handbag', 27: 'tie', 28: 'suitcase', 29: 'frisbee', 30: 'skis', 31: 'snowboard', 32: 'sports ball', 33: 'kite', 34: 'baseball bat', 35: 'baseball glove', 36: 'skateboard', 37: 'surfboard', 38: 'tennis racket', 39: 'bottle', 40: 'wine glass', 41: 'cup', 42: 'fork', 43: 'knife', 44: 'spoon', 45: 'bowl', 46: 'banana', 47: 'apple', 48: 'sandwich', 49: 'orange', 50: 'broccoli', 51: 'carrot', 52: 'hot dog', 53: 'pizza', 54: 'donut', 55: 'cake', 56: 'chair', 57: 'couch', 58: 'potted plant', 59: 'bed', 60: 'dining table', 61: 'toilet', 62: 'tv', 63: 'laptop', 64: 'mouse', 65: 'remote', 66: 'keyboard', 67: 'cell phone', 68: 'microwave', 69: 'oven', 70: 'toaster', 71: 'sink', 72: 'refrigerator', 73: 'book', 74: 'clock', 75: 'vase', 76: 'scissors', 77: 'teddy bear', 78: 'hair drier', 79: 'toothbrush'}
#obb: None
#orig_img: array([[[41, 29, 23],
#        [41, 29, 23],
#        [41, 30, 22],
#        ...,
#        [72, 54, 37],
#        [72, 54, 37],
#        [72, 54, 37]],
#
#       [[41, 29, 23],
#        [41, 29, 23],
#        [41, 30, 22],
#        ...,
#        [72, 54, 37],
#        [72, 54, 37],
#        [72, 54, 37]],
#
#       [[41, 29, 23],
#        [41, 29, 23],
#        [41, 30, 22],
#        ...,
#        [72, 54, 37],
#        [72, 54, 37],
#        [72, 54, 37]],
#
#       ...,
#
#       [[ 8,  0,  1],
#        [ 8,  0,  1],
#        [ 8,  0,  1],
#        ...,
#        [19,  5,  9],
#        [20,  6, 10],
#        [20,  6, 10]],
#
#       [[11,  0,  2],
#        [11,  0,  2],
#        [11,  0,  2],
#        ...,
#        [18,  4,  8],
#        [19,  5,  9],
#        [20,  6, 10]],
#
#       [[13,  2,  4],
#        [13,  2,  4],
#        [14,  1,  3],
#        ...,
#        [18,  4,  8],
#        [18,  4,  8],
#        [20,  6, 10]]], dtype=uint8)
#orig_shape: (360, 640)
#path: 'image0.jpg'
#probs: None
#save_dir: 'runs/detect/predict'
#speed: {'preprocess': 2.3249490186572075, 'inference': 459.4727719959337, 'postprocess': 0.836567982332781}]
#0: 384x640 2 persons, 1 car, 459.5ms
#Speed: 2.3ms preprocess, 459.5ms inference, 0.8ms postprocess per image at shape (1, 3, 384, 640)

    


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