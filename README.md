# FLUIDOS-IDG-Example


## Installing K3s, Liqo and FLUIDOS
run: `./setup-script.sh  [install|uninstall]`

## Steps executed
```
git clone https://github.com/e-candeloro/Driver-State-Detection
# removing the .git folder in it to include it in the repo easily
rm -rf Driver-State-Detection/.git
 sudo apt install python3-venv -y
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r Driver-State-Detection/requirements.txt

python3 ./Driver-State-Detection/driver_state_detection/main.py --help
QT_QPA_PLATFORM=offscreen python ./Driver-State-Detection/driver_state_detection/main.py --verbose --ear_time_tresh 5
```