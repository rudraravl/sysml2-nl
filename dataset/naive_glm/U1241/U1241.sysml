package USB_System {
    import ScalarValues::*;

    unit Gbps;
    unit W;
    unit V;
    unit A;
    unit m;
    unit byte;
    unit GB;
    unit ms;

    value type USBAddress :> Integer;
    value type DataRate :> Real { unit Gbps; }
    value type PowerOutput :> Real { unit W; }
    value type Voltage :> Real { unit V; }
    value type Current :> Real { unit A; }
    value type CableLength :> Real { unit m; }
    value type PacketSize :> Integer { unit byte; }
    value type StorageCapacity :> Integer { unit GB; }
    value type TimeInterval :> Integer { unit ms; }

    enum def TransferType { control; bulk; interrupt; isochronous; }
    enum def ConnectorType { TypeA; TypeB; TypeC; MicroUSB; }
    enum def DeviceClass { MassStorage; HumanInterfaceDevice; Hub; Audio; }
    enum def USBStandard { USB1_1; USB2_0; USB3_0; USB3_1; USB3_2; }

    item def ElectricPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def USBDataPacket {
        attribute transferType : TransferType;
        attribute payload : String;
        attribute size : PacketSize;
        attribute sourceAddress : USBAddress;
        attribute destinationAddress : USBAddress;
    }

    item def EnumerationDescriptor {
        attribute deviceClass : DeviceClass;
        attribute vendorId : String;
        attribute productId : String;
        attribute maxPower : PowerOutput;
        attribute supportedStandard : USBStandard;
    }

    occurrence def PeripheralConnected;
    occurrence def PowerApplied;
    occurrence def PowerRemoved;
    occurrence def EnumerationComplete;
    occurrence def TransferRequested;
    occurrence def BusIdle;
    occurrence def SuspendRequested;
    occurrence def ResumeRequested;

    port def USBPort {
        inout item dataPackets : USBDataPacket;
        in item power : ElectricPower;
        attribute maxDataRate : DataRate := 20 [Gbps];
        attribute maxPower : PowerOutput := 100 [W];
    }

    action def EnumerateDevice {
        in descriptor : EnumerationDescriptor;
        out assignedAddress : USBAddress;
        out configured : Boolean;
    }

    action def TransferData {
        in packet : USBDataPacket;
        out acknowledgment : Boolean;
    }

    part def USBHostController {
        attribute standard : USBStandard := USB3_2;
        attribute maxDataRate : DataRate := 20 [Gbps];
        attribute maxBusPower : PowerOutput := 100 [W];
        attribute maxPorts : Integer := 4;
        attribute assignedAddresses : USBAddress[0..*];

        port usbPort[1..4] : USBPort;

        action enumerate : EnumerateDevice;
        action transfer : TransferData;

        state machine HostBehavior {
            state Idle;
            state Enumerating {
                entry action beginEnumeration {
                    perform enumerate;
                }
            }
            state Transferring {
                do action manageTransfers {
                    perform transfer;
                }
            }
            state Suspended;

            transition from Idle to Enumerating accept PeripheralConnected;
            transition from Enumerating to Transferring accept EnumerationComplete;
            transition from Transferring to Idle accept BusIdle;
            transition from Idle to Suspended accept SuspendRequested;
            transition from Transferring to Suspended accept SuspendRequested;
            transition from Suspended to Idle accept ResumeRequested;
        }
    }

    part def USBPeripheral {
        attribute deviceClass : DeviceClass;
        attribute standard : USBStandard := USB3_2;
        attribute assignedAddress : USBAddress;
        attribute powerRequirement : PowerOutput;
        attribute preferredTransfer : TransferType;

        port devicePort : USBPort;

        state machine PeripheralBehavior {
            state Unpowered;
            state Configured;
            state Operating;
            state Suspended;

            transition from Unpowered to Configured accept PowerApplied;
            transition from Configured to Operating accept EnumerationComplete;
            transition from Operating to Suspended accept SuspendRequested;
            transition from Suspended to Operating accept ResumeRequested;
            transition from Operating to Unpowered accept PowerRemoved;
        }
    }

    part def FlashDrive :> USBPeripheral {
        attribute deviceClass : DeviceClass := MassStorage;
        attribute preferredTransfer : TransferType := bulk;
        attribute storageCapacity : StorageCapacity := 256 [GB];
        attribute powerRequirement : PowerOutput := 2.5 [W];
    }

    part def Keyboard :> USBPeripheral {
        attribute deviceClass : DeviceClass := HumanInterfaceDevice;
        attribute preferredTransfer : TransferType := interrupt;
        attribute pollInterval : TimeInterval := 10 [ms];
        attribute powerRequirement : PowerOutput := 0.5 [W];
    }

    part def USBCable {
        attribute length : CableLength := 1.0 [m];
        attribute connectorA : ConnectorType := TypeA;
        attribute connectorB : ConnectorType := TypeC;
        attribute maxDataRate : DataRate := 20 [Gbps];
        attribute maxPower : PowerOutput := 100 [W];

        port endA : USBPort;
        port endB : USBPort;

        connection cableLink connect endA to endB;
    }

    part def USBSystem {
        part host : USBHostController;
        part flashDrive : FlashDrive;
        part keyboard : Keyboard;
        part cable1 : USBCable {
            attribute length := 0.5 [m];
            attribute connectorB := TypeC;
        }
        part cable2 : USBCable {
            attribute length := 1.5 [m];
            attribute connectorB := TypeA;
        }

        connection hostCable1 connect host.usbPort[1] to cable1.endA;
        connection cable1Device connect cable1.endB to flashDrive.devicePort;
        connection hostCable2 connect host.usbPort[2] to cable2.endA;
        connection cable2Device connect cable2.endB to keyboard.devicePort;
    }

    requirement def USBStandardRequirement {
        subject usbSystem : USBSystem;
        attribute requiredStandard : USBStandard := USB3_2;
        attribute requiredMaxDataRate : DataRate := 20 [Gbps];
        attribute requiredMaxPower : PowerOutput := 100 [W];
        require usbSystem.host.standard == requiredStandard;
        require usbSystem.host.maxDataRate >= requiredMaxDataRate;
        require usbSystem.host.maxBusPower >= requiredMaxPower;
    }

    requirement def EnumerationRequirement {
        subject controller : USBHostController;
        require controller.maxPorts <= 4;
        require controller.standard == USB3_2;
    }

    requirement def PowerDeliveryRequirement {
        subject peripheral : USBPeripheral;
        require peripheral.powerRequirement <= 100 [W];
    }

    requirement def DataTransferRequirement {
        subject peripheral : USBPeripheral;
        require peripheral.preferredTransfer == bulk or peripheral.preferredTransfer == interrupt;
    }

    requirement def CableRequirement {
        subject cable : USBCable;
        require cable.length <= 3.0 [m];
        require cable.maxDataRate >= 20 [Gbps];
        require cable.maxPower >= 100 [W];
    }

    requirement StandardCompliance : USBStandardRequirement;
    requirement EnumerationProcess : EnumerationRequirement;
    requirement PowerDelivery : PowerDeliveryRequirement;
    requirement DataTransfer : DataTransferRequirement;
    requirement CableSpecification : CableRequirement;
}
