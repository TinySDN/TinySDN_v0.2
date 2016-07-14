/*
 * Copyright (c) 2008-9 Stanford University.
 * Copyright (c) 2016 University of São Paulo (regarding modifications)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL COPYRIGHT
 * HOLDERS OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * @author Bruno Trevizan de Oliveira
 * @date April 4 2016
 *
 * This TinyOS component was implementated based on original CtpForwardingEngineP.nc by Philip Levis and Kyle Jamieson
 **/

#include <CtpForwardingEngine.h>
#include <LinkEstimator.h>
#include "TinySdnController.h"
#include "FlowTable.h"
#include "ControlFlowTable.h"



generic module TinySdnForwardingEngineP() {
  provides {
    interface Init;
    interface StdControl;
    interface AMSend as Send[uint8_t client];
    //interface Send as SendTopology[uint8_t client];
    interface Receive[tinysdnsocket_id_t id];
    interface Intercept[tinysdnsocket_id_t id]; // Bruno: interface used to collect information forwarding actions
    interface Packet;
    interface TinySDNSocketPacket;
    interface TinySdnPacket;
    interface TinySdnReportTopologyPacket;

    interface CtpCongestion;
  }
  uses {
    // These five interfaces are used in the forwarding path
    //   SubSend is for sending packets
    //   RetxmitTimer is for timing packet sends for improved performance
    interface AMSend as SubSend;
    interface Timer<TMilli> as RetxmitTimer;
    interface Packet as SubPacket;

    // These four data structures are used to manage packets to forward.
    // SendQueue and QEntryPool are the forwarding queue.
    // MessagePool is the buffer pool for messages to forward.
    // SentCache is for suppressing duplicate packet transmissions.
    interface Queue<fe_queue_entry_t*> as SendQueue;
    interface Pool<fe_queue_entry_t> as QEntryPool;
    interface Pool<message_t> as MessagePool;
    interface Cache<message_t*> as SentCache;

    //This data structure is used to
    //interface Queue<fe_queue_entry_t*> as WaitingToBeSentQueue;

    interface Receive as SubReceive;
    interface TinySDNSocketId[uint8_t client];
    interface AMPacket;
    interface Random;

    // The ForwardingEngine monitors whether the underlying
    // radio is on or not in order to start/stop forwarding
    // as appropriate.
    interface SplitControl as RadioControl;


    //timer to send reportMsg
    interface Timer<TMilli> as NotifyTimer;

    //interface TinySdnTopologyInfo;

    interface LinkEstimator;
    interface PacketAcknowledgements;

    interface Init as initLE;

    interface Send as CTPSendToController;

    interface StdControl as StdControlTopologyCollection;

    interface UnicastNameFreeRouting as CTPPathToController;

  }
}


