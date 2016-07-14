/**
 * SDN-enabled Sensor Node Test application using the TinySDN layer.
 * See README.txt
 *
 * @author Bruno Trevizan de Oliveira
  */

#ifndef SDN_ENABLED_SENSOR_NODE_H
#define SDN_ENABLED_SENSOR_NODE_H

#include "AM.h"

enum {
  /* Default sampling period. */
  DEFAULT_INTERVAL = 1000,
  AM_MVIZ_MSG = 0x93,
  AM_TEST_SERIAL_MSG = 0x89,
  MAXTESTE = 16
};

typedef nx_struct mviz_msg {
  nx_uint8_t msgTeste[MAXTESTE];
  nx_uint16_t interval; /* Samping period. */
} mviz_msg_t;


typedef nx_struct test_serial_msg {
  nx_uint16_t nodeId;
  nx_uint8_t packetType; /* 0 if is packet for send DATA and 1 if it's Packet for receive DATA */
} test_serial_msg_t;


typedef nx_struct radio_count_msg {
  nx_uint8_t counter;
} radio_count_msg_t;

#endif
