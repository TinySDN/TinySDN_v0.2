/*
 * Copyright (c) 2016 University of São Paulo
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
 * HOLDER OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
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
 **/

#include <Timer.h>
#include <LinkEstimator.h>
#include "TinySdn.h"

generic module TinySdnTopologyInformationP(){
  provides {
    interface StdControl;
  }
  uses {
    interface Timer<TMilli> as TopologyReportTimer;
    interface TinySdnReportTopologyPacket;
    interface LinkEstimator;
    interface Packet;
  }
}

implementation
{
  message_t packet;

  command error_t StdControl.start() {
    #ifdef PRINTF_DEV_DEBUG
    printf("Executou StdControlTopologyCollection.start()");
    printfflush();
    #endif
    call TopologyReportTimer.startPeriodic(5000);
    return SUCCESS;
  }

  command error_t StdControl.stop() {
    call TopologyReportTimer.stop();
    return SUCCESS;
  }

  event void LinkEstimator.evicted(am_addr_t neighbor) {}

  event void TopologyReportTimer.fired() {
    uint8_t i;
    uint8_t neighborTableElementsCount = 0;
    neighbor_table_entry_t NeighborTableLE[NEIGHBOR_TABLE_SIZE];
    topology_report_neighbor_table_entry NeighborTableToReport[NEIGHBOR_TABLE_SIZE];

    call LinkEstimator.getNeighborTable(NeighborTableLE);
    for(i=0 ; i < NEIGHBOR_TABLE_SIZE; i++){
      if(NeighborTableLE[i].flags != 0){
        NeighborTableToReport[i].neighbor_id = NeighborTableLE[i].ll_addr;
        NeighborTableToReport[i].etx = NeighborTableLE[i].etx;
        neighborTableElementsCount ++;
      }
    }

    call TinySdnReportTopologyPacket.pushReportPacket(NeighborTableToReport, neighborTableElementsCount);

  }

}
