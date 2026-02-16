package 'MatC Family System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        attribute def OperatorCommand;
        attribute def SystemReady;
        attribute def EmergencyStop;
        attribute def ProcessComplete;
        
        item def RawMaterial {
            attribute batchId : String;
            attribute mass : MassValue;
            attribute temperature : ThermodynamicTemperatureValue;
            attribute composition : String;
        }
        
        item def ProcessedMaterial {
            attribute batchId : String;
            attribute mass : MassValue;
            attribute temperature : ThermodynamicTemperatureValue;
            attribute qualityGrade : Real;
            attribute composition : String;
        }
        
        item def EnergyFlow {
            attribute voltage : ElectricPotentialValue;
            attribute current : ElectricCurrentValue;
            attribute power : PowerValue;
        }
        
        item def ControlSignal {
            attribute setpoint : Real;
            attribute feedback : Real;
            attribute commandActive : Boolean;
        }
        
        port def MaterialInputPort {
            in item rawMaterial : RawMaterial;
        }
        
        port def MaterialOutputPort {
            out item processedMaterial : ProcessedMaterial;
        }
        
        port def PowerPort {
            in item energy : EnergyFlow;
        }
        
        port def ControlPort {
            inout signal : ControlSignal;
        }
        
        part def MaterialReceptor {
            attribute capacity : MassValue;
            attribute currentLoad : MassValue;
            port materialIn : MaterialInputPort;
            port controlInterface : ControlPort;
            port powerIn : PowerPort;
        }
        
        part def ProcessingChamber {
            attribute operatingTemperature : ThermodynamicTemperatureValue;
            attribute pressure : PressureValue;
            attribute volume : VolumeValue;
            port materialInlet : MaterialInputPort;
            port materialOutlet : MaterialOutputPort;
            port controlInterface : ControlPort;
            port powerIn : PowerPort;
        }
        
        part def QualityAnalyzer {
            attribute analysisAccuracy : Real;
            attribute sampleRate : FrequencyValue;
            port materialSample : MaterialInputPort;
            port controlInterface : ControlPort;
            port powerIn : PowerPort;
        }
        
        part def MaterialDispenser {
            attribute dispensingRate : MassPerTimeValue;
            attribute bufferCapacity : MassValue;
            port materialIn : MaterialInputPort;
            port materialOut : MaterialOutputPort;
            port controlInterface : ControlPort;
            port powerIn : PowerPort;
        }
        
        part def SystemController {
            attribute processingMode : String;
            attribute safetyStatus : Boolean;
            port controlBus : ControlPort[4];
            port operatorInterface : ControlPort;
            port powerIn : PowerPort;
        }
        
        part def PowerDistribution {
            attribute inputVoltage : ElectricPotentialValue;
            attribute totalPowerCapacity : PowerValue;
            port mainPowerIn : PowerPort;
            port powerOut : PowerPort[5];
        }
    }
    
    package Behaviors {
        private import Definitions::*;
        
        action def ReceiveMaterial {
            in rawInput : RawMaterial;
            out acceptedMaterial : RawMaterial;
            out loadLevel : Real;
        }
        
        action def ApplyProcessing {
            in material : RawMaterial;
            in temperature : ThermodynamicTemperatureValue;
            in pressure : PressureValue;
            in duration : TimeValue;
            out transformedMaterial : ProcessedMaterial;
        }
        
        action def AnalyzeQuality {
            in sample : ProcessedMaterial;
            out qualityScore : Real;
            out passStatus : Boolean;
        }
        
        action def DispenseMaterial {
            in material : ProcessedMaterial;
            in targetRate : MassPerTimeValue;
            out deliveredMaterial : ProcessedMaterial;
        }
        
        action def MonitorAndControl {
            in operatorCmd : OperatorCommand;
            in systemStatus : ControlSignal[4];
            out controlCommands : ControlSignal[4];
            out safetyFlag : Boolean;
        }
        
        action def ExecuteMatCProcess {
            in inputMaterial : RawMaterial;
            in operatorCommand : OperatorCommand;
            out outputMaterial : ProcessedMaterial;
            out processStatus : String;
            
            private attribute currentMaterial : RawMaterial;
            private attribute intermediateProduct : ProcessedMaterial;
            private attribute qualityResult : Real;
            private attribute safetyOk : Boolean := true;
            
            first start;
            then merge cycleStart;
            
            action receive : ReceiveMaterial {
                in rawInput = inputMaterial;
                out acceptedMaterial;
                out loadLevel;
            }
            
            then assign currentMaterial := receive.acceptedMaterial;
            
            then action process : ApplyProcessing {
                in material = currentMaterial;
                in temperature = 573.15;
                in pressure = 101325.0;
                in duration = 3600.0;
                out transformedMaterial;
            }
            
            then assign intermediateProduct := process.transformedMaterial;
            
            then action analyze : AnalyzeQuality {
                in sample = intermediateProduct;
                out qualityScore;
                out passStatus;
            }
            
            then assign qualityResult := analyze.qualityScore;
            
            then decide;
                if analyze.passStatus = true then dispense;
                if analyze.passStatus = false then reprocess;
            
            action dispense : DispenseMaterial {
                in material = intermediateProduct;
                in targetRate = 10.0;
                out deliveredMaterial;
            }
            
            then assign outputMaterial := dispense.deliveredMaterial;
            then assign processStatus := "Complete";
            then done;
            
            action reprocess {
                assign processStatus := "Reprocessing";
            }
            
            then cycleStart;
        }
        
        state machine def MatCSystemStateMachine {
            initial state Offline;
            
            state Initializing {
                entry action initializeSystems;
            }
            
            state Ready {
                entry action signalReady;
            }
            
            state Processing {
                entry action beginProcessing;
                do action continuousMonitoring;
                exit action stopProcessing;
            }
            
            state QualityCheck {
                entry action performAnalysis;
            }
            
            state Dispensing {
                entry action activateDispenser;
            }
            
            state Fault {
                entry action triggerAlarm;
            }
            
            transition powerOn
                first Offline
                accept SystemReady
                then Initializing;
            
            transition initComplete
                first Initializing
                then Ready;
            
            transition startProcess
                first Ready
                accept OperatorCommand
                then Processing;
            
            transition processComplete
                first Processing
                accept ProcessComplete
                then QualityCheck;
            
            transition qualityPass
                first QualityCheck
                then Dispensing;
            
            transition qualityFail
                first QualityCheck
                then Processing;
            
            transition dispensingComplete
                first Dispensing
                then Ready;
            
            transition emergencyShutdown
                first Processing
                accept EmergencyStop
                then Fault;
            
            transition faultRecovery
                first Fault
                then Initializing;
        }
    }
    
    package SystemAssembly {
        private import Definitions::*;
        private import Behaviors::*;
        
        part def MatCSystem {
            attribute systemId : String;
            attribute nominalThroughput : MassPerTimeValue;
            attribute operationalEfficiency : Real;
            
            part receptor : MaterialReceptor {
                attribute capacity = 500.0;
                attribute currentLoad = 0.0;
            }
            
            part chamber : ProcessingChamber {
                attribute operatingTemperature = 573.15;
                attribute pressure = 101325.0;
                attribute volume = 2.0;
            }
            
            part analyzer : QualityAnalyzer {
                attribute analysisAccuracy = 0.98;
                attribute sampleRate = 1.0;
            }
            
            part dispenser : MaterialDispenser {
                attribute dispensingRate = 10.0;
                attribute bufferCapacity = 100.0;
            }
            
            part controller : SystemController {
                attribute processingMode = "Automatic";
                attribute safetyStatus = true;
            }
            
            part powerDist : PowerDistribution {
                attribute inputVoltage = 480.0;
                attribute totalPowerCapacity = 50000.0;
            }
            
            connection powerDist.powerOut[1] to receptor.powerIn;
            connection powerDist.powerOut[2] to chamber.powerIn;
            connection powerDist.powerOut[3] to analyzer.powerIn;
            connection powerDist.powerOut[4] to dispenser.powerIn;
            connection powerDist.powerOut[5] to controller.powerIn;
            
            connection controller.controlBus[1] to receptor.controlInterface;
            connection controller.controlBus[2] to chamber.controlInterface;
            connection controller.controlBus[3] to analyzer.controlInterface;
            connection controller.controlBus[4] to dispenser.controlInterface;
            
            connection receptor.materialIn to chamber.materialInlet;
            connection chamber.materialOutlet to analyzer.materialSample;
            connection chamber.materialOutlet to dispenser.materialIn;
            
            perform action mainProcess : ExecuteMatCProcess;
            
            state machine operationalBehavior : MatCSystemStateMachine;
        }
    }
    
    package Requirements {
        private import SystemAssembly::*;
        
        requirement def FunctionalRequirement;
        requirement def PerformanceRequirement;
        requirement def SafetyRequirement;
        
        requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
            doc /* 
                The MatC System shall autonomously transform raw material feedstock 
                into processed material output through controlled thermal and pressure 
                treatment, continuous quality monitoring, and regulated dispensing, 
                ensuring consistent product quality and operational safety.
            */
            
            subject matcSystem : MatCSystem;
            
            require materialProcessing;
            require qualityAssurance;
            require safeOperation;
        }
        
        requirement <'REQ-002'> materialProcessing : FunctionalRequirement {
            doc /* 
                The system shall receive raw material, apply thermal processing at 
                controlled temperature and pressure, and produce processed material 
                meeting specified composition and quality criteria.
            */
            
            subject matcSystem : MatCSystem;
        }
        
        requirement <'REQ-003'> qualityAssurance : FunctionalRequirement {
            doc /* 
                The system shall analyze each batch of processed material and verify 
                quality grade meets or exceeds 0.95 before dispensing.
            */
            
            subject matcSystem : MatCSystem;
        }
        
        requirement <'REQ-004'> throughputTarget : PerformanceRequirement {
            doc /* 
                The MatC System shall maintain a nominal throughput of at least 
                10 kg per hour during continuous operation.
            */
            
            subject matcSystem : MatCSystem;
        }
        
        requirement <'REQ-005'> safeOperation : SafetyRequirement {
            doc /* 
                The system shall halt all processing operations within 2 seconds 
                of emergency stop activation and maintain safe state until operator 
                clearance is received.
            */
            
            subject matcSystem : MatCSystem;
        }
    }
}
