package DigitalPillAdherenceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PillIdentifier :> String;
    attribute def PatientIdentifier :> String;
    attribute def MedicationName :> String;
    attribute def DosageAmount :> ISQ::MassValue;
    attribute def TimestampValue :> ISQ::TimeValue;
    attribute def BodyTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def PHLevel :> Real;
    attribute def BatteryCapacity :> ISQ::EnergyValue;
    attribute def SignalStrength :> ISQ::PowerValue;
    
    item def StomachFluid;
    item def BodyTissue;
    item def IngestionEvent;
    item def TelemetryPacket {
        attribute timestamp : TimestampValue;
        attribute temperature : BodyTemperature;
        attribute pH : PHLevel;
        attribute pillId : PillIdentifier;
        attribute patientId : PatientIdentifier;
    }
    
    port def SensorDataPort {
        out temperature : BodyTemperature;
        out acidity : PHLevel;
    }
    
    port def WirelessPort {
        out telemetry : TelemetryPacket;
    }
    
    port def PowerGenerationPort {
        in fluid : StomachFluid;
        in tissue : BodyTissue;
        out voltage : ISQ::ElectricPotentialValue;
    }
    
    part def IngestibleSensor {
        attribute sensorId : PillIdentifier;
        port sensorOut : SensorDataPort;
        
        action def MeasureGastricConditions {
            out bodyTemp : BodyTemperature;
            out pHValue : PHLevel;
        }
        
        perform action sensing : MeasureGastricConditions;
    }
    
    part def GalvanicCell {
        port powerOut : PowerGenerationPort;
        attribute capacity : BatteryCapacity;
        
        action def GenerateElectricity {
            in gastricFluid : StomachFluid;
            in bodyTissue : BodyTissue;
            out electricPotential : ISQ::ElectricPotentialValue;
        }
        
        state powerState {
            entry; then inactive;
            state inactive;
            state activating;
            state active;
            state depleted;
            
            transition inactiveToActivating
                first inactive
                accept ingestionTrigger : IngestionEvent
                then activating;
            
            transition activatingToActive
                first activating
                if capacity > 0.0[J]
                then active;
            
            transition activeToDepleted
                first active
                if capacity <= 0.0[J]
                then depleted;
        }
    }
    
    part def RadioTransmitter {
        port dataIn : SensorDataPort;
        port transmitOut : WirelessPort;
        attribute transmitPower : SignalStrength;
        
        action def EncodeAndTransmit {
            in sensorData : SensorDataPort;
            in powerLevel : ISQ::ElectricPotentialValue;
            out packet : TelemetryPacket;
        }
    }
    
    part def MedicationCapsule {
        attribute drugName : MedicationName;
        attribute dosage : DosageAmount;
        attribute releaseTime : ISQ::TimeValue;
        
        action def ReleaseMedication {
            in environmentalTrigger : PHLevel;
            out releasedDose : DosageAmount;
        }
    }
    
    part def WearablePatch {
        port receivePort : ~WirelessPort;
        attribute lastReceivedTime : TimestampValue;
        
        action def ReceiveTelemetry {
            in signal : TelemetryPacket;
            out confirmation : Boolean;
        }
        
        state receptionState {
            entry; then listening;
            state listening;
            state dataReceived;
            state forwarding;
            
            transition listenToReceived
                first listening
                accept incomingData : TelemetryPacket
                then dataReceived;
            
            transition receivedToForwarding
                first dataReceived
                then forwarding;
            
            transition forwardingToListening
                first forwarding
                then listening;
        }
    }
    
    part def MobileApplication {
        port patchInterface : ~WirelessPort;
        attribute storedRecords : TelemetryPacket[*];
        
        action def ProcessAdherenceData {
            in telemetryData : TelemetryPacket;
            out adherenceConfirmed : Boolean;
        }
    }
    
    part def CloudPlatform {
        attribute patientDatabase : TelemetryPacket[*];
        
        action def StoreAndAnalyze {
            in adherenceRecord : TelemetryPacket;
            out analysisResult : Boolean;
        }
    }
    
    part def DigitalPill {
        attribute pillIdentifier : PillIdentifier;
        attribute assignedPatient : PatientIdentifier;
        
        part sensor : IngestibleSensor {
            attribute sensorId = pillIdentifier;
        }
        
        part powerCell : GalvanicCell {
            attribute capacity = 100.0[J];
        }
        
        part transmitter : RadioTransmitter {
            attribute transmitPower = 10.0[W];
        }
        
        part medication : MedicationCapsule;
        
        connection powerSupply connect powerCell.powerOut to transmitter;
        connection sensorData connect sensor.sensorOut to transmitter.dataIn;
        
        perform action operationalCycle[*] ordered references monitorAndTransmit;
    }
    
    part adherenceSystem : DigitalPillAdherenceSystem {
        part pill : DigitalPill;
        part patch : WearablePatch;
        part mobileApp : MobileApplication;
        part cloudService : CloudPlatform;
        
        connection wirelessLink1 connect pill.transmitter.transmitOut to patch.receivePort;
        connection wirelessLink2 connect patch.receivePort to mobileApp.patchInterface;
    }
    
    action def MonitorAndTransmit {
        in pillId : PillIdentifier;
        in patientId : PatientIdentifier;
        out adherenceVerified : Boolean;
        out transmissionTime : TimestampValue;
        
        first start;
        then action awaitIngestion {
            doc /* Pill remains dormant until swallowed by patient */
        }
        then action activatePower : GalvanicCell::GenerateElectricity {
            in gastricFluid : StomachFluid;
            in bodyTissue : BodyTissue;
            out electricPotential : ISQ::ElectricPotentialValue;
        }
        then merge monitoringLoop;
        then action measureEnvironment : IngestibleSensor::MeasureGastricConditions {
            out bodyTemp : BodyTemperature;
            out pHValue : PHLevel;
        }
        then action releaseDrug : MedicationCapsule::ReleaseMedication {
            in environmentalTrigger = measureEnvironment.pHValue;
            out releasedDose : DosageAmount;
        }
        then action transmitData : RadioTransmitter::EncodeAndTransmit {
            in sensorData = measureEnvironment;
            in powerLevel = activatePower.electricPotential;
            out packet : TelemetryPacket;
        }
        then action receiveAtPatch : WearablePatch::ReceiveTelemetry {
            in signal = transmitData.packet;
            out confirmation : Boolean;
        }
        then action processInApp : MobileApplication::ProcessAdherenceData {
            in telemetryData = transmitData.packet;
            out adherenceConfirmed : Boolean;
        }
        then action storeInCloud : CloudPlatform::StoreAndAnalyze {
            in adherenceRecord = transmitData.packet;
            out analysisResult : Boolean;
        }
        then assign adherenceVerified := processInApp.adherenceConfirmed;
        then assign transmissionTime := transmitData.packet.timestamp;
        then decide;
            if activatePower.electricPotential > 0.5[V] then monitoringLoop;
            if activatePower.electricPotential <= 0.5[V] then terminateOperation;
        action terminateOperation {
            doc /* Power depleted or pill expelled from digestive system */
        }
        then done;
    }
    
    action monitorAndTransmit : MonitorAndTransmit {
        in pillId : PillIdentifier;
        in patientId : PatientIdentifier;
        out adherenceVerified : Boolean;
        out transmissionTime : TimestampValue;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'DP-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* The digital pill system shall detect medication ingestion and wirelessly transmit 
                confirmation to external monitoring devices for patient adherence tracking. */
        
        subject digitalPillSystem : DigitalPill;
        
        assume constraint patientIngestion {
            doc /* Patient swallows the digital pill containing prescribed medication. */
        }
        
        require constraint ingestionDetection {
            doc /* System shall detect ingestion within 60 seconds of stomach contact. */
        }
        
        require constraint wirelessTransmission {
            doc /* System shall transmit telemetry data within 5 minutes of activation. */
        }
    }
    
    requirement <'DP-REQ-002'> accuracyRequirement : PerformanceRequirement {
        doc /* The sensor subsystem shall measure physiological parameters with specified accuracy. */
        
        subject sensorSystem : IngestibleSensor;
        
        require constraint temperatureAccuracy {
            doc /* Temperature measurements shall be accurate to ±0.5°C. */
        }
        
        require constraint pHAccuracy {
            doc /* pH measurements shall be accurate to ±0.2 pH units. */
        }
    }
    
    requirement <'DP-REQ-003'> powerRequirement : PerformanceRequirement {
        doc /* The galvanic cell shall provide sufficient power for complete operational cycle. */
        
        subject powerSystem : GalvanicCell;
        
        require constraint operationalDuration {
            doc /* Power cell shall sustain operation for minimum 30 minutes after activation. */
        }
        
        require constraint voltageOutput {
            doc /* Power cell shall generate minimum 0.5V for transmitter operation. */
        }
    }
    
    requirement <'DP-REQ-004'> biocompatibility : SafetyRequirement {
        doc /* All pill components shall be biocompatible and safe for human ingestion. */
        
        subject entirePill : DigitalPill;
        
        require constraint materialSafety {
            doc /* All materials shall be FDA-approved for ingestion and digestive transit. */
        }
        
        require constraint safePassage {
            doc /* Pill dimensions shall allow safe passage through entire digestive tract. */
        }
        
        require constraint noRetention {
            doc /* Pill shall be naturally expelled within 72 hours of ingestion. */
        }
    }
    
    requirement <'DP-REQ-005'> dataIntegrity : PerformanceRequirement {
        doc /* Transmitted telemetry data shall maintain integrity and traceability. */
        
        require constraint uniqueIdentification {
            doc /* Each pill shall have unique identifier transmitted with all data packets. */
        }
        
        require constraint timestampAccuracy {
            doc /* All telemetry timestamps shall be accurate to ±1 second. */
        }
        
        require constraint transmissionReliability {
            doc /* System shall achieve 95% successful transmission rate to wearable patch. */
        }
    }
}
