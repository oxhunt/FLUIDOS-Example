import cv2
import paho.mqtt.client as mqtt
import base64
import sys
import os
import time
import warnings

# suppress deprecation warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# MQTT settings
broker = os.getenv('MQTT_BROKER')
port = os.getenv('MQTT_PORT')

if not broker or not port:
    print("Error: MQTT_BROKER and MQTT_PORT environment variables must be set.")
    sys.exit(1)

port = int(port)

topic = "camera/stream"

# Initialize MQTT client
client = mqtt.Client(client_id="", clean_session=True, userdata=None, protocol=mqtt.MQTTv311, transport="tcp")

# Function to connect to the broker with retry logic
def connect_to_broker():
    while True:
        try:
            client.connect(broker, port, 60)
            break
        except Exception as e:
            print(f"Error: Unable to connect to MQTT broker: {e}", file=sys.stderr)
            time.sleep(5)

connect_to_broker()

# Initialize the camera
cap = cv2.VideoCapture(-1)  # Ensure the correct camera index

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # Encode the frame as JPEG
    _, buffer = cv2.imencode('.jpg', frame)
    jpg_as_text = base64.b64encode(buffer).decode('utf-8')

    # Publish the frame to the MQTT topic
    try:
        client.publish(topic, jpg_as_text)
    except Exception as e:
        print(f"Error: Unable to publish to MQTT broker: {e}", file=sys.stderr)
        connect_to_broker()

    # Display the frame (optional)
    #cv2.imshow('frame', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# Release the camera and close any open windows
cap.release()
cv2.destroyAllWindows()
client.disconnect()