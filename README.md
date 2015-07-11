# Introduction
Learning Haskell is enjoyful but preparing an efficient development environment is painful. I don't want to quit again due to tooling issues. This repository will help us to dive into the wonderful world of Haskell after following some simple instructions.

All of us own a big thanks to Joe Nelson's great work on [Haskell Vim Now](https://github.com/begriffs/haskell-vim-now).

If you want to install all the staffs locally, please use Joe's [one-line command](https://github.com/begriffs/haskell-vim-now). This work only targets docker users.

# How to use
A docker image is built automatically on [docker hub](https://registry.hub.docker.com/u/huiwang/haskell-vim-now/).
## Pull the image
The command below pulls the latest image from docker hub.
```sh
docker pull huiwang/haskell-vim-now
```
## Run a container
This command fires up a container of this image by mounting your project to the specified path. 
```sh
docker run -t -i --rm -v $path_to_your_project:/home/$your_name/$your_project huiwang/haskell-vim-now bash
```
## Develop
Once logged in, go to /home/$your_name/$your_project, and start developing
```sh
vim somefile.hs
```
# How to customize
Fork this repository, and make a [automated build](https://docs.docker.com/docker-hub/builds/) pointing to the forked one. 
Tool installation is described in `install.sh`.
Vim configuratoins can be found in `.vimrc`

[Pull requests](https://help.github.com/articles/creating-a-pull-request/) are welcomed.
