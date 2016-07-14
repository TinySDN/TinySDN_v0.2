#!/usr/bin/env bash

BASEDIR=$(dirname "$0")
cd $BASEDIR; cd ./../TinyOSComponents/; ./install.sh;
cd ../StringNetworkTest/;
cd ControllerExample/;
make telosb;
cd SideControllerExample/;
make telosb;
cd ../SensorNodeExample/;
make telosb;
