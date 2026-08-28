package USBSystemModel {
    attribute def DataRate {
        attribute value : ScalarValues::Real;
        attribute unit : ScalarValues::String = "Gbps";
    }
    
    attribute def Power {
        attribute value : ScalarValues::Real;
        attribute unit : ScalarValues::String = "W";
    }
    
    attribute def Length {
        attribute value : ScalarValues::Real;
        attribute unit : ScalarValues::String = "m";
    }
    
    item def DataPacket {
        attribute payloadSize : ScalarValues::Integer;
        attribute transferType : TransferType;
    }
    
    enum def TransferType {
        Bulk;
        Interrupt;
        Control;
        Isochronous;
    }
    
    enum def DeviceClass {
        MassStorage;
        HumanInterface;
        Audio;
        Video;
        Communications;
    }
    
    enum def ConnectorType {
        TypeA;
        TypeC;
        MicroB;
    }
    
    attribute def DeviceConnectedSignal;
    attribute def EnumerationCompleteSignal;
    attribute def InactivityTimeoutSignal;
    attribute def DeviceDisconnectedSignal;
    attribute def WakeSignal;
    attribute def PowerAppliedSignal;
    attribute def AddressAssignedSignal;
    attribute def PowerRemovedSignal;
    
    port def USBPort {
        in item dataIn : DataPacket;
        out item dataOut : DataPacket;
        in item powerIn : Power;
        out item powerOut : Power;
    }
    
    connection def USBCable {
        attribute length : Length;
        attribute connectorType : ConnectorType;
        end hostEnd : USBPort;
        end peripheralEnd : USBPort;
    }
    
    part def USBHostController {
        attribute maxPorts : ScalarValues::Integer = 4;
        attribute maxDataRate : DataRate;
        attribute maxPowerOutput : Power;
        port hostPort[1..4] : ~USBPort;
        
        state def HostStates {
            entry; then idle;
            state idle;
            transition idle_to_enumerating
                first idle
                accept DeviceConnectedSignal
                then enumerating;
            state enumerating;
            transition enumerating_to_transferring
                first enumerating
                accept EnumerationCompleteSignal
                then transferring;
            state transferring;
            transition transferring_to_suspended
                first transferring
                accept InactivityTimeoutSignal
                then suspended;
            transition transferring_to_idle
                first transferring
                accept DeviceDisconnectedSignal
                then idle;
            state suspended;
            transition suspended_to_idle
                first suspended
                accept WakeSignal
                then idle;
        }
        
        state hostStateMachine : HostStates;
    }
    
    part def USBPeripheral {
        attribute deviceClass : DeviceClass;
        attribute powerRequirement : Power;
        port peripheralPort : USBPort;
        
        state def PeripheralStates {
            entry; then unpowered;
            state unpowered;
            transition unpowered_to_configured
                first unpowered
                accept PowerAppliedSignal
                then configured;
            state configured;
            transition configured_to_operating
                first configured
                accept AddressAssignedSignal
                then operating;
            state operating;
            transition operating_to_unpowered
                first operating
                accept PowerRemovedSignal
                then unpowered;
        }
        
        state peripheralStateMachine : PeripheralStates;
    }
    
    part def FlashDrive :> USBPeripheral {
        attribute :>> deviceClass = DeviceClass::MassStorage;
        attribute :>> powerRequirement = Power { value = 2.5; unit = "W"; };
        attribute storageCapacity : ScalarValues::Integer;
    }
    
    part def Keyboard :> USBPeripheral {
        attribute :>> deviceClass = DeviceClass::HumanInterface;
        attribute :>> powerRequirement = Power { value = 0.5; unit = "W"; };
    }
    
    action def EnumerationProcess {
        in device : USBPeripheral;
        in host : USBHostController;
        action detectConnection;
        action assignAddress;
        action queryCapabilities;
        action configureDevice;
        succession detectConnection then assignAddress;
        succession assignAddress then queryCapabilities;
        succession queryCapabilities then configureDevice;
    }
    
    requirement def USB32Standard {
        doc /* USB 3.2 specification dictates performance and power characteristics. */
        attribute maxDataRate : DataRate;
        attribute maxPowerDelivery : Power;
        attribute protocolVersion : ScalarValues::String = "3.2";
    }
    
    part usbSystem {
        part hostController : USBHostController;
        part flashDrive : FlashDrive;
        part keyboard : Keyboard;
        
        connection cable1 : USBCable {
            attribute length = Length { value = 1.5; unit = "m"; };
            attribute connectorType = ConnectorType::TypeC;
            end hostEnd ::> hostController.hostPort[1];
            end peripheralEnd ::> flashDrive.peripheralPort;
        }
        connection cable2 : USBCable {
            attribute length = Length { value = 2.0; unit = "m"; };
            attribute connectorType = ConnectorType::TypeA;
            end hostEnd ::> hostController.hostPort[2];
            end peripheralEnd ::> keyboard.peripheralPort;
        }
        
        flow dataFlowHostToFlash : DataPacket from hostController.hostPort[1] to flashDrive.peripheralPort;
        flow dataFlowFlashToHost : DataPacket from flashDrive.peripheralPort to hostController.hostPort[1];
        flow powerFlowToFlash : Power from hostController.hostPort[1] to flashDrive.peripheralPort;
        flow dataFlowHostToKbd : DataPacket from hostController.hostPort[2] to keyboard.peripheralPort;
        flow dataFlowKbdToHost : DataPacket from keyboard.peripheralPort to hostController.hostPort[2];
        flow powerFlowToKbd : Power from hostController.hostPort[2] to keyboard.peripheralPort;
        
        satisfy USB32Standard by hostController;
        satisfy USB32Standard by flashDrive;
        satisfy USB32Standard by keyboard;
        
        perform enumeration : EnumerationProcess;
    }
}
