docker run --rm -it -v /workspaces/jubilant-octo-giggle:/workspaces:rw debian:sid-slim bash -c "
    apt update && \
    apt install curl -y && \
    sed -i 's/^/\#/g' /etc/apt/sources.list.d/debian.sources && \
    apt clean && \
    curl -sfLo /etc/apt/trusted.gpg.d/jubilant-octo-giggle-keyring.asc https://iwconfig.github.io/jubilant-octo-giggle/gpg.key && \
    printf '%s https://iwconfig.github.io/jubilant-octo-giggle/ sid main\n' deb deb-src >/etc/apt/sources.list.d/jubilant-octo-giggle.list && \
    apt update && \
    exec bash
"