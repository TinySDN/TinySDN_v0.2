/**
 * SDN-enabled Sensor Node Test application using the TinySDN layer.
 * See README.txt
 *
 * @author Bruno Trevizan de Oliveira
  */

#include "SDNEnabledSensorNode.h"
#include "CC2420.h"
#include "printf.h"

module SDNEnabledSensorNodeTestC {
  uses {
    // Interfaces for initialization:
    interface Boot;
    interface SplitControl as RadioControl;
    interface StdControl as RoutingControl;

    // Interfaces for communication, multihop:
    interface AMSend as Send;
    interface Receive;
    interface TinySDNSocketPacket;

    // Miscalleny:
    interface Timer<TMilli>;
    interface Leds;

  }
}

implementation {

  message_t packet;

  bool locked;
  uint16_t counter = 0;

  event void Boot.booted() {
    printf("SDN-enabled sensor booted\n");
    printfflush();
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err == SUCCESS) {
	    call RoutingControl.start();
      if(TOS_NODE_ID == 5 /*|| TOS_NODE_ID == 4 || TOS_NODE_ID == 3*/) call Timer.startOneShot(5000);
    }
    else {
      call RadioControl.start();
    }
  }

  event void RadioControl.stopDone(error_t err) {
    // do nothing
  }

  event void Timer.fired() {
    counter++;
    dbg("SDNEnabledSensorNodeTestC", "SDNEnabledSensorNodeTestC: timer fired, counter is %hu.\n", counter);
    call Leds.set(counter);
    if (locked) {
      return;
    }
    else {
      radio_count_msg_t* rcm = (radio_count_msg_t*)call Send.getPayload(&packet, sizeof(radio_count_msg_t));
      if (rcm == NULL) {
	return;
      }

      rcm->counter = counter;
      if (call Send.send(2016, &packet, sizeof(radio_count_msg_t)) == SUCCESS) {
	dbg("SDNEnabledSensorNodeTestC", "SDNEnabledSensorNodeTestC: packet sent.\n", counter);
	locked = TRUE;
        printf("\nAPP : data packet has been sent, counter value = %u\n\n", counter);
        printfflush();
      }
      else{
        printf("APP : Data send failed\n");
        printfflush();

      }
    }
  }

  event message_t* Receive.receive(message_t* bufPtr,
				   void* payload, uint8_t len) {

    dbg("SDNEnabledSensorNodeTestC", "SDNEnabledSensorNodeTestC: received packet of length %hhu.\n", len);
    if (len != sizeof(radio_count_msg_t)) {return bufPtr;}
    else {
      radio_count_msg_t* rcm = (radio_count_msg_t*)payload;
      dbg("SDNEnabledSensorNodeTestC", "SDNEnabledSensorNodeTestC: received packet with counter = %hhu.\n", rcm->counter);
      call Leds.set(rcm->counter);
        printf("\nAPP : data packet has been received, counter value = %u\n\n", rcm->counter);
      printfflush();
      return bufPtr;
    }
  }

  event void Send.sendDone(message_t* bufPtr, error_t error) {
    #ifdef PRINTF_DEV_DEBUG
    printf("Chegou no sendDone()\n");
    printfflush();
    #endif
    if (&packet == bufPtr) {
      locked = FALSE;
    }

    if (call Timer.getdt()!=DEFAULT_INTERVAL) {
      call Timer.startPeriodic(DEFAULT_INTERVAL);
    }

  }

}
