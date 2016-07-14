/*
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

/**
 * @author Bruno Trevizan de Oliveira
 * @date April 4 2016
 *
 * This TinyOS component was implementated based on original CollectionC.nc by Rodrigo Fonseca, Omprakash Gnawali, Kyle Jamieson, and Philip Levis
 **/

#include "TinySdn.h"

configuration TinySDNSocketC {
  provides {
    interface StdControl;
    interface AMSend as Send[uint8_t client];
    interface Receive[tinysdnsocket_id_t id];
    interface Intercept[tinysdnsocket_id_t id];

    interface Packet;
    interface TinySDNSocketPacket;
    interface TinySdnPacket;
  }

  uses {
    interface TinySDNSocketId[uint8_t client];
    interface CollectionId[uint8_t client];
  }
}

implementation {
  components TinySdnP;

  StdControl = TinySdnP;
  Send = TinySdnP;
  Receive = TinySdnP.Receive;
  Intercept = TinySdnP;

  Packet = TinySdnP;
  TinySDNSocketPacket = TinySdnP;
  TinySdnPacket = TinySdnP;

  TinySDNSocketId = TinySdnP;
  CollectionId = TinySdnP;
}
