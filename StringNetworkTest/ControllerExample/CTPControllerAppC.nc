#include "TinySdnController.h"
#include "Topology.h"
#include "printf.h"
#define NEW_PRINTF_SEMANTICS


configuration CTPControllerAppC {}
implementation {
  components MainC, CTPControllerC as App, LedsC, SerialPrintfC;
  components new AMSenderC(AM_TINYSDN_DATA);//AM_TINYSDN_CONTROLLER_MSG);

  components new AMReceiverC(AM_TINYSDN_CONTROLLER_MSG);
  components new AMReceiverC(0xda) as AMReceiver3;

  components new TimerMilliC();
  components ActiveMessageC;
  components SerialStartC;

  components new AMSenderC(AM_RSSIMSG) as rssiSender;
  components new AMReceiverC(AM_RSSIMSG) as rssiReceiver;

  components new AMSenderC(AM_TOPOLOGY_MSG) as TopologyMsgSender;
  components new AMReceiverC(AM_TOPOLOGY_MSG) as TopologyMsgReceiver;


  App.Boot -> MainC.Boot;

  App.receiveId2 -> AMReceiver3;
  App.receiveEtx -> AMReceiverC;

  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.MilliTimer -> TimerMilliC;
  App.Packet -> AMSenderC;

  components CollectionC as Collector;

  App.CTPreceive -> Collector.Receive[0xEF];
  App.RootControl-> Collector;
  App.CTPcontrol -> Collector;
  App.CollectionPacket -> Collector;


  App.beaconSend -> TopologyMsgSender;
  App.beaconReceive -> TopologyMsgReceiver;

  App.rssiAMSend -> rssiSender;
  App.Receive -> rssiReceiver;
  App.rssiPacket -> rssiSender;

  components new CollectionSenderC(0x02);
  App.Send -> CollectionSenderC;

}
