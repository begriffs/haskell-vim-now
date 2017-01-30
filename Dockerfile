FROM haskell:7.8

# install vim tooling
RUN apt-get update \
 && apt-get install -y git vim curl wget build-essential \
      # for vim extensions
      exuberant-ctags libcurl4-openssl-dev \
 && apt-get clean

# install stack
RUN wget -q -O- https://s3.amazonaws.com/download.fpcomplete.com/debian/fpco.key | apt-key add -
RUN echo 'deb http://download.fpcomplete.com/debian/jessie stable main'| tee /etc/apt/sources.list.d/fpco.list
RUN apt-get update \
 && apt-get install -y stack \
 && apt-get install -y sudo \
 && apt-get clean

# Haskell Vim setup
ADD https://raw.githubusercontent.com/begriffs/haskell-vim-now/master/install.sh /install.sh
RUN /bin/bash /install.sh
