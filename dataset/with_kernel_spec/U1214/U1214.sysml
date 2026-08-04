package SmartMeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def MeterID;
    attribute def TamperStatus;
    attribute def TransmissionStatus;
    attribute def TamperEvent;
    attribute def TamperCleared;
    attribute def CommFailure;
    attribute def CommRestored;
    attribute def Shutdown;
    
    item def UsageRecord {
        attribute timestamp : ISQ::TimeValue;
        attribute energyConsumed : ISQ::EnergyValue;
        attribute averagePower : ISQ::PowerValue;
        attribute peakPower : ISQ::PowerValue;
    }
    
    port def ElectricalServicePort {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
    }
    
    port def CommunicationPort {
        out usageData : UsageRecord;
        out tamperAlert : TamperStatus;
        in priceSignal : Real;
    }
    
    part def VoltageSensor {
        port serviceIn : ElectricalServicePort;
        attribute reading : ISQ::ElectricPotentialValue;
    }
    
    part def CurrentSensor {
        port serviceIn : ElectricalServicePort;
        attribute reading : ISQ::ElectricCurrentValue;
    }
    
    part def DataProcessor {
        attribute instantaneousPower : ISQ::PowerValue;
        attribute cumulativeEnergy : ISQ::EnergyValue;
        attribute peakPower : ISQ::PowerValue;
    }
    
    part def CommunicationModule {
        port network : CommunicationPort;
        attribute status : TransmissionStatus;
    }
    
    part def DataStorage {
        part records : UsageRecord[*];
        attribute capacity : Integer;
    }
    
    part def DisplayUnit {
        attribute displayPower : ISQ::PowerValue;
        attribute displayEnergy : ISQ::EnergyValue;
    }
    
    part def TamperDetector {
        attribute status : TamperStatus;
    }
    
    action def MeasureVoltage {
        out voltage : ISQ::ElectricPotentialValue;
    }
    
    action def MeasureCurrent {
        out current : ISQ::ElectricCurrentValue;
    }
    
    action def CalculatePower {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
        out power : ISQ::PowerValue;
    }
    
    action def AccumulateEnergy {
        in power : ISQ::PowerValue;
        in deltaTime : ISQ::TimeValue;
        in previousEnergy : ISQ::EnergyValue;
        out totalEnergy : ISQ::EnergyValue;
    }
    
    action def UpdatePeakPower {
        in currentPower : ISQ::PowerValue;
        in previousPeak : ISQ::PowerValue;
        out newPeak : ISQ::PowerValue;
    }
    
    action def CreateRecord {
        in energy : ISQ::EnergyValue;
        in power : ISQ::PowerValue;
        in peak : ISQ::PowerValue;
        out record : UsageRecord;
    }
    
    action def StoreRecord {
        in record : UsageRecord;
        out stored : Boolean;
    }
    
    action def TransmitData {
        in record : UsageRecord;
        out success : Boolean;
    }
    
    action def UpdateDisplay {
        in power : ISQ::PowerValue;
        in energy : ISQ::EnergyValue;
    }
    
    action def DetectTamper {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
        out detected : Boolean;
    }
    
    action def MonitorAndReport {
        in samplingInterval : ISQ::TimeValue;
        in reportingInterval : ISQ::TimeValue;
        
        private attribute cumulativeEnergy : ISQ::EnergyValue;
        private attribute peakPower : ISQ::PowerValue;
        private attribute sampleCount : Integer := 0;
        private attribute samplesPerReport : Integer;
        
        first start;
        then merge continueMonitoring;
        
        then action measureV : MeasureVoltage {
            out voltage : ISQ::ElectricPotentialValue;
        }
        
        then action measureC : MeasureCurrent {
            out current : ISQ::ElectricCurrentValue;
        }
        
        then action calculateP : CalculatePower {
            in voltage = measureV.voltage;
            in current = measureC.current;
            out power : ISQ::PowerValue;
        }
        
        then action accumulateE : AccumulateEnergy {
            in power = calculateP.power;
            in deltaTime = samplingInterval;
            in previousEnergy = cumulativeEnergy;
            out totalEnergy : ISQ::EnergyValue;
        }
        
        then assign cumulativeEnergy := accumulateE.totalEnergy;
        
        then action updatePeak : UpdatePeakPower {
            in currentPower = calculateP.power;
            in previousPeak = peakPower;
            out newPeak : ISQ::PowerValue;
        }
        
        then assign peakPower := updatePeak.newPeak;
        
        then action tamperCheck : DetectTamper {
            in voltage = measureV.voltage;
            in current = measureC.current;
            out detected : Boolean;
        }
        
        then action updateDisp : UpdateDisplay {
            in power = calculateP.power;
            in energy = cumulativeEnergy;
        }
        
        then assign sampleCount := sampleCount + 1;
        
        then decide;
            if sampleCount >= samplesPerReport then reportUsage;
            if sampleCount < samplesPerReport then continueMonitoring;
        
        action reportUsage {
            action createRec : CreateRecord {
                in energy = cumulativeEnergy;
                in power = calculateP.power;
                in peak = peakPower;
                out record : UsageRecord;
            }
            
            then action storeRec : StoreRecord {
                in record = createRec.record;
                out stored : Boolean;
            }
            
            then action transmit : TransmitData {
                in record = createRec.record;
                out success : Boolean;
            }
            
            then assign sampleCount := 0;
            then continueMonitoring;
        }
    }
    
    state def MeterOperatingStates {
        entry; then initializing;
        
        state initializing;
        then operational;
        
        state operational {
            entry;
            
            state normalOperation {
                do action MonitorAndReport;
            }
            
            state tamperDetected {
                entry action DetectTamper;
            }
            
            state communicationFailure;
            
            transition first normalOperation
                accept TamperEvent
                then tamperDetected;
            
            transition first tamperDetected
                accept TamperCleared
                then normalOperation;
            
            transition first normalOperation
                accept CommFailure
                then communicationFailure;
            
            transition first communicationFailure
                accept CommRestored
                then normalOperation;
        }
        
        transition accept Shutdown
            then shutdown;
        
        state shutdown;
    }
    
    part def SmartMeter {
        attribute meterID : MeterID;
        attribute samplingInterval : ISQ::TimeValue;
        attribute reportingInterval : ISQ::TimeValue;
        
        port servicePort : ElectricalServicePort;
        port commPort : CommunicationPort;
        
        part voltageSensor : VoltageSensor;
        part currentSensor : CurrentSensor;
        part dataProcessor : DataProcessor;
        part communicator : CommunicationModule;
        part dataStorage : DataStorage;
        part displayUnit : DisplayUnit;
        part tamperDetector : TamperDetector;
        
        perform action primaryOperation : MonitorAndReport {
            in samplingInterval = samplingInterval;
            in reportingInterval = reportingInterval;
        }
        
        exhibit state operatingState : MeterOperatingStates;
        
        connection sensorToService 
            connect voltageSensor.serviceIn to servicePort;
        
        connection commConnection 
            connect communicator.network to commPort;
    }
    
    part def UtilityGrid {
        port powerOutput : ElectricalServicePort;
    }
    
    part def CustomerPremises {
        port powerInput : ElectricalServicePort;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* Measurement accuracy requirements for smart meter components. */
        
        subject meter : SmartMeter;
        
        require constraint voltageAccuracy {
            doc /* Voltage measurements shall have accuracy within ±0.5 percent. */
        }
        
        require constraint currentAccuracy {
            doc /* Current measurements shall have accuracy within ±1.0 percent. */
        }
        
        require constraint energyAccuracy {
            doc /* Energy measurements shall have accuracy within ±2.0 percent. */
        }
    }
    
    requirement def CommunicationRequirement {
        doc /* Data transmission and reporting requirements. */
        
        subject meter : SmartMeter;
        
        require constraint reportingFrequency {
            doc /* Meter shall transmit usage data at intervals not exceeding one hour. */
        }
        
        require constraint transmissionReliability {
            doc /* Communication success rate shall exceed 99 percent. */
        }
        
        require constraint dataRetention {
            doc /* Meter shall store at least 90 days of usage records locally. */
        }
    }
    
    requirement def SecurityRequirement {
        doc /* Security and tamper detection requirements. */
        
        subject meter : SmartMeter;
        
        require constraint tamperDetection {
            doc /* System shall detect physical tampering within 5 seconds. */
        }
        
        require constraint dataEncryption {
            doc /* All transmitted data shall use encryption. */
        }
        
        require constraint accessControl {
            doc /* Remote access shall require authenticated authorization. */
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The primary function of the smart meter system is to continuously monitor 
            electrical energy consumption at the customer service point by measuring 
            voltage and current, calculating instantaneous power and cumulative energy, 
            and transmitting usage records to the utility company at regular intervals 
            for billing and grid management purposes.
        */
        
        subject meter : SmartMeter;
        
        requirement measurementAccuracyReq : MeasurementAccuracyRequirement;
        requirement communicationReq : CommunicationRequirement;
        requirement securityReq : SecurityRequirement;
    }
    
    part deployedMeter : SmartMeter {
        :>> meterID = "SM-2026-001";
    }
    
    part grid : UtilityGrid;
    part premises : CustomerPremises;
    
    connection gridToMeter 
        connect grid.powerOutput to deployedMeter.servicePort;
}
