# Introduction
Learning Haskell is enjoyful but preparing an efficient development environment is tedious. I don't want to quit again due to tooling issues. This repository will make our life easier in learning Haskell.

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
Fork this repository, and make an [automated build](https://docs.docker.com/docker-hub/builds/) pointing to the forked one. 
Tool installation is described in `install.sh`.
Vim configuratoins can be found in `.vimrc`

[Pull requests](https://help.github.com/articles/creating-a-pull-request/) are welcomed.

# Future work
I wish to adopt more modern tools to make the workflow easier
- [Stack](https://github.com/commercialhaskell/stack) instead of cabal-install
- Guard and Guard-shell to automatically compile and run tests as shown in [Haskell Live](http://haskelllive.com/environment.html)
