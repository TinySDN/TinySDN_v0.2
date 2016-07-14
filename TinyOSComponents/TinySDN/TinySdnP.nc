/*
 * Copyright (c) 2005 The Regents of the University  of California.
 * Copyright (c) 2006 Stanford University.
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

#include <Ctp.h>
#include "TinySdn.h"


/**
* TinySDN component configuration
*
* @author Bruno Trevizan de Oliveira
* @date April 4 2016
*
* This TinyOS component was implementated based on original CtpP.nc by Rodrigo Fonseca, Omprakash Gnawali, Philip Levis and Kyle Jamieson
*/


configuration TinySdnP {
  provides {
    interface StdControl;
    interface AMSend as Send[uint8_t client];
    interface Receive[tinysdnsocket_id_t id];

    interface Intercept[tinysdnsocket_id_t id];

    interface Packet;
    interface TinySDNSocketPacket;
    interface TinySdnPacket;

//  interface RootControl; //future controller implementations
  }

  uses {
    interface CollectionId[uint8_t client];
    interface TinySDNSocketId[uint8_t client];
  }
}

implementation {

  enum {
    CLIENT_COUNT = uniqueCount(UQ_TINYSDN_CLIENT),
    FORWARD_COUNT = 12,
    TREE_ROUTING_TABLE_SIZE = 10,
    QUEUE_SIZE = CLIENT_COUNT + FORWARD_COUNT,
    CACHE_SIZE = 4
  };

  components SerialPrintfC, SerialStartC;    // For testing

  components MainC;
  components ActiveMessageC;
  components new TinySdnForwardingEngineP() as TSDNForwarder;
  components new TinySdnTopologyInformationP() as TopologyInformationCollector;

  components LinkEstimatorP as Estimator;
  components new AMSenderC(AM_CTP_ROUTING) as LEControlSender;
  components new AMReceiverC(AM_CTP_ROUTING) as LEControlReceiver;

  components new TimerMilliC() as TopologyNotificationTimer;

  components RandomC;

  TSDNForwarder.Random -> RandomC;

  TSDNForwarder.NotifyTimer -> TopologyNotificationTimer;

  Send = TSDNForwarder;
  StdControl = TSDNForwarder;
  Receive = TSDNForwarder.Receive;
  Intercept = TSDNForwarder;
  Packet = TSDNForwarder;
  TinySDNSocketId = TSDNForwarder;
  TinySDNSocketPacket = TSDNForwarder;
  TinySdnPacket = TSDNForwarder;

  components new PoolC(message_t, FORWARD_COUNT) as MessagePoolP;
  components new PoolC(fe_queue_entry_t, FORWARD_COUNT) as QEntryPoolP;
  TSDNForwarder.QEntryPool -> QEntryPoolP;
  TSDNForwarder.MessagePool -> MessagePoolP;

  components new QueueC(fe_queue_entry_t*, QUEUE_SIZE) as CTPSendQueueP;
  components new QueueC(fe_queue_entry_t*, QUEUE_SIZE) as SendQueueP;

  TSDNForwarder.SendQueue -> SendQueueP;

  components new LruTinySdnMsgCacheC(CACHE_SIZE) as SentCacheP;
  TSDNForwarder.SentCache -> SentCacheP;

  components new AMSenderC(AM_CTP_DATA) as CTPAMSender;
  components new AMReceiverC(AM_CTP_DATA) as CTPAMReceiver;
  components new AMSenderC(AM_TINYSDN_DATA) as TSDNAMSender;
  components new AMReceiverC(AM_TINYSDN_DATA) as TSDNAMReceiver;

  components new TimerMilliC() as RetxmitTimer;
  components new TimerMilliC() as CTPRetxmitTimer;
  TSDNForwarder.RetxmitTimer -> RetxmitTimer;

  MainC.SoftwareInit -> TSDNForwarder;
  TSDNForwarder.SubSend -> TSDNAMSender;
  TSDNForwarder.SubReceive -> TSDNAMReceiver;
  TSDNForwarder.SubPacket -> TSDNAMSender;

  TSDNForwarder.RadioControl -> ActiveMessageC;
  TSDNForwarder.AMPacket -> TSDNAMSender;



  /**
   * Link Estimator wiring
   */

  StdControl = Estimator;

  Estimator.Random -> RandomC;
  Estimator.AMSend -> LEControlSender;
  Estimator.SubReceive -> LEControlReceiver;
  Estimator.SubPacket -> LEControlSender;
  Estimator.SubAMPacket -> LEControlSender;
  MainC.SoftwareInit -> Estimator;

  TSDNForwarder.LinkEstimator -> Estimator.LinkEstimator;
  TSDNForwarder.PacketAcknowledgements -> TSDNAMSender.Acks;
  TSDNForwarder.initLE -> Estimator.Init;

  #if defined(CC2420X)
  components CC2420XActiveMessageC as PlatformActiveMessageC;
  #elif defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ)
  #ifndef TOSSIM
  components CC2420ActiveMessageC as PlatformActiveMessageC;
  #else
  components DummyActiveMessageP as PlatformActiveMessageC;
  #endif
  #elif defined (PLATFORM_MICA2) || defined (PLATFORM_MICA2DOT)
  components CC1000ActiveMessageC as PlatformActiveMessageC;
  #elif defined(PLATFORM_EYESIFXV1) || defined(PLATFORM_EYESIFXV2)
  components WhiteBitAccessorC as PlatformActiveMessageC;
  #elif defined(PLATFORM_IRIS) || defined(PLATFORM_MESHBEAN)
  components RF230ActiveMessageC as PlatformActiveMessageC;
  #elif defined(PLATFORM_MESHBEAN900)
  components RF212ActiveMessageC as PlatformActiveMessageC;
  #elif defined(PLATFORM_UCMINI)
  components RFA1ActiveMessageC as PlatformActiveMessageC;
  #else
  components DummyActiveMessageP as PlatformActiveMessageC;
  #endif

  Estimator.LinkPacketMetadata -> PlatformActiveMessageC;


  /**
   * Topology Information Collector wiring
   */

  TopologyInformationCollector.LinkEstimator -> Estimator.LinkEstimator;
  TopologyInformationCollector.TopologyReportTimer -> TopologyNotificationTimer;
  TopologyInformationCollector.TinySdnReportTopologyPacket -> TSDNForwarder;

  TSDNForwarder.StdControlTopologyCollection -> TopologyInformationCollector.StdControl;

  /**
   * CTP Router wiring
   */
  components new CtpRoutingEngineP(TREE_ROUTING_TABLE_SIZE, 128, 512000) as Router;

  components new TimerMilliC() as RoutingBeaconTimer;
  components new TimerMilliC() as RouteUpdateTimer;

  StdControl = Router;
//  RootControl = Router;

  MainC.SoftwareInit -> Router;
  Router.BeaconSend -> Estimator.Send;
  Router.BeaconReceive -> Estimator.Receive;
  Router.LinkEstimator -> Estimator.LinkEstimator;

  Router.CompareBit -> Estimator.CompareBit;

  Router.AMPacket -> ActiveMessageC;
  Router.RadioControl -> ActiveMessageC;
  Router.BeaconTimer -> RoutingBeaconTimer;
  Router.RouteTimer -> RouteUpdateTimer;
  Router.CtpCongestion -> TSDNForwarder;
  Router.Random -> RandomC;

  TSDNForwarder.CTPPathToController -> Router.Routing;


  /**
   * CTP Forwarder wiring
   */
  components new CtpForwardingEngineP() as CtpForwarder;

  StdControl = CtpForwarder;
  CollectionId = CtpForwarder;

  MainC.SoftwareInit -> CtpForwarder;

  CtpForwarder.RootControl -> Router;
  CtpForwarder.CtpInfo -> Router;
  CtpForwarder.UnicastNameFreeRouting -> Router.Routing;

  CtpForwarder.LinkEstimator -> Estimator;

  CtpForwarder.SubSend -> CTPAMSender;
  CtpForwarder.SubPacket -> CTPAMSender;
  CtpForwarder.AMPacket -> CTPAMSender;
  CtpForwarder.PacketAcknowledgements -> CTPAMSender.Acks;

  CtpForwarder.SubReceive -> CTPAMReceiver;

  CtpForwarder.SentCache -> SentCacheP;
  CtpForwarder.SendQueue -> CTPSendQueueP;

  CtpForwarder.RadioControl -> ActiveMessageC;

  CtpForwarder.MessagePool -> MessagePoolP;
  CtpForwarder.QEntryPool -> QEntryPoolP;

  CtpForwarder.Random -> RandomC;
  CtpForwarder.RetxmitTimer -> CTPRetxmitTimer;

  TSDNForwarder.CTPSendToController -> CtpForwarder.Send[unique(UQ_CTP_CLIENT)];
}


/*  This work is partially funded by São Paulo Research Foundation (FAPESP) under grants #2013/15417-4 and #2014/06479-9. */
