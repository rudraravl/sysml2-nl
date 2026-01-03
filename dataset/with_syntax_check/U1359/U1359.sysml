package 'RS232SerialCommunicationSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BaudRate :> ISQ::FrequencyValue {
        doc /* Serial data transmission rate in bits per second */
    }
    
    attribute def ParityType {
        attribute value : String;
    }
    
    attribute def DataBitCount :> Integer;
    attribute def StopBitCount :> Real;
    
    attribute def VoltageLevel :> ISQ::ElectricPotentialValue {
        doc /* RS-232 voltage levels: +3V to +15V for logic 0 (SPACE), -3V to -15V for logic 1 (MARK) */
    }
    
    item def SerialFrame {
        attribute startBit : Boolean;
        attribute dataBits : Integer;
        attribute parityBit : Boolean;
        attribute stopBits : Real;
        attribute payload : String;
    }
    
    port def RS232Port {
        attribute txd : VoltageLevel;
        attribute rxd : VoltageLevel;
        attribute rts : VoltageLevel;
        attribute cts : VoltageLevel;
        attribute dtr : VoltageLevel;
        attribute dsr : VoltageLevel;
        attribute gnd : VoltageLevel;
    }
    
    part def UART {
        doc /* Universal Asynchronous Receiver/Transmitter - converts parallel data to serial */
        
        attribute baudRate : BaudRate;
        attribute dataBits : DataBitCount;
        attribute stopBits : StopBitCount;
        attribute parity : ParityType;
        
        port parallelDataIn;
        port parallelDataOut;
        port serialOut;
        port serialIn;
    }
    
    part def VoltageConverter {
        doc /* Converts TTL/CMOS logic levels to RS-232 voltage levels and vice versa */
        
        port ttlIn;
        port ttlOut;
        port rs232In;
        port rs232Out;
        
        attribute logicHighVoltage : VoltageLevel;
        attribute logicLowVoltage : VoltageLevel;
        attribute rs232MarkVoltage : VoltageLevel;
        attribute rs232SpaceVoltage : VoltageLevel;
    }
    
    part def DB9Connector {
        doc /* Standard 9-pin D-subminiature connector for RS-232 */
        
        port pin1_DCD;
        port pin2_RXD;
        port pin3_TXD;
        port pin4_DTR;
        port pin5_GND;
        port pin6_DSR;
        port pin7_RTS;
        port pin8_CTS;
        port pin9_RI;
    }
    
    action def EncodeSerialFrame {
        in dataPayload : String;
        in dataBitCount : DataBitCount;
        in parityType : ParityType;
        in stopBitCount : StopBitCount;
        out frame : SerialFrame;
        
        first start;
        then action setStartBit {
            then assign frame.startBit := false;
        }
        then action setDataBits {
            then assign frame.dataBits := dataBitCount;
            then assign frame.payload := dataPayload;
        }
        then action calculateParity {
            out parityValue : Boolean;
        }
        then action setParityBit {
            then assign frame.parityBit := calculateParity.parityValue;
        }
        then action setStopBits {
            then assign frame.stopBits := stopBitCount;
        }
        then done;
    }
    
    action def DecodeSerialFrame {
        in frame : SerialFrame;
        in expectedDataBits : DataBitCount;
        in expectedParity : ParityType;
        out dataPayload : String;
        out isValid : Boolean;
        
        first start;
        then action validateStartBit {
            out valid : Boolean;
        }
        then decide;
            if validateStartBit.valid then checkDataBits;
            if not validateStartBit.valid then reportError;
        
        action checkDataBits {
            out valid : Boolean;
        }
        then decide;
            if checkDataBits.valid then verifyParity;
            if not checkDataBits.valid then reportError;
        
        action verifyParity {
            out valid : Boolean;
        }
        then decide;
            if verifyParity.valid then extractPayload;
            if not verifyParity.valid then reportError;
        
        action extractPayload {
            then assign dataPayload := frame.payload;
            then assign isValid := true;
        }
        then done;
        
        action reportError {
            then assign isValid := false;
        }
        then done;
    }
    
    action def TransmitSerialData {
        in dataToSend : String;
        in baudRate : BaudRate;
        in dataBits : DataBitCount;
        in stopBits : StopBitCount;
        in parity : ParityType;
        out transmissionComplete : Boolean;
        
        first start;
        then action checkRTS {
            out rtsAsserted : Boolean;
        }
        then decide;
            if checkRTS.rtsAsserted then waitForCTS;
            if not checkRTS.rtsAsserted then checkRTS;
        
        action waitForCTS {
            out ctsAsserted : Boolean;
        }
        then decide;
            if waitForCTS.ctsAsserted then encodeData;
            if not waitForCTS.ctsAsserted then waitForCTS;
        
        action encodeData : EncodeSerialFrame {
            in dataPayload = dataToSend;
            in dataBitCount = dataBits;
            in parityType = parity;
            in stopBitCount = stopBits;
            out frame;
        }
        then action convertToRS232Voltage {
            in logicFrame = encodeData.frame;
            out rs232Signal : VoltageLevel;
        }
        then action transmitBits {
            in signal = convertToRS232Voltage.rs232Signal;
            in rate = baudRate;
        }
        then assign transmissionComplete := true;
        then done;
    }
    
    action def ReceiveSerialData {
        in baudRate : BaudRate;
        in expectedDataBits : DataBitCount;
        in expectedParity : ParityType;
        out receivedPayload : String;
        out receptionValid : Boolean;
        
        first start;
        then action detectStartBit {
            out startDetected : Boolean;
        }
        then decide;
            if detectStartBit.startDetected then sampleBits;
            if not detectStartBit.startDetected then detectStartBit;
        
        action sampleBits {
            in rate = baudRate;
            out rawFrame : SerialFrame;
        }
        then action decodeData : DecodeSerialFrame {
            in frame = sampleBits.rawFrame;
            in expectedDataBits = expectedDataBits;
            in expectedParity = expectedParity;
            out dataPayload;
            out isValid;
        }
        then assign receivedPayload := decodeData.dataPayload;
        then assign receptionValid := decodeData.isValid;
        then done;
    }
    
    state def RS232CommunicationState {
        entry; then idle;
        
        state idle {
            accept transmitRequest;
            then transmitting;
        }
        
        state transmitting {
            do action transmit : TransmitSerialData;
            accept transmitComplete;
            then idle;
        }
        
        parallel state receiving {
            state listening {
                do action receive : ReceiveSerialData;
                accept dataReceived;
                then processing;
            }
            
            state processing {
                accept processingComplete;
                then listening;
            }
        }
    }
    
    part def DataTerminalEquipment {
        doc /* DTE device such as computer or terminal */
        
        port rs232Port : RS232Port;
        part uart : UART;
        part voltageConverter : VoltageConverter;
        part connector : DB9Connector;
        
        attribute config {
            attribute baudRate : BaudRate := 9600 [Hz];
            attribute dataBits : DataBitCount := 8;
            attribute stopBits : StopBitCount := 1;
            attribute parity : ParityType;
        }
        
        connect uart.serialOut to voltageConverter.ttlIn;
        connect voltageConverter.rs232Out to connector.pin3_TXD;
        connect connector.pin2_RXD to voltageConverter.rs232In;
        connect voltageConverter.ttlOut to uart.serialIn;
        connect connector.pin5_GND to rs232Port.gnd;
    }
    
    part def DataCommunicationEquipment {
        doc /* DCE device such as modem or peripheral */
        
        port rs232Port : RS232Port;
        part uart : UART;
        part voltageConverter : VoltageConverter;
        part connector : DB9Connector;
        
        attribute config {
            attribute baudRate : BaudRate := 9600 [Hz];
            attribute dataBits : DataBitCount := 8;
            attribute stopBits : StopBitCount := 1;
            attribute parity : ParityType;
        }
        
        connect uart.serialOut to voltageConverter.ttlIn;
        connect voltageConverter.rs232Out to connector.pin2_RXD;
        connect connector.pin3_TXD to voltageConverter.rs232In;
        connect voltageConverter.ttlOut to uart.serialIn;
        connect connector.pin5_GND to rs232Port.gnd;
    }
    
    connection def RS232SignalConnection {
        end source : RS232Port;
        end target : RS232Port;
    }
    
    part rs232CommunicationSystem {
        doc /* 
            RS-232 Serial Communication System
            
            This system implements asynchronous serial data communication between two devices 
            using the RS-232 standard (EIA/TIA-232). The primary function is to enable reliable 
            point-to-point data transmission over a serial interface using standardized voltage 
            signaling and handshaking protocols.
            
            The system converts parallel digital data into serial bit streams, transmits them 
            using RS-232 voltage levels (+/-3V to +/-15V), and reconstructs the original data 
            at the receiving end. It supports configurable baud rates, data formats, parity 
            checking, and hardware flow control (RTS/CTS) for robust communication between 
            Data Terminal Equipment (DTE) and Data Communication Equipment (DCE).
        */
        
        part dte : DataTerminalEquipment {
            :>> config {
                :>> baudRate = 115200 [Hz];
                :>> dataBits = 8;
                :>> stopBits = 1;
            }
        }
        
        part dce : DataCommunicationEquipment {
            :>> config {
                :>> baudRate = 115200 [Hz];
                :>> dataBits = 8;
                :>> stopBits = 1;
            }
        }
        
        connection txConnection : RS232SignalConnection connect 
            dte.rs232Port to dce.rs232Port;
        
        perform action serialCommunication {
            first start;
            then action initializeConnection {
                action assertDTR;
                action assertDSR;
                action assertRTS;
            }
            then merge communicationLoop;
            
            loop {
                action communicationLoop {
                    action dteTransmit : TransmitSerialData;
                    flow dteTransmit.transmissionComplete to dceReceive;
                    
                    action dceReceive : ReceiveSerialData;
                    flow dceReceive.receptionValid to dceTransmit;
                    
                    action dceTransmit : TransmitSerialData;
                    flow dceTransmit.transmissionComplete to dteReceive;
                    
                    action dteReceive : ReceiveSerialData;
                }
                accept continueOperation;
                then communicationLoop;
            }
        }
    }
    
    requirement def RS232VoltageRequirement {
        doc /* RS-232 voltage levels shall conform to EIA/TIA-232-F standard */
        
        require constraint voltageMarkRange {
            -15.0 [V] <= rs232MarkVoltage and rs232MarkVoltage <= -3.0 [V]
        }
        
        require constraint voltageSpaceRange {
            3.0 [V] <= rs232SpaceVoltage and rs232SpaceVoltage <= 15.0 [V]
        }
    }
    
    requirement def RS232DataRateRequirement {
        doc /* Maximum data rate shall not exceed 115200 bps for reliable operation */
        
        require constraint maxBaudRate {
            baudRate <= 115200 [Hz]
        }
    }
    
    requirement def RS232ReliabilityRequirement {
        doc /* System shall detect transmission errors using parity checking */
        
        require constraint parityEnabled {
            parityCheckEnabled == true
        }
    }
    
    requirement def RS232FlowControlRequirement {
        doc /* System shall support hardware flow control using RTS/CTS signals */
        
        require constraint flowControlSupport {
            rtsSupported == true and ctsSupported == true
        }
    }
    
    requirement systemRequirements {
        subject rs232CommunicationSystem;
        
        doc /* Top-level requirements for RS-232 serial communication system */
        
        require voltageReq : RS232VoltageRequirement;
        require dataRateReq : RS232DataRateRequirement;
        require reliabilityReq : RS232ReliabilityRequirement;
        require flowControlReq : RS232FlowControlRequirement;
    }
}
