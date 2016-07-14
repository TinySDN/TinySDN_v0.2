#ifndef CTP_CONTROLLER_H
#define CTP_CONTROLLER_H

typedef struct {
  nx_uint16_t next_hop;
  nx_uint16_t destination;
  nx_uint16_t target;
  nx_uint16_t origin;
} tinysdn_controller_t;

typedef struct {
  uint16_t source;
  uint16_t neighbor;
  uint16_t etxle;
} tinysdn_report_t;

typedef struct {
  nx_uint16_t origin;
} tinysdn_set_controller_t;

/* OPEN PATH

   OLHAR ARTIGO SDWN_2012 PARA IMPLEMENTAR*/
enum {
  AM_CTP_CONTROLLER_MSG = 0xC0,
};

#endif
