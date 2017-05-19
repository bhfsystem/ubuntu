ifeq (nih,$(firstword $(MAKECMDGOALS)))
VIP := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(VIP):;@:)
endif
VIP ?= 172.28.128.1

SHELL = bash

BLOCK_PATH ?= $(HOME)/work

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(patsubst %/,%,$(dir $(mkfile_path)))

docker_host := $(shell aws ecr describe-repositories | jq -r --arg repo block '.repositories | map(select(.repositoryName == $$repo))[].repositoryUri' | cut -d/ -f1)

all:
	@true

cache:
	rm -f .bashrc.cache
	@bash .bashrc
	@bash .bashrc

sync:
	git pull
	$(make) sync_fr

sync_fr:
	cd /config && git pull
	git submodule update --init
	cat Blockfile.lock  | envsubst | runmany 1 5 'set -x; cd $$2 && git checkout --force $$5 && git reset --hard $$4 || (cd $$2 && git fetch && git checkout --force $$5 && git reset --hard)'
	$(make) cache

include $(BLOCK_PATH)/base/Makefile.docker

docker_default = docker-image

aws_default = aws-image

docker-image:
	time $(make) home=$(block) recycle home-deploy image-update

aws-image:
	time env BASEBOX_NAME_OVERRIDE=block:ubuntu AWS_SYNC=/data/cache/packages/$(ID_INSTALL) AWS_TYPE=$(aws_type) chexec $(current_dir) $(make) home=$(block) aws-image-fr

aws-image-fr:
	van recycle
	van vagrant ssh -- sudo sudo dpkg --configure -a
	van vagrant ssh -- sudo apt-get update
	time script/deploy van vagrant ssh --
	(cd $(BLOCK_PATH)/base && make new-cidata)
	time van reuse ubuntu

docker-update: /config/ssh/authorized_keys
	time $(make) recycle home-deploy block-finish minimize commit
	time $(make) build
	$(make) clean

docker-save-all:
	mkdir -p /data/cache/box/docker
	docker images | grep $(docker_host)| perl -ne '@w = split /\s+/, $$_; print "$$w[0]:$$w[1]\n" unless $$base; $$base = 1 if $$w[1] eq "base"' | xargs docker save -o /data/cache/box/docker/block-all.tar.1
	mv -f /data/cache/box/docker/block-all.tar.1 /data/cache/box/docker/block-all.tar

docker-save:
	mkdir -p /data/cache/box/docker
	docker save -o /data/cache/box/docker/block-ubuntu.tar.1 $(docker_host)/block:{base,ubuntu}
	mv -f /data/cache/box/docker/block-ubuntu.tar.1 /data/cache/box/docker/block-ubuntu.tar

virtualbox:
	env BASEBOX_NAME_OVERRIDE=block:ubuntu $(make) virtualbox_fr

virtualbox_fr:
	(cd $(BLOCK_PATH)/base && make new-cidata)
	plane recycle block:ubuntu
	plane vagrant ssh -- sudo sudo dpkg --configure -a
	plane vagrant ssh -- sudo apt-get update
	time script/deploy plane vagrant ssh --
	(cd $(BLOCK_PATH)/base && make new-cidata)
	time plane reuse ubuntu

/config/ssh/authorized_keys:
	git clone git@github.com:imma/imma-config /config 2>/dev/null || true
	rsync -ia .ssh/authorized_keys /config/ssh/

update:
	$(make) sync
	home update

add-modules:
	block list | awk '/\/work\// {print $$3, $$2}' | perl -pe 's{[^\s]+?/work/}{work/}' | runmany 1 2 'git submodule add -f -b $(shell git rev-parse --abbrev-ref HEAD) $$1 $$2'

update-modules:
	block list | awk '/\/work\// {print $$3, $$2}' | perl -pe 's{[^\s]+?/work/}{work/}' | grep -v 'work/ubuntu' | runmany 1 2 'git update-index --cacheinfo 160000 $$(cd $(BLOCK_PATH)/../$$2 && git rev-parse HEAD) $$2'

lock:
	$(make) update-modules || true
	block lock
	git add -u work Blockfile.lock
	gs

reset:
	docker tag $(hub)/block:base $(registry)/$(image)

reset-virtualbox:
	vagrant box add -f block:ubuntu /data/cache/box/virtualbox/block-base.box

reset-aws:
	vagrant box add -f block:ubuntu /data/cache/box/aws/block-base.box

rebuild:
	$(make) rebuild-ubuntu
	$(make) save-ubuntu
	$(make) rebuild-kids

rebuild-kits:
	$(make) up
	$(make) wait-ssh
	$(make) remote rebuild-nih
	$(make) clean
	$(make) up
	$(make) up-nih
	$(make) prune
	docker images | grep $(docker_host)

rebuild-ubuntu:
	$(make) docker-update

save-ubuntu:
	$(make) docker-save
