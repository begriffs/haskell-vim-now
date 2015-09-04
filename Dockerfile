FROM haskell:7.8

# install vim tooling
RUN apt-get update \
 && apt-get install -y git vim curl build-essential \
      # for vim extensions
      exuberant-ctags libcurl4-openssl-dev \
 && apt-get clean

# Haskell Vim setup
ADD https://raw.githubusercontent.com/begriffs/haskell-vim-now/master/install.sh /install.sh
RUN /bin/bash /install.sh && rm -r /root/.cabal
