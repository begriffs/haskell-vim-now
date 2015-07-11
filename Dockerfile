FROM haskell:7.8

# set haskell vim now install package
ENV hvn /root/.haskell-vim-now

# install vim tooling
RUN apt-get update \
 && apt-get install -y git vim curl build-essential \
      # for vim extensions
      exuberant-ctags libcurl4-openssl-dev \
 && apt-get clean

# Haskell Vim setup
ADD . $hvn
RUN chmod +x $hvn/install.sh
RUN $hvn/install.sh && rm -r /root/.cabal
