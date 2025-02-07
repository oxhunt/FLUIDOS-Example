import kopf
import socket
import kubernetes.config as config
import kubernetes.client as client
import logging
import netifaces

logging.basicConfig(level=logging.INFO)

previous_ip = None

def get_host_ip():
    """Get the IP address of the host machine."""
    try:
        # Iterate over all interfaces and return the first non-localhost IP address
        for interface in netifaces.interfaces():
            addresses = netifaces.ifaddresses(interface).get(netifaces.AF_INET, [])
            for address in addresses:
                ip = address['addr']
                if ip != '127.0.0.1':
                    return ip
    except Exception as e:
        logging.error(f"Could not get IP address: {e}")
    return None

@kopf.on.startup()
def configure(settings: kopf.OperatorSettings, **kwargs):
    settings.namespace = None  # Monitor all namespaces
    settings.clusterwide = True  # Set to monitor all namespaces

@kopf.on.update('v1', 'pods')
def pod_ip_changed(spec, status, name, namespace, **kwargs):
    # Get the current pod's IP address
    current_pod_ip = get_host_ip()
    
    # Check if the event is for the current pod
    if 'status' in status and 'podIP' in status and status['podIP'] == current_pod_ip:
        previous_ip = spec.get('podIP', None)
        
        if previous_ip and status['podIP'] != previous_ip:
            logging.error(f"Current pod IP: {current_pod_ip}")

if __name__ == '__main__':
    previous_pod_ip = get_host_ip()
    logging.error(f"Current pod IP: {previous_pod_ip}")
    
    config.load_incluster_config()  # Load the in-cluster config
    kopf.run()  # Start the Kopf operator