package 'BELTRI System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SignalStrength {
        attribute value : Real;
        attribute unit : String = "dBm";
    }
    
    attribute def Frequency {
        attribute value : FrequencyValue;
    }
    
    attribute def Bandwidth {
        attribute value : FrequencyValue;
    }
    
    attribute def DataRate {
        attribute value : Real;
        attribute unit : String = "Mbps";
    }
    
    attribute def Position {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }
    
    attribute def TargetData {
        attribute position : Position;
        attribute velocity : SpeedValue;
        attribute signalStrength : SignalStrength;
        attribute classification : String;
        attribute timestamp : Real;
    }
    
    port def RFPort {
        out signalData : SignalStrength;
        out frequencyData : Frequency;
    }
    
    port def DataPort {
        in commandData : String;
        out statusData : String;
        out telemetryData : TargetData;
    }
    
    port def PowerPort {
        in powerSupply : PowerValue;
        out powerDemand : PowerValue;
    }
    
    part def AntennaArray {
        port rfOutput : RFPort;
        attribute operatingFrequency : Frequency;
        attribute gain : Real;
        attribute beamwidth : Real;
    }
    
    part def ReceiverModule {
        port rfInput : ~RFPort;
        attribute sensitivity : SignalStrength;
        attribute bandwidth : Bandwidth;
        out receivedSignal : SignalStrength;
    }
    
    part def SignalProcessor {
        in rawSignal : SignalStrength;
        out processedData : TargetData;
        attribute processingGain : Real;
        attribute detectionThreshold : Real;
    }
    
    part def TransmitterModule {
        in dataToTransmit : TargetData;
        port dataOutput : DataPort;
        attribute transmitPower : PowerValue;
        attribute dataRate : DataRate;
    }
    
    part def PowerSupplyUnit {
        port powerOutput : PowerPort;
        attribute capacity : EnergyValue;
        attribute voltage : ElectricPotentialValue;
        attribute currentLoad : ElectricCurrentValue;
    }
    
    part def ControlProcessor {
        in targetData : TargetData;
        out controlCommands : String;
        attribute processingCapacity : Real;
        attribute memorySize : Real;
    }
    
    action def DetectSignal {
        in frequency : Frequency;
        in sensitivity : SignalStrength;
        out detectedSignal : SignalStrength;
        out detectionFlag : Boolean;
        
        first start;
        then action checkSignal;
        then done;
    }
    
    action def ProcessSignal {
        in rawSignal : SignalStrength;
        in processingGain : Real;
        in detectionThreshold : Real;
        out targetData : TargetData;
        
        first start;
        then action amplifySignal;
        then action extractPosition;
        then action classifyTarget {
            decide;
                if true then assignHighPriority;
            action assignHighPriority;
        }
        then done;
    }
    
    action def TransmitData {
        in targetData : TargetData;
        in transmitPower : PowerValue;
        out transmissionStatus : String;
        
        first start;
        then action encodeData;
        then action transmit;
        then done;
    }
    
    action def MonitorPower {
        in powerDemand : PowerValue;
        in powerCapacity : EnergyValue;
        out powerStatus : String;
        
        first start;
        then decide;
            if true then normalOperation;
        action normalOperation;
        then done;
    }
    
    state def BELTRIOperationalStates {
        entry; then idle;
        
        state idle;
        
        transition idle_to_scanning
            first idle
            accept command : String
            if command == "StartScanning"
            then scanning;
        
        state scanning;
        
        transition scanning_to_tracking
            first scanning
            then tracking;
        
        transition scanning_to_idle
            first scanning
            accept command : String
            if command == "Stop"
            then idle;
        
        state tracking;
        
        transition tracking_to_scanning
            first tracking
            then scanning;
        
        transition tracking_to_idle
            first tracking
            accept command : String
            if command == "Stop"
            then idle;
    }
    
    action def OperateBELTRI {
        in operatingFrequency : Frequency;
        in scanSensitivity : SignalStrength;
        out detectedTargets : TargetData[*];
        out systemStatus : String;
        
        private attribute currentState : String := "Idle";
        private attribute targetList : TargetData[*] := ();
        
        first start;
        then merge continuousOperation;
        
        then action initializeSystem;
        
        then action scanEnvironment : DetectSignal {
            in frequency = operatingFrequency;
            in sensitivity = scanSensitivity;
            out detectedSignal;
            out detectionFlag;
        }
        
        then decide;
            if scanEnvironment.detectionFlag == true then processDetection;
            if scanEnvironment.detectionFlag == false then continuousOperation;
        
        action processDetection {
            action extractTargetData : ProcessSignal {
                in rawSignal = scanEnvironment.detectedSignal;
                in processingGain = 20.0;
                in detectionThreshold = -95.0;
                out targetData;
            }
            
            then action transmitTargetInfo : TransmitData {
                in targetData = extractTargetData.targetData;
                in transmitPower = 10.0 [SI::W];
                out transmissionStatus;
            }
        }
        
        then continuousOperation;
        then done;
    }
    
    part def BELTRISystem {
        doc /*
            BELTRI (Bistatic Electronic Intelligence Tracking and Reconnaissance Instrument)
            is an advanced electronic surveillance system designed to detect, track, and 
            characterize electromagnetic emissions from targets of interest.
            
            Primary Function:
            The BELTRI system operates as a passive bistatic receiver that detects and 
            processes electromagnetic signals transmitted by external sources and reflected 
            or emitted by targets. The system continuously scans the electromagnetic spectrum,
            identifies signals of interest, processes them to extract target characteristics
            including position, velocity, and signal parameters, and transmits this intelligence
            data to remote operators or command centers for analysis and decision-making.
            
            The system employs multiple antenna elements for spatial coverage, sophisticated
            signal processing algorithms for target discrimination, and secure communication
            links for real-time data transmission. It operates autonomously through various
            operational states including idle standby, active scanning, and target tracking,
            while continuously monitoring its power consumption to ensure sustained operation.
        */
        
        attribute systemId : String;
        attribute operationalMode : String;
        
        part antennaArray : AntennaArray[4];
        part receiverUnit : ReceiverModule;
        part signalProcessingUnit : SignalProcessor;
        part transmitterUnit : TransmitterModule;
        part powerSupplyUnit : PowerSupplyUnit;
        part controlProcessorUnit : ControlProcessor;
    }
    
    part beltriSystem : BELTRISystem {
        attribute systemId = "BELTRI-001";
        
        part antennaArray : AntennaArray[4] {
            attribute :>> operatingFrequency {
                attribute :>> value = 3.0e9 [SI::Hz];
            }
            attribute :>> gain = 15.0;
            attribute :>> beamwidth = 30.0;
        }
        
        part receiverUnit : ReceiverModule {
            attribute :>> sensitivity {
                attribute :>> value = -110.0;
                attribute :>> unit = "dBm";
            }
            attribute :>> bandwidth {
                attribute :>> value = 100.0e6 [SI::Hz];
            }
        }
        
        part signalProcessingUnit : SignalProcessor {
            attribute :>> processingGain = 25.0;
            attribute :>> detectionThreshold = -95.0;
        }
        
        part transmitterUnit : TransmitterModule {
            attribute :>> transmitPower = 20.0 [SI::W];
            attribute :>> dataRate {
                attribute :>> value = 100.0;
                attribute :>> unit = "Mbps";
            }
        }
        
        part powerSupplyUnit : PowerSupplyUnit {
            attribute :>> capacity = 500.0 [SI::J];
            attribute :>> voltage = 28.0 [SI::V];
            attribute :>> currentLoad = 5.0 [SI::A];
        }
        
        part controlProcessorUnit : ControlProcessor {
            attribute :>> processingCapacity = 1000.0;
            attribute :>> memorySize = 16.0;
        }
        
        connect antennaArray[1].rfOutput to receiverUnit.rfInput;
        
        perform action beltriOperation : OperateBELTRI {
            in operatingFrequency {
                attribute :>> value = 3.0e9 [SI::Hz];
            }
            in scanSensitivity {
                attribute :>> value = -110.0;
            }
            out detectedTargets;
            out systemStatus;
        }
        
        exhibit state operationalBehavior : BELTRIOperationalStates;
    }
    
    requirement def DetectionRequirement {
        doc /* The system shall detect electromagnetic signals with minimum sensitivity of -110 dBm. */
        subject system : BELTRISystem;
    }
    
    requirement def TrackingRequirement {
        doc /* The system shall track detected targets and update position data at minimum 10 Hz rate. */
        subject system : BELTRISystem;
    }
    
    requirement def DataTransmissionRequirement {
        doc /* The system shall transmit processed target data at minimum 100 Mbps data rate. */
        subject system : BELTRISystem;
    }
    
    requirement def PowerEfficiencyRequirement {
        doc /* The system shall operate continuously for minimum 8 hours on internal power supply. */
        subject system : BELTRISystem;
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for BELTRI system operational capability. */
        
        require detectionReq : DetectionRequirement;
        require trackingReq : TrackingRequirement;
        require dataTransmissionReq : DataTransmissionRequirement;
        require powerEfficiencyReq : PowerEfficiencyRequirement;
    }
}
