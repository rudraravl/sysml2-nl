package RS232System {
    private import ScalarValues::*;
    private import ISQElectromagnetism::*;
    private import ISQ::*;

    item def Bit;
    item def SerialFrame {
        attribute startBit : Bit;
        attribute dataBits : Bit[5..8];
        attribute parityBit : Bit[0..1];
        attribute stopBits : Bit[1..2];
    }

    item def TxRequest;
    item def RxStart;
    item def TxComplete;
    item def RxComplete;

    attribute def BaudRate :> Integer;
    attribute def ParityMode :> String;
    attribute def VoltageLevel :> ElectricPotentialUnit;

    port def DataPort;
    port def ControlPort;
    port def GroundPort;

    action def SerializeFrame {
        in frame : SerialFrame;
        out bit : Bit;
    }

    action def DeserializeFrame {
        in bit : Bit;
        out frame : SerialFrame;
    }

    action def AssertRTS {
        out rtsSignal : Boolean;
    }

    action def CheckCTS {
        in ctsSignal : Boolean;
        out isClear : Boolean;
    }

    state def UARTState {
        entry; then Idle;

        state Idle {
            do action AssertRTS;
        }

        state Transmitting {
            do action SerializeFrame;
        }

        state Receiving {
            do action DeserializeFrame;
        }

        state FullDuplex {
            state Tx;
            state Rx;
        }

        transition first Idle
            accept TxRequest
            then Transmitting;
        transition first Idle
            accept RxStart
            then Receiving;
        transition first Transmitting
            accept TxComplete
            then Idle;
        transition first Receiving
            accept RxComplete
            then Idle;
        transition first Transmitting
            accept RxStart
            then FullDuplex;
        transition first Receiving
            accept TxRequest
            then FullDuplex;
        transition first FullDuplex
            accept TxComplete
            then Receiving;
        transition first FullDuplex
            accept RxComplete
            then Transmitting;
    }

    part def UART {
        attribute baudRate : BaudRate = 115200;
        attribute dataBitCount : Integer = 8;
        attribute paritySetting : ParityMode = "none";
        attribute stopBitCount : Integer = 1;

        port parallelBus;
        port txPort : DataPort;
        port rxPort : DataPort;
        port rtsPort : ControlPort;
        port ctsPort : ControlPort;

        state uartState : UARTState;
    }

    part def VoltageConverter {
        doc /** Translates logic-level signals to RS-232 voltage levels: positive for 0, negative for 1. **/
        attribute positiveVoltage : VoltageLevel = 12 [V];
        attribute negativeVoltage : VoltageLevel = -12 [V];

        port logicTxIn : DataPort;
        port logicRxOut : DataPort;
        port rs232TxOut : DataPort;
        port rs232RxIn : DataPort;
        port logicRtsIn : ControlPort;
        port logicCtsOut : ControlPort;
        port rs232RtsOut : ControlPort;
        port rs232CtsIn : ControlPort;
        port groundRef : GroundPort;
    }

    part def DB9Connector {
        doc /** Standard 9-pin RS-232 connector. **/
        port pin2_rxd : DataPort;
        port pin3_txd : DataPort;
        port pin5_gnd : GroundPort;
        port pin7_rts : ControlPort;
        port pin8_cts : ControlPort;
    }

    part def DTE {
        doc /** Data Terminal Equipment - data source or destination (e.g., computer). **/
        port internalBus;

        part uart : UART;
        part converter : VoltageConverter;
        part connector : DB9Connector;

        connect internalBus to uart.parallelBus;
        connect uart.txPort to converter.logicTxIn;
        connect converter.logicRxOut to uart.rxPort;
        connect uart.rtsPort to converter.logicRtsIn;
        connect converter.logicCtsOut to uart.ctsPort;
        connect converter.rs232TxOut to connector.pin3_txd;
        connect connector.pin2_rxd to converter.rs232RxIn;
        connect converter.rs232RtsOut to connector.pin7_rts;
        connect connector.pin8_cts to converter.rs232CtsIn;
        connect connector.pin5_gnd to converter.groundRef;
    }

    part def DCE {
        doc /** Data Communication Equipment - handles network connection (e.g., modem). **/
        port networkPort;

        part uart : UART;
        part converter : VoltageConverter;
        part connector : DB9Connector;

        connect networkPort to uart.parallelBus;
        connect uart.txPort to converter.logicTxIn;
        connect converter.logicRxOut to uart.rxPort;
        connect uart.rtsPort to converter.logicRtsIn;
        connect converter.logicCtsOut to uart.ctsPort;
        connect converter.rs232TxOut to connector.pin2_rxd;
        connect connector.pin3_txd to converter.rs232RxIn;
        connect converter.rs232RtsOut to connector.pin8_cts;
        connect connector.pin7_rts to converter.rs232CtsIn;
        connect connector.pin5_gnd to converter.groundRef;
    }

    connection def RS232Cable {
        end dteTxd : DataPort;
        end dceRxd : DataPort;
        end dceTxd : DataPort;
        end dteRxd : DataPort;
        end dteRts : ControlPort;
        end dceCts : ControlPort;
        end dceRts : ControlPort;
        end dteCts : ControlPort;
        end dteGnd : GroundPort;
        end dceGnd : GroundPort;
    }

    part rs232System {
        part dte : DTE;
        part dce : DCE;

        connection cable : RS232Cable {
            end dteTxd ::> dte.connector.pin3_txd;
            end dceRxd ::> dce.connector.pin2_rxd;
            end dceTxd ::> dce.connector.pin3_txd;
            end dteRxd ::> dte.connector.pin2_rxd;
            end dteRts ::> dte.connector.pin7_rts;
            end dceCts ::> dce.connector.pin8_cts;
            end dceRts ::> dce.connector.pin7_rts;
            end dteCts ::> dte.connector.pin8_cts;
            end dteGnd ::> dte.connector.pin5_gnd;
            end dceGnd ::> dce.connector.pin5_gnd;
        }
    }

    requirement def RS232CommunicationRequirement {
        doc /** The system shall support RS-232 serial communication up to 115200 baud. **/
        attribute maxBaudRate : BaudRate = 115200;
        attribute minBaudRate : BaudRate = 300;
        attribute supportedDataBits : Integer = 8;
        attribute supportedParity : ParityMode = "none";
        attribute supportedStopBits : Integer = 1;
    }

    requirement def FlowControlRequirement {
        doc /** The system shall use RTS/CTS hardware flow control to prevent data loss. **/
    }

    requirement def VoltageRequirement {
        doc /** Logic 0 shall be represented by positive voltage, logic 1 by negative voltage per RS-232. **/
        attribute positiveLevel : VoltageLevel = 12 [V];
        attribute negativeLevel : VoltageLevel = -12 [V];
    }

    requirement def FrameFormatRequirement {
        doc /** Data shall be packaged into serial frames with start bit, data bits, optional parity, and stop bits. **/
        attribute startBits : Integer = 1;
        attribute dataBitRange : String = "5..8";
        attribute parityOptional : Boolean = true;
        attribute stopBitRange : String = "1..2";
    }

    requirement def ReliabilityRequirement {
        doc /** The system shall provide reliable point-to-point data exchange between DTE and DCE. **/
        attribute maxBitErrorRate : Real = 1e-9;
    }

    satisfy RS232CommunicationRequirement by rs232System;
    satisfy FlowControlRequirement by rs232System.dte.uart, rs232System.dce.uart;
    satisfy VoltageRequirement by rs232System.dte.converter, rs232System.dce.converter;
    satisfy FrameFormatRequirement by rs232System;
    satisfy ReliabilityRequirement by rs232System;
}
