#!/usr/bin/env bash

# Load var
load_var() {
    PRO_URL="https://jihulab.com/jetsung/nvim.git"
    PLUG_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/autoload/plug.vim"

    NVIM_CONF_FILE="${HOME}/.config/nvim/init.vim"
    NVIM_CONF="${NVIM_CONF_FILE%/*}"
    
    TMP_FOLDER="/tmp/nvim"
}

# Get OS
get_os() {
    OS=$(uname | tr '[:upper:]' '[:lower:]')
    case $OS in
    darwin) OS='darwin' ;;
    linux) OS='linux' ;;
    *)
        printf "\e[1;31mOS %s is not supported by this installation script\e[0m\n" ${OS}
        exit 1
        ;;
    esac
}

# Get package name
get_pkg_name() {
    local PKG_LIST="brew apt dnf"
    for PKG in ${PKG_LIST}; do
        if chkcmd ${PKG}; then
            echo "${PKG}"
            return
        fi
    done
}

# Check in China
check_in_china() {
    urlstatus=$(curl -s -m 2 -IL https://google.com | grep 200)
    [[ -z "${urlstatus}" ]] && IN_CHINA="Yes"
    # unset IN_CHINA
    # echo $IN_CHINA
}

chkcmd() {
    command -v "$@" >/dev/null 2>&1
}

# Install NeoVim
install_neovim() {
    PKG_NAME=$(get_pkg_name)

    if ! chkcmd "nvim"; then
        if [[ "${PKG_NAME}" = "brew" ]]; then
            ${PKG_NAME} install nvim gsed
        else
            if [[ $(id -u) -eq 0 ]]; then
                ${PKG_NAME} install neovim -y
            else
                sudo ${PKG_NAME} install neovim -y
            fi
        fi
    fi

    set_vi_alias
}

# Online install nvim
online_install() {
    check_in_china
    plug_install

    if [[ ! -d "${TMP_FOLDER}" ]]; then
        echo "Online install"
        
        [[ -z "${IN_CHINA}" ]] && PRO_URL=${PRO_URL//jihulab//github}
        git clone "${PRO_URL}" "${TMP_FOLDER}"
        cd "${TMP_FOLDER}"
    else
        cd "${TMP_FOLDER}" 
        git pull origin main
    fi

    ./install.sh --reinstall update
}

plug_install() {
    if [[ ! -f "${PLUG_FILE}" ]]; then
        [[ -z "${IN_CHINA}" ]] || GH="https://ghproxy.com/"
        curl -fsLo "${PLUG_FILE}" --create-dirs "${GH}https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    fi
}

sedi() {
    if [[ "${OS}" = "darwin" ]]; then
        gsed "$@"
    else
        sed "$@"
    fi
}

# Set plugins
set_plugins() {
    if [[ "${OS}" = "darwin" ]]; then
        chkcmd "gsed" || brew install gsed
    fi

    if [[ ! -f "${NVIM_CONF_FILE}" ]]; then
        [[ -d "${NVIM_CONF}" ]] || mkdir -p "${NVIM_CONF}"
        cp ./init.vim "${NVIM_CONF}/"
    fi

    local GIT_PLUGIN="./plugin/plugin.vim"
    local GIT_PLUGCFG="./plugin/plugcfg.vim"
    local PLUGIN_HAS=$(grep 'call plug#begin' "${NVIM_CONF_FILE}")
    local UPDATED
    if [[ -z "${PLUGIN_HAS}" ]]; then
        cat "${GIT_PLUGIN}" >>"${NVIM_CONF_FILE}"
        cat "${GIT_PLUGCFG}" >>"${NVIM_CONF_FILE}"
        UPDATED="Yes"
    else
        install_plugins
    fi

    update_plugcfg

    [[ -z "${UPDATED}" ]] || nvim +PlugUpdate
}

# install plugins
install_plugins() {
    local NUM=1
    IFS=$'\n'
    for PLUG in $(cat "${GIT_PLUGIN}" | grep "Plug "); do
        local PLUGIN=$(echo "${PLUG}" | cut -d "'" -f2)
        local PLUGIN_EXIST=$(grep "${PLUGIN}" "${NVIM_CONF_FILE}")
        if [[ -z "${PLUGIN_EXIST}" ]]; then
            local LINE_END=$(cat "${NVIM_CONF_FILE}" | grep -n 'call plug#end()' | cut -d ':' -f1)
            # ??? call plug#end() ???????????????
            printf "Add Plugin ${NUM}: %s\n" "${PLUGIN}"
            sedi -i "${LINE_END} i${PLUG}" "${NVIM_CONF_FILE}"

            NUM=$(expr ${NUM} + 1)
            UPDATED="Yes"
        fi
    done
}

# ???????????????????????????????????????????????????
update_plugcfg_fliter() {
    local CFG_NAME=$(echo "${1}" | awk '{print $2}')

    # rust-lang/rust.vim
    if [[ 'g:rust_clip_command' = "${CFG_NAME}" ]]; then
        [[ "${OS}" = "darwin" ]] || CFG="let g:rust_clip_command = 'xclip -selection clipboard'"
    fi
}

# ??????????????????
update_plugcfg() {
    # ????????????
    IFS=$'\n'
    for CFG in $(cat "${GIT_PLUGCFG}"); do
        # ?????? " ??????
        if ! [[ "${CFG}" =~ ^\".* ]]; then
            local PLUGCFG_KEY=$(echo "${CFG}" | cut -d "=" -f1)
            local PLUGCFG_EXIST=$(grep "${PLUGCFG_KEY}" "${NVIM_CONF}")

            # ??????????????? (????????????????????????)
            update_plugcfg_fliter "${PLUGCFG_KEY}"

            # ????????????????????????????????????
            if [[ -z "${PLUGCFG_EXIST}" ]]; then
                echo "${CFG}" >>"${NVIM_CONF}"
            else
                sedi -i "s@^${PLUGCFG_KEY}.*@${CFG}@" "${NVIM_CONF}"
            fi
        fi
    done
}

# ?????? nvim ???????????? vi
set_vi_alias() {
    local PROFILE="${HOME}/.bashrc"
    if [[ $(basename ${SHELL}) = 'zsh' ]]; then
        PROFILE="${HOME}/.zshrc"
    fi
    if [ -z "$(grep 'alias vi=nvim' ${PROFILE})" ]; then
        printf "\n## NeoVim\n" >>"${PROFILE}"
        echo "alias vi=nvim" >>"${PROFILE}"
    fi
}

# ??????????????????
remove_config() {
    [[ -d "${NVIM_CONF}" ]] && rm -rf "${NVIM_CONF}"
    [[ -f "${PLUG_FILE}" ]] && rm -rf "${PLUG_FILE}"
}

# ??????????????????
show_help() {
    printf "${0}

Options:

  --install   : Install vim-plug
  --reinstall : Reinstall vim-plug and update plugins
  --upgrade   : Upgrade vim-plug
  --uninstall : Remove vim-plug
  -h | --help : Help
\n"
}

main() {
    get_os
    load_var
    install_neovim

    if [[ $# -eq 0 ]]; then
        online_install
        exit
    fi

    case "${1}" in
    --install | --reinstall)
        check_in_china
        plug_install
        
        # ????????????
        [[ "${2}" = "update" ]] && git pull origin main

        # ??????
        [[ "${1}" = "--reinstall" ]] && remove_config

        set_plugins
        ;;

    --upgrade)
        cd ${HOME}
        [[ -d "${TMP_FOLDER}" ]] && rm -rf "${TMP_FOLDER}"
        online_install
        ;;

    --uninstall)
        [[ -d "${NVIM_CONF}" ]] && rm -rf "${NVIM_CONF}"
        if [[ ! -f "${NVIM_CONF_FILE}" ]]; then
            [[ -d "${NVIM_CONF}" ]] || mkdir -p "${NVIM_CONF}"
            cp "${TMP_FOLDER}/init.vim" "${NVIM_CONF}/"
        fi

        if [[ -f "${PLUG_FILE}" ]]; then
            nvim +:PlugClean
            rm -rf "${PLUG_FILE}"
        fi
        ;;
        

    -h | --help)
        show_help
        ;;
    esac
}

main "$@"
