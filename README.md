# FLUIDOS-IDG-Example

## Missing Files
Container `image-recognition` is missing the file `weights.cfg` because it is too big to be included in the repository.
You can download it from here: `https://github.com/patrick013/Object-Detection---Yolov3/raw/refs/heads/master/model/yolov3.weights`

## Installing K3s, Liqo and FLUIDOS
run: `./setup-script.sh  [install|uninstall]`
You can find more details in the script itself as comments.

## Building Images
requires docker to be installed.
```
cd ./tools/
./my-build-script.sh
```

## Installing Docker
```
cd setup-scripts
./install-docker.sh
```

## Steps executed to setup the .venv
```
sudo apt install python3-venv -y
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r requirements.txt
```

## Running the example 
After having successfully installed FLUIDOS on both clusters run:
`kubectl apply -f fluidos_example/solver`
This will automatically leverage FLUIDOS to peer the clusters.



After having successfully peered the clusters thanks to FLUIDOS run:
`./my-simple-orchestrator.sh`
the script offloads the default namespace and gives you the options to move the running pods (you find instructions in the executable itself).

### Verifying that video is being published
`sudo apt install mosquitto-clients`
`mosquitto_sub -h localhost -p 30004 -t "camera/stream"`
`mosquitto_sub -h localhost -p 30004 -t "camera/objects"`
By I've set the mosquitto service to listen using nodeport 30004.
