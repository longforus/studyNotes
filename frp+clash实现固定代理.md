# frp+clash实现固定代理

最近需要将外地的网络请求转发到某个固定的区域,现在用frp服务器+clash的方式来实现,

```
[远程设备A机]
     ↓  (连接 VPS:8334)
[云服务器B机:8334] --frp转发--> [你家里的 Clash Verge:7890]
     ↓
Clash Verge 全局代理 C机 → 访问外网

```



## C机服务端出口 ubuntu20.04

### 安装mihomo

`````````````````````````````````````````````shell
 mkdir -p ~/clash-meta && cd ~/clash-meta
 wget https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-linux-amd64-alpha-5344e86.deb
 sudo dpkg -i mihomo-linux-amd64-alpha-5344e86.deb
 
 wget https://github.com/haishanh/yacd/archive/refs/heads/gh-pages.zip -O yacd.zip
 unzip yacd.zip
 mkdir -p ~/.config/mihomo/ui
 mv ~/clash-meta/yacd-gh-pages/* ~/.config/mihomo/ui/
 
 cd ~/.config/mihomo
 nano config.yaml
 
 `````````````````````````````````
mode: global
mixed-port: 7890
allow-lan: true
log-level: info
secret: ''
external-controller: 0.0.0.0:9090
external-ui: ../mihomo/ui

``````````````````````````````



sudo nano /etc/systemd/system/mihomo.service
```````````````````````````````````````
[Unit]
Description=Mihomo (Clash.Meta) Service
After=network.target

[Service]
Type=simple
User=void
ExecStart=/usr/bin/mihomo -d /home/void/.config/mihomo
Restart=on-failure
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
````````````````````````````````````````````
sudo systemctl daemon-reexec  # 或 sudo systemctl daemon-reload
sudo systemctl enable mihomo
sudo systemctl start mihomo

`````````````````````````````````````````````

启动后[yacd](http://192.168.0.227:9090/ui/#/)可以访问ui   

`journalctl -u mihomo -f`可以持续查看输出日志

### 安装frpc

```shell
 cd ~
 wget https://github.com/fatedier/frp/releases/download/v0.62.1/frp_0.62.1_linux_amd64.tar.gz
 tar -zxf frp_0.62.1_linux_amd64.tar.gz
 cd frp_0.62.1_linux_amd64
 sudo mv frpc /usr/bin/
 sudo mkdir -p /etc/frp
 cp frpc.toml /etc/frp/
 sudo nano /etc/frp/frpc.toml
 
 ```````````````````````````````````````````
 [common]
server_addr = "1.2.3.4"
server_port = 7000
token = Mddkbasyssdhbowei

[clash-verge-proxy-ubuntu] #這个不同的C机需要不同
type = "tcp"
local_ip = "127.0.0.1"
local_port = 7890   #mihomo的本地代理端口
remote_port = 8334  #這个就是A机代理需要填的端口,不同的C机需要不同的端口
 ```````````````````````````````````````````
 
 sudo nano /etc/systemd/system/frpc.service
 
 ``````````````````````````````````````````````
 [Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/frpc -c /etc/frp/frpc.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target

 ``````````````````````````````````````````````
 
 
sudo systemctl daemon-reexec  # 或 daemon-reload
sudo systemctl enable frpc
sudo systemctl start frpc
systemctl status frpc  #查看状态

```

## B机云服务器转发

暂略

## A机客户端用户

安装Clash Verge,填写B机IP和8334,即可访问