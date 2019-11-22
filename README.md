# kube-router-for-sctp

 已经实现了基于kube-router的 sctp报文 ，NodeIP、Service IP的sctp服务端和客户的 消息 通信。
 如有需要可以联系我
 
 2019-11-19
# kube-router支持SCTP问题解决思路
时间：2019年11月
-------------------------------------------------
## 1、	环境介绍
系统环境
系统系统：CentOS 7.3
[root@k8s03 ~]# cat /proc/version     
Linux version 3.10.0-514.el7.x86_64 (builder@kbuilder.dev.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-11) (GCC) ) #1 SMP Tue Nov 22 16:42:41 UTC 2016

组件：
Kubernetes 1.15.3       
kube-router latest最新版本       
kubeadm  1.15.3 (cloudnativelabs/kube-router:latest)      

## 2、	解决思路
### 安装sctp协议栈库
Centos7.3系统上SCTP协议栈软件支持环境准备：           
[root@k8s01 opt]# rpm -qa | grep sctp               
lksctp-tools-devel-1.0.17-2.el7.x86_64               
lksctp-tools-1.0.17-2.el7.x86_64                       

### 更新ipvsadm版本
原生版本不支持ipvsadm配置sctp server规则                   
ipvsadm v1.30 2019/07/02                 

### 更新iperf3版本（可选）
[root@k8s01 opt]# iperf3 --version                 
iperf 3.7 (cJSON 1.5.2)                    
Linux k8s01 3.10.0-514.el7.x86_64 #1 SMP Tue Nov 22 16:42:41 UTC 2016 x86_64                
如果没有使用到可以不需要更新iperf                  

### 重制kube-router镜像
更新kube-router原始镜像，原生镜像版本内ipvsadm版本不支持sctp规则配置；kube-router进程不支持sctp规则下发                 
重制后的镜像为10.101.50.110:5000/kube-router:1114                  

上述完成之后可以正常下发sctp ipvs规则如下
Kube-router supports configuration of sctp used by ipvsadm，such as：
UDP  192.168.122.1:32002 rr              
  -> 172.20.1.6:32002             Masq    1      0          0         
SCTP 10.120.10.120:32000 rr            
  -> 172.20.1.6:32000             Masq    1      0          0         
SCTP 10.101.50.61:32000 rr             
  -> 172.20.1.6:32000             Masq    1      0          0         
SCTP 10.254.125.172:32000 rr                 
  -> 172.20.1.6:32000             Masq    1      0          0         
SCTP 127.0.0.1:32000 rr                
  -> 172.20.1.6:32000             Masq    1      0          0         
SCTP 192.168.122.1:32000 rr                      
  -> 172.20.1.6:32000             Masq    1      0          0

此时已经支持了k8s集群内部sctp服务端和集群外部sctp客户端之间的通信，                  
反之，k8s集群内部sctp客户端和集群外部sctp服务端之间的通信不支持。                

### 更新centos7.3系统
更新版本为centos8                  
 [root@k8s02 ~]# cat /proc/version                       
Linux version 4.18.0-80.el8.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 8.2.1 20180905 (Red Hat 8.2.1-3) (GCC)) #1 SMP Tue Jun 4 09:19:46 UTC 2019          

[root@k8s01 auto-kubernetes]# uname -r              
4.18.0-80.el8.x86_64

默认centos8原生ipvsadm版本支持sctp配置              
[root@k8s02 ~]# ipvsadm --version             
ipvsadm v1.29 2016/12/23 (compiled with popt and IPVS v1.2.1)            

### 安装docker依赖  
原生docker-ce、docker-ce-cli安装纯在问题，需要替换runc。               
runc-1.0.0-55.rc5.dev.git2abd837.module_el8.0.0+58+91b614e7.x86_64            
新装containerd.io-1.2.6-3.3.fc30.x86_64.rpm               

### 安装sctp库
[root@k8s02 ~]# rpm -qa | grep sctp                 
lksctp-tools-doc-1.0.18-3.el8.x86_64        
lksctp-tools-1.0.18-3.el8.x86_64                    
lksctp-tools-devel-1.0.18-3.el8.x86_64               

### 添加sctp模块
默认原生内核模块中没有sctp.ko文件。需要下载kernel-4.18.0-80.7.1.el8_0.src.rpm源码包rpm –ivh安装，然后重新编译内核和内核模块，并insmod加载sctp模块               
[root@k8s02 ~]# lsmod | grep sctp            
sctp                  389120  8
xt_sctp                16384  0
libcrc32c              16384  5 nf_conntrack,nf_nat,xfs,ip_vs,sctp

### 安装k8s集群
利用kubeadm安装k8s集群，初始化系统配置。安装k8s组件、利用kube-router替换kube-proxy；这里使用重制后的kube-router。

### 实验结果

测试工具：使用lsctp自带工具              
server:          
  sctp_test -H local-addr -P local-port -l [-d level] [-x]            
  sctp_test -H 172.20.3.35 -P 32000 -l            

