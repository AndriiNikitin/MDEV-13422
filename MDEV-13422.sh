set -e

M7VER=${M7VER:-10.1}
M7VER2=${M7VER2:-$M7VER}
M7_EXTRA_OPTS=${M7_EXTRA_OPTS:-""}

# just use current directory if called from framework
if [ ! -f common.sh ] ; then
  [ -d mariadb-environs ] || git clone http://github.com/AndriiNikitin/mariadb-environs
  cd mariadb-environs
fi

function collectInfo {
  echo ==== m1 ERROR LOG =====
  cat m1*/dt/error.log
  echo ==== m2 ERROR LOG =====
  cat m2*/dt/error.log
  echo ==== datadirs =====
  ls -la m1*/dt
  ls -la m2*/dt
}


function onExit {
  [ "$passed" == 1 ] || collectInfo
}
trap onExit EXIT

[ -d m0-system ] || ./replant.sh m0-system
[ -d m1-system2 ] || ./replant.sh m1-system2
[ -d m2-$M7VER2 ] || ./replant.sh m2-$M7VER2

sudo _system/uninstall.sh || :
sudo m0*/install.sh ${M7VER} backup
m1*/gen_cnf.sh $M7_EXTRA_OPTS
m1*/install_db.sh
m1*/startup.sh

[ -d m2-$M7VER2/build ] || ./build_or_download.sh m2

m2*/gen_cnf.sh $M7_EXTRA_OPTS

mariabackup --defaults-file=m1-system2/my.cnf --backup --target-dir=m2-${M7VER2}/dt
mariabackup --prepare --target-dir=m2-${M7VER2}/dt

# see MDEV-13311 - 10.2+ needs to remove ib_logfile0 if its size is 0
[ -s m2*/dt/ib_logfile0 ] || rm m2*/dt/ib_logfile0

m2*/startup.sh
m2*/status.sh

passed=1
