include:
  - minion-swarm-host.repos

docker.packages:
  pkg.installed:
    - pkgs:
        - docker
        - python-docker-py
    - require:
      - sls: minion-swarm-host.repos
    - unless: rpm -q docker && rpm -q python-docker-py

vdb1.device:
    cmd.run:
      - name: /usr/sbin/parted -s /dev/vdb mklabel gpt && /usr/sbin/parted -s /dev/vdb mkpart primary 2048 100% && /sbin/mkfs.btrfs /dev/vdb1
      - unless: ls /dev/vdb1

/var/lib/docker:
  file.directory:
    - user: root
    - group: users
    - mode: 700
    - makedirs: True
  mount.mounted:
    - device: /dev/vdb1
    - fstype: btrfs
    - mkmnt: True
    - persist: True
    - opts:
      - defaults
    - require:
        - cmd: vdb1.device

docker.service:
  service.running:
    - name: docker
    - enable: True
    - require:
      - pkg: docker.packages
      - file: /var/lib/docker

docker.sle-image.pkg:
  pkg.installed:
    - pkgs:
        - sles12-docker-image
    - require:
      - sls: minion-swarm-host.repos
    - unless: rpm -q sles-12-docker-image

docker.sle-image:
  cmd.run:
    - name: cat /usr/share/suse-docker-images/sles12-docker.*.xz | docker import - suse/sles12
    - unless: docker history suse/sles12
    - require:
        - pkg: docker.sle-image.pkg
        - pkg: docker.packages
        - service: docker.service

docker.minion-image:
  cmd.run:
    - name: docker build -t minion /srv/salt/minion-swarm-host/docker/minion
    - unless: docker history minion
    - require:
        - cmd: docker.sle-image
        - service: docker.service

/root/run.sh:
  file.managed:
    - source: salt://minion-swarm-host/run.sh
    - mode: 755