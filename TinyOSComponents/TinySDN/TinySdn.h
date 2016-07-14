/*
 * Copyright (c) 2006 Stanford University.
 * Copyright (c) 2016   University of São Paulo
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
 * - Neither the name of the Stanford University nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 * - Neither the name of the University of São Paulo nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
 * UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Header file that declares the AM types, message formats, and
 * constants for the TinyOS reference implementation of TinySDN
 *
 * @author Bruno Trevizan de Oliveira
 * @date April 4 2016
 *
 * This TinyOS component was implementated based on original Ctp.h by Philip Levis
 **/


#ifndef TINYSDN_H
#define TINYSDN_H


#ifndef MAX_OPEN_PATH_HOPS
  #define MAX_OPEN_PATH_HOPS 6
#endif

#include <TinySDNSocket.h>
#include <AM.h>

#define UQ_TINYSDN_CLIENT "TinySDNSocketSenderC.CollectId"

enum {
  // AM types:
  AM_TINYSDN_DATA        = 0x73,
  //AM_CTP_FIND_CONTROLLER = 0xee,
  //AM_TINYSDN_DEBUG   = 0xDE,

  // CTP Options:
  TINYSDN_OPT_PULL      = 0x80, // TEP 123: P field
  TINYSDN_OPT_ECN       = 0x40, // TEP 123: C field
  TINYSDN_OPT_ALL       = 0xff,


  // PACKET TYPES
  DATA_PACKET             = 0x00,
  DATA_FLOW_REQUEST       = 0x01,
  DATA_FLOW_RESPONSE      = 0x02,
  CONTROL_FLOW_REQUEST    = 0x03,
  CONTROL_FLOW_RESPONSE   = 0x04,
  TOPOLOGY_REPORT_PACKET  = 0x05,
  DATA_FLOW_OPEN_PATH     = 0x06,
  CONTROL_FLOW_OPEN_PATH  = 0x07,

  //FLOW ACTIONS
  ACTION_RECEIVE = 0x00,
  ACTION_FORWARD = 0x01,
  ACTION_DROP    = 0x02
};

typedef nx_uint8_t nx_tinysdn_options_t;
typedef uint8_t tinysdn_options_t;

typedef nx_struct {
  nx_tinysdn_options_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_tinysdnsocket_id_t  tinySdnSocketID;

  nx_uint8_t          type;
  nx_am_addr_t        origin;
  nx_am_addr_t        destination;

  nx_uint8_t (COUNT(0) data)[0]; // Deputy place-holder, field will probably be removed when we Deputize Ctp
} tinysdn_data_header_t;


typedef nx_struct tinysdn_controller_msg {
  nx_tinysdn_options_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_tinysdnsocket_id_t  tinySdnSocketID;

  nx_uint8_t          type;
  nx_am_addr_t        origin;
  nx_am_addr_t        destination;

  nx_am_addr_t        next_hop;
  nx_uint16_t         target; //It can be Flow ID (in data flow case) or Node Address (in control flow case)

} tinysdn_controller_t;


typedef nx_struct tinysdn_data_flow_setup_msg {
  nx_tinysdn_options_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_tinysdnsocket_id_t  tinySdnSocketID;

  nx_uint8_t          type;
  nx_am_addr_t        origin;
  nx_am_addr_t        destination;

  nx_uint16_t         flowId;
  nx_uint8_t          actionId;
  nx_uint16_t         actionParameter;

} tinysdn_data_flow_setup_t;



typedef nx_struct tinysdn_open_path_msg {
  nx_tinysdn_options_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_tinysdnsocket_id_t  tinySdnSocketID;

  nx_uint8_t          type;
  nx_am_addr_t        origin;
  nx_am_addr_t destination;

  //nx_am_addr_t next_hop; // we are using path[processingIndex] as next_hop (remember the different use of first bit)
  //nx_uint16_t target; // we are using path[0] as target
  nx_uint16_t path[MAX_OPEN_PATH_HOPS];
  nx_uint8_t  processingIndex; //the first bit is used to inform the Open Path packet direction (downstream = 0, upstream = 1)
} tinysdn_open_path_t; //reference: SDWN 2012 paper

typedef nx_struct tinysdn_report_msg {
  nx_tinysdn_options_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_tinysdnsocket_id_t  tinySdnSocketID;

  nx_uint8_t          type;
  nx_am_addr_t        origin;
  nx_am_addr_t destination;

  nx_neighbor_table neighborTable;
} tinysdn_topology_report_t;

typedef struct {
  am_addr_t neighbor_id;
  int16_t etx;
  uint16_t rssi;
} topology_report_neighbor_table_entry;

typedef nx_struct tinysdn_flow_request_ctp {
  nx_uint8_t          type;
  nx_am_addr_t        origin;
  nx_uint16_t         target; //It can be Flow ID (in data flow case) or Node Address (in control flow case)
} tinysdn_flow_request_ctp_t;


#endif
