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


#ifndef _TOPOLOGY_H
#define _TOPOLOGY_H

#include <AM.h>

enum {
  //constants
  NEIGHBOR_TTL_RENEW = 5,
  NEIGHBOR_TTL_DECREASE_INTERVAL = 2000,
  RSSI_BEACON_INTERVAL = 2000,
  NEIGHBOR_TABLE_SIZE = 10,
  TOPOLOGY_NOTIFICATION_INTERVAL = 2000,
  NEIGHBOR_UNAVAILABLE = 345,
  AM_TOPOLOGY_MSG = 0xbc
};

// beacon packet struct
typedef nx_struct rssi_beacon_msg{
  nx_uint16_t source_id;
  nx_uint16_t controller_id;
  nx_uint16_t metric;
} rssi_beacon_msg;

typedef struct {
  uint16_t source_id;
  uint16_t controller_id;
  uint16_t metric;
} controller_path_neighbor;

//neighborTable entry struct
typedef struct {
  uint16_t neighbor_id;
  uint16_t rssi;
  uint16_t etx;
  uint8_t time_to_live;
} neighbor_table_entry;

//neighborTable packet struct
typedef nx_struct {
  nx_am_addr_t neighbor_id;
  nx_uint16_t etx;
  nx_uint16_t rssi;
} nx_neighbor_table_entry;

typedef nx_struct {
  nx_uint8_t numOfNeighbors;
  nx_neighbor_table_entry neighbors[NEIGHBOR_TABLE_SIZE];
} nx_neighbor_table;

#endif
