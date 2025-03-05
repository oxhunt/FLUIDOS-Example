import time
import socket
import kubernetes.config as config
import kubernetes.client as client
import logging
import requests
import os
from prometheus_api_client import PrometheusConnect

logging.basicConfig(level=logging.INFO)

QUERY_INTERVAL = int(os.getenv('QUERY_INTERVAL', 1))
PROMETHEUS_SERVICE = os.getenv('PROMETHEUS_SERVICE', 'prometheus-server.monitoring.svc.cluster.local')


NAMESPACE = os.getenv('NAMESPACE', 'default')
NODE_NAME = os.getenv('NODE_NAME', None)
#NODE_IP = os.getenv('NODE_IP', socket.gethostbyname(socket.gethostname()))
PORT= os.getenv('PORT', 9100)
TIME_RANGE_SAMPLES= os.getenv('TIME_RANGE_SAMPLES', 30)
LOW_THRESHOLD_CPU= os.getenv('LOW_THRESHOLD_CPU', 0.3)
HIGH_THRESHOLD_CPU= os.getenv('HIGH_THRESHOLD_CPU', 0.8)


if not NODE_NAME:
    logging.error('NODE_NAME environment variable is not set.')
    exit(1)


class STATE:
    SAFE_RANGE=0
    LIGHTEN_LOAD=1
    AVAILABLE_RESOURCES=2
    
    
