#!/usr/bin/env bash

set -eo pipefail

temp_path="WeChatWin/temp"
latest_path="WeChatWin/latest"

download_link="$1"
if [ -z "$1" ]; then
    >&2 echo -e "Missing argument. Using default download link"
    download_link="https://dldir1v6.qq.com/weixin/Universal/Windows/WeChatWin.exe"
fi

function install_depends() {
    printf "#%.0s" {1..60}
    echo 
    echo -e "## \033[1;33mInstalling 7zip, shasum, wget, curl, git\033[0m"
    printf "#%.0s" {1..60}
    echo 

    apt install -y p7zip-full p7zip-rar libdigest-sha-perl wget curl git
}

function login_gh() {
    printf "#%.0s" {1..60}
    echo 
    echo -e "## \033[1;33mLogin to github to use github-cli...\033[0m"
    printf "#%.0s" {1..60}
    echo 
    if [ -z $GHTOKEN ]; then
        >&2 echo -e "\033[1;31mMissing Github Token! Please get a GHToken from 'Github Settings->Developer settings->Personal access tokens' and set it in Repo Secrect\033[0m"
        exit 1
    fi

    echo $GHTOKEN > WeChatWin/temp/GHTOKEN
    gh auth login --with-token < WeChatWin/temp/GHTOKEN
    if [ "$?" -ne 0 ]; then
        >&2 echo -e "\033[1;31mLogin Failed, please check your network or token!\033[0m"
        clean_data 1
    fi
    rm -rfv WeChatWin/temp/GHTOKEN
}

function download_wechat() {
    printf "#%.0s" {1..60}
    echo 
    echo -e "## \033[1;33mDownloading the newest WeChatWin...\033[0m"
    printf "#%.0s" {1..60}
    echo 

    wget "$download_link" -O ${temp_path}/WeChatWin.exe
    if [ "$?" -ne 0 ]; then
        >&2 echo -e "\033[1;31mDownload Failed, please check your network!\033[0m"
        clean_data 1
    fi
}

function extract_version() {
    printf "#%.0s" {1..60}
    echo 
    echo -e "## \033[1;33mExtract WeChatWin, get the dest version of wechat\033[0m"
    printf "#%.0s" {1..60}
    echo 
    
    # old version
    #local outfile=`7z l ${temp_path}/WeChatWin.exe | grep improve.xml | awk 'NR ==1 { print $NF }'`
    ## 7z x ${temp_path}/WeChatWin.exe -o${temp_path}/temp "\$R5/Tencent/WeChat/improve.xml"
    #7z x ${temp_path}/WeChatWin.exe -o${temp_path}/temp $outfile
    # dest_version=`awk '/MinVersion/{ print $2 }' ${temp_path}/temp/$outfile | sed -e 's/^.*="//g' -e 's/".*$//g'`
    
    # new version
    echo "temp_path="${temp_path}
    7z x ${temp_path}/WeChatWin.exe -o${temp_path}/temp
    7z x ${temp_path}/temp/install.7z -o${temp_path}/temp/install
    dest_version=`ls -l ${temp_path}/temp/install | awk '{print $9}' | grep '^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$' | sed -e 's/^\[//g' -e 's/\]$//g'`
    echo "dest_version="${dest_version}

}


# rename and replace
function prepare_commit() {
    printf "#%.0s" {1..60}
    echo 
    echo -e "## \033[1;33mPrepare to commit new version\033[0m"
    printf "#%.0s" {1..60}
    echo 

    mkdir -p WeChatWin/$dest_version
    cp $temp_path/WeChatWin.exe WeChatWin/$dest_version/WeChatWin-$dest_version.exe
    echo "DestVersion: $dest_version" > WeChatWin/$dest_version/WeChatWin-$dest_version.exe.sha256
    echo "Sha256: $now_sum256" >> WeChatWin/$dest_version/WeChatWin-$dest_version.exe.sha256
    echo "UpdateTime: $(date -u '+%Y-%m-%d %H:%M:%S') (UTC)" >> WeChatWin/$dest_version/WeChatWin-$dest_version.exe.sha256
    echo "DownloadFrom: $download_link" >> WeChatWin/$dest_version/WeChatWin-$dest_version.exe.sha256
    
}

function clean_data() {
    printf "#%.0s" {1..60}
    echo 
    echo -e "## \033[1;33mClean runtime and exit...\033[0m"
    printf "#%.0s" {1..60}
    echo 

    rm -rfv WeChatWin/*
    exit $1
}

function main() {
    # rm -rfv WeChatWin/*
    mkdir -p ${temp_path}/temp
    # login_gh
    ## https://github.com/actions/virtual-environments/blob/main/images/linux/Ubuntu2004-Readme.md
    # install_depends
    download_wechat

    now_sum256=`shasum -a 256 ${temp_path}/WeChatWin.exe | awk '{print $1}'`
    local latest_sum256=`gh release view  --json body --jq ".body" | awk '/Sha256/{ print $2 }'`

    if [ "$now_sum256" = "$latest_sum256" ]; then
        >&2 echo -e "\n\033[1;32mThis is the newest Version!\033[0m\n"
        clean_data 0
    fi
    ## if not the newest
    extract_version
    prepare_commit

    gh release create v$dest_version ./WeChatWin/$dest_version/WeChatWin-$dest_version.exe -F ./WeChatWin/$dest_version/WeChatWin-$dest_version.exe.sha256 -t "Wechat v$dest_version"

    clean_data 0
}

main