client:           
  sctp_test -H local-addr -P local-port -h remote-addr                 
  sctp_test -H 10.101.50.110 -P 32000 -h 172.20.3.35 -p 32000 -s -x 10                

### 抓包：
如：tcpdump -nn -i eth5 -p sctp –s 0               

clusterIP和NodeIP的SCTP通信正常             
此时已经支持了k8s集群内部sctp服务端和集群外部sctp客户端之间的通信，            
反之，k8s集群内部sctp客户端和集群外部sctp服务端之间的通信。               

K8s集群外部，通过externalIP通信异常                
K8s集群pod做SCTP服务端，其他集群外节点做SCTP客户端，此时的通信异常，externalIP达到集群内没有正常转发到Pod内，sctp协议始终处理    init初始连接状态，该问题待进一步解决。                       

怀疑点：externalIP 10.120.10.120是VIP，172.20.1.6也是VIP，都是由kubelet在集群内分配的虚拟IP地址，sctp在RIP转发VIP规则上可能存在问题。

[root@k8s01 yum]# tcpdump -nn -i eno1 -p sctp           
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eno1, link-type EN10MB (Ethernet), capture size 262144 bytes
16:51:57.290066 IP 10.101.50.85.32000 > 10.120.10.120.32000: sctp (1) [INIT] [init tag: 472532726] [rwnd: 106496] [OS: 10] [MIS: 65535] [init TSN: 2392046513] 
16:52:00.291485 IP 10.101.50.85.32000 > 10.120.10.120.32000: sctp (1) [INIT] [init tag: 472532726] [rwnd: 106496] [OS: 10] [MIS: 65535] [init TSN: 2392046513]

这里的报文没有正常转发到pod内，但ipvs规则是存在的            
SCTP 10.120.10.120:32000 rr
  -> 172.20.1.6:32000             Masq    1      0          0         
SCTP 10.254.125.172:32000 rr
  -> 172.20.1.6:32000             Masq    1      0          0         
SCTP 127.0.0.1:32000 rr
  -> 172.20.1.6:32000             Masq    1      0          0         
SCTP 192.168.122.1:32000 rr
  -> 172.20.1.6:32000             Masq    1      0          0


## 3、	实验框架

