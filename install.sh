#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}نسخه سیستم شناسایی نشد، لطفا با نویسنده اسکریپت تماس بگیرید!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "این نرم افزار از سیستم 32 بیتی (x86) پشتیبانی نمی کند، لطفا از سیستم 64 بیتی (x86_64) استفاده کنید، اگر سیستم شما اشتباه تشخیص داده شده است، لطفا با نویسنده این اسکریپت تماس بگیرید."
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}لطفاً از CentOS 7 یا بالاتر استفاده کنید! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}لطفا از اوبونتو 16 یا بالاتر استفاده کنید! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}لطفا از دبیان 8 یا بالاتر استفاده کنید!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}لطفاْ پس از پایان نصب/به‌روزرسانی، پورت و رمز عبور حساب کاربری را تغییر دهید.${plain}"
    read -p "ادامه می‌دهید?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "نام اکانت هود را وارد کنید:" config_account
        echo -e "${yellow}نام حساب کاربری شما:${config_account}${plain}"
        read -p "رمزعبور خود را وارد کنید:" config_password
        echo -e "${yellow}رمز عبور شما:${config_password}${plain}"
        read -p "پورت دسترسی پنل را وارد کنید:" config_port
        echo -e "${yellow}پورت دسترسی شما:${config_port}${plain}"
        echo -e "${yellow}تایید تنطمیات${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}تخصیص رمزعبور به اکانت شما با موفقیت انجام شد${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}تنظیمات پورت پتل با موفقیت  انجام شد${plain}"
    else
        echo -e "${red}فرآیند نصب کنسل شد. تمام تنطیمات برابر مقادیر پیس‌فرض هستند. لطفاْ‌آنها را تغییر دهید.${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}شناسایی نسخه x-ui ناموفق بود، ممکن است مشکل مربوط به محدودیت‌های Github API باشد، لطفاً بعداً دوباره امتحان کنید، یا به صورت دستی نسخه x-ui را برای نصب مشخص کنید.${plain}"
            exit 1
        fi
        echo -e "آخرین نسخه x-ui شناسایی شد:${last_version}نصب را آغار کنید"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}x-ui دانلود نشد، لطفاً مطمئن شوید که سرور شما می‌تواند فایل‌های Github را دانلود کند${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "آغاز نصب x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}x-ui v$1 دانلود نشد، لطفاً مطمئن شوید که این نسخه وجود دارد${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/vaxilu/x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} نصب کامل و پنل راه اندازی شد，"
    echo -e ""
    echo -e "x-ui نحوه استفاده از اسکریپت مدیریت: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - نمایش منوی مدیریت (عملکردهای بیشتر)"
    echo -e "x-ui start        - پانل x-ui را راه اندازی کنید"
    echo -e "x-ui stop         - پانل x-ui را متوقف کنید"
    echo -e "x-ui restart      - پانل x-ui را مجددا راه اندازی کنید"
    echo -e "x-ui status       - وضعیت x-ui را مشاهده کنید"
    echo -e "x-ui enable       - x-ui را تنظیم کنید تا به طور خودکار در هنگام بوت اجرا شود"
    echo -e "x-ui disable      - لغو اجرای خودکار x-ui"
    echo -e "x-ui log          - مشاهده گزارش‌های x-ui"
    echo -e "x-ui v2-ui        - اطلاعات حساب v2-ui این دستگاه را به x-ui منتقل کنید"
    echo -e "x-ui update       - پانل x-ui را به روز کنید"
    echo -e "x-ui install      - نصب پنل x-ui"
    echo -e "x-ui uninstall    - پانل x-ui را حذف کنید"
    echo -e "----------------------------------------------"
}

echo -e "${green}نصب را آغاز کنید${plain}"
install_base
install_x-ui $1
