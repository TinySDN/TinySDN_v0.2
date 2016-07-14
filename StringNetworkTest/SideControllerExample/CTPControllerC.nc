//Set TOS_NODE_ID = 0

#include "Timer.h"
#include "TinySdnController.h"
//#include "Topology.h"
#include "printf.h"


#define CONTROL_FLOW_TABLE_SIZE 10
#define DATA_FLOW_TABLE_SIZE 6
#define CONTROL_FLOW_NOT_FOUND 65535U
#define DATA_FLOW_NOT_FOUND 65535U



module CTPControllerC {
  uses {
    interface Leds;
    interface Boot;
    interface Receive as receiveId2;
    interface Receive as receiveEtx;
    interface AMSend;
    interface Timer<TMilli> as MilliTimer;
    interface SplitControl as AMControl;
    interface Packet;

    interface CollectionPacket;
    interface Receive as CTPreceive;
    interface StdControl as CTPcontrol;
    interface RootControl;

    interface AMSend as rssiAMSend;
    interface Receive;
    interface AMSend as beaconSend;
    interface Receive as beaconReceive;
    interface Packet as rssiPacket;

    interface Send;

  }
}
implementation {

  typedef struct {
    uint16_t destination;
    nx_uint16_t target;
    nx_uint16_t next_hop;
    nx_uint8_t actionID;
  } flow_entry_t;


  message_t packetTest;
  message_t packetRequest;
  message_t packetResponse;
  uint16_t request_source;
  uint16_t request_target;
  uint8_t request_type;

  uint16_t destination;
  uint16_t target;
  uint8_t seqno = 0;

  bool locked=FALSE;
  bool hasRequest=FALSE;
  bool ctpRequest=FALSE;

  message_t packet;

  message_t sendbuf;

  flow_entry_t control_flow_table[CONTROL_FLOW_TABLE_SIZE];
  flow_entry_t data_flow_table[DATA_FLOW_TABLE_SIZE];

  uint8_t control_flow_index = 0;
  uint8_t data_flow_index = 0;

/************
Novos testes
************/

uint16_t destinationA = 1;
uint16_t targetA = 2;


  task void sendResponseTask();
  task void sendTest();
  uint16_t controlFlowTableFindEntry(am_addr_t dest, am_addr_t target);
  uint16_t dataFlowTableFindEntry(am_addr_t dest, am_addr_t target);
  task void applyNextFlow();

  event void Boot.booted() {
    printf("SDN controller booted\n");
    printfflush();

    call AMControl.start();


    control_flow_table[0].destination = 5;
    control_flow_table[0].target = 4;
    control_flow_table[0].next_hop = 4;

    control_flow_table[1].destination = 5;
    control_flow_table[1].target = 3;
    control_flow_table[1].next_hop = 4;

    control_flow_table[2].destination = 4;
    control_flow_table[2].target = 3;
    control_flow_table[2].next_hop = 3;

    data_flow_table[0].destination = 5;
    data_flow_table[0].target = 2016;
    data_flow_table[0].next_hop = 4;
    data_flow_table[0].actionID = ACTION_FORWARD;

    data_flow_table[1].destination = 4;
    data_flow_table[1].target = 2016;
    data_flow_table[1].next_hop = 3;
    data_flow_table[1].actionID = ACTION_FORWARD;

    data_flow_table[2].destination = 3;
    data_flow_table[2].target = 2016;
    data_flow_table[2].next_hop = 2;
    data_flow_table[2].actionID = ACTION_FORWARD;


  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
		call CTPcontrol.start();
		call RootControl.setRoot();

    //call MilliTimer.startPeriodic(100);

    }
    else {
      call AMControl.start();
    }
  }

  event message_t* CTPreceive.receive(message_t* msg, void *payload, uint8_t len) {

    //if (!(call MilliTimer.isRunning() || destinationA == 4 ))    //call MilliTimer.startPeriodic(250);

      call Leds.led1Toggle();

	 if (locked) {
			return msg;
		}

    if(len == sizeof(nx_neighbor_table)){
      uint8_t i;
      nx_neighbor_table* rcm = (nx_neighbor_table*)payload;

      printf("CTP : TOPOLOGY INFORMATION REPORT received from node %u \n", call CollectionPacket.getOrigin(msg));

      for(i=0; i < rcm->numOfNeighbors; i++) {
        printf("        -> Neighbor ID:%u ETX:%u\n", rcm->neighbors[i].neighbor_id, rcm->neighbors[i].etx);
      }

      printfflush();

    }

    else if (len == sizeof(tinysdn_find_controller_t)) {
  			tinysdn_find_controller_t* rcm = (tinysdn_find_controller_t*)payload;
  			request_source =  rcm->origin;
        request_type = CONTROL_FLOW_REQUEST;
  			call Leds.led2Toggle();
  			printf("CTP message received from node _%u_.\n", request_source);
  			printfflush();
  			ctpRequest = TRUE;
  			hasRequest = TRUE;

  			if(request_source == TOS_NODE_ID)
  				call Leds.led0On();

  			if(request_source == 1)
  				call Leds.led1Toggle();

  			post sendResponseTask();
  	} else if (len == sizeof(tinysdn_flow_request_ctp_t)){
      tinysdn_flow_request_ctp_t* rcm = (tinysdn_flow_request_ctp_t*)payload;
      request_type = rcm->type;
      request_target = rcm->target;
      request_source = rcm->origin;

      if(request_type == DATA_FLOW_REQUEST){
        printf("CTP : DATA FLOW REQUEST to FLOW ID=%u received from node %u\n", request_target, request_source);
      }
      else{
        printf("CTP : CONTROL FLOW REQUEST to node %u received from node %u\n", request_target, request_source);
      }
      ctpRequest = TRUE;
      hasRequest = TRUE;
      post sendResponseTask();

      //printf()
    }
		return msg;
  }

  task void applyNextFlow(){

    printf("applyNextFlow \n");
    printfflush();


    if(control_flow_index < CONTROL_FLOW_TABLE_SIZE){
      tinysdn_controller_t* rcm = (tinysdn_controller_t*)call Packet.getPayload(&packetResponse, sizeof(tinysdn_controller_t));
      if (rcm == NULL) {
				return;
			}

      rcm->thl = 0;
      rcm->originSeqNo = seqno++;
      rcm->tinySdnSocketID = 777;
      rcm->type = CONTROL_FLOW_RESPONSE;
      rcm->origin = TOS_NODE_ID;
			rcm->destination = control_flow_table[control_flow_index].destination;
			rcm->target = control_flow_table[control_flow_index].target;
      rcm->next_hop = control_flow_table[control_flow_index].next_hop;

			printf("Hi node _%u_, I am a Controller, forward to node _%u_ . BR, Node _%u_.\n", control_flow_table[control_flow_index].destination, control_flow_table[control_flow_index].next_hop, control_flow_table[control_flow_index].target);
			printfflush();

			if (call AMSend.send(2, &packetResponse, sizeof(tinysdn_controller_t)) == SUCCESS) {
				//call Leds.led2Toggle();
			}

      control_flow_index++;
    }
    else{

      call MilliTimer.stop();/*

      if(data_flow_index < DATA_FLOW_TABLE_SIZE){
        tinysdn_controller_t* rcm = (tinysdn_controller_t*)call Packet.getPayload(&packetResponse, sizeof(tinysdn_controller_t));
        if (rcm == NULL) {
  				return;
  			}

        rcm->thl = 0;
        rcm->originSeqNo = seqno++;
        rcm->tinySdnSocketID = 6;
        rcm->type = DATA_FLOW_RESPONSE;
        rcm->origin = TOS_NODE_ID;
  			rcm->destination = data_flow_table[data_flow_index].destination;
  			rcm->target = data_flow_table[data_flow_index].target;
        rcm->next_hop = data_flow_table[data_flow_index].next_hop;

  			printf("Hi node _%u_, I am a Controller, forward to node _%u_ . BR, DataFlow _%u_.\n",data_flow_table[data_flow_index].destination, data_flow_table[data_flow_index].next_hop, data_flow_table[data_flow_index].target);
  			printfflush();

  			if (call AMSend.send(2, &packetResponse, sizeof(tinysdn_controller_t)) == SUCCESS) {
  				//call Leds.led2Toggle();
  			}

        data_flow_index++;*
      }*/
    }
  }

  event void AMControl.stopDone(error_t err) {
    // do nothing
  }

  event void MilliTimer.fired() { //logo pode apagar isso


      /*uint8_t *o = (uint8_t *)call Send.getPayload(&sendbuf, sizeof(uint8_t));
      uint8_t x = 55;
      if (o == NULL) {
	       printf("erro ao enviar 1\n");
         printfflush();
	        return;
      }
      memcpy(o, &x, sizeof(x));
      if (call Send.send(&sendbuf, sizeof(x)) == SUCCESS){
        printf("Enviou pelo CTP!\n");
        printfflush();
      }
      else{
        printf("erro ao enviar 2\n");
        printfflush();
      }*/


/*      tinysdn_controller_t* rcm = (tinysdn_controller_t*)call Packet.getPayload(&packetResponse, sizeof(tinysdn_controller_t));
      if (rcm == NULL) {
				return;
			}


      if (destinationA == 4 && targetA == 2) {
        call MilliTimer.stop();
        return;
      }

      if (targetA == 5) { //chegou no ultimo fluxo de controle
        targetA = 2;
      }
      else {
        if (targetA == 2) { //já estabeleceu o data flow para o nó 2, pode passar para o próximo destino
          destinationA ++;
          targetA = destinationA + 1;
        }
        else {
          targetA ++;
        }
      }




      rcm->thl = 0;
      rcm->originSeqNo = seqno++;
      rcm->tinySdnSocketID = 777;
      rcm->type = CONTROL_FLOW_RESPONSE;
      rcm->origin = TOS_NODE_ID;
			rcm->destination = destinationA;
			rcm->target = targetA;
      rcm->next_hop = destinationA + 1;

			//printf("Hi node _%u_, I am a Controller, forward to node _%u_ . BR, Node _%u_.\n",request_source, rcm->next_hop, rcm->target);
			//printfflush();

      if(rcm->destination == TOS_NODE_ID){
        //printf("SUPER ERROR!!!!\n");
        //printfflush();

      }

			if (call AMSend.send(2, &packetResponse, sizeof(tinysdn_controller_t)) == SUCCESS) {
				call Leds.led2Toggle();
			}*/


	  //post sendResponseTask(); //responde


    post applyNextFlow();
  }

	task void sendResponseTask() { //enviar resposta ao nó que requisitou o fluxo
/*
    printf("SUPER ERROR!!!!\n");
    printfflush();*/


		if (!hasRequest || locked) { //se estiver usando o radio ou se nao houver solitacoes (request_source = 0), entao nao faz nada quando expira o tempo
			return;
		}
		else if(ctpRequest) {
      uint8_t flowTableIndex;

      if(request_type == CONTROL_FLOW_REQUEST){
        tinysdn_controller_t* rcm = (tinysdn_controller_t*)call Packet.getPayload(&packetResponse, sizeof(tinysdn_controller_t));
        if (rcm == NULL) {
          return;
        }
        rcm->thl = 0;
        rcm->originSeqNo = seqno++;
        rcm->tinySdnSocketID = 777;

        rcm->type = CONTROL_FLOW_RESPONSE;
        flowTableIndex = controlFlowTableFindEntry(request_source, request_target);
        rcm->next_hop = control_flow_table[flowTableIndex].next_hop;

        rcm->origin = TOS_NODE_ID;
        rcm->destination = request_source;
        rcm->target = request_target;

        if (call AMSend.send(5, &packetResponse, sizeof(tinysdn_data_flow_setup_t)) == SUCCESS) {
          locked = TRUE;
        }
        printf("TSDN: CONTROL FLOW SETUP to node %u has been sent to node %u\n", request_target, request_source);
      }
      else if(request_type == DATA_FLOW_REQUEST){

        tinysdn_data_flow_setup_t* rcm = (tinysdn_data_flow_setup_t*)call Packet.getPayload(&packetResponse, sizeof(tinysdn_data_flow_setup_t));
        if (rcm == NULL) {
          return;
        }
        rcm->thl = 0;
        rcm->originSeqNo = seqno++;
        rcm->tinySdnSocketID = 777;

        rcm->type = DATA_FLOW_RESPONSE;
        flowTableIndex = dataFlowTableFindEntry(request_source, request_target);
        rcm->actionId = data_flow_table[flowTableIndex].actionID;
        rcm->actionParameter = data_flow_table[flowTableIndex].next_hop;

        rcm->origin = TOS_NODE_ID;
  			rcm->destination = request_source;
  			rcm->flowId = request_target;

        if (call AMSend.send(5, &packetResponse, sizeof(tinysdn_data_flow_setup_t)) == SUCCESS) {
  				locked = TRUE;
  			}
        printf("TSDN: DATA FLOW SETUP to FLOW ID=%u has been sent to node %u", rcm->flowId, rcm->destination);
        if(rcm->actionId == ACTION_FORWARD){
          printf("     -> Action: FORWARD, Parameter (next hop): %u\n", rcm->actionParameter);
        }else if(rcm->actionId == ACTION_RECEIVE){
          printf("     -> Action: RECEIVE\n");
        }
      }

			//printf("Hi node _%u_, I am a Controller, forward to node _%u_ . BR, Node _%u_.\n",request_source, rcm->next_hop, rcm->target);
			//printfflush();

      if(request_source == TOS_NODE_ID){
        printf("SUPER ERROR!!!!\n");
        printfflush();
      }


		}
		else {
			tinysdn_controller_t* rcm = (tinysdn_controller_t*)call Packet.getPayload(&packetResponse, sizeof(tinysdn_controller_t));
			if (rcm == NULL) {
				return;
			}
		  rcm->thl = 0;
		  rcm->originSeqNo = seqno++;
      if(request_type == CONTROL_FLOW_REQUEST) rcm->type = CONTROL_FLOW_RESPONSE;
      else if(request_type == DATA_FLOW_REQUEST) rcm->type = DATA_FLOW_RESPONSE;
		  rcm->tinySdnSocketID = 147;

			if(request_source > target)
				rcm->next_hop = request_source-1; //indicando o proximo salto em direcao ao sensor de id = 1
			else
				rcm->next_hop = request_source+1;

			rcm->destination = request_source;
			rcm->target = target;
			rcm->origin = TOS_NODE_ID;


      if(rcm->destination == TOS_NODE_ID){
        //printf("SUPER ERROR!!!!\n");
        //printfflush();

      }

			if (call AMSend.send(2, &packetResponse, sizeof(tinysdn_controller_t)) == SUCCESS) {
				/*call Leds.led1Off();
				call Leds.led2On();
				call Leds.led0Off();*/
				locked = TRUE;
				//printf("\n\nrequest = %u\n\ndestination = %u\n\ntarget = %u\n\n",request_source, rcm->destination, target);
				//printfflush();
				//printf("Hello node _%u_, send to node _%u_ it will be sent to node _%u_.\n",request_source, rcm->next_hop, rcm->target);
				//printfflush();
			}
		}
		return;
	}

  event message_t* receiveEtx.receive(message_t* bufPtr,
				   void* payload, uint8_t len) {

		call Leds.led2Toggle();

      /*if (len == sizeof(id_plus_etx)) {
		id_plus_etx* rcm = (id_plus_etx*)payload;
		printf("\n\nMensagem recebida do noh: %u\n", rcm->source);
		printf("O noh %u eh vizinho com ETX de %u\n\n", rcm->neighbor, rcm-> etxle);
		printfflush();
      }
*/
	return bufPtr;
  }

  event message_t* receiveId2.receive(message_t* bufPtr, void* payload, uint8_t len) {
	  //call Leds.led0Toggle();
		if (locked)
			return bufPtr;

   //printf("Chegou mensagem de controle no receiveId2.\n");
    //printfflush();


		if(len == sizeof(tinysdn_controller_t)) {
			tinysdn_controller_t* rcm = (tinysdn_controller_t*)payload;
			request_source =  rcm->origin;
			destination = rcm->destination;
			target = rcm->target;
      request_type = rcm->type;

			if(request_source == TOS_NODE_ID) {
				call Leds.led0Toggle();
        //printf("Deu erro, recebi uma requisicao de mim mesmo! Type:%u, Thl:%u, Seqno:%u\n",  rcm->type,  rcm->thl,  rcm->originSeqNo);
       // printfflush();
			}
      else{
        //call Leds.led1On();
        hasRequest = TRUE;
        //printf("Node _%u_ received flow request from node _%u_  to target = _%u_, type = \n", destination, request_source,  target, type);
        //if(target == 1 && type == DATA_FLOW_REQUEST)
          //post sendTest(); //para o Open Path
        //else
          post sendResponseTask();

        //printfflush();
      }

		}

		return bufPtr;

  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	if (&packetResponse == bufPtr) {
      locked = FALSE;
      hasRequest = FALSE;// sinaliza a solicitacao de fluxo atendida
      ctpRequest = FALSE;
    } //else call Leds.led0On();

    if (error==FAIL){
      printf("Error trying to send");
    	call Leds.led0On();
    }
    else if (error==ECANCEL)
      printf("Error trying to send");
      call Leds.led1On();

  }

  task void sendTest(){

	uint8_t i = 0;
	uint8_t totalHops = target-1;

    tinysdn_open_path_t*  rct = (tinysdn_open_path_t* )call Packet.getPayload(&packetTest, sizeof(tinysdn_open_path_t));


   // printf("Entrou no openpath!\n");
    //printfflush();

    //path init
    for (i = 0; i <  MAX_OPEN_PATH_HOPS; i++)  rct->path[i] = NOT_A_NODE_ADDR;

    if(locked){
      //printf("ERRO LOCKED!\n");
      //printfflush();
      return;
    }

    if (rct == NULL) {
      //printf("ERRO NULL!\n");
      //printfflush();
      return;
    }

    locked = TRUE;

    rct->thl = 0;
    rct->originSeqNo = seqno++;
    rct->tinySdnSocketID = 147;
    rct->type = DATA_FLOW_OPEN_PATH;
    rct->origin = TOS_NODE_ID;
    rct->destination = 1;



   // rct->path = {TOS_NODE_ID, 1, 2, 3, 4, 5};

    rct->path[0] = target;

  for(i = 1; i < totalHops ; i++){ //one of the hops is the destination
		rct->path[i] = target - i;
	}
	rct->processingIndex = i - 1;


    //printf(">>>>>>>>>>>>>>>>PASSOU!\n");
   // printfflush();

    if(call AMSend.send(1, &packetTest, sizeof(tinysdn_open_path_t)) == SUCCESS){}
      //  printf("Mandou openpath packet!\n");
   // printfflush();
  }



  event message_t* beaconReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {

    rssi_beacon_msg* sendpointer = (rssi_beacon_msg*)call Packet.getPayload(&packet, sizeof(rssi_beacon_msg));

    sendpointer -> source_id = TOS_NODE_ID;
    sendpointer->controller_id = TOS_NODE_ID;
    sendpointer -> metric = 0;
    if (call beaconSend.send(1, &packet, sizeof(rssi_beacon_msg)) == SUCCESS)
      call Leds.led0Toggle();

    return bufPtr;
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    report* notifypointer = (report*)payload;
    uint8_t i;


    printf("\n\n***********Mensagem recebida do noh: %u***********\n", notifypointer->sender);
    printfflush();

    for(i=0; i< notifypointer->n_neighbors; i++){
      printf("O vizinho %u tem RSSI de %u\n -> com Fator de tempo = %u\n\n", notifypointer->neighbors[i].neighbor_id, notifypointer->neighbors[i].rssi, notifypointer->neighbors[i].time_to_live);
      printfflush();
    }
    printf("-----------------------------\n");
    printfflush();



    return bufPtr;
  }

  event void beaconSend.sendDone(message_t* bufPtr, error_t error) {}

  event void rssiAMSend.sendDone(message_t* bufPtr, error_t error) {}

  event void Send.sendDone(message_t* bufPtr, error_t error) {}

    //given a destination, if it exists in control flow table return entry index, else return the FLOW_NOT_FOUND value
    uint16_t controlFlowTableFindEntry(am_addr_t dest, am_addr_t target) {
      uint16_t i;
      for (i = 0; i < CONTROL_FLOW_TABLE_SIZE; i++) {
        if (control_flow_table[i].destination == dest && control_flow_table[i].target == target)
          break;
      }

      if(CONTROL_FLOW_TABLE_SIZE == i)
        return CONTROL_FLOW_NOT_FOUND;

      return i;
    }

    //given a destination, if it exists in data flow table return entry index, else return the FLOW_NOT_FOUND value
    uint16_t dataFlowTableFindEntry(am_addr_t dest, am_addr_t target) {
      uint16_t i;
      for (i = 0; i < DATA_FLOW_NOT_FOUND; i++) {
        if (data_flow_table[i].destination == dest && data_flow_table[i].target == target)
          break;
      }

      if(DATA_FLOW_TABLE_SIZE == i)
        return DATA_FLOW_NOT_FOUND;

      return i;
    }


}
