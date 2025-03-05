# this container needs access to the usb camera, which means that 
# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /usr/src/app

#RUN apt-get update && apt-get install -y \
#    build-essential \
#    python3-dev \
#    && rm -rf /var/lib/apt/lists/*


# netifaces


# Copy the current directory contents into the container at /usr/src/app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
# Run image-recognition.py when the container launches
CMD ["python", "./main.py"]