### 测试拓扑图
10.101.50.61/10.101.50.117/10.101.50.110/10.101.50.85为4台独立centos操作系统主机。
 ![Image text](https://github.com/lehongwen/kube-router-for-sctp/blob/master/mmexport1574382682152.jpg)

### 集群运行状态
[root@k8s01 yum]# kubectl get pods  -n kube-system -o wide
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE    NOMINATED NODE   READINESS GATES
coredns-bccdc95cf-72rx5         1/1     Running   0          16h   172.20.1.5      k8s02   <none>           <none>
coredns-bccdc95cf-bhtzg         1/1     Running   0          16h   172.20.0.3      k8s01   <none>           <none>
etcd-k8s01                      1/1     Running   0          16h   10.101.50.61    k8s01   <none>           <none>
kube-apiserver-k8s01            1/1     Running   0          16h   10.101.50.61    k8s01   <none>           <none>
kube-controller-manager-k8s01   1/1     Running   0          16h   10.101.50.61    k8s01   <none>           <none>
kube-router-2cx2s               1/1     Running   0          16h   10.101.50.117   k8s02   <none>           <none>
kube-router-mrgzb               1/1     Running   0          16h   10.101.50.61    k8s01   <none>           <none>
kube-scheduler-k8s01            1/1     Running   0          16h   10.101.50.61    k8s01   <none>           <none>

 [root@k8s01 yum]# kubectl get pods  -o wide
NAME                           READY   STATUS    RESTARTS   AGE   IP           NODE    NOMINATED NODE   READINESS GATES
sctp-deploy-5c9dfb5959-gw5g9   1/1     Running   0          16h   172.20.1.6   k8s02   <none>           <none>

[root@k8s01 yum]# kubectl get nodes -o wide
NAME    STATUS   ROLES    AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION         CONTAINER-RUNTIME
k8s01   Ready    master   16h   v1.15.3   10.101.50.61    <none>        CentOS Linux 8 (Core)   4.18.0-80.el8.x86_64   docker://18.9.8
k8s02   Ready    <none>   16h   v1.15.3   10.101.50.117   <none>        CentOS Linux 8 (Core)   4.18.0-80.el8.x86_64   docker://18.9.8

[root@k8s01 yum]# kubectl get svc -o wide
NAME             TYPE        CLUSTER-IP       EXTERNAL-IP     PORT(S)                                            AGE   SELECTOR
kubernetes       ClusterIP   10.254.0.1       <none>          443/TCP                                            16h   <none>
sctp-expserver   NodePort    10.254.125.172   10.120.10.120   32000:32000/SCTP,32001:32001/TCP,32002:32002/UDP   16h   app=sctp-socket

### 集群部署参数

[root@k8s01 yum]# ps -ef | grep kube
root      7832     1  1 00:32 ?        00:13:51 /usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --cgroup-driver=cgroupfs --network-plugin=cni --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.1 --feature-gates=SCTPSupport=true

root      8112  8093  0 00:33 ?        00:09:14 kube-controller-manager --allocate-node-cidrs=true --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf --bind-address=127.0.0.1 --client-ca-file=/etc/kubernetes/pki/ca.crt --cluster-cidr=172.20.0.0/16 --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt --cluster-signing-key-file=/etc/kubernetes/pki/ca.key --controllers=*,bootstrapsigner,tokencleaner --feature-gates=SCTPSupport=true --kubeconfig=/etc/kubernetes/controller-manager.conf --leader-elect=true --node-cidr-mask-size=24 --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt --root-ca-file=/etc/kubernetes/pki/ca.crt --service-account-private-key-file=/etc/kubernetes/pki/sa.key --use-service-account-credentials=true

root      8160  8143  1 00:33 ?        00:18:12 kube-apiserver --advertise-address=10.101.50.61 --allow-privileged=true --authorization-mode=Node,RBAC --client-ca-file=/etc/kubernetes/pki/ca.crt --enable-admission-plugins=NodeRestriction --enable-bootstrap-token-auth=true --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key --etcd-servers=https://127.0.0.1:2379 --feature-gates=SCTPSupport=true --insecure-port=0 --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key --requestheader-allowed-names=front-proxy-client --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt --requestheader-extra-headers-prefix=X-Remote-Extra- --requestheader-group-headers=X-Remote-Group --requestheader-username-headers=X-Remote-User --secure-port=6443 --service-account-key-file=/etc/kubernetes/pki/sa.pub --service-cluster-ip-range=10.254.0.0/16 --tls-cert-file=/etc/kubernetes/pki/apiserver.crt --tls-private-key-file=/etc/kubernetes/pki/apiserver.key

root      8194  8177  1 00:33 ?        00:10:35 etcd --advertise-client-urls=https://10.101.50.61:2379 --cert-file=/etc/kubernetes/pki/etcd/server.crt --client-cert-auth=true --data-dir=/var/lib/etcd --initial-advertise-peer-urls=https://10.101.50.61:2380 --initial-cluster=k8s01=https://10.101.50.61:2380 --key-file=/etc/kubernetes/pki/etcd/server.key --listen-client-urls=https://127.0.0.1:2379,https://10.101.50.61:2379 --listen-peer-urls=https://10.101.50.61:2380 --name=k8s01 --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt --peer-client-cert-auth=true --peer-key-file=/etc/kubernetes/pki/etcd/peer.key --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt --snapshot-count=10000 --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt

root      8228  8205  0 00:33 ?        00:00:45 kube-scheduler --bind-address=127.0.0.1 --feature-gates=SCTPSupport=true --kubeconfig=/etc/kubernetes/scheduler.conf --leader-elect=true

root     13021 13004  0 00:42 ?        00:05:35 /usr/local/bin/kube-router --run-router=true --run-firewall=true --run-service-proxy=true --kubeconfig=/var/lib/kube-router/kubeconfig --masquerade-all=true --hairpin-mode=true --enable-cni=true --enable-pod-egress=true --enable-ibgp=true --advertise-cluster-ip=true --advertise-pod-cidr=true --advertise-loadbalancer-ip=true --advertise-external-ip=true --cluster-asn=64512 --cluster-cidr=172.20.0.0/16 --peer-router-ips=10.101.50.85 --peer-router-asns=64513 --nodeport-bindon-all-ip=true --nodes-full-mesh=true --v=3


## 4、	问题总结
（1）	centos7.3需要配置支持lksctp库，默认ipvsadm版本不支持sctp规则，需要安装lksctp和更新ipvsadm（可选）。               
（2）	kube-router原始镜像中ipvsadm版本不支持sctp规则配置下发，需要更新ipvsadm版本至1.29及以上。              
（3）	kube-router原始镜像中kube-router源码不支持sctp规则解析，需要修改源码并Go build源码。                  
（4）	重制kuber-router镜像替换原始镜像，制作kube-router镜像Dockerfile文件，编译ipvsadm 1.30版本，安装kube-router可执行程序等。kube-router基础镜像使用最新alpine:3.10.3版本。              
（5）	centos7.3内核版本对sctp SNAT转换和crc校验存在问题，更新centos7系统版本为centos8。              
（6）	centos8原生版本中不带sctp.ko模块，需要下载原始内核并重新编译内核sctp ko模块。               
（7）	centos8默认自启动防火墙，sctp服务端是无法正常通信，需要禁用防火墙。                      
（8）	centos8默认安装docker-ce会与runc冲突，需要强制安装containerd.io替换runc。                      
（9）	k8s集群默认不支持sctp，部分组件需要配置SCTPSupport规则。                 
