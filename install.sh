#!/bin/bash

source ./vars/VERSION
source ./vars/DOMAIN

func_connect(){

	echo "generate ssh key pairs and upload to hosts..."
	ssh-keygen

	for host in $(cat ./vars/hosts | awk -F" " '{print $2}'); do
		ssh-copy-id $host
	done 

}

func_kubectl(){

	echo "install kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
        echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
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
	ssh rancher_master01
        swapoff -a
        systemctl stop ufw
        systemctl disable ufw
        iptables -F
        apt-get install curl -y
        curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=v${rke2_version}+rke2r1 INSTALL_RKE2_TYPE="server" sh -

}


func_rancher(){

	echo "install rancher..."

	kubectl apply -f  https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.yaml

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

func_prometheus()
{
	echo "install prometheus stack..."
	kubectl create ns monitoring
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update prometheus-community
	helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --version $promethues_version -n monitoring
}


while true
do

	echo ""
	echo ""
	echo "========================================= packages =================================================="
	echo "1. ssh keypair        2. kubectl         3. helm "       
	echo ""
	echo "========================================= proxy ====================================================="
	echo "4. haproxy            5. kong "
	echo ""
	echo "========================================= auth ======================================================"
	echo "6. keycloak "
	echo ""
	echo "========================================= rancher ==================================================="
	echo "7. rke2               8. rancher "
	echo ""
	echo "========================================= CI/CD ====================================================="
	echo "9. gitlab             10. harbor          11. argocd "
	echo ""
	echo "======================================== service mesh ==============================================="
	echo "12. istio             13. kiali           14. jaeger "
	echo ""
	echo "========================================= monitoring ================================================"
	echo "15. prometheus stack "
	echo ""

	read -p 'enter a number to install : ' number

	case $number in
		1) func_connect ;;
        	2) func_kubectl ;;
        	3) func_helm ;;
		4) func_haproxy ;;
		5) func_kong ;;
		6) func_keycloak ;;
		7) func_rke2 ;;
		8) func_rancher ;;
		9) func_gitlab ;;
		10) func_harbor ;;
		11) func_argocd ;;
		12) func_istio ;;
		13) func_kiali ;;
		14) func_jaeger ;;
		15) func_prometheus ;;
        	*) echo "invalid number" ;;
	esac

done

