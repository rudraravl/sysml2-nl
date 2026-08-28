package ElectrochemicalFatigueCrackSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;
        private import SI::*;
        
        attribute def Voltage :> ISQ::electricPotential;
        attribute def Resistance :> ISQ::electricResistance;
        attribute def Power :> ISQ::power;
        attribute def CrackDepth :> ISQ::length;
        attribute def CrackLength :> ISQ::length;
        attribute def CrackGrowthRate :> ISQ::speed;
        
        attribute def ActivateSignal;
        attribute def InitializationCompleteSignal;
        attribute def MeasurementCompleteSignal;
        attribute def ReportCompleteSignal;
        attribute def FaultSignal;
        attribute def ShutdownSignal;
        
        item def RawSignal {
            attribute resistance: Resistance;
        }
        item def ConditionedSignal {
            attribute voltage: Voltage;
        }
        item def DigitalData {
            attribute value: Real;
        }
        item def CrackMeasurement {
            attribute depth: CrackDepth;
            attribute length: CrackLength;
            attribute growthRate: CrackGrowthRate;
        }
        
        port def PowerPort {
            out item power: Power;
        }
        port def RawSignalPort {
            out item rawSignal: RawSignal;
        }
        port def ConditionedSignalPort {
            out item conditionedSignal: ConditionedSignal;
        }
        port def DigitalDataPort {
            out item digitalData: DigitalData;
        }
        port def CrackMeasurementPort {
            out item crackMeasurement: CrackMeasurement;
        }
        
        part def Electrode {
            attribute material: String = "Platinum";
        }
        part def Electrolyte;
        
        part def SensingUnit {
            port powerIn: PowerPort;
            port rawSignalOut: RawSignalPort;
            attribute baselineResistance: Resistance;
            attribute currentResistance: Resistance;
            part electrodes[10..50]: Electrode;
            part electrolyte: Electrolyte;
            perform action measureResistance;
        }
        part def SignalConditioner {
            port powerIn: PowerPort;
            port signalIn: RawSignalPort;
            port signalOut: ConditionedSignalPort;
            perform action amplifyAndFilter;
        }
        part def DataAcquisitionModule {
            port powerIn: PowerPort;
            port analogIn: ConditionedSignalPort;
            port digitalOut: DigitalDataPort;
            perform action convertAD;
        }
        part def CrackAnalysisProcessor {
            port powerIn: PowerPort;
            port digitalIn: DigitalDataPort;
            port measurementOut: CrackMeasurementPort;
            attribute calibrationFactor: Real;
            perform action analyzeCrack;
        }
        part def RegulatedPowerSupply {
            port powerOut: PowerPort;
        }
        
        action def CalibrateAndSelfTest;
        action def PerformMeasurement;
        action def ReportData;
        action def ExecuteShutdown;
        
        action calibrateAndSelfTest : CalibrateAndSelfTest;
        action performMeasurement : PerformMeasurement;
        action reportData : ReportData;
        action executeShutdown : ExecuteShutdown;
        
        state def OperationalStates {
            entry; then idle;
            state idle;
            accept ActivateSignal then initializing;
            state initializing {
                entry calibrateAndSelfTest;
            }
            accept InitializationCompleteSignal then measuring;
            accept FaultSignal then faulted;
            state measuring {
                do performMeasurement;
            }
            accept MeasurementCompleteSignal then reporting;
            accept FaultSignal then faulted;
            state reporting {
                do reportData;
            }
            accept ReportCompleteSignal then idle;
            accept FaultSignal then faulted;
            state faulted;
            accept ShutdownSignal then shutdown;
            state shutdown {
                entry executeShutdown;
            }
        }
        
        requirement def DetectCrackGrowthRequirement {
            /* The system shall detect the presence and growth of fatigue cracks by measuring resistance changes. */
        }
        requirement def MeasureCrackDimensionsRequirement {
            /* The system shall calculate the precise depth, length, and growth rate of the crack. */
        }
        
        part def ElectrochemicalFatigueCrackSensingSystem {
            part powerSupply: RegulatedPowerSupply;
            part sensingUnit: SensingUnit;
            part signalConditioner: SignalConditioner;
            part dataAcquisition: DataAcquisitionModule;
            part crackAnalysisProcessor: CrackAnalysisProcessor;
            
            connect powerSupply.powerOut to sensingUnit.powerIn;
            connect powerSupply.powerOut to signalConditioner.powerIn;
            connect powerSupply.powerOut to dataAcquisition.powerIn;
            connect powerSupply.powerOut to crackAnalysisProcessor.powerIn;
            
            connect sensingUnit.rawSignalOut to signalConditioner.signalIn;
            connect signalConditioner.signalOut to dataAcquisition.analogIn;
            connect dataAcquisition.digitalOut to crackAnalysisProcessor.digitalIn;
            
            exhibit state operationalStates: OperationalStates;
        }
    }
    
    private import Definitions::*;
    
    part electrochemicalFatigueSystem : ElectrochemicalFatigueCrackSensingSystem;
    
    satisfy requirement DetectCrackGrowthRequirement by electrochemicalFatigueSystem;
    satisfy requirement MeasureCrackDimensionsRequirement by electrochemicalFatigueSystem;
}
