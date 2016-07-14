: ${TOSROOT:?"Need to set TOSROOT. TinyOS enviromental variables not set correctly."}

echo "Copying TinySDN base files to $TOSROOT/tos/lib/net/..."

if cp TinySDNSocketIdP.nc $TOSROOT/tos/lib/net/TinySDNSocketIdP.nc; then 
	echo "TinySDNSocketIdP.nc file -> OK"
else 
	echo -e "\e[0;31mTinySDN installation has NOT been completed!\e[0m"
	exit 1
fi 


if cp TinySDNSocketId.nc $TOSROOT/tos/lib/net/TinySDNSocketId.nc; then 
	echo "TinySDNSocketId.nc file -> OK"
else 
	echo -e "\e[0;31mTinySDN installation has NOT been completed!\e[0m"
	exit 1
fi 
    

if cp TinySDNSocketPacket.nc $TOSROOT/tos/lib/net/TinySDNSocketPacket.nc; then
	echo "TinySDNSocketPacket.nc file -> OK"
else 
	echo -e "\e[0;31mTinySDN installation has NOT been completed!\e[0m"
	exit 1
fi 


rm -r -f $TOSROOT/tos/lib/net/TinySDN/
if cp -r -f ./TinySDN/ $TOSROOT/tos/lib/net/TinySDN/; then
	echo "TinySDN folder -> OK"
else 
	echo -e "\e[0;31mTinySDN installatiocn has NOT been completed!\e[0m"
	exit 1
fi 

echo -e "\e[1;34mTinySDN installation has been completed!\e[0m"
exit 1
