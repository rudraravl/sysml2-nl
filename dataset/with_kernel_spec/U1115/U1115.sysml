package AutomatedLabSystem {
    private import ScalarValues::*;
    
    unit def mL;
    unit def degC;
    unit def s;
    
    value def Volume :> Real { unit mL; }
    value def Temperature :> Real { unit degC; }
    value def Duration :> Real { unit s; }
    
    item def SampleVial {
        attribute sampleId : String;
        attribute sampleType : String;
        attribute volume : Volume;
    }
    
    item def Reagent {
        attribute name : String;
        attribute volume : Volume;
    }
    
    item def TestRequest {
        attribute requestId : String;
        attribute sampleId : String;
        attribute testType : String;
        attribute priority : Integer;
    }
    
    item def PreparedSample {
        attribute sampleId : String;
        attribute reagentName : String;
        attribute volume : Volume;
    }
    
    item def RawData {
        attribute sampleId : String;
        attribute measurement : Real;
        attribute timestamp : String;
    }
    
    item def AnalysisReport {
        attribute reportId : String;
        attribute sampleId : String;
        attribute result : String;
        attribute timestamp : String;
    }
    
    port def CommandPort {
        out command : String;
        in status : String;
    }
    
    port def SamplePort {
        in sample : SampleVial;
    }
    
    port def DataPort {
        in data : RawData;
    }
    
    port def ReportPort {
        in report : AnalysisReport;
    }
    
    part def SchedulerController {
        port cmdToSampleHandler : CommandPort;
        port cmdToLiquidHandler : CommandPort;
        port cmdToIncubator : CommandPort;
        port cmdToAnalyzer : CommandPort;
        port cmdToDataSystem : CommandPort;
        port reportFromData : ReportPort;
        
        attribute requestQueue : TestRequest[0..*];
        attribute activeTests : Integer = 0;
        attribute completedTests : Integer = 0;
        
        action def Prioritize {
            in reqs : TestRequest[0..*];
            out orderedReqs : TestRequest[0..*];
        }
        
        action def DispatchTest {
            in req : TestRequest;
            out command : String;
        }
        
        action prioritize : Prioritize {
            in reqs = requestQueue;
        }
        
        state machine {
            state Idle {
                transition to Queueing;
            }
            state Queueing {
                transition to Dispatching;
            }
            state Dispatching {
                transition to Monitoring;
            }
            state Monitoring {
                transition to Queueing when activeTests > 0;
                transition to Idle when activeTests == 0;
            }
        }
    }
    
    part def SampleHandler {
        port cmdIn : ~CommandPort;
        port sampleIn : SamplePort;
        port sampleOut : ~SamplePort;
        
        part gripper {
            attribute heldSampleId : String[0..1];
            attribute isOpen : Boolean = true;
        }
        
        action def ValidateSample {
            in sample : SampleVial;
            out valid : Boolean;
        }
        
        action def PickUpSample {
            in sample : SampleVial;
        }
        
        action def Transport {
            in sample : SampleVial;
            in destination : String;
        }
        
        action validate : ValidateSample {
            in sample = sampleIn.sample;
        }
    }
    
    part def LiquidHandler {
        port cmdIn : ~CommandPort;
        port sampleIn : SamplePort;
        port sampleOut : ~SamplePort;
        
        attribute accuracy : Volume = 0.01 [mL];
        attribute maxVolume : Volume = 5.0 [mL];
        
        part pipette {
            attribute currentVolume : Volume = 0.0 [mL];
            attribute tipPresent : Boolean = true;
        }
        
        action def Aspirate {
            in targetVolume : Volume;
            out success : Boolean;
        }
        
        action def Dispense {
            in volume : Volume;
            out success : Boolean;
        }
        
        action def PrepareSample {
            in sample : SampleVial;
            in reagent : Reagent;
            out prepared : PreparedSample;
        }
        
        action prepare : PrepareSample {
            in sample = sampleIn.sample;
        }
    }
    
    part def Incubator {
        port cmdIn : ~CommandPort;
        port sampleIn : SamplePort;
        port sampleOut : ~SamplePort;
        
        attribute setTemp : Temperature = 37.0 [degC];
        attribute currentTemp : Temperature = 25.0 [degC];
        attribute duration : Duration = 600.0 [s];
        attribute tolerance : Temperature = 0.5 [degC];
        
        state machine {
            state Idle {
                transition to Heating;
            }
            state Heating {
                transition to Maintaining when currentTemp >= setTemp - tolerance;
            }
            state Maintaining {
                transition to Cooling after 600 [s];
            }
            state Cooling {
                transition to Complete when currentTemp <= 25.0 [degC];
            }
            state Complete;
        }
    }
    
    part def Analyzer {
        port cmdIn : ~CommandPort;
        port sampleIn : SamplePort;
        port dataOut : ~DataPort;
        
        attribute measurementType : String;
        attribute calibrationStatus : Boolean = true;
        
        action def Analyze {
            in sample : SampleVial;
            out data : RawData;
        }
        
        action analyze : Analyze {
            in sample = sampleIn.sample;
        }
    }
    
    part def DataManagementSystem {
        port cmdIn : ~CommandPort;
        port dataIn : DataPort;
        port reportOut : ~ReportPort;
        
        attribute databaseStatus : Boolean = true;
        attribute storedRecords : RawData[0..*];
        attribute generatedReports : AnalysisReport[0..*];
        
        action def Log {
            in data : RawData;
            out logged : Boolean;
        }
        
        action def GenerateReport {
            in data : RawData;
            out report : AnalysisReport;
        }
        
        action generate : GenerateReport {
            in data = dataIn.data;
        }
    }
    
    part def AutomatedLab {
        part scheduler : SchedulerController;
        part sampleHandler : SampleHandler;
        part liquidHandler : LiquidHandler;
        part incubator : Incubator;
        part analyzer : Analyzer;
        part dataSystem : DataManagementSystem;
        
        connect scheduler.cmdToSampleHandler to sampleHandler.cmdIn;
        connect scheduler.cmdToLiquidHandler to liquidHandler.cmdIn;
        connect scheduler.cmdToIncubator to incubator.cmdIn;
        connect scheduler.cmdToAnalyzer to analyzer.cmdIn;
        connect scheduler.cmdToDataSystem to dataSystem.cmdIn;
        
        connect sampleHandler.sampleOut to liquidHandler.sampleIn;
        connect liquidHandler.sampleOut to incubator.sampleIn;
        connect incubator.sampleOut to analyzer.sampleIn;
        
        connect analyzer.dataOut to dataSystem.dataIn;
        connect dataSystem.reportOut to scheduler.reportFromData;
    }
    
    requirement def LabSystemRequirements {
        subject lab : AutomatedLab;
        
        requirement ThroughputReq {
            doc /* The system shall process at least 100 samples per hour. */
            attribute minThroughput : Integer = 100;
        }
        
        requirement AccuracyReq {
            doc /* The Liquid Handler shall dispense reagents with an accuracy of at least 0.01 mL. */
            attribute maxDeviation : Volume = 0.01 [mL];
        }
        
        requirement TempStabilityReq {
            doc /* The Incubator shall maintain the set temperature within plus or minus 0.5 degrees Celsius. */
            attribute tolerance : Temperature = 0.5 [degC];
        }
        
        requirement TraceabilityReq {
            doc /* The Data Management System shall associate all results with the original sample ID. */
        }
        
        requirement ReliabilityReq {
            doc /* The system shall operate continuously for at least 24 hours without failure. */
            attribute minUptime : Duration = 86400.0 [s];
        }
    }
}
