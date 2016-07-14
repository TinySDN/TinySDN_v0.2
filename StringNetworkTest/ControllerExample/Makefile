COMPONENT=CTPControllerAppC
CFLAGS += -I$(TOSDIR)/lib/net/ -I$(TOSDIR)/lib/net/ctp -I$(TOSDIR)/lib/net/4bitle -I.
CFLAGS += -I/opt/tinyos-2.1.0/tos/chips/cc2420/packet/ -I/opt/tinyos-2.1.0/tos/chips/cc2420
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -I$(TOSDIR)/lib/net/TinySDN

PFLAGS += -RECEIVE_HISTORY_SIZE=0

CFLAGS += -I$(TOSDIR)/lib/T2Hack

CFLAGS += -DTOSH_DATA_LENGTH=128

TestSerial.class: $(wildcard *.java) TestSerialMsg.java
	javac -target 1.4 -source 1.4 *.java

TestSerialMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=TestSerialMsg MViz.h test_serial_msg -o $@


include $(MAKERULES)
