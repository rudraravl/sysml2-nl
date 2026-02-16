package 'X10 Firecracker System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def HouseCode {
        value : String;
    }
    
    attribute def UnitCode {
        value : Integer;
    }
    
    attribute def X10Address {
        houseCode : HouseCode;
        unitCode : UnitCode;
    }
    
    enum def X10FunctionCode {
        on;
        off;
        dim;
        bright;
        allLightsOn;
        allUnitsOff;
    }
    
    attribute def X10Command {
        address : X10Address;
        function : X10FunctionCode;
    }
    
    attribute def RFCarrierFrequency :> FrequencyValue;
    attribute def PowerLineFrequency :> FrequencyValue;
    
    item def RFSignal {
        attribute carrierFrequency : RFCarrierFrequency;
        attribute modulatedCommand : X10Command;
    }
    
    item def PowerLineSignal {
        attribute lineFrequency : PowerLineFrequency;
        attribute encodedCommand : X10Command;
    }
    
    port def SerialPort {
        in commandData : X10Command;
    }
    
    port def RFTransmitPort {
        out rfSignal : RFSignal;
    }
    
    port def RFReceivePort {
        in rfSignal : RFSignal;
    }
    
    port def PowerLinePort {
        out powerLineSignal : PowerLineSignal;
        in powerLineSignal : PowerLineSignal;
    }
    
    part def HostComputer {
        port serialOut : SerialPort;
        
        action def GenerateX10Command {
            in targetHouse : HouseCode;
            in targetUnit : UnitCode;
            in desiredFunction : X10FunctionCode;
            out command : X10Command;
        }
    }
    
    part def FirecrackerModule {
        doc /*
            The X10 Firecracker is a computer-controlled RF transmitter module
            that receives X10 commands via serial interface and transmits them
            as radio frequency signals to X10 RF receivers.
        */
        
        attribute operatingFrequency : RFCarrierFrequency = 310.0[SI::MHz];
        attribute transmitPower : PowerValue = 0.01[SI::W];
        
        port serialIn : SerialPort;
        port rfOut : RFTransmitPort;
        
        action def ConvertSerialToRF {
            in serialCommand : X10Command;
            in carrierFreq : RFCarrierFrequency;
            out rfOutput : RFSignal;
        }
    }
    
    part def RFReceiverModule {
        doc /*
            The X10 RF Receiver receives radio frequency X10 commands and
            retransmits them as X10 protocol signals on the AC power line
            to control X10 devices throughout the home.
        */
        
        attribute receiverFrequency : RFCarrierFrequency = 310.0[SI::MHz];
        attribute powerLineFreq : PowerLineFrequency = 60.0[SI::Hz];
        
        port rfIn : RFReceivePort;
        port powerLineOut : PowerLinePort;
        
        action def DemodulateRFSignal {
            in receivedRF : RFSignal;
            out demodulatedCommand : X10Command;
        }
        
        action def EncodeForPowerLine {
            in command : X10Command;
            in lineFreq : PowerLineFrequency;
            out powerLineOutput : PowerLineSignal;
        }
    }
    
    part def X10DeviceModule {
        attribute deviceAddress : X10Address;
        attribute powerState : Boolean = false;
        attribute brightnessLevel : Real = 100.0;
        
        port powerLineIn : PowerLinePort;
        
        action def ProcessX10Command {
            in receivedSignal : PowerLineSignal;
            in assignedAddress : X10Address;
            inout deviceState : Boolean;
            inout brightness : Real;
        }
    }
    
    state def FirecrackerOperationStates {
        entry; then Idle;
        
        state Idle;
        state ReceivingCommand;
        state EncodingRF;
        state Transmitting;
        
        transition IdleToReceiving
            first Idle
            accept serialCommandArrived
            then ReceivingCommand;
        
        transition ReceivingToEncoding
            first ReceivingCommand
            accept commandValidated
            then EncodingRF;
        
        transition EncodingToTransmitting
            first EncodingRF
            accept rfSignalReady
            then Transmitting;
        
        transition TransmittingToIdle
            first Transmitting
            accept transmissionComplete
            then Idle;
    }
    
    state def ReceiverOperationStates {
        entry; then Monitoring;
        
        state Monitoring;
        state Decoding;
        state Injecting;
        
        transition MonitoringToDecoding
            first Monitoring
            accept rfSignalDetected
            then Decoding;
        
        transition DecodingToInjecting
            first Decoding
            accept commandDecoded
            then Injecting;
        
        transition InjectingToMonitoring
            first Injecting
            accept injectionComplete
            then Monitoring;
    }
    
    action def TransmitX10CommandViaRF {
        doc /*
            Primary system function: Accept X10 control commands from a host computer
            via serial interface, convert them to radio frequency signals, transmit
            wirelessly to an RF receiver, which then injects the commands onto the
            household AC power line to control X10-compatible devices.
        */
        
        in targetAddress : X10Address;
        in controlFunction : X10FunctionCode;
        out deviceResponse : Boolean;
        
        first start;
        
        then action generateCommand : HostComputer::GenerateX10Command {
            in targetHouse = targetAddress.houseCode;
            in targetUnit = targetAddress.unitCode;
            in desiredFunction = controlFunction;
            out command : X10Command;
        }
        
        then action convertToRF : FirecrackerModule::ConvertSerialToRF {
            in serialCommand = generateCommand.command;
            in carrierFreq : RFCarrierFrequency;
            out rfOutput : RFSignal;
        }
        
        then action demodulate : RFReceiverModule::DemodulateRFSignal {
            in receivedRF = convertToRF.rfOutput;
            out demodulatedCommand : X10Command;
        }
        
        then action encodePowerLine : RFReceiverModule::EncodeForPowerLine {
            in command = demodulate.demodulatedCommand;
            in lineFreq : PowerLineFrequency;
            out powerLineOutput : PowerLineSignal;
        }
        
        then action processAtDevice : X10DeviceModule::ProcessX10Command {
            in receivedSignal = encodePowerLine.powerLineOutput;
            in assignedAddress : X10Address;
            inout deviceState : Boolean;
            inout brightness : Real;
        }
        
        then assign deviceResponse := processAtDevice.deviceState;
        then done;
    }
    
    part def X10FirecrackerControlSystem {
        doc /*
            Complete home automation control system using X10 Firecracker technology.
            Enables wireless control of household devices through RF transmission
            and power line communication.
        */
        
        part computer : HostComputer;
        
        part firecracker : FirecrackerModule {
            attribute operatingFrequency = 310.0[SI::MHz];
            attribute transmitPower = 0.01[SI::W];
            
            state firecrackerState : FirecrackerOperationStates;
        }
        
        part rfReceiver : RFReceiverModule {
            attribute receiverFrequency = 310.0[SI::MHz];
            attribute powerLineFreq = 60.0[SI::Hz];
            
            state receiverState : ReceiverOperationStates;
        }
        
        part lampModule1 : X10DeviceModule {
            attribute deviceAddress : X10Address {
                houseCode : HouseCode { value = "A"; }
                unitCode : UnitCode { value = 1; }
            }
        }
        
        part lampModule2 : X10DeviceModule {
            attribute deviceAddress : X10Address {
                houseCode : HouseCode { value = "A"; }
                unitCode : UnitCode { value = 2; }
            }
        }
        
        part applianceModule : X10DeviceModule {
            attribute deviceAddress : X10Address {
                houseCode : HouseCode { value = "A"; }
                unitCode : UnitCode { value = 3; }
            }
        }
        
        connect computer.serialOut to firecracker.serialIn;
        
        connection rfLink connect firecracker.rfOut to rfReceiver.rfIn {
            item flow rfTransmission : RFSignal from firecracker.rfOut to rfReceiver.rfIn;
        }
        
        connection powerLine1 connect rfReceiver.powerLineOut to lampModule1.powerLineIn {
            item flow plSignal1 : PowerLineSignal from rfReceiver.powerLineOut to lampModule1.powerLineIn;
        }
        
        connection powerLine2 connect rfReceiver.powerLineOut to lampModule2.powerLineIn {
            item flow plSignal2 : PowerLineSignal from rfReceiver.powerLineOut to lampModule2.powerLineIn;
        }
        
        connection powerLine3 connect rfReceiver.powerLineOut to applianceModule.powerLineIn {
            item flow plSignal3 : PowerLineSignal from rfReceiver.powerLineOut to applianceModule.powerLineIn;
        }
        
        perform action systemOperation : TransmitX10CommandViaRF;
    }
    
    requirement def SystemFunctionRequirement {
        doc /*
            The X10 Firecracker system shall enable remote control of household
            devices by converting serial X10 commands to RF signals and retransmitting
            them on the AC power line.
        */
    }
    
    requirement def RFFrequencyRequirement {
        doc /*
            The system shall operate at an RF carrier frequency of 310 MHz
            for wireless transmission between Firecracker and receiver modules.
        */
        
        attribute requiredFrequency : RFCarrierFrequency = 310.0[SI::MHz];
    }
    
    requirement def PowerLineCompatibilityRequirement {
        doc /*
            The system shall inject X10 protocol signals onto standard 60 Hz
            AC power lines for device control.
        */
        
        attribute standardFrequency : PowerLineFrequency = 60.0[SI::Hz];
    }
    
    requirement def AddressCapabilityRequirement {
        doc /*
            The system shall support 256 unique device addresses using
            16 house codes and 16 unit codes.
        */
        
        attribute maxHouseCodes : Integer = 16;
        attribute maxUnitCodes : Integer = 16;
    }
    
    requirement systemFunction : SystemFunctionRequirement;
    requirement rfFrequency : RFFrequencyRequirement;
    requirement powerLineCompatibility : PowerLineCompatibilityRequirement;
    requirement addressCapability : AddressCapabilityRequirement;
    
    part x10System : X10FirecrackerControlSystem {
        satisfy systemFunction;
        satisfy rfFrequency by firecracker;
        satisfy powerLineCompatibility by rfReceiver;
        satisfy addressCapability;
    }
}
