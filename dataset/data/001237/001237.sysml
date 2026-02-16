package SeismometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def SeismicMagnitude :> Real;
    attribute def SignalVoltage :> Real;
    attribute def DataRate :> Real;

    enum def SeismicEventClass {
        background;
        microseismic;
        local;
        regional;
        teleseismic;
    }

    enum def OperatingMode {
        standby;
        active;
        recording;
        transmitting;
        fault;
    }

    item def GroundMotion {
        attribute displacement : LengthValue;
        attribute velocity : SpeedValue;
        attribute acceleration : AccelerationValue;
        attribute frequency : FrequencyValue;
    }

    item def SeismicSignal {
        attribute voltage : SignalVoltage;
        attribute timestamp : TimeInstantValue;
        attribute amplitude : Real;
    }

    item def SeismicRecord {
        attribute eventTime : TimeInstantValue;
        attribute duration : DurationValue;
        attribute peakAmplitude : Real;
        attribute eventClass : SeismicEventClass;
        attribute magnitude : SeismicMagnitude;
    }

    port def GroundCouplingPort {
        in motion : GroundMotion;
    }

    port def AnalogSignalPort {
        out signal : SeismicSignal;
    }

    port def DigitalDataPort {
        out data : SeismicRecord;
    }

    port def PowerInputPort {
        in voltage : SignalVoltage;
        in current : Real;
    }

    port def NetworkPort {
        out transmittedData : SeismicRecord;
    }

    part def InertialMass {
        attribute mass : MassValue = 0.5 [kg];
        attribute suspensionStiffness : Real = 100.0;
        attribute dampingCoefficient : Real = 0.7;
    }

    action def ConvertMotionToSignal {
        in groundMotion : GroundMotion;
        out electricalSignal : SeismicSignal;
    }

    action def AmplifySignal {
        in rawSignal : SeismicSignal;
        in amplificationFactor : Real;
        out amplifiedSignal : SeismicSignal;
    }

    action def Digitize {
        in analogSignal : SeismicSignal;
        in sampleRate : FrequencyValue;
        out digitalRecord : SeismicRecord;
    }

    action def AnalyzeSeismicData {
        in rawData : SeismicRecord;
        out processedData : SeismicRecord;
        out classification : SeismicEventClass;
    }

    action def StoreRecord {
        in seismicData : SeismicRecord;
    }

    action def TransmitData {
        in eventData : SeismicRecord;
    }

    part def TransducerAssembly {
        attribute sensitivity : Real = 400.0;
        attribute naturalFrequency : FrequencyValue = 1.0 [Hz];
        attribute dynamicRange : Real = 120.0;
        
        part inertialElement : InertialMass;
        
        port groundInterface : GroundCouplingPort;
        port signalOutput : AnalogSignalPort;
        
        perform action convertMotion : ConvertMotionToSignal;
    }

    part def SignalAmplifier {
        attribute gain : Real = 1000.0;
        attribute bandwidth : FrequencyValue = 100.0 [Hz];
        attribute noiseLevel : SignalVoltage = 1.0e-6;
        
        port analogIn : AnalogSignalPort;
        port analogOut : AnalogSignalPort;
        
        perform action amplify : AmplifySignal;
    }

    part def AnalogToDigitalConverter {
        attribute resolution : Real = 24.0;
        attribute samplingRate : FrequencyValue = 200.0 [Hz];
        attribute conversionTime : DurationValue = 0.001 [s];
        
        port analogInput : AnalogSignalPort;
        port digitalOutput : DigitalDataPort;
        
        perform action digitize : Digitize;
    }

    part def SignalProcessor {
        attribute processingAlgorithm : String = "STA/LTA";
        attribute detectionThreshold : Real = 3.0;
        attribute eventBufferSize : Real = 10000.0;
        
        port dataInput : DigitalDataPort;
        port dataOutput : DigitalDataPort;
        
        action def DetectEvent {
            in continuousData : SeismicRecord;
            in threshold : Real;
            out eventDetected : Boolean;
        }
        
        perform action analyze : AnalyzeSeismicData;
    }

    part def DataStorage {
        attribute capacity : Real = 1.0e9;
        attribute usedSpace : Real = 0.0;
        attribute retentionPeriod : DurationValue = 2592000.0 [s];
        
        port dataIn : DigitalDataPort;
        
        assert constraint storageLimit {
            usedSpace <= capacity
        }
        
        perform action store : StoreRecord;
    }

    part def CommunicationInterface {
        attribute protocol : String = "TCP/IP";
        attribute transmissionRate : DataRate = 10000.0;
        attribute bufferCapacity : Real = 5000.0;
        
        port dataIn : DigitalDataPort;
        port networkOut : NetworkPort;
        
        perform action transmit : TransmitData;
    }

    part def PowerSupply {
        attribute inputVoltage : SignalVoltage = 12.0;
        attribute outputVoltage : SignalVoltage = 5.0;
        attribute efficiency : Real = 0.85;
        attribute maxCurrent : Real = 2.0;
        
        port powerIn : PowerInputPort;
        port powerOut : PowerInputPort;
    }

    action def ContinuousSeismicMonitoring {
        first start;
        then merge monitoringLoop;
        
        action sense : ConvertMotionToSignal {
            in groundMotion;
            out rawSignal : SeismicSignal;
        }
        
        then action amplify : AmplifySignal {
            in rawSignal = sense.rawSignal;
            in amplificationFactor;
            out boostedSignal : SeismicSignal;
        }
        
        then action convert : Digitize {
            in analogSignal = amplify.boostedSignal;
            in sampleRate;
            out digitalData : SeismicRecord;
        }
        
        then action analyze : AnalyzeSeismicData {
            in rawData = convert.digitalData;
            out analyzedData : SeismicRecord;
            out eventType : SeismicEventClass;
        }
        
        then action store : StoreRecord {
            in seismicData = analyze.analyzedData;
        }
        
        then decide eventSignificance;
            if analyze.eventType != SeismicEventClass::background then transmit;
            if analyze.eventType == SeismicEventClass::background then monitoringLoop;
        
        action transmit : TransmitData {
            in eventData = analyze.analyzedData;
        }
        
        then monitoringLoop;
        then done;
    }

    attribute def PowerOnSignal;
    attribute def EventDetectedSignal;
    attribute def RecordCompleteSignal;
    attribute def TransmissionCompleteSignal;
    attribute def SystemErrorSignal;
    attribute def ResetSignal;
    attribute def PowerOffSignal;

    state def SeismometerOperationalStates {
        entry; then standbyState;
        
        state standbyState;
        transition standby_to_active
            first standbyState
            accept at PowerOnSignal
            then activeState;
        
        state activeState {
            entry; then monitoring;
            
            state monitoring {
                do action continuousMonitor : ContinuousSeismicMonitoring;
            }
            
            transition monitoring_to_recording
                first monitoring
                accept at EventDetectedSignal
                then recording;
            
            state recording {
                do action captureEvent : StoreRecord;
            }
            
            transition recording_to_transmitting
                first recording
                accept at RecordCompleteSignal
                then transmitting;
            
            state transmitting {
                do action sendData : TransmitData;
            }
            
            transition transmitting_to_monitoring
                first transmitting
                accept at TransmissionCompleteSignal
                then monitoring;
        }
        
        transition active_to_fault
            first activeState
            accept at SystemErrorSignal
            then faultState;
        
        state faultState;
        
        transition fault_to_standby
            first faultState
            accept at ResetSignal
            then standbyState;
        
        transition active_to_standby
            first activeState
            accept at PowerOffSignal
            then standbyState;
    }

    part def Seismometer {
        attribute operatingTemperature : TemperatureValue = 298.15 [K];
        attribute totalMass : MassValue = 5.0 [kg];
        attribute powerConsumption : PowerValue = 10.0 [W];
        attribute measurementRange : AccelerationValue = 0.01 [m/s^2];
        
        port groundConnection : GroundCouplingPort;
        port powerInput : PowerInputPort;
        port dataOutput : NetworkPort;
        
        part transducer : TransducerAssembly {
            attribute :>> sensitivity = 400.0;
            attribute :>> naturalFrequency = 1.0 [Hz];
        }
        
        part amplifier : SignalAmplifier {
            attribute :>> gain = 1000.0;
            attribute :>> bandwidth = 100.0 [Hz];
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> resolution = 24.0;
            attribute :>> samplingRate = 200.0 [Hz];
        }
        
        part processor : SignalProcessor {
            attribute :>> detectionThreshold = 3.0;
        }
        
        part storage : DataStorage {
            attribute :>> capacity = 1.0e9;
        }
        
        part communication : CommunicationInterface {
            attribute :>> transmissionRate = 10000.0;
        }
        
        part power : PowerSupply {
            attribute :>> outputVoltage = 5.0;
            attribute :>> efficiency = 0.85;
        }
        
        connect groundConnection to transducer.groundInterface;
        connect transducer.signalOutput to amplifier.analogIn;
        connect amplifier.analogOut to adc.analogInput;
        connect adc.digitalOutput to processor.dataInput;
        connect processor.dataOutput to storage.dataIn;
        connect processor.dataOutput to communication.dataIn;
        connect communication.networkOut to dataOutput;
        connect powerInput to power.powerIn;
        
        perform action monitoring : ContinuousSeismicMonitoring;
        
        exhibit state behavior : SeismometerOperationalStates;
    }

    requirement <'REQ-SEIS-100'> primaryFunction {
        doc /* The seismometer system shall continuously detect, measure, 
             * record, and transmit ground motion data to enable seismic 
             * event detection and analysis for earthquake monitoring and 
             * early warning applications.
             */
        subject seismometer : Seismometer;
    }

    requirement <'REQ-SEIS-101'> sensitivityRequirement {
        doc /* The seismometer transducer shall have a sensitivity of at 
             * least 400 V/(m/s) to detect low-amplitude ground motion.
             */
        subject seismometer : Seismometer;
        
        require constraint {
            seismometer.transducer.sensitivity >= 400.0
        }
    }

    requirement <'REQ-SEIS-102'> samplingRequirement {
        doc /* The system shall digitize seismic signals at a minimum 
             * sampling rate of 100 Hz with 24-bit resolution to capture 
             * the full frequency content of seismic waves.
             */
        subject seismometer : Seismometer;
        
        require constraint {
            seismometer.adc.samplingRate >= 100.0 [Hz] and
            seismometer.adc.resolution >= 24.0
        }
    }

    requirement <'REQ-SEIS-103'> dataRetentionRequirement {
        doc /* The seismometer shall store at least 30 days of continuous 
             * seismic data for post-event analysis and verification.
             */
        subject seismometer : Seismometer;
        
        require constraint {
            seismometer.storage.retentionPeriod >= 2592000.0 [s]
        }
    }

    requirement <'REQ-SEIS-104'> powerEfficiencyRequirement {
        doc /* The power supply shall operate with a minimum efficiency 
             * of 80% to minimize heat generation and energy consumption.
             */
        subject seismometer : Seismometer;
        
        require constraint {
            seismometer.power.efficiency >= 0.80
        }
    }

    part seismometerSystem : Seismometer {
        attribute :>> operatingTemperature = 298.15 [K];
        attribute :>> totalMass = 5.0 [kg];
        attribute :>> powerConsumption = 10.0 [W];
    }

    satisfy primaryFunction by seismometerSystem;
    satisfy sensitivityRequirement by seismometerSystem.transducer;
    satisfy samplingRequirement by seismometerSystem.adc;
    satisfy dataRetentionRequirement by seismometerSystem.storage;
    satisfy powerEfficiencyRequirement by seismometerSystem.power;
}
