FROM haskell:7.8

# install vim tooling
RUN apt-get update \
 && apt-get install -y git vim curl build-essential \
      # for vim extensions
      exuberant-ctags libcurl4-openssl-dev \
 && apt-get clean

# Haskell Vim setup
ADD install.sh /install.sh
RUN chmod +x /install.sh
RUN /install.sh && rm -r /root/.cabal
