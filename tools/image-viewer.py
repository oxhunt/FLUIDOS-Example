import cv2
import paho.mqtt.client as mqtt
import base64
import numpy as np
import sys
import os
import time

# TOOL used to debug the view the camera stream for debugging purposes

# MQTT settings
broker = os.getenv('MQTT_BROKER')
port = os.getenv('MQTT_PORT')

if not broker or not port:
    print("Error: MQTT_BROKER and MQTT_PORT environment variables must be set.")
    sys.exit(1)

port = int(port)
subscribe_topic = "camera/stream"

# Initialize MQTT client
def on_connect(client, userdata, flags, rc):  # Keep the parameters for the callback signature
    if rc == 0:
        print("Connected with result code " + str(rc))
        client.subscribe(subscribe_topic)
    else:
        print("Connection refused with result code " + str(rc), file=sys.stderr)

def on_message(client, userdata, msg):  # Keep the parameters for the callback signature
    # Decode the image
    jpg_original = base64.b64decode(msg.payload)
    jpg_as_np = np.frombuffer(jpg_original, dtype=np.uint8)
    frame = cv2.imdecode(jpg_as_np, flags=1)

    # Display the frame
    cv2.imshow('Camera Stream', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        client.disconnect()
        cv2.destroyAllWindows()

client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

connected = False
while not connected:
    try:
        client.connect(broker, port, 60)
        client.loop_start()
        connected = True
    except Exception as e:
        print(f"Connection failed: {e}", file=sys.stderr)
        time.sleep(5)

# Keep the script running to display the images
while True:
    pass