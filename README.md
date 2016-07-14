Instalation
    cd TinyOSComponents/

    $./install.sh
    It will copy the TinySDN_base_files folder content to $(TOSDIR)/lib/net/.



Executing String Network Test Example:	
    $ cd StringNetworkTest
    $ ./compileString.sh
	then run StringTopology.csc on cooja
	You can add a extra SecundaryControllerNode to network, place it near to node 5
	
	It includes just hardcoded controllers, so topology is spefic and static

TinySDN Usage

To be able to use TinySDN protocol is necessary to include the following line in Makefile :
CFLAGS += -I$(TOSDIR)/lib/net/ -I$(TOSDIR)/lib/net/TinySDN -I$(TOSDIR)/lib/net/ctp  -I$(TOSDIR)/lib/net/4bitle

The TinySdnP component provide to TinyOS application programmer two main interfaces:

    AMSend - it is an interface that enables data sending through the TinySDN tool protocol by calling the send command function, which receives three parameters: data flow id that identifies the flow to be used, a pointer to the message packet to be sent, and packet length. Furthermore, when instantiating this interface is mandatory implementation of the send done event to handles results (callbacks) of send command calls.
        command to send : call AMSend.send([destination_dataflow_Id], [message_packet_pointer], [sizeof(message)])
        event to handle command send result : event void AMSend.sendDone(message_t* bufPtr, error_t error) { ... }

    Receive - it is an interface that enables data receiving through the TinySDN tool protocol by handling the packet reception event in a callback function implementation. This receive event implementation receives from the lower software layers the following parameters: received packet, a pointer to the packet's payload, and packet length.
        event to handle packet reception in a TinyOS application : event void AMSend.sendDone(message_t* bufPtr, error_t error) { ... }

