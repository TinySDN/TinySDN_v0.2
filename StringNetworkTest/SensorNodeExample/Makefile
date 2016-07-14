COMPONENT=SDNEnabledSensorNodeTestAppC


CFLAGS += -I$(TOSDIR)/lib/net/ -I$(TOSDIR)/lib/net/TinySDN/ -I$(TOSDIR)/lib/net/ctp -I$(TOSDIR)/lib/net/TinySDN/4bitle #-I/home/btrevizan/TinySDN-code/CodigosSendoTrabalhado/TinyOSComponents/TinySDN/
#CFLAGS += -I$(TOSDIR)/lib/net/4bitle
#CFLAGS += -I$(TOSDIR)/lib/net/ctp


CFLAGS += -I/opt/tinyos-2.1.0/tos/chips/cc2420/packet/ -I/opt/tinyos-2.1.0/tos/chips/cc2420
CFLAGS += -I$(TOSDIR)/tos/chips/cc2420/interfaces

PFLAGS += -RECEIVE_HISTORY_SIZE=0

CFLAGS += -I$(TOSDIR)/lib/printf #for TinyOS Printf Library using
CFLAGS += -DNEW_PRINTF_SEMANTICS #for TinyOS Printf Library using
#CFLAGS += -DPRINTF_DEV_DEBUG #for development printf debug (requires NEW_PRINTF_SEMANTICS definition)

CFLAGS += -DTOSH_DATA_LENGTH=128

include $(MAKERULES)
