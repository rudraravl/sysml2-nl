package RightspotPHIndicator {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    value def pHValue :> Real { 
        unit 'pH'; 
    }
    value def Temperature :> Real { 
        unit 'C'; 
    }
    value def Confidence :> Real { 
        unit '%'; 
    }

    // Item Definitions
    item def Aspirate;
    
    item def RawMeasurement {
        attr pH : pHValue;
        attr temp : Temperature;
    }
    
    item def CorrectedMeasurement {
        attr pH : pHValue;
    }
    
    enum def PlacementStatus {
        gastric;
        nonGastric;
        indeterminate;
    }
    
    item def AnalysisResult {
        attr pH : pHValue;
        attr placement : PlacementStatus;
        attr confidence : Confidence;
    }

    // Port Definitions
    port def AspiratePort { in item : Aspirate; }
    port def RawDataOutPort { out item : RawMeasurement; }
    port def CorrectedDataOutPort { out item : CorrectedMeasurement; }
    port def ResultOutPort { out item : AnalysisResult; }
    port def CommandOutPort { out command : String; }
    port def StatusOutPort { out status : String; }

    // Parts
    part def RightspotSystem {
        port aspirateIn : AspiratePort;
        
        part sensorProbe : PHSensorProbe;
        part signalProcessor : SignalProcessor;
        part placementAnalyzer : PlacementAnalyzer;
        part display : VisualDisplay;
        part controlUnit : ControlUnit;

        connect aspirateIn to sensorProbe.aspirateIn;
        connect sensorProbe.rawOut to signalProcessor.rawIn;
        connect signalProcessor.correctedOut to placementAnalyzer.correctedIn;
        connect placementAnalyzer.resultOut to display.resultIn;
        
        connect controlUnit.sensorCmd to sensorProbe.cmdIn;
        connect controlUnit.processorCmd to signalProcessor.cmdIn;
        connect controlUnit.analyzerCmd to placementAnalyzer.cmdIn;
        connect controlUnit.displayCmd to display.cmdIn;
        
        connect sensorProbe.statusOut to controlUnit.sensorStatus;
        connect signalProcessor.statusOut to controlUnit.processorStatus;
        connect placementAnalyzer.statusOut to controlUnit.analyzerStatus;
        connect display.statusOut to controlUnit.displayStatus;
    }

    part def PHSensorProbe {
        port aspirateIn : AspiratePort;
        port rawOut : RawDataOutPort;
        port cmdIn : ~CommandOutPort;
        port statusOut : StatusOutPort;
        
        action def takeMeasurement {
            in sample : Aspirate;
            out measurement : RawMeasurement;
        }
    }

    part def SignalProcessor {
        port rawIn : ~RawDataOutPort;
        port correctedOut : CorrectedDataOutPort;
        port cmdIn : ~CommandOutPort;
        port statusOut : StatusOutPort;
        
        action def processSignal {
            in raw : RawMeasurement;
            out corrected : CorrectedMeasurement;
        }
    }

    part def PlacementAnalyzer {
        port correctedIn : ~CorrectedDataOutPort;
        port resultOut : ResultOutPort;
        port cmdIn : ~CommandOutPort;
        port statusOut : StatusOutPort;
        
        readonly attr gastricThreshold : pHValue = 5.5;
        
        action def analyzePlacement {
            in corrected : CorrectedMeasurement;
            out result : AnalysisResult;
        }
    }

    part def VisualDisplay {
        port resultIn : ~ResultOutPort;
        port cmdIn : ~CommandOutPort;
        port statusOut : StatusOutPort;
        
        action def displayResult {
            in result : AnalysisResult;
        }
    }

    part def ControlUnit {
        port sensorCmd : CommandOutPort;
        port processorCmd : CommandOutPort;
        port analyzerCmd : CommandOutPort;
        port displayCmd : CommandOutPort;
        
        port sensorStatus : ~StatusOutPort;
        port processorStatus : ~StatusOutPort;
        port analyzerStatus : ~StatusOutPort;
        port displayStatus : ~StatusOutPort;
        
        attr aspirateDetected : Boolean = false;
        attr measureStart : Boolean = false;
        attr measurementDone : Boolean = false;
        attr analysisDone : Boolean = false;
        attr reset : Boolean = false;
        attr fault : Boolean = false;
        
        state machine def OperationalStates {
            initial start;
            state idle;
            state ready;
            state measuring;
            state analyzing;
            state displaying;
            state error;
            
            transition start to idle;
            transition idle to ready when aspirateDetected;
            transition ready to measuring when measureStart;
            transition measuring to analyzing when measurementDone;
            transition analyzing to displaying when analysisDone;
            transition displaying to idle when reset;
            transition measuring to error when fault;
            transition analyzing to error when fault;
            transition error to idle when reset;
        }
    }

    // Requirements
    requirement def VerifyPlacement {
        subject system : RightspotSystem;
        objective {
            doc "The system shall verify the correct placement of nasogastric feeding tubes by measuring the pH level of an aspirate sample."
        }
    }

    requirement def MeasurePH {
        subject sensor : PHSensorProbe;
        objective {
            doc "The pH Sensor Probe shall measure the raw pH and temperature of the aspirate sample."
        }
    }

    requirement def ProcessSignal {
        subject processor : SignalProcessor;
        objective {
            doc "The Signal Processor shall apply calibration formulas and temperature compensation to produce an accurate pH value."
        }
    }

    requirement def AnalyzePlacement {
        subject analyzer : PlacementAnalyzer;
        objective {
            doc "The Placement Analyzer shall determine if the tube placement is gastric, non-gastric, or indeterminate based on a pH threshold of 5.5 or lower, and assign a confidence level."
        }
    }

    requirement def DisplayResults {
        subject display : VisualDisplay;
        objective {
            doc "The Visual Display shall show the pH value, placement status, and confidence score to the healthcare professional."
        }
    }

    requirement def ManageStates {
        subject control : ControlUnit;
        objective {
            doc "The Control Unit shall manage the system's operational states, moving from idle to ready, measuring, analyzing, displaying, and handling errors."
        }
    }
}
