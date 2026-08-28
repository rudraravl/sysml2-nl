package RS232SerialCommunication {

    import ScalarValues::*;

    package Units {
        unit bps;
        unit volt;
        unit bit;
    }

    package ValueTypes {
        value type BaudRate :> Real {
            unit bps;
        }
        value type VoltageLevel :> Real {
            unit volt;
        }
        value type BitCount :> Integer;
        value type PinNumber :> Integer(1..9);
    }

    package Enums {
        enum def ParityType {
            none;
            even;
            odd;
        }
        enum def DeviceRole {
            dte;
            dce;
        }
    }

    package Items {
        item def LogicBit {
            value value : Integer(0..1);
        }
        item def RS232Bit {
            value value : Integer(0..1);
        }
        item def ParallelByte {
            value bits : Integer(0..1)[8];
        }
        item def SerialFrame {
            attribute startBit : LogicBit;
            attribute dataBits : LogicBit[5..8];
            attribute parityBit : LogicBit optional;
            attribute stopBits : LogicBit[1..2];
            attribute parityType : ParityType;
            attribute frameValid : Boolean;
        }
    }

    package Ports {
        import Items::*;
        import ValueTypes::*;

        port def ParallelBusPort {
            out txByte : ParallelByte;
            in rxByte : ParallelByte;
        }
        port def LogicSerialPort {
            attribute baudRate : BaudRate;
            out tx : LogicBit;
            in rx : LogicBit;
            out rts : LogicBit;
            in cts : LogicBit;
        }
        port def RS232LinePort {
            out tx : RS232Bit;
            in rx : RS232Bit;
            out rts : RS232Bit;
            in cts : RS232Bit;
        }
        port def DB9PinPort {
            attribute pinNumber : PinNumber;
            in signal : RS232Bit;
        }
    }

    package Interfaces {
        import Ports::*;
        import Items::*;

        interface def LogicSerialLink {
            end a : LogicSerialPort;
            end b : LogicSerialPort;
            flow txData of LogicBit from a.tx to b.rx;
            flow rtsSignal of LogicBit from a.rts to b.cts;
        }
        interface def RS232CableLink {
            end a : RS232LinePort;
            end b : RS232LinePort;
            flow txA of RS232Bit from a.tx to b.rx;
            flow txB of RS232Bit from b.tx to a.rx;
            flow rtsA of RS232Bit from a.rts to b.cts;
            flow rtsB of RS232Bit from b.rts to a.cts;
        }
    }

    package Components {
        import Ports::*;
        import Interfaces::*;
        import Items::*;
        import ValueTypes::*;
        import Enums::*;

        part def UART {
            attribute baudRate : BaudRate = 9600 [bps];
            attribute dataBits : BitCount = 8;
            attribute parity : ParityType = ParityType::none;
            attribute stopBits : BitCount = 1;

            port busPort : ParallelBusPort;
            port serialPort : LogicSerialPort;

            item txBuffer : SerialFrame[*];
            item rxBuffer : SerialFrame[*];

            private attribute txActive : Boolean = false;
            private attribute rxActive : Boolean = false;

            action def SerializeFrame {
                in frame : SerialFrame;
                out bitStream : LogicBit[*];
            }
            action def DeserializeFrame {
                in bitStream : LogicBit[*];
                out frame : SerialFrame;
            }
            action def CheckParity {
                in frame : SerialFrame;
                out valid : Boolean;
            }

            state machine UARTStateMachine {
                state idle;
                state transmitting;
                state receiving;
                state transmitAndReceive;

                transition t_init initial to idle;

                transition t_startTx
                    idle to transmitting
                    when txBuffer->notEmpty() and serialPort.cts.value == 1
                    do { txActive := true; };

                transition t_startRx
                    idle to receiving
                    when serialPort.rx.value == 0
                    do { rxActive := true; };

                transition t_txThenRx
                    transmitting to transmitAndReceive
                    when serialPort.rx.value == 0
                    do { rxActive := true; };

                transition t_rxThenTx
                    receiving to transmitAndReceive
                    when txBuffer->notEmpty() and serialPort.cts.value == 1
                    do { txActive := true; };

                transition t_endTx
                    transmitting to idle
                    when txBuffer->isEmpty()
                    do { txActive := false; };

                transition t_endTxFromBoth
                    transmitAndReceive to receiving
                    when txBuffer->isEmpty()
                    do { txActive := false; };

                transition t_endRx
                    receiving to idle
                    when rxBuffer->size() >= 1
                    do { rxActive := false; };

                transition t_endRxFromBoth
                    transmitAndReceive to transmitting
                    when rxBuffer->size() >= 1
                    do { rxActive := false; };
            }
        }

        part def VoltageConverter {
            attribute logicHigh : VoltageLevel = 3.3 [volt];
            attribute logicLow : VoltageLevel = 0.0 [volt];
            attribute rs232Zero : VoltageLevel = 12.0 [volt];
            attribute rs232One : VoltageLevel = -12.0 [volt];

            port logicSide : LogicSerialPort;
            port lineSide : RS232LinePort;

            action def ConvertLogicToRS232 {
                in logicBit : LogicBit;
                out rs232Bit : RS232Bit;
                if logicBit.value == 0 then {
                    rs232Bit.value := 0;
                } else {
                    rs232Bit.value := 1;
                }
            }
            action def ConvertRS232ToLogic {
                in rs232Bit : RS232Bit;
                out logicBit : LogicBit;
                logicBit.value := rs232Bit.value;
            }
        }

        part def DB9Connector {
            attribute pinCount : Integer = 9;
            attribute txdPin : PinNumber = 3;
            attribute rxdPin : PinNumber = 2;
            attribute rtsPin : PinNumber = 7;
            attribute ctsPin : PinNumber = 8;
            attribute gndPin : PinNumber = 5;

            port linePort : RS232LinePort;
            port pin2 : DB9PinPort { pinNumber = 2; }
            port pin3 : DB9PinPort { pinNumber = 3; }
            port pin5 : DB9PinPort { pinNumber = 5; }
            port pin7 : DB9PinPort { pinNumber = 7; }
            port pin8 : DB9PinPort { pinNumber = 8; }
        }

        part def DTE {
            attribute role : DeviceRole = DeviceRole::dte;
            attribute deviceName : String;

            port internalBus : ParallelBusPort;
            port rs232Interface : RS232LinePort;

            part uart : UART {
                baudRate = 115200 [bps];
                parity = ParityType::none;
            }
            part converter : VoltageConverter;
            part connector : DB9Connector;

            connect uart.busPort to internalBus;
            connect uart.serialPort to converter.logicSide;
            connect converter.lineSide to connector.linePort;
            connect connector.linePort to rs232Interface;
        }

        part def DCE {
            attribute role : DeviceRole = DeviceRole::dce;
            attribute deviceName : String;

            port internalBus : ParallelBusPort;
            port rs232Interface : RS232LinePort;

            part uart : UART {
                baudRate = 115200 [bps];
                parity = ParityType::none;
            }
            part converter : VoltageConverter;
            part connector : DB9Connector;

            connect uart.busPort to internalBus;
            connect uart.serialPort to converter.logicSide;
            connect converter.lineSide to connector.linePort;
            connect connector.linePort to rs232Interface;
        }

        part def RS232Cable {
            attribute length : Real = 1.5;
            attribute shielded : Boolean = true;
            port endA : RS232LinePort;
            port endB : RS232LinePort;
            interface : RS232CableLink connect endA to endB;
        }
    }

    package Requirements {
        import Components::*;
        import ValueTypes::*;

        requirement def ReliableDataExchange {
            subject system;
            requirement {
                The system shall support reliable point-to-point data exchange between a DTE and a DCE over a cabled RS-232 connection.
            }
        }
        requirement def MaxBaudRate {
            subject uart : UART;
            attribute maxRate : BaudRate = 115200 [bps];
            requirement {
                The UART shall operate reliably at baud rates up to maxRate.
            }
        }
        requirement def SerialFrameFormat {
            subject uart : UART;
            requirement {
                The UART shall package data into serial frames comprising a start bit, 5 to 8 data bits, an optional parity bit, and 1 or 2 stop bits.
            }
        }
        requirement def RS232VoltageLevels {
            subject converter : VoltageConverter;
            requirement {
                The converter shall translate logic-level signals to RS-232 levels with positive voltage representing a '0' bit and negative voltage representing a '1' bit.
            }
        }
        requirement def HardwareFlowControl {
            subject uart : UART;
            requirement {
                The UART shall use RTS and CTS signals for hardware flow control and shall transmit data only when CTS is asserted.
            }
        }
        requirement def ConfigurableParameters {
            subject uart : UART;
            requirement {
                The UART shall allow configuration of baud rate, number of data bits, and parity type.
            }
        }
        requirement def SimultaneousTxRx {
            subject uart : UART;
            requirement {
                The UART shall support simultaneous transmission and reception of data.
            }
        }
        requirement def DB9PhysicalInterface {
            subject connector : DB9Connector;
            requirement {
                The connector shall provide a standard 9-pin physical interface for RS-232 communication.
            }
        }

        requirement reliableComm : ReliableDataExchange;
        requirement maxBaud : MaxBaudRate;
        requirement frameFormat : SerialFrameFormat;
        requirement voltageLevels : RS232VoltageLevels;
        requirement flowControl : HardwareFlowControl;
        requirement configParams : ConfigurableParameters;
        requirement simultaneousTxRx : SimultaneousTxRx;
        requirement db9Interface : DB9PhysicalInterface;
    }

    part RS232System {
        import Components::*;
        import Interfaces::*;
        import Requirements::*;

        part dte : DTE {
            deviceName = "HostComputer";
        }
        part dce : DCE {
            deviceName = "Modem";
        }
        part cable : RS232Cable;

        interface : RS232CableLink connect dte.rs232Interface to cable.endA;
        interface : RS232CableLink connect cable.endB to dce.rs232Interface;

        satisfy reliableComm by RS232System;
        satisfy maxBaud by dte.uart;
        satisfy maxBaud by dce.uart;
        satisfy frameFormat by dte.uart;
        satisfy frameFormat by dce.uart;
        satisfy voltageLevels by dte.converter;
        satisfy voltageLevels by dce.converter;
        satisfy flowControl by dte.uart;
        satisfy flowControl by dce.uart;
        satisfy configParams by dte.uart;
        satisfy configParams by dce.uart;
        satisfy simultaneousTxRx by dte.uart;
        satisfy simultaneousTxRx by dce.uart;
        satisfy db9Interface by dte.connector;
        satisfy db9Interface by dce.connector;
    }
}
