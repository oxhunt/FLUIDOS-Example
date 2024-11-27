# FLUIDOS-IDG-Example


## Installing K3s, Liqo and FLUIDOS
run: `./setup-script.sh  [install|uninstall]`
You can find more details in the script itself as comments.

## Steps executed
```
sudo apt install python3-venv -y
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r requirements.txt

python3 ./Driver-State-Detection/driver_state_detection/main.py --help
QT_QPA_PLATFORM=offscreen python ./Driver-State-Detection/driver_state_detection/main.py --ear_time_tresh 5
```

### Sample driver-monitoring-system
`git clone https://github.com/e-candeloro/Driver-State-Detection`
I'm not using it for this demo, but I've tried it and it seems to be working well.

### Verifying that video is being published
`sudo apt install mosquitto-clients`
`mosquitto_sub -h localhost -p 30004 -t "camera/stream"`
`mosquitto_sub -h localhost -p 30004 -t "camera/objects"`
By I've set the mosquitto service to listen using nodeport 30004.