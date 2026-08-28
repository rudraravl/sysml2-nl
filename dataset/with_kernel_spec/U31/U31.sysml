package 'AcceleromyographSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        part def Acceleromyograph {
            part nerveStimulator : NerveStimulator;
            part accelerometerSensor : AccelerometerSensor;
            part analysisUnit : AnalysisUnit;
            part displayController : DisplayController;
            
            exhibit state 'device states' : AcceleromyographStates;
        }
        
        part def NerveStimulator {
            out stimPort : StimOutPort;
            perform action 'generate TOF' : GenerateTOF;
        }
        
        part def AccelerometerSensor {
            in stimPort : StimInPort;
            out dataPort : DataOutPort;
            perform action 'measure acceleration' : MeasureAcceleration;
        }
        
        part def AnalysisUnit {
            in dataPort : DataInPort;
            out displayPort : DisplayDataOutPort;
            perform action 'calculate TOF ratio' : CalculateTOFRatio;
            perform action 'assess blockade' : AssessBlockade;
        }
        
        part def DisplayController {
            in displayPort : DisplayDataInPort;
            perform action 'update display' : UpdateDisplay;
        }
        
        port def StimOutPort { out stimulus : TOFStimulus; }
        port def StimInPort { in stimulus : TOFStimulus; }
        port def DataOutPort { out response : MuscleResponse; }
        port def DataInPort { in response : MuscleResponse; }
        port def DisplayDataOutPort { out assessment : BlockadeAssessment; }
        port def DisplayDataInPort { in assessment : BlockadeAssessment; }
        
        item def TOFStimulus {
            attribute pulseCount : Integer = 4;
            attribute interval : ISQ::Time = 0.5;
            attribute current : ISQ::ElectricCurrent = 40;
        }
        
        item def MuscleResponse {
            attribute accelerations : ISQ::Acceleration[4];
        }
        
        item def BlockadeAssessment {
            attribute ratio : Real;
            attribute depth : Real;
            attribute trend : String;
        }
        
        action def GenerateTOF {
            out stimulus : TOFStimulus;
        }
        
        action def MeasureAcceleration {
            in stimulus : TOFStimulus;
            out response : MuscleResponse;
        }
        
        action def CalculateTOFRatio {
            in response : MuscleResponse;
            out ratio : Real;
        }
        
        action def AssessBlockade {
            in ratio : Real;
            out assessment : BlockadeAssessment;
        }
        
        action def UpdateDisplay {
            in assessment : BlockadeAssessment;
        }
        
        action def PerformSelfTest;
        action def CalibrateSensor;
        action def TriggerAlarm;
        
        attribute def StartSession;
        attribute def BeginMonitoring;
        attribute def Pause;
        attribute def Resume;
        attribute def AcknowledgeAlarm;
        attribute def DeepBlockadeSignal;
        
        state def AcceleromyographStates;
    }
    
    package Requirements {
        requirement MeasureMuscleRelaxation {
            doc /* The system shall quantitatively measure the degree of muscle relaxation using acceleromyography. */
        }
        requirement CalculateTOFRatioReq {
            doc /* The system shall calculate the Train-of-Four ratio by comparing the strength of the fourth muscle twitch to the first. */
        }
        requirement AlarmOnDeepBlockade {
            doc /* The system shall activate an alarm if the blockade becomes too deep, indicated by a TOF ratio below a critical threshold. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        private import Requirements::*;
        
        action 'perform self test' : PerformSelfTest;
        action 'calibrate sensor' : CalibrateSensor;
        action 'trigger alarm' : TriggerAlarm;
        
        part acceleromyograph : Acceleromyograph {
            connect nerveStimulator.stimPort to accelerometerSensor.stimPort;
            connect accelerometerSensor.dataPort to analysisUnit.dataPort;
            connect analysisUnit.displayPort to displayController.displayPort;
            
            satisfy MeasureMuscleRelaxation;
            satisfy CalculateTOFRatioReq;
            satisfy AlarmOnDeepBlockade;
            
            exhibit state 'device states' : AcceleromyographStates {
                entry; then initialization;
                
                state initialization {
                    entry 'perform self test';
                    do 'calibrate sensor';
                }
                accept StartSession then ready;
                
                state ready;
                accept BeginMonitoring then monitoring;
                
                state monitoring {
                    do action 'monitoring cycle' {
                        perform nerveStimulator.'generate TOF';
                        perform accelerometerSensor.'measure acceleration';
                        perform analysisUnit.'calculate TOF ratio';
                        perform analysisUnit.'assess blockade';
                        perform displayController.'update display';
                    }
                }
                accept DeepBlockadeSignal then alarm;
                accept Pause then paused;
                
                state paused;
                accept Resume then monitoring;
                
                state alarm {
                    entry 'trigger alarm';
                }
                accept AcknowledgeAlarm then monitoring;
            }
        }
    }
    
    alias Acceleromyograph = Definitions::Acceleromyograph;
    alias AcceleromyographStates = Definitions::AcceleromyographStates;
}
