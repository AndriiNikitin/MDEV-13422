set -e

M7VER=${M7VER:-10.1}
M7VER2=${M7VER2:-$M7VER}
IMAGE=${IMAGE:-centos}
M7_EXTRA_OPTS=${M7_EXTRA_OPTS:-""}

[ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs

mkdir -p docker-context
mkdir -p docker-context-MDEV-13422
cp mariadb-environs/*.sh docker-context
cp -R mariadb-environs/_template docker-context
cp -R mariadb-environs/_plugin docker-context

cp MDEV-13422.sh docker-context-MDEV-13422
# this to reset docker cache if new commit was in the tree
commithash=$(git ls-remote --heads http://github.com/MariaDB/server refs/heads/$M7VER2)


tee docker-context/Dockerfile <<EOF
from $IMAGE

WORKDIR /farm/_template
COPY _template /farm/_template
WORKDIR /farm/_plugin
COPY _plugin /farm/_plugin
WORKDIR /farm
COPY *.sh /farm/

RUN _template/install_m-system_dep.sh
RUN _template/install_m-branch_dep.sh

ENV M7VER $M7VER
ENV M7VER2 $M7VER2
EOF

exec 5>&1
baseid=$(docker build docker-context 2>&1 |tee /dev/fd/5 |  awk '/Successfully built/{print $NF}'; exit ${PIPESTATUS[0]})

tee docker-context-MDEV-13422/Dockerfile <<EOF
from $baseid
RUN ./replant.sh m0-system
RUN m0*/install.sh ${M7VER} backup
RUN ./replant.sh m2-$M7VER2
# this should invalidate cache when new commit comes
RUN echo $commithash
RUN ./build_or_download.sh m2
ADD MDEV-13422.sh /farm/
RUN bash -v -x MDEV-13422.sh
EOF

docker build docker-context-MDEV-13422