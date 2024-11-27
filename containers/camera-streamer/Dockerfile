# this container needs access to the usb camera, which means that 
# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir opencv-python mediapipe opencv-python paho-mqtt


# Copy the current directory contents into the container at /usr/src/app
COPY . .

# Run image-recognition.py when the container launches
CMD ["python", "./camera-streamer.py"]