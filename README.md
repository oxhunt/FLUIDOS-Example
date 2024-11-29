# FLUIDOS-IDG-Example


## Installing K3s, Liqo and FLUIDOS
run: `./setup-script.sh  [install|uninstall]`
You can find more details in the script itself as comments.

## Steps executed (old version)
```
sudo apt install python3-venv -y
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r requirements.txt
```

### Verifying that video is being published
`sudo apt install mosquitto-clients`
`mosquitto_sub -h localhost -p 30004 -t "camera/stream"`
`mosquitto_sub -h localhost -p 30004 -t "camera/objects"`
By I've set the mosquitto service to listen using nodeport 30004.
