#!/bin/bash

D="/home/ahmet-genc/git/hayguen/librtlsdr/build/src"

cd /dev/shm
if [ ! -d perftest ]; then
  mkdir perftest
fi

cd perftest
pwd


FREQSTART="87600"
NDONGLES="4"
# NCH: must be even: 4 / 6 / 8 / ..
NCH="8"
# calculate outer carrier frequencies: NCH = 8 => CH = 700
BH=$[ ($NCH - 1) * 100 ]
# calculate necessary bandwidth: 200 kHz per carrier + small tolerance
# check, that the output, i.e.
#    Bandwidth parameter 1650000 Hz resulted in 1600000 Hz.
# results in a bandwidth, that is >= calculated MINBW
# in other case, put in manual bandwidth value,
#   after checking available bandwidths with rtl_test
MINBW=$[ $NCH * 200 - 40 ]
BW=$[ $NCH * 200 + 50 ]
BUFSZ="512"
#NCIRCBUF="64"
NCIRCBUF="16"
TOTAL_BUF_SZ=$[ ( ${NCIRCBUF} * ${BUFSZ} ) / 2 ]
RT="-R 900"

# RDSSPLIT=10
# RDSLIMIT=4
# AUDSPLIT=60

# test by increasing the load with smaller splitsize
# RDSSPLIT=30
RDSSPLIT=20
RDSLIMIT=4
# AUDSPLIT=60
AUDSPLIT=30

# RDSSPLIT=28
# RDSLIMIT=4
# AUDSPLIT=300

MCPIDS=(0)


# time $D/rtl_multichannel -d 0 -v -f 105.1M -f -700k:700k:200k -m 2393k -w 1600k -M mwfm -W 512 -n ${NCIRCBUF} -t x:${RDSSPLIT} -t a:${AUDSPLIT} -l x:${RDSLIMIT} $RT -a p: -x p: 2>&1 |tee log0.txt

for k in $(seq 1 ${NDONGLES}); do
  dongle=$[ $k - 1]
  if [ -d $k ]; then
    rm -rf $k
  fi
  mkdir $k
  echo "==========================================================================="  >> $k/log${k}.txt
  echo "receive ${NCH} carrier with one dongle: half BH = ${BH} with bandwidth ${BW}" >> $k/log${k}.txt
  echo "verify resulting bandwidth is greater than MINBW = ${MINBW}"                  >> $k/log${k}.txt
  echo "NCIRCBUF = ${NCIRCBUF} (option -n) => consumes ${TOTAL_BUF_SZ} kB per dongle" >> $k/log${k}.txt
  echo "==========================================================================="  >> $k/log${k}.txt
  echo ""  >> $k/log${k}.txt
  echo ""  >> $k/log${k}.txt
  echo -e "$k : $[ $f - ${BH} ] .. $f .. $[ $f + ${BH} ]"  >> $k/log${k}.txt
done

f=$[ ${FREQSTART} + ${BH} ]
for k in $(seq 1 ${NDONGLES}); do
  dongle=$[ $k - 1]
  # try to avoid, that all redsea's are started/running at same time
  #   possibly increase RDSSPLIT
  sleep ${RDSLIMIT}
  echo -e "$k : $[ $f - ${BH} ] .. $f .. $[ $f + ${BH} ]"
            echo $D/rtl_multichannel -d $dongle -f ${f}k -f -${BH}k:${BH}k:200k -m 2393k -w ${BW}k -M mwfm -W ${BUFSZ} -n ${NCIRCBUF} -t x:${RDSSPLIT} -t a:${AUDSPLIT} -l x:${RDSLIMIT} $RT -a p: -x p:
  (cd $k && time $D/rtl_multichannel -d $dongle -f ${f}k -f -${BH}k:${BH}k:200k -m 2393k -w ${BW}k -M mwfm -W ${BUFSZ} -n ${NCIRCBUF} -t x:${RDSSPLIT} -t a:${AUDSPLIT} -l x:${RDSLIMIT} $RT -a p: -x p: 2>&1 |tee log${k}.txt) &
  MCPIDS[dongle]=$!
  f=$[$f + ${BH} + 200 + ${BH}]
done


# processes are running in background .. with some startup messages => wait
sleep 4

echo ""
echo ""

RDSOPTPLIT=$[ ( ${NDONGLES} * ( 10 * ${RDSLIMIT} + 3) ) / 10 ]
echo "==========================================================================="
if [ ${RDSSPLIT} -lt ${RDSOPTPLIT} ]; then
    echo "you should increase RDSSPLIT to have NDONGLES * RDSLIMIT = ${RDSOPTPLIT}"
    echo "that should avoid, that rdseas from multiple dongles run at same time"
else
    echo "RDSSPLIT = ${RDSSPLIT}   with  NDONGLES * RDSLIMIT + tolerance = ${RDSOPTPLIT}"
fi
echo "==========================================================================="
echo "receive ${NCH} carrier with one dongle: half BH = ${BH} with bandwidth ${BW}"
echo "verify resulting bandwidth is greater than MINBW = ${MINBW}"
echo "NCIRCBUF = ${NCIRCBUF} (option -n) => consumes ${TOTAL_BUF_SZ} kB per dongle"
echo "==========================================================================="
echo "waiting for PIDS: ${MCPIDS[*]}"
echo "==========================================================================="
echo ""
for pid in "${MCPIDS[*]}"; do
    wait $pid
done