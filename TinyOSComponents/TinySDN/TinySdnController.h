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

#ifndef TINYSDN_CONTROLLER_H
#define TINYSDN_CONTROLLER_H

#include "Topology.h"

typedef nx_struct tinysdn_find_controller_msg {
  nx_uint16_t origin;
} tinysdn_find_controller_t;

//neighborTable struct
typedef struct {
  nx_uint16_t sender;
  nx_uint16_t numOfNeighbors;
  neighbor_table_entry neighbors[NEIGHBOR_TABLE_SIZE];
} report;


enum {
  AM_TINYSDN_CONTROLLER_MSG = 7,
  OPEN_PATH_DIRECTION_BIT   = 0x80,
  OPEN_PATH_INDEX_BITS      = 0x7F,
  //OPEN_PATH_NULL_POSITION   = 0xFFFF, //no next hop in vector position
  NOT_A_NODE_ADDR           = 65535U,
  NO_CONTROLLER_RETRY       = 1000
};

#endif
