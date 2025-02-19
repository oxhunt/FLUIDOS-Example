import cv2
import paho.mqtt.client as mqtt
import base64
import sys
import os
import time
import warnings
import logging



logging.basicConfig(level=logging.INFO)


SECONDS_BETWEEN_FRAMES = int(os.getenv('SECONDS_BETWEEN_FRAMES', "5"))

# Function to connect to the broker with retry logic
def connect_to_broker(broker, port):
    while True:
        try:
            client.connect(broker, port, 60)
            logging.info(f"Connected to MQTT broker at {broker}:{port}")
            break
        except Exception as e:
            logging.error(f"Error: Unable to connect to MQTT broker: {e}")
            time.sleep(5)
            
            
def connect_to_camera():
    for _ in range(3):
        # check that there exist a /dev/video* device
        camera_connected=False
        for i in range(10):
            if os.path.exists(f"/dev/video{i}"):
                camera_connected=True
                break
        if not camera_connected:
            logging.error("Camera not connected, retrying")
            time.sleep(5)
            
    logging.error("Error: Unable to connect to camera after multiple retries.")
    return None
    
    

if __name__ == "__main__":

    # suppress deprecation warnings
    warnings.filterwarnings("ignore", category=DeprecationWarning)

    # MQTT settings
    broker = os.getenv('MQTT_BROKER')
    port = os.getenv('MQTT_PORT')
    VIDEO_TO_PLAY = os.getenv('VIDEO_TO_PLAY')

    if not broker or not port:
        logging.error("Error: MQTT_BROKER and MQTT_PORT environment variables must be set.")
        sys.exit(1)

    port = int(port)

    topic = "camera/stream"

    # Initialize MQTT client
    client = mqtt.Client(client_id="", clean_session=True, userdata=None, protocol=mqtt.MQTTv311, transport="tcp")

    connect_to_broker(broker, port)

    # Initialize the camera
    cap = connect_to_camera()
    
    do_loop = False
    if not cap:
        logging.info("Repeating in a loop a video to simulate a camera")
        cap = cv2.VideoCapture(f"{VIDEO_TO_PLAY}")
        do_loop = True
        
        
    
    while True:
        # Read the frame from the camera at the specified interval
        time.sleep(SECONDS_BETWEEN_FRAMES) # around 500 ms
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
            logging.error(f"Error: Unable to publish to MQTT broker: {e}")
            connect_to_broker()

        # Display the frame (optional)
        #cv2.imshow('frame', frame)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Release the camera and close any open windows
    cap.release()
    cv2.destroyAllWindows()
    client.disconnect()