class OrchestratorLogic:
    def __init__(self, query_interval, prometheus_service, node_name):
        config.load_incluster_config()  # Load the in-cluster config
        self.core_v1_api = client.CoreV1Api()
        self.apps_v1_api = client.AppsV1Api()
        self._status=STATE.SAFE_RANGE
        self.prom = PrometheusConnect(url=PROMETHEUS_SERVICE, disable_ssl=True)
        self.node_name = node_name
        
        self.nodes_in_cluster = self.core_v1_api.list_node()
        
        # print the values for all the environment variables
        logging.info(f'QUERY_INTERVAL: {QUERY_INTERVAL}')
        logging.info(f'PROMETHEUS_SERVICE: {PROMETHEUS_SERVICE}')
        logging.info(f'NAMESPACE: {NAMESPACE}')
        logging.info(f'NODE_NAME: {NODE_NAME}')
        #logging.info(f'NODES IN CLUSTER: {self.nodes_in_cluster}')
        logging.info(f'OFFLOADABLE DEPLOYMENTS: {list(map(lambda v: v.metadata.name, self.list_offloadable_deployments()))}')
        logging.info(f'-----------------------')
        
        
        
        self.offloaded=[]
        self.local=[]
        pass
    @property
    def status(self):
        return self._status
    
    def offload(self, deployment):
        deployment_name = deployment.metadata.name
        logging.info(f'Offloading deployment {deployment_name}...')
        
        # do the offloading
        deployment.spec.template.spec.affinity = {
            "nodeAffinity": {
                "requiredDuringSchedulingIgnoredDuringExecution": {
                    "nodeSelectorTerms": [
                        {
                            "matchExpressions": [
                                {
                                    "key": "liqo.io/type",
                                    "operator": "In",
                                    "values": ["virtual-node"]
                                }
                            ]
                        }
                    ]
                }
            }
        }
        self.apps_v1_api.patch_namespaced_deployment(deployment.metadata.name, NAMESPACE, deployment)

        # do a rollout
        #self.apps_v1_api.patch_namespaced_deployment(deployment.metadata.name, NAMESPACE, {"spec": {"template": {"metadata": {"annotations": {"kubectl.kubernetes.io/restartedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ")}}}}})
        
        self.wait_for_all_pods_to_be_running(deployment_name)
        
        logging.info(f'Deployment {deployment_name} offloaded.')
        
    def unoffload(self, deployment):
        deployment_name = deployment.metadata.name
        logging.info(f'Offloading deployment {deployment_name}...')
        
        # do the unoffloading
        deployment.spec.template.spec.affinity = {
            "nodeAffinity": {
                "requiredDuringSchedulingIgnoredDuringExecution": {
                    "nodeSelectorTerms": [
                        {
                            "matchExpressions": [
                                {
                                    "key": "liqo.io/type",
                                    "operator": "NotIn",
                                    "values": ["virtual-node"]
                                }
                            ]
                        }
                    ]
                }
            }
        }
        self.apps_v1_api.patch_namespaced_deployment(deployment.metadata.name, NAMESPACE, deployment)
        
        # do a rollout
        #self.apps_v1_api.patch_namespaced_deployment(deployment.metadata.name, NAMESPACE, {"spec": {"template": {"metadata": {"annotations": {"kubectl.kubernetes.io/restartedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ")}}}}})
        
        self.wait_for_all_pods_to_be_running(deployment_name)
        logging.info(f'Deployment {deployment_name} offloaded.')
    
    @staticmethod
    def is_offloaded(deployment):
        try:
            v = deployment.spec.template.spec.affinity.node_affinity.required_during_scheduling_ignored_during_execution.node_selector_terms[0]
            if v.match_expressions[0].key == "liqo.io/type" and v.match_expressions[0].operator == "In" and v.match_expressions[0].values[0] == "virtual-node":
                return True
        except:
            return False
    
    def wait_for_all_pods_to_be_running(self, deployment_name):
        # wait for all pods to be in running state
        while True:
            pods = self.core_v1_api.list_namespaced_pod(NAMESPACE)
            pod_names = [pod.metadata.name for pod in pods.items if pod.metadata.owner_references[0].name == deployment_name]
            if all(filter(lambda v: v in pod_names, self.list_active_pods())):
                break
            else:
                logging.info(f'Waiting for deployment {deployment_name} to be fully running...')
            time.sleep(1)
        return True
    
    def list_offloadable_deployments(self, node=None):
        return list(filter(lambda v: OrchestratorLogic.is_offloadable(v),self.list_deployments()))
    
    
    def list_active_pods(self):
        pods = self.core_v1_api.list_namespaced_pod(NAMESPACE)
        active_pods = [pod.metadata.name for pod in pods.items if pod.status.phase == "Running"]
        logging.info(f'Active pods in namespace {NAMESPACE}: {active_pods}')
        return active_pods
    
    def get_node_cpu_usage(self):
        
        query =  '1 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\'idle\', '+ \
                    f'node=\'{self.node_name}\'' + \
                    '}'+ \
                    f"[{TIME_RANGE_SAMPLES}s])))"
                    
        
        logging.debug(f'Prometheus query: {query}')
        try:
            response = self.prom.custom_query(query=query)
            print("received response")
            print(response)
        except requests.exceptions.RequestException as e:
            logging.error(f'Failed to get CPU usage for node {self.node_name}. Error: {e}')
            logging.info(f"Query that caused the error: {query}")
            return -1
        if response.status_code != 200:
            logging.error(f'Failed to get CPU usage for node {self.node_name}. Status code: {response.status_code}')
            logging.error(response.json())
            logging.info(f"Query that caused the error: {query}")
            return -1
        if 'data' not in response.json():
            logging.error(f'Failed to get CPU usage for node {self.node_name}. No data in response:')
            logging.error(response.json())
            logging.info(f"Query that caused the error: {query}")
            return -1
        if 'result' not in response.json()['data']:
            logging.error(f'Failed to get CPU usage for node {self.node_name}.')
            logging.error(f"No result in response: {response.json()}")
            logging.info(f"Query that caused the error: {query}")
            return -1
        result = response.json()['data']['result']
        if result:
            return float(result[0]['value'][1])
        logging.error(f"No result in response: {response.json()}")
        logging.info(f"Query that caused the error: {query}")
        return -1

    @status.setter
    def status(self, value):
        if self._status != value:
            logging.info(f'Status changed from {self._status} to {value}')
            self._status = value
    
    @staticmethod
    def is_offloadable(deployment):
        if not deployment.metadata.labels:
            return False
        return deployment.metadata.labels.get("liqo.io/offloadable") == "true"
    @staticmethod
    def has_name(deployment, name):
        return deployment.metadata.name == name
    
    def list_deployments(self):
        return self.apps_v1_api.list_namespaced_deployment(NAMESPACE).items
        
    
    def list_offloaded_deployments(self):
        # returns the list of deployments that are on the nodes with the label liqo.io/type=virtual-node and with the label liqo.io/offloadable=true
        return list(filter(lambda v: OrchestratorLogic.is_offloaded(v),self.list_offloadable_deployments()))
    
    def list_unoffloaded_deployments(self):
        # returns the list of deployments that are on the nodes with the label liqo.io/type=virtual-node and with the label liqo.io/offloadable=true
        return list(filter(lambda v: not OrchestratorLogic.is_offloaded(v),self.list_offloadable_deployments()))
    
    def run(self):
        while True:
            time.sleep(QUERY_INTERVAL)
            logging.debug(f'Checking CPU usage for node {NODE_NAME}...')
            cpu_usage = self.get_node_cpu_usage()
            
            
            if cpu_usage < 0:
                logging.error(f'Failed to get CPU usage for node {NODE_NAME}')
                continue
            
            if cpu_usage > HIGH_THRESHOLD_CPU:
                logging.info(f'CPU usage is high: {cpu_usage:.2f}')
                self.status=STATE.LIGHTEN_LOAD
                d = self.list_unoffloaded_deployments()
                if len(d):
                    self.offload(d[0])
                    logging.info(f'Offloading deployment {d[0].metadata.name}')
                else:
                    logging.info(f'No unoffloaded deployments to offload')
                
            elif cpu_usage < LOW_THRESHOLD_CPU:
                logging.info(f'CPU usage is low: {cpu_usage:.2f}. Taking action...')
                self.status=STATE.AVAILABLE_RESOURCES
                d = self.list_offloaded_deployments()
                if len(d):
                    logging.info(f'Unoffloading deployment {d[0].metadata.name}')
                    self.unoffload(d[0])
                else:
                    logging.info(f'No offloaded deployments to unoffload')
            else:
                logging.info(f'Node {NODE_NAME} CPU usage: {cpu_usage:.2f}')
                self.status=STATE.SAFE_RANGE
            
def main():
    
    orchestrator = OrchestratorLogic(QUERY_INTERVAL, PROMETHEUS_SERVICE, NODE_NAME)
    orchestrator.run()
    
        
        

if __name__ == '__main__':
    main()
