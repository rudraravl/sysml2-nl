package 'USB Data Transfer System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def USBStandard {
        attribute version : String;
        attribute maxDataRate : Real;
        attribute maxPowerOutput : PowerValue;
        attribute voltageLevel : Real;
    }
    
    attribute def DeviceAddress :> Integer;
    
    attribute def TransferMode {
        attribute modeName : String;
        attribute guaranteedBandwidth : Boolean;
    }
    
    item def DataPacket {
        attribute packetID : Integer;
        attribute payloadSize : Real;
        attribute timestamp : Real;
        attribute checksum : Integer;
    }
    
    item def ControlMessage {
        attribute messageType : String;
        attribute targetAddress : DeviceAddress;
    }
    
    port def USBHostPort {
        out item powerSupply : PowerValue;
        out item controlOut : ControlMessage;
        in item controlIn : ControlMessage;
        out item dataOut : DataPacket[*];
        in item dataIn : DataPacket[*];
        attribute vBusVoltage : Real;
    }
    
    port def USBDevicePort {
        in item powerInput : PowerValue;
        in item controlIn : ControlMessage;
        out item controlOut : ControlMessage;
        in item dataIn : DataPacket[*];
        out item dataOut : DataPacket[*];
        attribute powerConsumption : PowerValue;
    }
    
    part def USBHostController {
        attribute controllerID : String;
        attribute usbStandard : USBStandard;
        attribute maxDevices : Integer;
        port hostPort : USBHostPort[1..4];
        
        state machine {
            state Idle;
            state Enumerating;
            state Configured;
            state Transferring;
            state Suspended;
            
            transition first start then Idle;
            transition deviceConnectedTransition
                first Idle
                accept deviceConnected
                then Enumerating;
            transition enumerationCompleteTransition
                first Enumerating
                accept enumerationComplete
                then Configured;
            transition dataRequestTransition
                first Configured
                accept dataRequest
                then Transferring;
            transition transferCompleteTransition
                first Transferring
                accept transferComplete
                then Configured;
            transition suspendRequestTransition
                first Configured
                accept suspendRequest
                then Suspended;
            transition resumeRequestTransition
                first Suspended
                accept resumeRequest
                then Configured;
            transition deviceDisconnectedTransition
                first Configured
                accept deviceDisconnected
                then Idle;
        }
        
        perform action manageDevices {
            first start;
            then action detectConnection {
                out connectionDetected : Boolean;
            }
            then decide;
                if detectConnection.connectionDetected then enumerate;
                else monitorBus;
            action enumerate {
                action resetDevice;
                then action assignAddress {
                    out deviceAddr : DeviceAddress;
                }
                then action getDescriptor {
                    in addr : DeviceAddress = assignAddress.deviceAddr;
                    out descriptorData : String;
                }
                then action setConfiguration {
                    in config : String = getDescriptor.descriptorData;
                    out configured : Boolean;
                }
            }
            then transferData;
            action monitorBus {
                out busStatus : String;
            }
            then transferData;
            action transferData {
                loop {
                    action scheduleTransfer {
                        out transferType : String;
                    }
                    then action executeTransfer {
                        in txType : String = scheduleTransfer.transferType;
                        out transferSuccess : Boolean;
                    }
                    then decide;
                        if executeTransfer.transferSuccess then continueOp;
                        else handleError;
                    action continueOp;
                    then done;
                    action handleError {
                        action retryTransfer;
                    }
                    then done;
                }
            }
            then done;
        }
    }
    
    part def USBPeripheral {
        attribute deviceID : String;
        attribute deviceClass : String;
        attribute requiredPower : PowerValue;
        port devicePort : USBDevicePort;
        
        state machine {
            state Unpowered;
            state Powered;
            state Default;
            state Addressed;
            state Configured;
            state Operating;
            
            transition first start then Unpowered;
            transition powerAppliedTransition
                first Unpowered
                accept powerApplied
                then Powered;
            transition resetReceivedTransition
                first Powered
                accept resetReceived
                then Default;
            transition addressAssignedTransition
                first Default
                accept addressAssigned
                then Addressed;
            transition configurationSetTransition
                first Addressed
                accept configurationSet
                then Configured;
            transition operationStartTransition
                first Configured
                accept operationStart
                then Operating;
            transition operationStopTransition
                first Operating
                accept operationStop
                then Configured;
            transition powerRemovedTransition
                first Configured
                accept powerRemoved
                then Unpowered;
        }
        
        perform action operateDevice {
            first start;
            then action waitForEnumeration {
                out enumerated : Boolean;
            }
            then decide;
                if waitForEnumeration.enumerated then processRequests;
                else waitForEnumeration;
            action processRequests {
                loop {
                    action receiveRequest {
                        out requestType : String;
                        out requestData : DataPacket[*];
                    }
                    then action processData {
                        in data : DataPacket[*] = receiveRequest.requestData;
                        out responseData : DataPacket[*];
                    }
                    then action sendResponse {
                        in response : DataPacket[*] = processData.responseData;
                        out sent : Boolean;
                    }
                }
            }
            then done;
        }
    }
    
    part def USBCable {
        attribute cableLength : LengthValue;
        attribute cableType : String;
        port connectorA : USBHostPort;
        port connectorB : USBDevicePort;
    }
    
    action def TransferBulkData {
        in sourcePackets : DataPacket[*];
        in transferRate : Real;
        out deliveredPackets : DataPacket[*];
        out transferDuration : Real;
    }
    
    action def SupplyBusPower {
        in requestedPower : PowerValue;
        in maxAvailablePower : PowerValue;
        out deliveredPower : PowerValue;
        out powerSufficient : Boolean;
    }
    
    requirement def <'REQ-USB-001'> DataTransferCapability {
        doc /* The USB system shall support bidirectional data transfer between 
                host and peripheral devices at rates up to the maximum specified 
                by the USB standard version. */
        subject usbSystem;
        require constraint {
            usbSystem.achievedDataRate <= usbSystem.usbStandard.maxDataRate
        }
    }
    
    requirement def <'REQ-USB-002'> PowerDeliveryCapability {
        doc /* The USB system shall provide electrical power from host to peripheral 
                devices without exceeding the maximum power limit of the USB standard. */
        subject usbSystem;
        require constraint {
            usbSystem.totalPowerDelivered <= usbSystem.usbStandard.maxPowerOutput
        }
    }
    
    requirement def <'REQ-USB-003'> DeviceEnumerationTime {
        doc /* The USB system shall complete device enumeration and configuration 
                within 500 milliseconds of device connection. */
        subject usbSystem;
        require constraint {
            usbSystem.enumerationDuration <= 500.0
        }
    }
    
    requirement def <'REQ-USB-004'> MultiDeviceSupport {
        doc /* The USB system shall support simultaneous operation of multiple 
                peripheral devices connected to a single host controller. */
        subject usbSystem;
    }
    
    part usbSystem {
        doc /* 
            This system describes a Universal Serial Bus (USB) implementation that 
            enables standardized communication and power delivery between a host 
            computer and peripheral devices.
            
            The system's primary function is to provide a unified interface for 
            connecting, powering, and exchanging data with external devices such as 
            storage drives, input devices, printers, and other peripherals.
            
            The process begins when a peripheral device is physically connected to 
            the host controller via a USB cable. The host detects the connection 
            through electrical signaling and initiates device enumeration. During 
            enumeration, the host resets the device, assigns it a unique address, 
            reads its descriptors to identify its capabilities and requirements, 
            and configures it for operation.
            
            Once configured, the system enables bidirectional data transfer using 
            one of several transfer modes (bulk, interrupt, isochronous, or control) 
            depending on the device type and application requirements. Simultaneously, 
            the host supplies electrical power through the same cable, eliminating 
            the need for separate power adapters for many devices.
            
            The USB system operates under host-controlled arbitration, where the 
            host schedules all data transfers and manages bandwidth allocation among 
            multiple connected devices. This ensures orderly communication and 
            prevents data collisions on the shared bus.
        */
        
        attribute usbStandard : USBStandard {
            attribute version = "3.2";
            attribute maxDataRate = 20.0;
            attribute maxPowerOutput = 100.0 [W];
            attribute voltageLevel = 5.0;
        }
        
        attribute achievedDataRate : Real;
        attribute totalPowerDelivered : PowerValue;
        attribute enumerationDuration : Real;
        attribute activeDeviceCount : Integer;
        
        part hostController : USBHostController {
            attribute controllerID = "USB-HOST-001";
            attribute usbStandard = usbSystem.usbStandard;
            attribute maxDevices = 127;
        }
        
        part flashDrive : USBPeripheral {
            attribute deviceID = "USB-STORAGE-001";
            attribute deviceClass = "Mass Storage";
            attribute requiredPower = 4.5 [W];
        }
        
        part keyboard : USBPeripheral {
            attribute deviceID = "USB-HID-001";
            attribute deviceClass = "Human Interface Device";
            attribute requiredPower = 2.5 [W];
        }
        
        part cable1 : USBCable {
            attribute cableLength = 1.0 [m];
            attribute cableType = "USB-A to USB-C";
        }
        
        part cable2 : USBCable {
            attribute cableLength = 0.5 [m];
            attribute cableType = "USB-A to USB-A";
        }
        
        connect hostController.hostPort[1] to cable1.connectorA;
        connect cable1.connectorB to flashDrive.devicePort;
        connect hostController.hostPort[2] to cable2.connectorA;
        connect cable2.connectorB to keyboard.devicePort;
        
        perform action operateUSBSystem {
            first start;
            then action initializeHost {
                action powerUpHost {
                    out hostReady : Boolean;
                }
                then action initializePorts {
                    out portsReady : Boolean;
                }
            }
            then merge mainOperationLoop;
            action mainOperationLoop {
                action monitorConnections {
                    out newDeviceDetected : Boolean;
                    out deviceAddress : DeviceAddress;
                }
                then decide;
                    if monitorConnections.newDeviceDetected then handleNewDevice;
                    else processActiveDevices;
                action handleNewDevice {
                    action enumerateDevice {
                        in addr : DeviceAddress = monitorConnections.deviceAddress;
                        action resetBus;
                        then action assignUniqueAddress {
                            out assignedAddr : DeviceAddress;
                        }
                        then action readDeviceDescriptors {
                            in deviceAddr : DeviceAddress = assignUniqueAddress.assignedAddr;
                            out descriptors : String;
                        }
                        then action selectConfiguration {
                            in desc : String = readDeviceDescriptors.descriptors;
                            out configSelected : Boolean;
                        }
                    }
                    then action allocateResources {
                        action allocateBandwidth {
                            out bandwidthAllocated : Real;
                        }
                        then action allocatePower : SupplyBusPower {
                            in requestedPower = flashDrive.requiredPower;
                            in maxAvailablePower = usbSystem.usbStandard.maxPowerOutput;
                            out deliveredPower;
                            out powerSufficient;
                        }
                    }
                }
                then processActiveDevices;
                action processActiveDevices {
                    action scheduleBulkTransfers : TransferBulkData {
                        in sourcePackets : DataPacket[*];
                        in transferRate = usbSystem.achievedDataRate;
                        out deliveredPackets : DataPacket[*];
                        out transferDuration;
                    }
                    then action scheduleInterruptTransfers {
                        in interruptData : DataPacket[*];
                        out processedInterrupts : DataPacket[*];
                    }
                    then action handleControlTransfers {
                        in controlMessages : ControlMessage[*];
                        out controlResponses : ControlMessage[*];
                    }
                }
            }
            then mainOperationLoop;
        }
        
        satisfy <'REQ-USB-001'> by operateUSBSystem.mainOperationLoop.processActiveDevices.scheduleBulkTransfers;
        satisfy <'REQ-USB-002'> by operateUSBSystem.mainOperationLoop.handleNewDevice.allocateResources.allocatePower;
        satisfy <'REQ-USB-003'> by operateUSBSystem.mainOperationLoop.handleNewDevice.enumerateDevice;
        satisfy <'REQ-USB-004'> by operateUSBSystem.mainOperationLoop;
    }
}
