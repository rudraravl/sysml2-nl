package BiophoneSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def HeartRateValue :> ISQ::FrequencyValue;
    attribute def BodyTemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def BloodPressureValue {
        attribute systolic : ISQ::PressureValue;
        attribute diastolic : ISQ::PressureValue;
    }
    attribute def OxygenSaturationValue :> Real;
    
    item def VitalSignsData {
        attribute heartRate : HeartRateValue;
        attribute bodyTemperature : BodyTemperatureValue;
        attribute bloodPressure : BloodPressureValue;
        attribute oxygenSaturation : OxygenSaturationValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def AudioData {
        attribute amplitude : Real;
        attribute frequency : ISQ::FrequencyValue;
        attribute duration : ISQ::TimeValue;
    }
    
    item def WirelessSignal {
        attribute signalStrength : ISQ::PowerValue;
        attribute frequency : ISQ::FrequencyValue;
        attribute payload : VitalSignsData;
    }
    
    attribute def DeviceStatus {
        attribute isActive : Boolean;
        attribute batteryLevel : Real;
        attribute connectionQuality : Real;
    }
    
    attribute def ActivationCommand;
    attribute def DataReady;
    attribute def TransmissionComplete;
    attribute def AbnormalVitals;
    attribute def ProviderResponse;
    attribute def CallEnded;
    attribute def LowBattery;
    attribute def BatteryCharged;
    
    port def VitalSensorPort {
        out vitalData : VitalSignsData;
    }
    
    port def AudioInterfacePort {
        in audioIn : AudioData;
        out audioOut : AudioData;
    }
    
    port def WirelessTransmissionPort {
        out transmit : WirelessSignal;
        in receive : WirelessSignal;
    }
    
    port def PowerSupplyPort {
        out voltage : ISQ::ElectricPotentialValue;
        out current : ISQ::ElectricCurrentValue;
    }
    
    part def BiomedicalSensorArray {
        port sensorOutput : VitalSensorPort;
        
        attribute samplingRate : ISQ::FrequencyValue;
        attribute accuracy : Real;
        
        action acquireVitals {
            out vitals : VitalSignsData;
        }
        
        perform action continuousSensing : acquireVitals[*];
    }
    
    part def SignalProcessingUnit {
        port dataInput : ~VitalSensorPort;
        port processedOutput : VitalSensorPort;
        
        attribute filterBandwidth : ISQ::FrequencyValue;
        attribute processingDelay : ISQ::TimeValue;
        
        action filterSignal {
            in rawData : VitalSignsData;
            out filteredData : VitalSignsData;
        }
        
        action analyzeVitals {
            in data : VitalSignsData;
            out analysis : VitalSignsData;
        }
    }
    
    part def WirelessCommunicationModule {
        port dataInterface : ~VitalSensorPort;
        port wirelessPort : WirelessTransmissionPort;
        port audioPort : AudioInterfacePort;
        
        attribute transmitPower : ISQ::PowerValue;
        attribute operatingFrequency : ISQ::FrequencyValue;
        attribute bandwidth : ISQ::FrequencyValue;
        
        action transmitData {
            in vitals : VitalSignsData;
            out signal : WirelessSignal;
        }
        
        action receiveData {
            in signal : WirelessSignal;
            out vitals : VitalSignsData;
        }
        
        action handleAudio {
            in audioIn : AudioData;
            out audioOut : AudioData;
        }
    }
    
    part def BatteryPowerSystem {
        port powerOutput : PowerSupplyPort;
        
        attribute capacity : ISQ::EnergyValue;
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute remainingCharge : Real;
        
        action supplyPower {
            out voltage : ISQ::ElectricPotentialValue;
            out current : ISQ::ElectricCurrentValue;
        }
        
        action monitorBattery {
            out batteryStatus : Real;
        }
    }
    
    part def UserControlInterface {
        port audioInterface : AudioInterfacePort;
        
        attribute displayMode : String;
        attribute alertThresholds : VitalSignsData;
        
        action displayStatus {
            in vitals : VitalSignsData;
            in deviceStatus : DeviceStatus;
        }
        
        action processUserInput {
            out command : String;
        }
        
        action generateAlert {
            in vitals : VitalSignsData;
            out alert : AudioData;
        }
    }
    
    part def Biophone {
        doc /*
            The Biophone is an integrated wearable biomedical communication device
            that continuously monitors patient vital signs including heart rate,
            body temperature, blood pressure, and oxygen saturation. It processes
            these biological signals in real-time, transmits the data wirelessly
            to remote healthcare providers, and provides bidirectional voice
            communication capabilities for patient-provider interaction.
        */
        
        part sensorArray : BiomedicalSensorArray {
            :>> samplingRate = 100.0 [SI::Hz];
            :>> accuracy = 0.98;
        }
        
        part processor : SignalProcessingUnit {
            :>> filterBandwidth = 50.0 [SI::Hz];
            :>> processingDelay = 0.01 [SI::s];
        }
        
        part commModule : WirelessCommunicationModule {
            :>> transmitPower = 0.1 [SI::W];
            :>> operatingFrequency = 2.45e9 [SI::Hz];
            :>> bandwidth = 20.0e6 [SI::Hz];
        }
        
        part battery : BatteryPowerSystem {
            :>> capacity = 36000.0 [SI::J];
            :>> voltage = 3.7 [SI::V];
            :>> remainingCharge = 85.0;
        }
        
        part userInterface : UserControlInterface {
            :>> displayMode = "Continuous";
        }
        
        connection sensorToProcessor connect 
            sensorArray.sensorOutput to processor.dataInput;
        
        connection processorToComm connect 
            processor.processedOutput to commModule.dataInterface;
        
        connection commToUI connect 
            commModule.audioPort to userInterface.audioInterface;
        
        perform action operateBiophone;
        
        exhibit state biophoneStateMachine;
    }
    
    action def AcquireBiologicalSignals {
        in samplingRate : ISQ::FrequencyValue;
        out rawVitals : VitalSignsData;
    }
    
    action def ProcessVitalSigns {
        in rawVitals : VitalSignsData;
        in filterSettings : ISQ::FrequencyValue;
        out processedVitals : VitalSignsData;
    }
    
    action def TransmitVitalData {
        in vitals : VitalSignsData;
        in transmitPower : ISQ::PowerValue;
        out transmissionSuccess : Boolean;
    }
    
    action def ManageDevicePower {
        in currentDraw : ISQ::ElectricCurrentValue;
        in batteryLevel : Real;
        out powerStatus : Boolean;
    }
    
    action def HandleCommunication {
        in audioInput : AudioData;
        out audioOutput : AudioData;
    }
    
    action def MonitorPatientStatus {
        in vitals : VitalSignsData;
        out alertRequired : Boolean;
    }
    
    action operateBiophone {
        doc /*
            Primary operational behavior coordinating continuous vital sign
            monitoring, signal processing, wireless transmission, and
            bidirectional communication in an integrated cycle.
        */
        
        first start;
        
        then merge operationalLoop;
        
        then action checkPower : ManageDevicePower {
            in currentDraw = 0.5 [SI::A];
            in batteryLevel = 85.0;
            out powerStatus : Boolean;
        }
        
        then decide;
            if checkPower.powerStatus then acquireData;
            if !checkPower.powerStatus then enterLowPower;
        
        action acquireData : AcquireBiologicalSignals {
            in samplingRate = 100.0 [SI::Hz];
            out rawVitals : VitalSignsData;
        }
        
        then action processData : ProcessVitalSigns {
            in rawVitals = acquireData.rawVitals;
            in filterSettings = 50.0 [SI::Hz];
            out processedVitals : VitalSignsData;
        }
        
        then action checkStatus : MonitorPatientStatus {
            in vitals = processData.processedVitals;
            out alertRequired : Boolean;
        }
        
        then action transmitData : TransmitVitalData {
            in vitals = processData.processedVitals;
            in transmitPower = 0.1 [SI::W];
            out transmissionSuccess : Boolean;
        }
        
        then action handleComm : HandleCommunication {
            in audioInput;
            out audioOutput;
        }
        
        then operationalLoop;
        
        action enterLowPower {
            doc /* Transition to low power mode to conserve battery */
        }
        
        then done;
    }
    
    state def BiophoneStates {
        entry; then idle;
        
        state idle {
            doc /* Device is powered but not actively monitoring */
        }
        
        state monitoring {
            doc /* Actively acquiring and processing vital signs */
        }
        
        state transmitting {
            doc /* Sending data wirelessly to remote station */
        }
        
        state communicating {
            doc /* Engaged in voice communication */
        }
        
        state alerting {
            doc /* Abnormal vitals detected, alerting user and provider */
        }
        
        state lowPower {
            doc /* Battery conservation mode */
        }
        
        transition idle_to_monitoring
            first idle
            accept activationCommand : ActivationCommand
            then monitoring;
        
        transition monitoring_to_transmitting
            first monitoring
            accept dataReady : DataReady
            then transmitting;
        
        transition transmitting_to_monitoring
            first transmitting
            accept transmissionComplete : TransmissionComplete
            then monitoring;
        
        transition monitoring_to_alerting
            first monitoring
            accept abnormalVitals : AbnormalVitals
            then alerting;
        
        transition alerting_to_communicating
            first alerting
            accept providerResponse : ProviderResponse
            then communicating;
        
        transition communicating_to_monitoring
            first communicating
            accept callEnded : CallEnded
            then monitoring;
        
        transition anyToLowPower
            first idle
            accept lowBattery : LowBattery
            then lowPower;
        
        transition lowPowerToIdle
            first lowPower
            accept batteryCharged : BatteryCharged
            then idle;
    }
    
    state biophoneStateMachine : BiophoneStates;
    
    requirement def SystemRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def ReliabilityRequirement;
    
    requirement <'BIO-REQ-001'> continuousMonitoring : PerformanceRequirement {
        doc /*
            The Biophone shall continuously monitor patient vital signs
            including heart rate, body temperature, blood pressure, and
            oxygen saturation at a minimum sampling rate of 100 Hz with
            98% accuracy.
        */
        
        subject biophone : Biophone;
        
        require constraint {
            biophone.sensorArray.samplingRate >= 100.0 [SI::Hz]
        }
        
        require constraint {
            biophone.sensorArray.accuracy >= 0.98
        }
    }
    
    requirement <'BIO-REQ-002'> realTimeProcessing : PerformanceRequirement {
        doc /*
            The Biophone shall process acquired vital sign data with
            a maximum latency of 10 milliseconds to enable real-time
            health monitoring and rapid response to critical conditions.
        */
        
        subject biophone : Biophone;
        
        require constraint {
            biophone.processor.processingDelay <= 0.01 [SI::s]
        }
    }
    
    requirement <'BIO-REQ-003'> wirelessTransmission : SystemRequirement {
        doc /*
            The Biophone shall transmit processed vital sign data
            wirelessly using a 2.4 GHz frequency band with sufficient
            power for reliable communication over a minimum range of
            100 meters in open space.
        */
        
        subject biophone : Biophone;
        
        require constraint {
            biophone.commModule.operatingFrequency >= 2.4e9 [SI::Hz] and
            biophone.commModule.operatingFrequency <= 2.5e9 [SI::Hz]
        }
        
        require constraint {
            biophone.commModule.transmitPower >= 0.05 [SI::W] and
            biophone.commModule.transmitPower <= 0.2 [SI::W]
        }
    }
    
    requirement <'BIO-REQ-004'> bidirectionalCommunication : SystemRequirement {
        doc /*
            The Biophone shall provide bidirectional voice communication
            capability between patient and healthcare provider with
            clear audio quality for effective consultation.
        */
        
        subject biophone : Biophone;
    }
    
    requirement <'BIO-REQ-005'> batteryLife : PerformanceRequirement {
        doc /*
            The Biophone shall operate continuously for a minimum of
            24 hours on a single battery charge under normal monitoring
            conditions to ensure uninterrupted patient care.
        */
        
        subject biophone : Biophone;
        
        require constraint {
            biophone.battery.capacity >= 36000.0 [SI::J]
        }
    }
    
    requirement <'BIO-REQ-006'> patientSafety : SafetyRequirement {
        doc /*
            The Biophone shall detect abnormal vital sign patterns and
            generate immediate alerts to both patient and healthcare
            provider to enable rapid medical intervention.
        */
        
        subject biophone : Biophone;
    }
    
    requirement <'BIO-REQ-007'> systemReliability : ReliabilityRequirement {
        doc /*
            The Biophone shall maintain 99.9% uptime during operation
            with automatic recovery from transient failures to ensure
            continuous patient monitoring.
        */
        
        subject biophone : Biophone;
    }
    
    requirement primaryFunction : SystemRequirement {
        doc /*
            The Biophone system shall integrate biomedical sensing,
            real-time signal processing, wireless data transmission,
            and bidirectional voice communication to provide continuous
            remote patient health monitoring and enable direct
            patient-provider interaction for comprehensive telehealth care.
        */
        
        require continuousMonitoring;
        require realTimeProcessing;
        require wirelessTransmission;
        require bidirectionalCommunication;
        require batteryLife;
        require patientSafety;
        require systemReliability;
    }
}
