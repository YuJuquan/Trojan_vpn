# Trojan_vpn.sh
# *************************************
# 创建者：于钜权                       
# 创建时间：2020/05/21                            
# 说明：用于基于Trojan的VPN配置脚本
# 要求：本脚本仅适用于CentOS7系统！
# *************************************


# 标识颜色
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

# Step1:安装Trojan
function install_trojan(){

    # 1.1关闭防火墙
    systemctl stop firewalld
    systemctl disable firewalld

    # 1.2关闭selinux
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" == "SELINUX=enforcing" ]; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
    if [ "$CHECK" == "SELINUX=permissive" ]; then
        sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi

    # 1.3安装执行所需命令包
    yum -y install bind-utils wget curl zip unzip tar
    '''
    # 参考：https://blog.51cto.com/11956937/2152744
    # 参考：https://www.jianshu.com/p/1438ca0d3756
    '''

    # 1.4解析域名
    blue "******************************************************"
    yellow "请输入你的域名："
    blue "******************************************************"
    # 读入域名
    read domain
    # 提取域名
    real_addr=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'` 
    '''
    # ping -c 1,表示只发送一个icmp echo_request 包
    # sed命令，用于获得地址的正则表达式
    '''
    local_addr=`curl ipv4.icanhazip.com`
    # 验证域名是否正确
    if [ $real_addr == $local_addr ] ; then
	    blue "******************************************************"
	    green "域名解析正确"
        green "开始安装nginx"
	    blue "******************************************************"
	    sleep 1s

        # 1.5安装nginx
        '''
        # 参考：https://www.runoob.com/linux/nginx-install-setup.html
        '''
	    rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
        yum install -y nginx
	    systemctl enable nginx.service
	    # 设置伪装站
	    rm -rf /usr/share/nginx/html/*
	    cd /usr/share/nginx/html/
	    wget https://github.com/atrandys/v2ray-ws-tls/raw/master/web.zip
    	unzip web.zip
	    systemctl restart nginx.service

	    # 1.6申请https证书
        blue "******************************************************"
        green "开始申请https证书"
	    blue "******************************************************"
        sleep 1s
	    mkdir /usr/src/trojan-cert
        # 安装证书
        '''
        # 参考：https://my.oschina.net/u/3042999/blog/1858891
        '''
	    curl https://get.acme.sh | sh
	    ~/.acme.sh/
        acme.sh  --issue  -d $domain  --webroot /usr/share/nginx/html/
    	~/.acme.sh/acme.sh  --installcert  -d  $domain   \
        --key-file   /usr/src/trojan-cert/private.key \
        --fullchain-file /usr/src/trojan-cert/fullchain.cer \
        --reloadcmd  "systemctl force-reload  nginx.service"

        # 1.7下载Trojan
	    if test -s /usr/src/trojan-cert/fullchain.cer; then
            cd /usr/src
        # 下载Trojan服务器
	    wget https://github.com/trojan-gfw/trojan/releases/download/v1.14.0/trojan-1.14.0-linux-amd64.tar.xz
	    tar xf trojan-1.*
	    # 下载Trojan客户端
	    wget https://github.com/atrandys/trojan/raw/master/trojan-cli.zip
	    unzip trojan-cli.zip
        # 复制证书
        '''
        # 参考：https://www.runoob.com/linux/linux-comm-cp.html
        '''
	    cp /usr/src/trojan-cert/fullchain.cer /usr/src/trojan-cli/fullchain.cer # cp拷贝证书
        # 写入配置信息
        '''
        # 参考：https://www.runoob.com/linux/linux-comm-cat.html
        '''
        # Trojan客户端配置文件
        cat > /usr/src/trojan-cli/config.json <<-EOF
        {
            "run_type": "client",
            "local_addr": "127.0.0.1",
            "local_port": 1080,
            "remote_addr": "$domain",
            "remote_port": 1702,
            "password": [
                "1320171114"
            ],
            "log_level": 1,
            "ssl": {
                "verify": true,
                "verify_hostname": true,
                "cert": "fullchain.cer",
                "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
            "sni": "",
                "alpn": [
                    "h2",
                    "http/1.1"
                ],
                "reuse_session": true,
                "session_ticket": false,
                "curves": ""
            },
            "tcp": {
                "no_delay": true,
                "keep_alive": true,
                "fast_open": false,
                "fast_open_qlen": 20
            }
        }
EOF
        # Trojan服务器配置文件
        rm -rf /usr/src/trojan/server.conf
        cat > /usr/src/trojan/server.conf <<-EOF
        {
            "run_type": "server",
            "local_addr": "0.0.0.0",
            "local_port": 443,
            "remote_addr": "127.0.0.1",
            "remote_port": 80,
            "password": [
                "1320171114"
            ],
            "log_level": 1,
            "ssl": {
                "cert": "/usr/src/trojan-cert/fullchain.cer",
                "key": "/usr/src/trojan-cert/private.key",
                "key_password": "",
                "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
            "prefer_server_cipher": true,
                "alpn": [
                    "http/1.1"
                ],
                "reuse_session": true,
                "session_ticket": false,
                "session_timeout": 600,
                "plain_http_response": "",
                "curves": "",
                "dhparam": ""
            },
            "tcp": {
                "no_delay": true,
                "keep_alive": true,
                "fast_open": false,
                "fast_open_qlen": 20
            },
            "mysql": {
                "enabled": false,
                "server_addr": "127.0.0.1",
                "server_port": 3306,
                "database": "trojan",
                "username": "trojan",
                "password": ""
            }
        }
EOF

        cd /usr/src/trojan-cli/
        zip -q -r trojan-cli.zip /usr/src/trojan-cli/
        trojan_path=$(cat /dev/urandom | head -1 | md5sum | head -c 16) # 16位随机数
        '''
        https://segmentfault.com/q/1010000007761269/a-1020000007761350
        '''
        mkdir /usr/share/nginx/html/${trojan_path}
        mv /usr/src/trojan-cli/trojan-cli.zip /usr/share/nginx/html/${trojan_path}/ # mv 文件名 目录名

        # 1.8增加启动脚本
        cat > /usr/lib/systemd/system/trojan.service <<-EOF
        [Unit]  
        Description=trojan  
        After=network.target  
        
        [Service]  
        Type=simple  
        PIDFile=/usr/src/trojan/trojan/trojan.pid
        ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"  
        ExecReload=  
        ExecStop=/usr/src/trojan/trojan  
        PrivateTmp=true  
        
        [Install]  
        WantedBy=multi-user.target
EOF
    
	chmod +x /usr/lib/systemd/system/trojan.service
	systemctl start trojan.service
	systemctl enable trojan.service
    '''
    https://www.cnblogs.com/zwcry/p/9602756.html
    '''
	blue "******************************************************"
	green "Trojan已安装完成"
    green "复制以下链接下载Trojan客户端"
	yellow "http://${domain}/$trojan_path/trojan-cli.zip"
	blue "******************************************************"
	else
        red "******************************************************"
	    red "https证书申请失败，请重新申请证书"
        red "本次安装失败"
	    red "******************************************************"
	fi
    else
        red "******************************************************"
        red "域名解析地址与VPS IP地址不一致，请确保域名解析正常"
        red "本次安装失败"
        red "******************************************************"
    fi
}

# Step2:卸载Trojan
function remove_trojan(){
    red "******************************************************"
    red "卸载Trojan"
    red "卸载nginx"
    red "******************************************************"
    sleep 1s
    systemctl stop trojan
    systemctl disable trojan
    rm -f /usr/lib/systemd/system/trojan.service
    rm -rf /usr/src/trojan*
    yum remove -y nginx
    rm -rf /usr/share/nginx/html/*
    blue "******************************************************"
    green "Trojan与nginx卸载完毕"
    blue "******************************************************"
}

# Step3:启动脚本
start_menu(){
    clear
    blue "******************************************************"
    green " 使用Trojan搭建VPN"
    green " 系统要求：centos7"
    green " 创建者：于钜权"
    blue "******************************************************"
    echo
    blue "******************************************************"
    green " 1. 安装Trojan"
    red " 2. 卸载Trojan"
    yellow " 3. 退出脚本"
    blue "******************************************************"
    echo
    read -p "请输入数字:" num
    case "$num" in
        1)
            install_trojan
        ;;
        2)
            remove_trojan 
        ;;
        3)
            exit 1
        ;;
        *)
            clear
            red "您输入的数字无效，请重新输入"
            sleep 1s
            start_menu
        ;;
    esac
}

# 启动脚本
start_menu
