#ifndef TINYSDN_CONTROLLER_H
#define TINYSDN_CONTROLLER_H

/*typedef struct {
  nx_uint16_t next_hop;
  nx_uint16_t destination;
  nx_uint16_t target;
  nx_uint16_t origin;

  } tinysdn_controller_t;*/

typedef nx_struct tinysdn_controller_msg {
  nx_uint8_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_uint8_t  tinySdnSocketID;

  nx_uint8_t         type;
  nx_uint16_t        origin;
  nx_uint16_t        destination;

  nx_uint16_t        next_hop;
  nx_uint16_t         target; //It can be Flow ID (in data flow case) or Node Address (in control flow case)
} tinysdn_controller_t;

typedef nx_struct tinysdn_data_flow_setup_msg {
  nx_uint8_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_uint8_t  tinySdnSocketID;

  nx_uint8_t          type;
  nx_uint16_t        origin;
  nx_uint16_t        destination;

  nx_uint16_t         flowId;
  nx_uint8_t          actionId;
  nx_uint16_t         actionParameter;

} tinysdn_data_flow_setup_t;


typedef struct {
  nx_uint16_t source;
  nx_uint16_t neighbor;
  nx_uint16_t etxle;
} tinysdn_report_t;

typedef nx_struct tinysdn_find_controller_msg {
  nx_uint16_t origin;
} tinysdn_find_controller_t;

typedef nx_struct tinysdn_open_path_msg {
  nx_uint8_t    options;
  nx_uint8_t          thl;
  nx_uint8_t          originSeqNo;
  nx_uint8_t  tinySdnSocketID;

  nx_uint8_t  type;
  nx_uint16_t origin;
  nx_uint16_t destination;

  //nx_uint16_t target; // we are using path[0] as target

  nx_uint16_t path[6];
  nx_uint8_t  processingIndex; //the first bit is used to inform the Open Path packet direction (downstream = 0, upstream = 1)
} tinysdn_open_path_t; //reference: SDWN 2012 paper

typedef nx_struct tinysdn_flow_request_ctp {
  nx_uint8_t          type;
  nx_uint16_t        origin;
  nx_uint16_t         target; //It can be Flow ID (in data flow case) or Node Address (in control flow case)

} tinysdn_flow_request_ctp_t;

enum {
  AM_TINYSDN_CONTROLLER_MSG = 0xC0,
  AM_TINYSDN_DATA        = 0x73,
  NOT_A_NODE_ADDR 			= 65535U,
  MAX_OPEN_PATH_HOPS 		= 6U,


  // PACKET TYPES
  DATA_PACKET             = 0x00,
  DATA_FLOW_REQUEST       = 0x01,
  DATA_FLOW_RESPONSE      = 0x02,
  CONTROL_FLOW_REQUEST    = 0x03,
  CONTROL_FLOW_RESPONSE   = 0x04,
  REPORT_PACKET           = 0x05,
  DATA_FLOW_OPEN_PATH     = 0x06,
  CONTROL_FLOW_OPEN_PATH  = 0x07,


  ACTION_RECEIVE = 0x00,
  ACTION_FORWARD = 0x01,
  ACTION_DROP    = 0x02

};


#endif
