#!/bin/bash

source ./vars/VERSION
source ./vars/DOMAIN
source ./vars/DEFAULT

func_connect(){

	echo "generate ssh key pairs and upload to hosts..."
	ssh-keygen

	for host in $(cat ./vars/hosts | awk -F" " '{print $2}'); do
		echo "ssh-copy-id $default_user@$host"
		ssh-copy-id $default_user@$host
	done 

}

func_kubectl(){

	echo "install kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
        echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	rm -f kubectl kubectl.sha256
}

func_helm(){

	echo "install helm..."
        apt-get install wget -y
        wget https://get.helm.sh/helm-v${helm_version}-linux-amd64.tar.gz
        tar xvzf helm-v${helm_version}-linux-amd64.tar.gz
        mv linux-amd64/helm /usr/local/bin
        rm -f helm-v${helm_version}-linux-amd64.tar.gz
        rm -rf ./linux-amd64

}

func_k9s(){
	wget https://github.com/derailed/k9s/releases/download/v0.26.7/k9s_Linux_x86_64.tar.gz
	tar xvzf k9s_Linux_x86_64.tar.gz
	mv ./k9s /usr/local/bin

	apt-get install bash-completion
	source /usr/share/bash-completion/bash_completion
	echo 'source <(kubectl completion bash)' >>~/.bashrc

	echo 'alias k=kubectl' >>~/.bashrc
        echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

}

func_haproxy(){

	echo "install haproxy..."
	hosts=("haproxy01" "haproxy02")
	for host in "${hosts[@]}"; do	
		ssh $host
		apt-get install --no-install-recommends software-properties-common
		add-apt-repository ppa:vbernat/haproxy-${haproxy_version}
		apt-get install haproxy=${haproxy_version}.\* -y
	done

}

func_kong(){

	echo "install kong..."
	helm repo add kong https://charts.konghq.com
	helm repo update
	helm upgrade --install --create-namespace --namespace kong kong kong/kong --version=${kong_version} -f ./values/kong_values.yaml

}

func_keycloak(){

	echo "install keycloak..."
	helm repo add codecentric https://codecentric.github.io/helm-charts
	helm repo update codecentric
	helm upgrade --install --create-namespace --namespace keycloak keycloak codecentric/keycloak --version=${keycloak_version} 
}

func_rke2(){

        echo "install rke2..."
        sed -i "s/{rke2_version}/$rke2_version/g" ./script/rke2.sh
	./script/rke2.sh
        #cat ./script/rke2.sh | ssh $default_user@${master_node01}
        sed -i "s/$rke2_version/{rke2_version}/g" ./script/rke2.sh

}

func_rke2_agent(){

	echo "install rke2..."

	read -p 'enter master token : ' token

	sed -i "s/{token}/$token/g" ./templates/rke2_config.yaml
	cat ./script/rke2_agent.sh | ssh $default_user@${worker_node01}
	sed -i "s/$token/{token}/g" ./templates/rke2_config.yaml

}

func_rancher(){

	echo "install rancher..."

	kubectl apply -f  https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml
	sleep 1m
	kubectl -n cert-manager rollout status deploy/cert-manager
	kubectl -n cert-manager rollout status deploy/cert-manager-webhook
	kubectl get pods --namespace cert-manager

        helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
        helm repo update rancher-stable
	kubectl create namespace cattle-system
        echo "helm install rancher rancher-stable/rancher --set hostname=${rancher_hostname} --version $racher_version"
	helm install rancher rancher-stable/rancher --namespace cattle-system --set hostname=${rancher_hostname}

}

func_harbor(){
	echo "install harbor..."
}


func_argocd(){
	echo "install argocd..."
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update argo
	helm upgrade --install --create-namespace -n argo argo argo/argo-cd -f ./values/argo_values.yaml
}


func_istio(){
	echo "install istio..."
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${istio_version} TARGET_ARCH=x86_64 sh -
	istioctl install --set profile=demo --set meshConfig.outboundTrafficPolicy.mode=ALLOW_ANY
}

func_longhorn(){
	helm repo add longhorn https://charts.longhorn.io
	helm repo update
	helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
}


func_prometheus(){
	echo "install prometheus stack..."
	kubectl create ns monitoring
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update prometheus-community

	helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
	#sed -i "s/{storage}/$default_storage/g" ./values/prometheus_values.yaml
	#sed -i "s/{grafana_hostname}/$grafana_hostname}/g" ./values/prometheus_values.yaml
	#sed -i "s/{prometheus_hostname}/$prometheus_hostname}/g" ./values/prometheus_values.yaml
	#sed -i "s/{alertmanager_hostname}/$alertmanager_hostname}/g" ./values/prometheus_values.yaml

	#helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --version $promethues_version -n monitoring -f ./values/prometheus_values.yaml
}

func_init_local(){

	echo "initializing local user..."
	mkdir $default_home
	useradd -d $default_home -s /bin/bash $default_user
	chown -R $default_user:$default_user $default_home
	usermod -aG sudo $default_user
	echo "$default_user ALL=NOPASSWD: ALL" >> /etc/sudoers
}

func_init_remote(){

	echo "initializing remote user..."


}
while true
do

	echo ""
	echo ""
	echo "====================================== basic setting ==============================================="
	echo "1. ssh keypair        2. kubectl         3. helm             4. k9s          5. default user "       
	echo ""
	echo "========================================= proxy ====================================================="
	echo "6. haproxy            7. kong "
	echo ""
	echo "========================================= auth ======================================================"
	echo "8. keycloak "
	echo ""
	echo "======================================  kubernetes  ==================================================="
	echo "9. rke2               10. rancher "
	echo ""
	echo "========================================= CI/CD ====================================================="
	echo "11. argocd "
	echo ""
	echo "======================================== service mesh ==============================================="
	echo "12. istio "
	echo ""
	echo "========================================= storage  ================================================"
	echo "13. longhorn "
	echo ""
	echo "========================================= monitoring ================================================"
	echo "14. prometheus stack "
	echo ""
	echo "=========================================== exit ================================================"
	echo "15. exit "
	echo ""

	read -p 'enter a number to install : ' number

	case $number in
		1) func_connect ;;
        	2) func_kubectl ;;
        	3) func_helm ;;
		4) func_k9s ;;
		5) func_init_local ;;
		6) func_haproxy ;;
		7) func_kong ;;
		8) func_keycloak ;;
		9) func_rke2 ;;
		10) func_rancher ;;
		11) func_argocd ;;
		12) func_istio ;;
		13) func_longhorn ;;
		14) func_prometheus ;;
		15) exit ;;
        	*) echo "invalid number" ;;
	esac

done

