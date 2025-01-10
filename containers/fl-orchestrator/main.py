import kopf
import socket
import kubernetes.config as config
import kubernetes.client as client
import logging

logging.basicConfig(level=logging.INFO)

previous_ip = None

@kopf.on.startup()
def configure(settings: kopf.OperatorSettings, **kwargs):
    settings.namespace = 'default'  # Set the namespace to monitor
    #settings.clusterwide = True  # Monitor all namespaces

@kopf.on.update('v1', 'pods')
def pod_ip_changed(spec, status, name, namespace, **kwargs):
    # Get the current pod's IP address
    current_pod_ip = socket.gethostbyname(socket.gethostname())
    
    # Check if the event is for the current pod
    if 'status' in status and 'podIP' in status and status['podIP'] == current_pod_ip:
        previous_ip = spec.get('podIP', None)
        
        if previous_ip and status['podIP'] != previous_ip:
            logging.info(f"Current pod IP: {current_pod_ip}")

if __name__ == '__main__':
    config.load_incluster_config()  # Load the in-cluster config
    kopf.run()  # Start the Kopf operator