package LaboratoryAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SampleID;
    attribute def TestType;
    attribute def TestStatus;
    
    item def Sample {
        attribute sampleID : SampleID;
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute collectionTime : DurationValue;
    }
    
    item def Reagent {
        attribute reagentType : String;
        attribute concentration : Real;
        attribute expirationDate : DurationValue;
    }
    
    item def TestRequest {
        attribute requestID : String;
        attribute testType : TestType;
        attribute priority : Integer;
        attribute sample : Sample;
    }
    
    item def AnalysisResult {
        attribute reportID : String;
        attribute testValue : Real;
        attribute testStatus : TestStatus;
        attribute completionTime : DurationValue;
    }
    
    port def SampleInputPort {
        in item sample : Sample;
    }
    
    port def SampleOutputPort {
        out item sample : Sample;
    }
    
    port def ReagentPort {
        in item reagent : Reagent;
    }
    
    port def DataPort {
        out item report : AnalysisResult;
    }
    
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }
    
    part def SampleHandler {
        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port control : ControlPort;
        
        attribute currentPosition : LengthValue;
        attribute gripperState : String;
        
        action def HandleSample {
            first start;
            then action receiveSample;
            then action validateSample;
            then action transportSample;
            then action deliverSample;
            then done;
        }
        
        perform action handleSample : HandleSample;
    }
    
    part def Analyzer {
        port sampleIn : SampleInputPort;
        port reagentIn : ReagentPort;
        port dataOut : DataPort;
        port control : ControlPort;
        
        attribute operatingTemperature : ThermodynamicTemperatureValue;
        attribute calibrationStatus : Boolean;
    }
    
    part def LiquidHandler {
        port reagentIn : ReagentPort;
        port samplePort : SampleOutputPort;
        port control : ControlPort;
        
        attribute pipetteVolume : VolumeValue;
        attribute dispensingAccuracy : Real;
        
        action def DispenseLiquid {
            first start;
            then action aspirateReagent;
            then action positionPipette;
            then action dispenseReagent;
            then done;
        }
        
        perform action dispenseLiquid : DispenseLiquid;
    }
    
    event LoadSampleEvent;
    
    part def Incubator {
        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port control : ControlPort;
        
        attribute setTemperature : ThermodynamicTemperatureValue;
        attribute actualTemperature : ThermodynamicTemperatureValue;
        attribute incubationTime : DurationValue;
        
        state incubatorStates {
            entry; then idle;
            
            state idle;
            transition idle_to_loading
                first idle
                accept LoadSampleEvent
                then loading;
            
            state loading;
            transition loading_to_heating
                first loading
                then heating;
            
            state heating {
                entry assign setTemperature := 37.0 [K];
            }
            transition heating_to_incubating
                first heating
                if actualTemperature >= setTemperature
                then incubating;
            
            state incubating;
            transition incubating_to_cooling
                first incubating
                then cooling;
            
            state cooling;
            transition cooling_to_unloading
                first cooling
                if actualTemperature <= 298.0 [K]
                then unloading;
            
            state unloading;
            transition unloading_to_idle
                first unloading
                then idle;
        }
    }
    
    part def DataManagementSystem {
        port dataIn : DataPort;
        port control : ControlPort;
        
        attribute databaseConnection : String;
        attribute reportQueue : AnalysisResult[*];
        
        action def ManageData {
            first start;
            then action receiveResults;
            then action validateResults;
            then action storeResults;
            then action generateReport;
            then action transmitReport;
            then done;
        }
        
        perform action manageData : ManageData;
    }
    
    part def SchedulerController {
        port control : ControlPort[*];
        
        attribute requestQueue : TestRequest[*];
        attribute activeTests : Integer;
        attribute maxConcurrentTests : Integer;
        
        action def ScheduleTests {
            first start;
            then merge checkQueue;
            then action prioritizeRequests;
            then decide;
                if activeTests < maxConcurrentTests then assignTest;
                else checkQueue;
            action assignTest;
            then checkQueue;
        }
        
        perform action scheduleTests : ScheduleTests;
    }
    
    action def PerformAnalysis {
        in testRequest : TestRequest;
        out analysisReport : AnalysisResult;
        
        first start;
        then merge checkQueue;
        
        then action loadSample {
            in sample = testRequest.sample;
        }
        
        then action prepareSample;
        
        then action addReagents;
        
        then action incubateSample {
            in incubationDuration : DurationValue;
        }
        
        then action measureResults {
            out rawData : Real;
        }
        
        then decide;
            if measureResults.rawData > 0.0 then processResults;
            if measureResults.rawData <= 0.0 then retest;
        
        action processResults {
            in data = measureResults.rawData;
            out result : Real;
        }
        then generateReport;
        
        action retest;
        then checkQueue;
        
        action generateReport {
            in result = processResults.result;
            out report : AnalysisResult = analysisReport;
        }
        then done;
    }
    
    part def LaboratoryAutomationSystem {
        
        part sampleHandler : SampleHandler;
        
        part liquidHandler : LiquidHandler;
        
        part incubator : Incubator;
        
        part analyzer : Analyzer;
        
        part dataSystem : DataManagementSystem;
        
        part scheduler : SchedulerController;
        
        connect sampleHandler.sampleOut to incubator.sampleIn;
        connect incubator.sampleOut to analyzer.sampleIn;
        connect liquidHandler.samplePort to analyzer.sampleIn;
        connect analyzer.dataOut to dataSystem.dataIn;
        connect scheduler.control to analyzer.control;
        connect scheduler.control to incubator.control;
        connect scheduler.control to dataSystem.control;
        
        action def AutomateLabProcess {
            doc /* 
                The laboratory automation system automatically processes biological and chemical samples
                through a complete analysis workflow. The system receives test requests with samples,
                schedules and prioritizes the work, handles sample preparation and transport, performs
                automated testing with precise reagent dispensing, controls incubation conditions,
                measures and analyzes results, and generates comprehensive reports. This end-to-end
                automation increases throughput, ensures consistency, reduces human error, and provides
                complete traceability of all laboratory operations.
            */
            
            first start;
            then merge processNextRequest;
            
            then action receiveTestRequest {
                out request : TestRequest;
            }
            
            then action schedulerControl : SchedulerController::ScheduleTests;
            
            then action sampleHandling : SampleHandler::HandleSample;
            
            then action liquidDispensing : LiquidHandler::DispenseLiquid;
            
            then action sampleIncubation;
            
            then action performTest : PerformAnalysis {
                in testRequest = receiveTestRequest.request;
                out analysisReport;
            }
            
            then action dataManagement : DataManagementSystem::ManageData;
            
            then decide;
                if true then processNextRequest;
                else done;
        }
        
        perform action automateLabProcess : AutomateLabProcess;
    }
    
    part laboratorySystem : LaboratoryAutomationSystem;
    
    requirement def SystemRequirement;
    
    requirement <'LAB-001'> throughputRequirement : SystemRequirement {
        doc /* The laboratory automation system shall process at least 100 samples per hour. */
        
        require constraint {
            laboratorySystem.scheduler.maxConcurrentTests >= 10
        }
    }
    
    requirement <'LAB-002'> accuracyRequirement : SystemRequirement {
        doc /* The liquid handling system shall dispense reagents with accuracy of ±1%. */
        
        require constraint {
            laboratorySystem.liquidHandler.dispensingAccuracy >= 0.99
        }
    }
    
    requirement <'LAB-003'> temperatureControlRequirement : SystemRequirement {
        doc /* The incubator shall maintain temperature within ±0.5K of setpoint. */
        
        require constraint {
            abs(laboratorySystem.incubator.actualTemperature - 
                laboratorySystem.incubator.setTemperature) <= 0.5 [K]
        }
    }
    
    requirement <'LAB-004'> traceabilityRequirement : SystemRequirement {
        doc /* The system shall maintain complete traceability of all samples and results. */
        
        require constraint {
            laboratorySystem.dataSystem.databaseConnection != null
        }
    }
    
    requirement <'LAB-MISSION'> automationMission {
        doc /* 
            The laboratory automation system shall automatically process test requests from
            sample receipt through analysis and reporting to increase laboratory efficiency
            and ensure consistent, traceable results.
        */
        
        assume constraint sampleAvailability {
            doc /* Valid samples with proper identification are available for testing. */
        }
        
        assume constraint reagentAvailability {
            doc /* Required reagents are available and within expiration dates. */
        }
        
        require throughputRequirement;
        require accuracyRequirement;
        require temperatureControlRequirement;
        require traceabilityRequirement;
    }
}
