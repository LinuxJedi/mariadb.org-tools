#!/bin/sh

set -x -v

build()
{
	source=$1
	mkdir build
	cd build
	/opt/bin/ccache --zero-stats
	cmake ../$source -DCMAKE_BUILD_TYPE="$2" \
		-DCMAKE_C_LAUNCHER=/opt/bin/ccache \
		-DCMAKE_CXX_LAUNCHER=/opt/bin/ccache \
		-DCMAKE_C_COMPILER=gcc \
		-DCMAKE_CXX_COMPILER=g++ \
		-DCMAKE_AR=/usr/bin/ar \
		-DLIBXML2_LIBRARY=/opt/freeware/lib/libxml2.a \
		-DPLUGIN_TOKUDB=NO \
		-DPLUGIN_MROONGA=NO \
		-DPLUGIN_SPIDER=NO \
		-DPLUGIN_OQGRAPH=NO \
		-DPLUGIN_SPHINX=NO \
		-DWITH_UNIT_TESTS=NO \
		-DPLUGIN_S3=NO \
		-DWITH_MARIABACKUP=NO \
		-DPLUGIN_WSREP_INFO=NO
	make -j"$(( $jobs * 2 ))"
	/opt/bin/ccache --show-stats
}

mariadbtest()
{
	# for saving logs
	ln -s build/mysql-test
	mysql-test/mysql-test-run.pl --verbose-restart --force --retry=3 --max-save-core=1 --max-save-datadir=1 \
		--skip-test='connect\.(grant|updelx)$' --max-test-fail=20 --parallel="$jobs"

}

clean()
{
	ls -ad "$@"
	rm -rf "$@" 2> /dev/null
}


export TMPDIR=$HOME/tmp
export LIBPATH=/opt/freeware/lib/pthread/ppc64:/opt/freeware/lib:/usr/lib
jobs=${4:-12}

case $1 in
	build)
		shift
		build "$@"
		;;
	test)
		mariadbtest
		;;
	clean)
		clean mariadb* build* mysql-test /mnt/packages/* /buildbot/logs/*
		;;
esac