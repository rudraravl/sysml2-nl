package CaltechSpaceExplorationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    doc /* 
     * This model represents a California Institute of Technology (Caltech) 
     * Jet Propulsion Laboratory (JPL) Deep Space Network (DSN) Ground Station System.
     * The primary function is to provide reliable two-way radio communication 
     * with interplanetary spacecraft, enabling command uplink and science data downlink 
     * for NASA's deep space missions.
     */
    
    attribute def FrequencyValue :> Real;
    attribute def DataRateValue :> Real;
    attribute def SignalPowerValue :> PowerValue;
    attribute def AzimuthValue :> Real;
    attribute def ElevationValue :> Real;
    
    item def CommandSequence {
        attribute sequenceId : String;
        attribute timestamp : Time::DateTime;
        attribute priority : Integer;
        attribute targetSpacecraft : String;
    }
    
    item def ScienceDataPacket {
        attribute packetId : String;
        attribute timestamp : Time::DateTime;
        attribute dataSize : Real;
        attribute sourceInstrument : String;
        attribute qualityIndicator : Real;
    }
    
    item def TrackingData {
        attribute timestamp : Time::DateTime;
        attribute range : LengthValue;
        attribute rangeRate : Real;
        attribute dopplerShift : FrequencyValue;
    }
    
    port def RFTransmitPort {
        out attribute transmitPower : SignalPowerValue;
        out attribute transmitFrequency : FrequencyValue;
        out item commandData : CommandSequence;
    }
    
    port def RFReceivePort {
        in attribute receivePower : SignalPowerValue;
        in attribute receiveFrequency : FrequencyValue;
        in item scienceData : ScienceDataPacket;
        in item trackingData : TrackingData;
    }
    
    port def ControlPort {
        in attribute pointingAzimuth : AzimuthValue;
        in attribute pointingElevation : ElevationValue;
        out attribute currentAzimuth : AzimuthValue;
        out attribute currentElevation : ElevationValue;
    }
    
    port def DataNetworkPort {
        in item uplinkCommands : CommandSequence;
        out item downlinkScience : ScienceDataPacket;
        out item navigationData : TrackingData;
    }
    
    part def AntennaSubsystem {
        attribute dishDiameter : LengthValue;
        attribute currentAzimuth : AzimuthValue;
        attribute currentElevation : ElevationValue;
        attribute pointingAccuracy : Real;
        
        port rfTransmit : RFTransmitPort;
        port rfReceive : RFReceivePort;
        port control : ControlPort;
        
        perform action trackSpacecraft : TrackingBehavior;
    }
    
    part def TransmitterSubsystem {
        attribute outputPower : SignalPowerValue;
        attribute operatingFrequency : FrequencyValue;
        attribute efficiency : Real;
        
        port commandInput : DataNetworkPort;
        port rfOutput : RFTransmitPort;
        
        perform action transmitCommands : TransmitBehavior;
    }
    
    part def ReceiverSubsystem {
        attribute sensitivity : SignalPowerValue;
        attribute noiseTemperature : TemperatureValue;
        attribute operatingFrequency : FrequencyValue;
        
        port rfInput : RFReceivePort;
        port dataOutput : DataNetworkPort;
        
        perform action receiveData : ReceiveBehavior;
    }
    
    part def SignalProcessingUnit {
        attribute processingCapacity : DataRateValue;
        attribute bufferSize : Real;
        
        port dataInput : DataNetworkPort;
        port dataOutput : DataNetworkPort;
        
        perform action processSignals : SignalProcessing;
    }
    
    part def MissionControlInterface {
        attribute operatorStations : Integer;
        attribute networkBandwidth : DataRateValue;
        
        port networkConnection : DataNetworkPort;
        
        perform action coordinateMission : MissionCoordination;
    }
    
    action def TrackingBehavior {
        in targetAzimuth : AzimuthValue;
        in targetElevation : ElevationValue;
        out actualAzimuth : AzimuthValue;
        out actualElevation : ElevationValue;
        
        first start;
        then merge trackingLoop;
        then action measurePosition {
            out azimuthError : Real;
            out elevationError : Real;
        }
        then decide;
            if measurePosition.azimuthError > 0.01 or measurePosition.elevationError > 0.01 then adjustPointing;
            if measurePosition.azimuthError <= 0.01 and measurePosition.elevationError <= 0.01 then maintainLock;
        
        action adjustPointing {
            in azError = measurePosition.azimuthError;
            in elError = measurePosition.elevationError;
            out newAzimuth = actualAzimuth;
            out newElevation = actualElevation;
        }
        then trackingLoop;
        
        action maintainLock {
            out azimuth = actualAzimuth;
            out elevation = actualElevation;
        }
        then trackingLoop;
    }
    
    action def TransmitBehavior {
        in commandSequence : CommandSequence;
        out transmittedPower : SignalPowerValue;
        
        first start;
        then action validateCommand {
            in cmd = commandSequence;
            out isValid : Boolean;
        }
        then decide;
            if validateCommand.isValid then modulateSignal;
            if !validateCommand.isValid then rejectCommand;
        
        action modulateSignal {
            in cmd = commandSequence;
            out modulatedSignal : Real;
        }
        then action amplifySignal {
            in signal = modulateSignal.modulatedSignal;
            out power = transmittedPower;
        }
        then done;
        
        action rejectCommand;
        then done;
    }
    
    action def ReceiveBehavior {
        in receivedSignal : SignalPowerValue;
        out decodedData : ScienceDataPacket;
        
        first start;
        then merge receiveLoop;
        then action detectSignal {
            in signal = receivedSignal;
            out signalDetected : Boolean;
        }
        then decide;
            if detectSignal.signalDetected then demodulateSignal;
            if !detectSignal.signalDetected then waitForSignal;
        
        action demodulateSignal {
            in signal = receivedSignal;
            out rawData : Real;
        }
        then action decodeData {
            in data = demodulateSignal.rawData;
            out packet = decodedData;
        }
        then done;
        
        action waitForSignal;
        then receiveLoop;
    }
    
    action def SignalProcessing {
        in rawDataPacket : ScienceDataPacket;
        out processedPacket : ScienceDataPacket;
        
        first start;
        then action errorCheck {
            in packet = rawDataPacket;
            out hasErrors : Boolean;
        }
        then decide;
            if errorCheck.hasErrors then correctErrors;
            if !errorCheck.hasErrors then formatData;
        
        action correctErrors {
            in packet = rawDataPacket;
            out correctedPacket : ScienceDataPacket;
        }
        then formatData;
        
        action formatData {
            in packet = rawDataPacket;
            out formatted = processedPacket;
        }
        then done;
    }
    
    action def MissionCoordination {
        first start;
        then action initializeSession;
        then merge operationLoop;
        then action monitorCommunication {
            out linkQuality : Real;
            out dataRate : DataRateValue;
        }
        then decide;
            if monitorCommunication.linkQuality >= 0.8 then continueOperation;
            if monitorCommunication.linkQuality < 0.8 then optimizeLink;
        
        action continueOperation;
        then operationLoop;
        
        action optimizeLink {
            in quality = monitorCommunication.linkQuality;
        }
        then operationLoop;
    }
    
    requirement def PrimaryMissionRequirement {
        doc /* The DSN ground station shall provide continuous two-way 
             * radio communication with deep space missions to enable 
             * command uplink and science data downlink.
             */
        subject station : DeepSpaceNetworkStation;
    }
    
    requirement def AntennaPerformanceRequirement {
        doc /* The antenna subsystem shall track spacecraft with pointing 
             * accuracy better than 0.01 degrees to maintain communication link.
             */
        subject antenna : AntennaSubsystem;
        require constraint {
            antenna.pointingAccuracy <= 0.01
        }
    }
    
    requirement def TransmitterPowerRequirement {
        doc /* The transmitter shall provide at least 20 kW of RF power 
             * for commanding distant spacecraft.
             */
        subject transmitter : TransmitterSubsystem;
        require constraint {
            transmitter.outputPower >= 20000.0 [W]
        }
    }
    
    requirement def ReceiverSensitivityRequirement {
        doc /* The receiver shall detect signals as weak as -160 dBm 
             * to receive data from deep space missions.
             */
        subject receiver : ReceiverSubsystem;
        require constraint {
            receiver.sensitivity <= -160.0
        }
    }
    
    requirement def DataRateRequirement {
        doc /* The system shall support data rates up to 1 Mbps 
             * for high-volume science data downlink.
             */
        subject processor : SignalProcessingUnit;
        require constraint {
            processor.processingCapacity >= 1.0e6
        }
    }
    
    part def DeepSpaceNetworkStation {
        doc /* A Caltech/JPL Deep Space Network ground station providing 
             * critical communication infrastructure for NASA's interplanetary 
             * missions, enabling command, control, and science data return 
             * from spacecraft exploring the solar system and beyond.
             */
        
        attribute stationId : String;
        attribute location : String;
        attribute operationalStatus : String;
        attribute missionCount : Integer;
        
        part antenna : AntennaSubsystem {
            attribute :>> dishDiameter = 70.0 [m];
            attribute :>> pointingAccuracy = 0.005;
        }
        
        part transmitter : TransmitterSubsystem {
            attribute :>> outputPower = 20000.0 [W];
            attribute :>> operatingFrequency = 7.2e9;
            attribute :>> efficiency = 0.65;
        }
        
        part receiver : ReceiverSubsystem {
            attribute :>> sensitivity = -165.0;
            attribute :>> noiseTemperature = 20.0 [K];
            attribute :>> operatingFrequency = 8.4e9;
        }
        
        part signalProcessor : SignalProcessingUnit {
            attribute :>> processingCapacity = 2.0e6;
            attribute :>> bufferSize = 1.0e9;
        }
        
        part missionControl : MissionControlInterface {
            attribute :>> operatorStations = 4;
            attribute :>> networkBandwidth = 1.0e9;
        }
        
        connection txPath connect transmitter.rfOutput to antenna.rfTransmit;
        connection rxPath connect antenna.rfReceive to receiver.rfInput;
        connection uplinkData connect missionControl.networkConnection to transmitter.commandInput;
        connection downlinkData connect receiver.dataOutput to signalProcessor.dataInput;
        connection processedData connect signalProcessor.dataOutput to missionControl.networkConnection;
    }
    
    part station : DeepSpaceNetworkStation {
        attribute :>> stationId = "DSS-14";
        attribute :>> location = "Goldstone, California";
        attribute :>> operationalStatus = "Active";
        attribute :>> missionCount = 0;
        
        assert constraint antennaPerformance : AntennaPerformanceRequirement {
            subject antenna = station.antenna;
        }
        
        assert constraint transmitterPower : TransmitterPowerRequirement {
            subject transmitter = station.transmitter;
        }
        
        assert constraint receiverSensitivity : ReceiverSensitivityRequirement {
            subject receiver = station.receiver;
        }
        
        assert constraint dataRate : DataRateRequirement {
            subject processor = station.signalProcessor;
        }
    }
    
    satisfy PrimaryMissionRequirement by station;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import CaltechSpaceExplorationSystem::*;

    action orchestrator {
        attribute testTargetAzimuth : AzimuthValue = 0.0;
        attribute testTargetElevation : ElevationValue = 0.0;
        action actionProbe : TrackingBehavior {
            in targetAzimuth = testTargetAzimuth;
            in targetElevation = testTargetElevation;
            // TODO(human): unsupported input type for azError: unknown (missing declared type)
            // TODO(human): unsupported input type for elError: unknown (missing declared type)
        }
        first actionProbe;
    }
}