implementation {

  message_t packet;

  uint8_t seqNumber;

  /* Helper functions to start the given timer with a random number
   * masked by the given mask and added to the given offset.
   */
  static void startRetxmitTimer(uint16_t mask, uint16_t offset);
  void clearState(uint8_t state);
  bool hasState(uint8_t state);
  void setState(uint8_t state);

  // CState variables.
  enum {
    QUEUE_CONGESTED       = 0x01, // Need to set C bit?
    FORWARDING_ON         = 0x02, // Forwarding running?
    RADIO_ON              = 0x04, // Radio is on?
    ACK_PENDING           = 0x08, // Have an ACK pending?
    SENDING               = 0x10, // Am sending a packet?
    CONTROLLER_ASSIGNED   = 0x20, // Have I assigned to an SDN Controller?
    REQUESTING            = 0x40  // Am doing a request to the Controller?
  };

  // Start with all states false
  uint8_t forwardingState = 0;

  enum {
    CLIENT_COUNT = uniqueCount(UQ_TINYSDN_CLIENT)
  };

 //------------------------------------------------------------------------------------------------------------
 // Flow Tables
  uint16_t controlFlowTableActive = 0;
  uint16_t controlFlowTableFindEntry(am_addr_t dest);
  error_t controlFlowTableUpdate(am_addr_t dest, am_addr_t nextHop);
  control_flow_table_entry controlFlowTable[CONTROL_FLOW_TABLE_SIZE];

  uint16_t flowTableActive = 0;
  uint16_t flowTableFindEntry(uint16_t dataFlowID);
  error_t flowTableUpdate(uint16_t updatingDataFlowID, uint8_t updatingActionId, uint16_t updatingActionParam);
  flow_table_entry flowTable[FLOW_TABLE_SIZE];

 //--------------------------------------------------------------------------------------------------------------
  bool controlFlowUpwardThroughCTP = FALSE;
 //--------------------------------------------------------------------------------------------------------------

  neighbor_table_entry neighborTable[NEIGHBOR_TABLE_SIZE]; //
  uint16_t neighborTableActive = 0; //number of neighbors in neighborTable
  bool locked = FALSE;




  /* Each sending client has its own reserved queue entry.
     If the client has a packet pending, its queue entry is in the
     queue, and its clientPtr is NULL. If the client is idle,
     its queue entry is pointed to by clientPtrs. */

  fe_queue_entry_t clientEntries[CLIENT_COUNT];
  fe_queue_entry_t* ONE_NOK clientPtrs[CLIENT_COUNT];

  /* The loopback message is for when a collection roots calls
     Send.send. Since Send passes a pointer but Receive allows
     buffer swaps, the forwarder copies the sent packet into
     the loopbackMsgPtr and performs a buffer swap with it.
     See sendTask(). */

  message_t loopbackMsg;
  message_t* ONE_NOK loopbackMsgPtr;

  neighbor_table_entry reportNeighborTable[NEIGHBOR_TABLE_SIZE];
  uint16_t reportNeighborTableActive = 0;

  uint8_t pullOriginSeqNo();

  rssi_beacon_msg *beaconMsg;
  message_t beaconMsgBuffer;

  command error_t Init.init() {
    int i;
    for (i = 0; i < CLIENT_COUNT; i++) {
      clientPtrs[i] = clientEntries + i;
      dbg("Forwarder", "clientPtrs[%hhu] = %p\n", i, clientPtrs[i]);
    }
    seqNumber=0;
    loopbackMsgPtr = &loopbackMsg;

    return SUCCESS;
  }

  command error_t StdControl.start() {
    //printf("StdControl.start()");
    //printfflush();
    setState(FORWARDING_ON);
    return SUCCESS;
  }

  command error_t StdControl.stop() {
    clearState(FORWARDING_ON);
    return SUCCESS;
  }
  /* sendTask is where the first phase of all send logic
   * exists (the second phase is in SubSend.sendDone()). */
  task void sendTask();

  event void RadioControl.startDone(error_t err) {

    call initLE.init();

    if (err == SUCCESS) {
      setState(RADIO_ON);

      if (!call SendQueue.empty()) {
        dbg("FHangBug", "%s posted sendTask.\n", __FUNCTION__);
        post sendTask();
      }

    }
  }


  static void startRetxmitTimer(uint16_t window, uint16_t offset) {
    uint16_t r = call Random.rand16();
    r %= window;
    r += offset;
    call RetxmitTimer.startOneShot(r);
    dbg("Forwarder", "Rexmit timer will fire in %hu ms\n", r);
  }

  event void RadioControl.stopDone(error_t err) {
    if (err == SUCCESS) {
      clearState(RADIO_ON);
    }
  }

  tinysdn_data_header_t* getHeader(message_t* m) {
    return (tinysdn_data_header_t*)call SubPacket.getPayload(m, sizeof(tinysdn_data_header_t));
  }
  command error_t Send.send[uint8_t client](am_addr_t destinationFlowID, message_t* msg, uint8_t len) {
    tinysdn_data_header_t* hdr;
    fe_queue_entry_t *qe;

    dbg("Forwarder", "%s: sending packet from client %hhu: %x, len %hhu\n", __FUNCTION__, client, msg, len);
    if (!hasState(FORWARDING_ON) || !hasState(CONTROLLER_ASSIGNED)) {
      return EOFF;
    }
    if (len > call Send.maxPayloadLength[client]()) {
      return ESIZE;
    }
    if (clientPtrs[client] == NULL) {
      dbg("Forwarder", "%s: send failed as client is busy.\n", __FUNCTION__);
      return EBUSY;
    }

    call Packet.setPayloadLength(msg, len);

    hdr = getHeader(msg);

    hdr->thl = 0;
    hdr->originSeqNo  = pullOriginSeqNo();
    hdr->tinySdnSocketID = call TinySDNSocketId.fetch[client]();

    hdr->type = DATA_PACKET;
    hdr->origin = TOS_NODE_ID;
    hdr->destination = destinationFlowID;

    qe = clientPtrs[client];
    qe->msg = msg;
    qe->client = client;
    qe->retries = MAX_RETRIES;
    dbg("Forwarder", "%s: queue entry for %hhu is %hhu deep\n", __FUNCTION__, client, call SendQueue.size());
    if (call SendQueue.enqueue(qe) == SUCCESS) {
      #ifdef PRINTF_DEV_DEBUG
      printf("Enfileirou1 QSize %u \n", call SendQueue.size());
      printfflush();
      #endif
      if (hasState(RADIO_ON) && !hasState(SENDING)) {
        dbg("FHangBug", "%s posted sendTask.\n", __FUNCTION__);
        post sendTask();
      }
      clientPtrs[client] = NULL;
      return SUCCESS;
    }
    else {
      #ifdef PRINTF_DEV_DEBUG
      printf("Erro ao enfileirar no SEND!!\n");
      printfflush();
      #endif

      dbg("Forwarder",
          "%s: send failed as packet could not be enqueued.\n",
          __FUNCTION__);
      // Return the pool entry, as it's not for me...
      return FAIL;
    }
  }
  command error_t Send.cancel[uint8_t client](message_t* msg) {
    // cancel not implemented. will require being able
    // to pull entries out of the queue.
    return FAIL;
  }

  command uint8_t Send.maxPayloadLength[uint8_t client]() {
    return call Packet.maxPayloadLength();
  }

  command void* Send.getPayload[uint8_t client](message_t* msg, uint8_t len) {
    return call Packet.getPayload(msg, len);
  }

  task void sendTask() {
    if (hasState(SENDING) || call SendQueue.empty()) {
      /* System is busy or has nothing to send */
    	return;
    }
    else{
      /*There is a packet to send.
      First check if it is a duplicate;
      if not, try to send/forward. */

      error_t subsendResult;
      fe_queue_entry_t* qe = call SendQueue.head();
      uint8_t payloadLen = call SubPacket.payloadLength(qe->msg);

      if (call SentCache.lookup(qe->msg)) {
        /* This packet is a duplicate, so suppress it: free memory and
        * send next packet.  Duplicates are only possible for
        * forwarded packets, so we can circumvent the client or
        * forwarded branch for freeing the buffer. */

        call SendQueue.dequeue();

        if (call MessagePool.put(qe->msg) != SUCCESS){
          printf("Error return allocated msg memory space to the MessagePool\n");
        }

        if (call QEntryPool.put(qe) != SUCCESS){
          printf("Error return allocated queue entry memory space to the QEntryPool\n");
        }
        post sendTask();
        return;
      }
      else {
        if( (call TinySdnPacket.getType(qe->msg) == DATA_PACKET && flowTableFindEntry(call TinySdnPacket.getDestination(qe->msg)) != FLOW_NOT_FOUND)  ||
            (call TinySdnPacket.getType(qe->msg) != DATA_PACKET && controlFlowTableFindEntry(call TinySdnPacket.getDestination(qe->msg)) != CONTROL_FLOW_NOT_FOUND) )  {  // sabe enviar?
          /* The basic forwarding/sending case. */
          am_addr_t nextHopAddr;
          call TinySdnPacket.clearOption(qe->msg, TINYSDN_OPT_ECN | TINYSDN_OPT_PULL);

          if (call PacketAcknowledgements.requestAck(qe->msg) == SUCCESS) {
            setState(ACK_PENDING);
          }

          if (hasState(QUEUE_CONGESTED)) {
            call TinySdnPacket.setOption(qe->msg, TINYSDN_OPT_ECN);
            clearState(QUEUE_CONGESTED);
          }

          if(call TinySdnPacket.getType(qe->msg) == DATA_PACKET) nextHopAddr = flowTable[flowTableFindEntry(call TinySdnPacket.getDestination(qe->msg))].actionParameter;
          else nextHopAddr =  controlFlowTable[controlFlowTableFindEntry(call TinySdnPacket.getDestination(qe->msg))].nextHop;

          subsendResult = call SubSend.send(nextHopAddr, qe->msg, payloadLen);

          if (subsendResult == SUCCESS) {
            // Successfully submitted to the data-link layer.
            setState(SENDING);
            dbg("Forwarder", "%s: subsend succeeded with %p.\n", __FUNCTION__, qe->msg);
            return;
          }
          // The packet is too big: truncate it and retry.
          else{
            if (subsendResult == ESIZE) {
              dbg("Forwarder", "%s: subsend failed from ESIZE: truncate packet.\n", __FUNCTION__);
              call Packet.setPayloadLength(qe->msg, call Packet.maxPayloadLength());
              post sendTask();
            }
            else {
             dbg("Forwarder", "%s: subsend failed from %i\n", __FUNCTION__, (int)subsendResult);
            }
          }
        }

        else {
          if (controlFlowUpwardThroughCTP) {

            if (controlFlowUpwardThroughCTP) { // Forward request through CTP path

              tinysdn_flow_request_ctp_t* rcm = (tinysdn_flow_request_ctp_t*)call CTPSendToController.getPayload(&packet, sizeof(tinysdn_flow_request_ctp_t)); // Create the packet to continue forwarding

              //if(TOS_NODE_ID == 5) return;

              if(call TinySdnPacket.getType(qe->msg) == DATA_PACKET ) rcm->type = DATA_FLOW_REQUEST;
              else rcm->type = CONTROL_FLOW_REQUEST;
              rcm->origin = TOS_NODE_ID;
              rcm->target = call TinySdnPacket.getDestination(qe->msg);


              if (call CTPSendToController.send(&packet, sizeof(tinysdn_flow_request_ctp_t)) == SUCCESS) {

                if (rcm->type == DATA_FLOW_REQUEST){
                  printf("CTP : DATA FLOW REQUEST has been sent to SDN controller, FLOW ID=%u\n",rcm->target);
                }else if (rcm->type == CONTROL_FLOW_REQUEST){
                  printf("CTP : CONTROL FLOW REQUEST to node %u has been sent to SDN controller\n",rcm->target);
                }
                return;

                setState(REQUESTING);
                call SendQueue.dequeue();
                if(call SendQueue.enqueue(qe)== SUCCESS){
                #ifdef PRINTF_DEV_DEBUG
                  printf("Enfileirou2 QSize %u \n", call SendQueue.size());
                  printfflush();
                #endif
                }
                call RetxmitTimer.startOneShot(NO_CONTROLLER_RETRY);

                setState(SENDING);
              }

            }
          }
          else {                                                                             // It have no Controller yet
            call RetxmitTimer.startOneShot(NO_CONTROLLER_RETRY);                                  // do nothing -> waiting for a Controller Registration
          }
        }
      }
    }
    return;
  }
  /*
   *
   * The second phase of a send operation; based on whether the transmission was
   * successful, the ForwardingEngine either stops sending or starts the
   * RetxmitTimer with an interval based on what has occured. If the send was
   * successful or the maximum number of retransmissions has been reached, then
   * the ForwardingEngine dequeues the current packet. If the packet is from a
   * client it signals Send.sendDone(); if it is a forwarded packet it returns
   * the packet and queue entry to their respective pools.
   *
   */

  void packetComplete(fe_queue_entry_t* qe, message_t* msg, bool success) {
    // Four cases:
    // Local packet: success or failure
    // Forwarded packet: success or failure
    if (qe->client < CLIENT_COUNT) {
      clientPtrs[qe->client] = qe;
      signal Send.sendDone[qe->client](msg, SUCCESS);

      if (success) {
        dbg("TinySDNForwarder", "%s: packet %hu.%hhu for client %hhu acknowledged.\n", __FUNCTION__, call TinySDNSocketPacket.getOrigin(msg), call TinySDNSocketPacket.getSequenceNumber(msg), qe->client);
      }
      else {
        dbg("TinySDNForwarder", "%s: packet %hu.%hhu for client %hhu dropped.\n", __FUNCTION__, call TinySDNSocketPacket.getOrigin(msg), call TinySDNSocketPacket.getSequenceNumber(msg), qe->client);
      }
    }
    else {
      if (success) {
        call SentCache.insert(qe->msg);
        dbg("TinySDNForwarder", "%s: forwarded packet %hu.%hhu acknowledged: insert in transmit queue.\n", __FUNCTION__, call TinySDNSocketPacket.getOrigin(msg), call TinySDNSocketPacket.getSequenceNumber(msg));
      }
      else {
        dbg("TinySDNForwarder", "%s: forwarded packet %hu.%hhu dropped.\n", __FUNCTION__, call TinySDNSocketPacket.getOrigin(msg), call TinySDNSocketPacket.getSequenceNumber(msg));
      }


      if (call MessagePool.put(qe->msg) != SUCCESS){
        printf("Error return allocated msg memory space to the MessagePool\n");
      }
      if (call QEntryPool.put(qe) != SUCCESS){
        printf("Error return allocated queue entry memory space to the QEntryPool\n");
      }

    }
  }
  event void SubSend.sendDone(message_t* msg, error_t error) {
    fe_queue_entry_t *qe = call SendQueue.head();
    dbg("Forwarder", "%s to %hu and %hhu\n", __FUNCTION__, call AMPacket.destination(msg), error);

    if(hasState(REQUESTING)){
      printf("REQUESTING ON");
      printfflush();
      clearState(REQUESTING);
      return;
    }


    if (error != SUCCESS) {
      /* The radio wasn't able to send the packet: retransmit it. */
      dbg("Forwarder", "%s: send failed\n", __FUNCTION__);
      printf("%s: send failed\n", __FUNCTION__);
      startRetxmitTimer(SENDDONE_FAIL_WINDOW, SENDDONE_FAIL_OFFSET);
    }
    else if (hasState(ACK_PENDING) && !call PacketAcknowledgements.wasAcked(msg)) {
      /* No ack: if countdown is not 0, retransmit, else drop the packet. */
      call LinkEstimator.txNoAck(call AMPacket.destination(msg));
      if (--qe->retries) {
        dbg("Forwarder", "%s: not acked, retransmit\n", __FUNCTION__);
        startRetxmitTimer(SENDDONE_NOACK_WINDOW, SENDDONE_NOACK_OFFSET);
      }
      else {
      /* Hit max retransmit threshold: drop the packet. */
        call SendQueue.dequeue();
        clearState(SENDING);
        startRetxmitTimer(SENDDONE_OK_WINDOW, SENDDONE_OK_OFFSET);
        packetComplete(qe, msg, FALSE);
      }
    }
    else {
      /* Packet was acknowledged. Updated the link estimator,
   free the buffer (pool or sendDone), start timer to
   send next packet. */
      call SendQueue.dequeue();
      clearState(SENDING);
      startRetxmitTimer(SENDDONE_OK_WINDOW, SENDDONE_OK_OFFSET);
      call LinkEstimator.txAck(call AMPacket.destination(msg));
      packetComplete(qe, msg, TRUE);
    }
  }

  /*
   * Function for preparing a packet for forwarding. Performs
   * a buffer swap from the message pool. If there are no free
   * message in the pool, it returns the passed message and does not
   * put it on the send queue.
   */
  message_t* ONE forward(message_t* ONE m) {
    if (call MessagePool.empty()) {
      dbg("Route", "%s cannot forward, message pool empty.\n", __FUNCTION__);
      printf("%s cannot forward, message pool empty.\n", __FUNCTION__);
    }
    else if (call QEntryPool.empty()) {
      dbg("Route", "%s cannot forward, queue entry pool empty.\n",
          __FUNCTION__);
      printf("%s cannot forward, queue entry pool empty.\n", __FUNCTION__);
    }
    else {
      message_t* newMsg; //pointer to a possible free memory space to be swaped with subReceiver
      fe_queue_entry_t *qe;

      qe = call QEntryPool.get();
      if (qe == NULL) {
        #ifdef PRINTF_DEV_DEBUG
        printf("Error when getting queue entry memory space from QEntryPool\n");
        #endif
        return m;
      }

      newMsg = call MessagePool.get();
      if (newMsg == NULL) { //There is no free memory space in the pool to be swaped
        #ifdef PRINTF_DEV_DEBUG
        printf("Error when getting message memory space from MessagePool\n");
        #endif
        return m;
      }

      memset(newMsg, 0, sizeof(message_t)); // Cleaning the memory space to be swaped
      memset(m->metadata, 0, sizeof(message_metadata_t));
      qe->msg = m;
      qe->client = 0xff;
      qe->retries = MAX_RETRIES;


      if (call SendQueue.enqueue(qe) == SUCCESS) {
        #ifdef PRINTF_DEV_DEBUG
        printf("Enfileirou4 QSize %u \n", call SendQueue.size());
        printfflush();
        #endif


        dbg("Forwarder,Route", "%s forwarding packet %p with queue size %hhu\n", __FUNCTION__, m, call SendQueue.size());

        // Loop-detection code:
        if (!call RetxmitTimer.isRunning()) {
          // sendTask is only immediately posted if we don't detect a
          // loop.
          dbg("FHangBug", "%s: posted sendTask.\n", __FUNCTION__);
          post sendTask();
        }

        // Successful function exit point:
        return newMsg;
      } else {
        // There was a problem enqueuing to the send queue.

        if (call MessagePool.put(qe->msg) != SUCCESS){
          printf("Error return allocated msg memory space to the MessagePool.\n");
        }

        if (call QEntryPool.put(qe) != SUCCESS){
          printf("Error return allocated queue entry memory space to the QEntryPool.\n");
        }

      }
    }

    // NB: at this point, we have a resource acquistion problem.
    // Log the event, and drop the
    // packet on the floor.

    printf("Error when acquiring a resource because send queue full.\n");

    return m;
  }

  event message_t*
  SubReceive.receive(message_t* msg, void* payload, uint8_t len) {
    tinysdnsocket_id_t collectid;
    bool duplicate = FALSE;
    fe_queue_entry_t* qe;
    uint8_t i, thl;

    tinysdn_data_header_t* hdr;

    hdr = getHeader(msg);

    collectid = call TinySdnPacket.getSocketID(msg);
    #ifdef PRINTF_DEV_DEBUG
    printf("collectid = %u\n",collectid);
    printfflush();
    printf("Recebeu pacote no SubReceive.receive\n");
    printfflush();
    #endif

    // Update the THL here, since it has lived another hop, and so
    // that the root sees the correct THL.
    thl = call TinySdnPacket.getThl(msg);
    thl++;
    call TinySdnPacket.setThl(msg, thl);

    if (len > call SubSend.maxPayloadLength()) {
      return msg;
    }

    //See if we remember having seen this packet
    //We look in the sent cache ...
    if (call SentCache.lookup(msg)) {
      #ifdef PRINTF_DEV_DEBUG
      printf("Repeated packet. \n");
      printf("%s: duplicate message. There is an equal message in SentCache.\n", __FUNCTION__);
      printfflush();
      #endif
      return msg;
    }
    //... and in the queue for duplicates


    if (call SendQueue.size() > 0) {
      for (i = call SendQueue.size(); i >0; i--) {
        qe = call SendQueue.element(i-1);
        if (call TinySdnPacket.matchInstance(qe->msg, msg)) {
          duplicate = TRUE;
          break;
        }
      }
    }

    if (duplicate) {
      printf("%s: duplicate message. There is an equal message in SendQueue.\n", __FUNCTION__);
      return msg;
    }
    else {
      uint16_t dataFlowIndex = 0;

      if(hdr->type == DATA_PACKET) dataFlowIndex = flowTableFindEntry(hdr->destination);

      if(hdr->type == DATA_PACKET && dataFlowIndex != FLOW_NOT_FOUND && flowTable[dataFlowIndex].actionID == ACTION_RECEIVE) { // If I'm the destination and it is a data packet, signal receive.
        #ifdef PRINTF_DEV_DEBUG
        printf("dataFlowIndex %u", dataFlowIndex);
        #endif
        return signal Receive.receive[collectid](msg,
          call Packet.getPayload(msg, call Packet.payloadLength(msg)),
          call Packet.payloadLength(msg));
      }
      else if (hdr->destination == TOS_NODE_ID && hdr->type != DATA_PACKET) {

        if (hdr->type > DATA_PACKET && hdr->type < TOPOLOGY_REPORT_PACKET) {


          if(hdr->type == CONTROL_FLOW_RESPONSE){
            tinysdn_controller_t* controlMsg = (tinysdn_controller_t*)payload;
            printf("TSDN: CONTROL FLOW SETUP to node %u has been received\n", controlMsg->target);
            printfflush();
            controlFlowTableUpdate(controlMsg->target,controlMsg->next_hop);
          }
          else if(hdr->type == DATA_FLOW_RESPONSE) {
            tinysdn_data_flow_setup_t* controlMsg = (tinysdn_data_flow_setup_t*)payload;
            printf("TSDN: DATA FLOW SETUP has been received, FLOW ID=%u\n", controlMsg->flowId);
            printfflush();
            flowTableUpdate(controlMsg->flowId, controlMsg->actionId, controlMsg->actionParameter);
          }

          post sendTask();
          return msg;

        }
        else { //It is a OPEN PATH packet

          tinysdn_open_path_t* rcm = (tinysdn_open_path_t*)payload;
          //tinysdn_open_path_t* sdm;
          uint8_t packetDirection       = rcm->processingIndex & OPEN_PATH_DIRECTION_BIT; //what direction  (upstream or downstream)
          uint8_t packetProcessingIndex = rcm->processingIndex & OPEN_PATH_INDEX_BITS; //which path element must be processed
          am_addr_t forwardToNextHop;

          if (len != sizeof (tinysdn_open_path_t) ) {  // if it really has a OPEN PATH packet size
            post sendTask();
            return msg;
          }


          //controlFlowTableUpdate(rcm->path[0],rcm->path[packetProcessingIndex]);
          flowTableUpdate       (rcm->path[0], ACTION_FORWARD ,rcm->path[packetProcessingIndex]);

          forwardToNextHop = rcm->path[packetProcessingIndex];

            //printf("Recebido Pacote Open Path. Target:%u , Next:%u, Direction: %u\n",rcm->path[0],forwardToNextHop,packetDirection);
            //printfflush();

          if (packetDirection) { //Is it upstream?


            if(rcm->path[++packetProcessingIndex] ==  NOT_A_NODE_ADDR)   {
              post sendTask();
              return msg;
            }
          }
          else {  //It is downstream

            //printf("Recebido Pacote Open Path. Target:%u , Next:%u\n",rcm->path[0],forwardToNextHop);
            //printfflush();

            if(--packetProcessingIndex  == 0)   { // Is this not the position 0 in the path vector? note: the path vector[0] is the controlflow target
              post sendTask();
              return msg;
            }
          }


            packetProcessingIndex |= packetDirection;

            rcm->processingIndex = packetProcessingIndex;
            rcm->destination = forwardToNextHop;

            return forward(msg);

              //repassar em direção ao rcm->path[packetProcessingIndex]
              //PROCESS FINISHED
        }
      }
      // I'm on the routing path and Intercept indicates that I
      // should not forward the packet.
      else {
/*        if(hdr->type == DATA_FLOW_RESPONSE) {
          tinysdn_data_flow_setup_t* controlMsg = (tinysdn_data_flow_setup_t*)payload;
          printf("chegou DATA_FLOW_RESPONSE or:%u action:%u flowID:%u actParam:%u\n",controlMsg->origin, controlMsg->actionId, controlMsg->flowId, controlMsg->actionParameter);
        }*/
        if (!signal Intercept.forward[collectid](msg,
              call Packet.getPayload(msg, call Packet.payloadLength(msg)),
              call Packet.payloadLength(msg)))
          return msg;
        else {
          dbg("Route", "Forwarding packet from %hu.\n", getHeader(msg)->origin);

          return forward(msg);
        }
      }
    }
  }

  event void RetxmitTimer.fired() {
    clearState(SENDING);
    dbg("FHangBug", "%s posted sendTask.\n", __FUNCTION__);
    post sendTask();
  }

  // Packet ADT commands
  command void Packet.clear(message_t* msg) {
    call SubPacket.clear(msg);
  }

  command uint8_t Packet.payloadLength(message_t* msg) {
    return call SubPacket.payloadLength(msg) - sizeof(tinysdn_data_header_t);
  }

  command void Packet.setPayloadLength(message_t* msg, uint8_t len) {
    call SubPacket.setPayloadLength(msg, len + sizeof(tinysdn_data_header_t));
  }

  command uint8_t Packet.maxPayloadLength() {
    return call SubPacket.maxPayloadLength() - sizeof(tinysdn_data_header_t);
  }

  command void* Packet.getPayload(message_t* msg, uint8_t len) {
    uint8_t* payload = call SubPacket.getPayload(msg, len + sizeof(tinysdn_data_header_t));
    if (payload != NULL) {
      payload += sizeof(tinysdn_data_header_t);
    }
    return payload;
  }

  //given a destination, if it exists in control flow table return entry index, else return the FLOW_NOT_FOUND value
  uint16_t controlFlowTableFindEntry(am_addr_t dest) {
    uint16_t i;
    for (i = 0; i < controlFlowTableActive; i++) {
      if (controlFlowTable[i].destination == dest)
        break;
    }

    if(controlFlowTableActive == i)
      return CONTROL_FLOW_NOT_FOUND;

    return i;
  }

//update an entry to the control flow table
  error_t controlFlowTableUpdate(am_addr_t dest, am_addr_t nextHop)    {
    uint16_t controlFlowToBeUpdated = controlFlowTableFindEntry(dest);

    #ifdef PRINTF_DEV_DEBUG
    printf("controlFlowTableUpdate foi chamado!\n");
    printfflush();
    #endif

    if(controlFlowToBeUpdated == CONTROL_FLOW_NOT_FOUND) {  // it is a new control flow
      controlFlowToBeUpdated = controlFlowTableActive;
      controlFlowTable[controlFlowToBeUpdated].destination = dest;
      controlFlowTable[controlFlowToBeUpdated].nextHop = nextHop;
      controlFlowTableActive ++;

      printf("TSDN: CONTROL FLOW to node %u has been added/updated, next hop = %u\n", dest, nextHop);
      printfflush();

      return SUCCESS;
    }else {  // to update an old control flow
      flowTable[controlFlowToBeUpdated].actionParameter = nextHop;
      return SUCCESS;
    }
  }


  //given a dataFlowID, if it exists in flow table return index, else return the FLOW_NOT_FOUND value
  uint16_t flowTableFindEntry(uint16_t dataFlowID) {
    uint16_t i;
    for (i = 0; i < flowTableActive; i++) {
      if (flowTable[i].dataFlowID == dataFlowID)  break;
    }

    if(flowTableActive == i)
      return FLOW_NOT_FOUND;

    return i;
  }

  //update the flowTable
  error_t flowTableUpdate(uint16_t updatingDataFlowID, uint8_t updatingActionId, uint16_t updatingActionParam)   {
    uint16_t flowToBeUpdated = flowTableFindEntry(updatingDataFlowID);

    if(flowToBeUpdated == FLOW_NOT_FOUND) { // it is a new flow
      flowToBeUpdated = flowTableActive;
      flowTable[flowToBeUpdated].dataFlowID = updatingDataFlowID;
      flowTable[flowToBeUpdated].actionID = updatingActionId;
      flowTable[flowToBeUpdated].actionParameter = updatingActionParam;
      flowTableActive++;
      printf("TSDN: DATA FLOW ID=%u has been added/updated", updatingDataFlowID);
      if(updatingActionId == ACTION_FORWARD){
        printf("     -> Action: FORWARD, Parameter (next hop): %u\n", updatingActionParam);
      }else if(updatingActionId == ACTION_RECEIVE){
        printf("     -> Action: RECEIVE\n");
      }
      return SUCCESS;
     }
    else {                                 // to update an old control flow
      flowTable[flowToBeUpdated].actionID = updatingActionId;
      flowTable[flowToBeUpdated].actionParameter = updatingActionParam;
      return SUCCESS;
    }
  }

  // CollectionPacket ADT commands
  command am_addr_t       TinySDNSocketPacket.getOrigin(message_t* msg) {return getHeader(msg)->origin;}
  command tinysdnsocket_id_t TinySDNSocketPacket.getSocketID(message_t* msg) {return getHeader(msg)->tinySdnSocketID;}
  command uint8_t         TinySDNSocketPacket.getSequenceNumber(message_t* msg) {return getHeader(msg)->originSeqNo;}
  command void TinySDNSocketPacket.setOrigin(message_t* msg, am_addr_t addr) {getHeader(msg)->origin = addr;}
  command void TinySDNSocketPacket.setSocketID(message_t* msg, tinysdnsocket_id_t id) {getHeader(msg)->tinySdnSocketID = id;}
  command void TinySDNSocketPacket.setSequenceNumber(message_t* msg, uint8_t _seqno) {getHeader(msg)->originSeqNo = _seqno;}

  // CtpPacket ADT commands
  command uint8_t       TinySdnPacket.getSocketID(message_t* msg) {return getHeader(msg)->tinySdnSocketID;}
  command am_addr_t     TinySdnPacket.getOrigin(message_t* msg) {return getHeader(msg)->origin;}
  command uint8_t       TinySdnPacket.getSequenceNumber(message_t* msg) {return getHeader(msg)->originSeqNo;}
  command uint8_t       TinySdnPacket.getThl(message_t* msg) {return getHeader(msg)->thl;}
  command am_addr_t     TinySdnPacket.getDestination(message_t* msg) {return getHeader(msg)->destination;}
  command uint8_t       TinySdnPacket.getType(message_t* msg){return getHeader(msg)->type;}

  command void TinySdnPacket.setDestination(message_t* msg, am_addr_t addr){getHeader(msg)->destination = addr;}
  command void TinySdnPacket.setType(message_t* msg, uint8_t type){getHeader(msg)->type = type;}
  command void TinySdnPacket.setThl(message_t* msg, uint8_t thl) {getHeader(msg)->thl = thl;}
  command void TinySdnPacket.setOrigin(message_t* msg, am_addr_t addr) {getHeader(msg)->origin = addr;}
  command void TinySdnPacket.setSocketID(message_t* msg, uint8_t id) {getHeader(msg)->tinySdnSocketID = id;}
  command void TinySdnPacket.setSequenceNumber(message_t* msg, uint8_t _seqno) {getHeader(msg)->originSeqNo = _seqno;}
  command bool TinySdnPacket.option(message_t* msg, tinysdn_options_t opt) {
    return ((getHeader(msg)->options & opt) == opt) ? TRUE : FALSE;
  }
  command void TinySdnPacket.setOption(message_t* msg, tinysdn_options_t opt) {
    getHeader(msg)->options |= opt;
  }
  command void TinySdnPacket.clearOption(message_t* msg, tinysdn_options_t opt) {
    getHeader(msg)->options &= ~opt;
  }

  command bool TinySdnPacket.matchInstance(message_t* m1, message_t* m2) {
    return (call TinySdnPacket.getOrigin(m1) == call TinySdnPacket.getOrigin(m2) &&
      call TinySdnPacket.getSequenceNumber(m1) == call TinySdnPacket.getSequenceNumber(m2) &&
      call TinySdnPacket.getThl(m1) == call TinySdnPacket.getThl(m2) &&
      call TinySdnPacket.getSocketID(m1) == call TinySdnPacket.getSocketID(m2));
  }

  command bool TinySdnPacket.matchPacket(message_t* m1, message_t* m2) {
    return (call TinySdnPacket.getOrigin(m1) == call TinySdnPacket.getOrigin(m2) &&
      call TinySdnPacket.getSequenceNumber(m1) == call TinySdnPacket.getSequenceNumber(m2) &&
      call TinySdnPacket.getSocketID(m1) == call TinySdnPacket.getSocketID(m2));
  }
  void clearState(uint8_t state) {
    forwardingState = forwardingState & ~state;
  }
  bool hasState(uint8_t state) {
    return forwardingState & state;
  }

  void setState(uint8_t state) {
    forwardingState = forwardingState | state;
  }

  /************** Defaults **************/

  default event void
  Send.sendDone[uint8_t client](message_t *msg, error_t error) {
  }

  default event bool
  Intercept.forward[tinysdnsocket_id_t collectid](message_t* msg, void* payload,
                                               uint8_t len) {
    return TRUE;
  }

  default event message_t *
  Receive.receive[tinysdnsocket_id_t collectid](message_t *msg, void *payload,
                                             uint8_t len) {
    return msg;
  }


  default command tinysdnsocket_id_t TinySDNSocketId.fetch[uint8_t client]() {
    return 0;
  }

  command void TinySdnReportTopologyPacket.setPeriod(uint16_t period) {
    call NotifyTimer.startPeriodic(period); //used to set report period shared with TinySdnTopologyInformationP.TopologyReportTimer
  }

  event void NotifyTimer.fired() {
    //Do nothing. It is here because TinySdnReportTopologyPacket.setPeriod
  }

  command void TinySdnReportTopologyPacket.pushReportPacket(topology_report_neighbor_table_entry topologyReportNeighborTable[NEIGHBOR_TABLE_SIZE], uint8_t numberOfNeighbors) {
    uint8_t i = 0;

    if (controlFlowUpwardThroughCTP) {
      nx_neighbor_table* topologyReportPacketPointer = (tinysdn_topology_report_t*)call CTPSendToController.getPayload(&packet, sizeof(tinysdn_topology_report_t));
      topologyReportPacketPointer-> numOfNeighbors = numberOfNeighbors;

      for(i=0; i < numberOfNeighbors; i++) {
        topologyReportPacketPointer->neighbors[i].neighbor_id = topologyReportNeighborTable[i].neighbor_id;
        topologyReportPacketPointer->neighbors[i].etx         = topologyReportNeighborTable[i].etx;
        topologyReportPacketPointer->neighbors[i].rssi        = topologyReportNeighborTable[i].rssi;
      }

      if (topologyReportPacketPointer == NULL) {
         //printf("erro ao enviar 1\n");
         //printfflush();
          return;
      }

      if (call CTPSendToController.send(&packet, sizeof(nx_neighbor_table)) == SUCCESS){
        setState(SENDING);
        printf("CTP : TOPOLOGY INFORMATION REPORT has been sent to SDN controller! %u neighbors.\n", topologyReportPacketPointer-> numOfNeighbors);
        printfflush();
      }
      else{
        //printf("erro ao enviar pacote de topologia + %u\n", success);
        //printfflush();
      }
    }


    //call SubSend.send(controlFlowTable[controlFlowTableFindEntry(topologyReportPacketPointer->destination)].nextHop, &packet, sizeof(tinysdn_topology_report_t)); //sending the report Packet to controller
    /*i = 0;
    for(i; i < numberOfNeighbors; i++){
      printf("%u:%u etx:%u\n", i, topologyReportNeighborTable[i].neighbor_id, topologyReportNeighborTable[i].etx);
    }
    printfflush();*/
  }

  uint8_t pullOriginSeqNo() { //allocate an origin sequence number
    return seqNumber++;
  }

  event void LinkEstimator.evicted(am_addr_t neighbor) {}

  command bool CtpCongestion.isCongested() {
    return FALSE;
  }

  command void CtpCongestion.setClientCongested(bool congested) {
    // Do not respond to congestion.
  }

  event void CTPSendToController.sendDone(message_t* msg, error_t error) {
    clearState(SENDING);
  }

  event void CTPPathToController.routeFound(){
    printf("CTP : SDN controller found!\n");
    printfflush();
    setState(CONTROLLER_ASSIGNED);
    controlFlowUpwardThroughCTP = TRUE;
    call StdControlTopologyCollection.start();
  }

  event void CTPPathToController.noRoute(){
    clearState(CONTROLLER_ASSIGNED);
  }
}
