import cv2
import paho.mqtt.client as mqtt
import base64
import sys
import os
import time
import warnings
import logging
import struct


def get_log_level_from_env():
    log_level = os.getenv('LOG_LEVEL', "INFO")
    if log_level == "INFO":
        return logging.INFO
    elif log_level == "DEBUG":
        return logging.DEBUG
    elif log_level == "ERROR":
        return logging.ERROR
    else:
        logging.warning(f"Invalid LOG_LEVEL value: {log_level}. Defaulting to INFO")
        return logging.INFO

logging.basicConfig(level=get_log_level_from_env())


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
    
def check_video_file(video_path):
    if not os.path.exists(video_path):
        logging.error(f"Error: The video file {video_path} does not exist.")
        return False

    # check that the file has at least one frame
    if not os.path.getsize(video_path) > 0:
        logging.error(f"Error: The video file {video_path} is empty.")
        return False

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        logging.error(f"Error: The video file {video_path} cannot be opened.")
        return False

    ret, frame = cap.read()
    if not ret:
        logging.error(f"Error: The video file {video_path} does not contain any frames.")
        return False

    cap.release()
    return True

if __name__ == "__main__":

    # suppress deprecation warnings
    warnings.filterwarnings("ignore", category=DeprecationWarning)

    # MQTT settings
    broker = os.getenv('MQTT_BROKER')
    port = os.getenv('MQTT_PORT')
    VIDEO_TO_PLAY = os.getenv('VIDEO_TO_PLAY')
    FPS = int(os.getenv('FPS', '30'))  # Default to 30 FPS if not set

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
        if not check_video_file(VIDEO_TO_PLAY):
            logging.error(f"Error: The video file {VIDEO_TO_PLAY} does not exist.")
            sys.exit(1)
        
        logging.info(f"Repeating in a loop the video {VIDEO_TO_PLAY} to simulate a camera")
        cap = cv2.VideoCapture(f"{VIDEO_TO_PLAY}")
        if FPS:
            cap.set(cv2.CAP_PROP_FPS, FPS)  # Set the FPS
        do_loop = True
    
    
    while True:
        ret, frame = cap.read()
        if not ret:
            if do_loop:
                logging.info("Reached end of video file, restarting")
                cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                continue
            else:
                logging.info("cannot read frame of the camera, exiting")
                break
        # make the frame a numpy array and send it as a byte array
        frame_data = cv2.imencode('.jpg', frame)[1].tobytes()

        # Publish the frame to the MQTT topic
        try:
            logging.info("publishing frame to MQTT, size: %d" % len(frame_data))
            client.publish(topic, frame_data)
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