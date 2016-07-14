#ifndef _TOPOLOGY_H
#define _TOPOLOGY_H

#include "AM.h"

enum {
  //constants
  NEIGHBOR_TTL_RENEW = 5,
  NEIGHBOR_TTL_DECREASE_INTERVAL = 5000,
  RSSI_BEACON_INTERVAL = 5000,
  NEIGHBOR_TABLE_SIZE = 10,
  TOPOLOGY_NOTIFICATION_INTERVAL = 2000,
  NEIGHBOR_UNAVAILABLE = 345,
  AM_TOPOLOGY_MSG = 0xdd,
  AM_RSSIMSG = 0xbb
};

// beacon packet struct
typedef nx_struct rssi_beacon_msg{
  nx_uint16_t source_id;
  nx_uint16_t controller_id;
  nx_uint16_t metric;
  nx_bool findController;
}rssi_beacon_msg;

//neighborTable entry struct
typedef struct {
  uint16_t neighbor_id;
  uint16_t rssi;
  uint8_t time_to_live;
} neighbor_table_entry;

//neighborTable struct
typedef struct {
  nx_uint16_t sender;
  nx_uint16_t n_neighbors;
  neighbor_table_entry neighbors[NEIGHBOR_TABLE_SIZE];
} report;

//RSSI packet struct
typedef nx_struct RssiMsg{
  nx_int16_t rssi;
} RssiMsg;

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
