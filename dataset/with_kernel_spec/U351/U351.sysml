package PerineometerSystem {
    private import ScalarValues::*;
    
    package Definitions {
        attribute def PressureValue :> Real;
        attribute def DurationValue :> Real;
        attribute def StrengthIndexValue :> Real;
        
        attribute def PowerOnSignal;
        attribute def PowerOffSignal;
        attribute def StartSignal;
        attribute def StopSignal;
        attribute def CalibrationCompleteSignal;
        attribute def MeasurementCompleteSignal;
        attribute def AnalysisCompleteSignal;
        attribute def DisplayCompleteSignal;
        
        item def PressureSignal {
            attribute pressure : PressureValue;
        }
        item def FilteredPressureSignal {
            attribute pressure : PressureValue;
        }
        item def AnalyzedResults {
            attribute strengthIndex : StrengthIndexValue;
            attribute peakPressure : PressureValue;
            attribute contractionDuration : DurationValue;
        }
        item def ControlCommand {
            attribute mode : String;
            attribute cmd : String;
        }
        
        port def PressureOutPort {
            out signal : PressureSignal;
        }
        port def ResultsOutPort {
            out results : AnalyzedResults;
        }
        port def ControlOutPort {
            out command : ControlCommand;
        }
        
        action def FilterSignal {
            in rawSignal : PressureSignal;
            out filteredSignal : FilteredPressureSignal;
        }
        action def AnalyzeData {
            in filteredSignal : FilteredPressureSignal;
            out strengthIndex : StrengthIndexValue;
            out peakPressure : PressureValue;
            out contractionDuration : DurationValue;
        }
        action def CalibrateRoutine;
        action def DisplayResultsAction {
            in results : AnalyzedResults;
        }
        
        part def PressureSensor {
            port pressureOut : PressureOutPort;
        }
        part def InflatableProbe {
            part sensor : PressureSensor;
        }
        part def ProcessingUnit {
            port pressureIn : ~PressureOutPort;
            port resultsOut : ResultsOutPort;
            port controlIn : ~ControlOutPort;
            perform action purifySignal : FilterSignal;
            perform action evaluateData : AnalyzeData;
            perform action calibrate : CalibrateRoutine;
        }
        part def DisplayUnit {
            port resultsIn : ~ResultsOutPort;
            perform action showResults : DisplayResultsAction;
        }
        part def ControlUnit {
            port controlOut : ControlOutPort;
        }
        
        state def PerineometerStates {
            entry; then poweredOff;
            state poweredOff;
            transition t1 first poweredOff accept PowerOnSignal then idle;
            state idle;
            transition t2 first idle accept StartSignal then calibrating;
            transition t3 first idle accept PowerOffSignal then poweredOff;
            state calibrating;
            transition t4 first calibrating accept CalibrationCompleteSignal then measuring;
            state measuring;
            transition t5 first measuring accept MeasurementCompleteSignal then analyzing;
            transition t6 first measuring accept StopSignal then idle;
            state analyzing;
            transition t7 first analyzing accept AnalysisCompleteSignal then displaying;
            transition t8 first analyzing accept StopSignal then idle;
            state displaying;
            transition t9 first displaying accept DisplayCompleteSignal then idle;
            transition t10 first displaying accept StopSignal then idle;
        }
        
        part def Perineometer {
            part probe : InflatableProbe;
            part processor : ProcessingUnit;
            part display : DisplayUnit;
            part controller : ControlUnit;
            
            connect probe.sensor.pressureOut to processor.pressureIn;
            connect processor.resultsOut to display.resultsIn;
            connect controller.controlOut to processor.controlIn;
            
            exhibit state states : PerineometerStates;
        }
        
        requirement def MeasureMuscleStrength {
            subject perineometer : Perineometer;
            doc /* The device shall measure and assess the strength of pelvic floor muscles. */;
        }
        requirement def ProvideBiofeedback {
            subject perineometer : Perineometer;
            doc /* The device shall provide real-time visual biofeedback to the user or clinician. */;
        }
        requirement def SupportMeasurementModes {
            subject perineometer : Perineometer;
            doc /* The device shall support quick, extended, and endurance measurement modes. */;
        }
        requirement def CalibrationBeforeMeasurement {
            subject perineometer : Perineometer;
            doc /* The device shall run a calibration routine before each measurement session. */;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part perineometer1 : Perineometer {
            satisfy MeasureMuscleStrength by perineometer1;
            satisfy ProvideBiofeedback by perineometer1;
            satisfy SupportMeasurementModes by perineometer1;
            satisfy CalibrationBeforeMeasurement by perineometer1;
        }
    }
}
