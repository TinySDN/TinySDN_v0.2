/**
 * SDN-enabled Sensor Node Test application using the TinySDN layer.
 * See README.txt
 *
 * @author Bruno Trevizan de Oliveira
  */

//#include "SDNEnabledSensorNode.h"
#include "CC2420.h"
#include "printf.h"
#include "Topology.h"

configuration SDNEnabledSensorNodeTestAppC {}
implementation {
  components  MainC, SDNEnabledSensorNodeTestC as App, LedsC, new TimerMilliC(), CC2420ActiveMessageC;

  App.Boot -> MainC;
  App.Timer -> TimerMilliC;
  App.Leds -> LedsC;

  components SerialPrintfC;
  components SerialStartC;


  components TinySDNSocketC,  // Collection layer
    ActiveMessageC,                   // AM layer
    new TinySDNSocketSenderC(AM_MVIZ_MSG, 0xEF); // Sends multihop RF

  components TinySdnP as TinySdn;

  App.RadioControl -> ActiveMessageC;
  App.RoutingControl -> TinySDNSocketC;

  App.Send -> TinySDNSocketSenderC;
  App.Receive -> TinySDNSocketC.Receive[AM_MVIZ_MSG];


}
