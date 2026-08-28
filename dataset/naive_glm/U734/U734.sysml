package ISE_System {
    import ISQ::*;
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    attribute def Voltage :> Real { doc "Electrical potential difference"; }
    attribute def Concentration :> Real { doc "Amount concentration of an ion"; }
    attribute def Temperature :> Real { doc "Thermodynamic temperature"; }
    attribute def Conductivity :> Real { doc "Electrical conductivity"; }
    attribute def Impedance :> Real { doc "Electrical impedance"; }
    attribute def Gain :> Real { doc "Dimensionless gain factor"; }
    attribute def SlopeFactor :> Real { doc "Electrode slope in mV per decade"; }
    attribute def TimeValue :> Real { doc "Elapsed time"; }
    attribute def DriftIndicator :> Real { doc "Measure of signal drift"; }

    // ===== Item Types =====
    item def LiquidSample {
        attribute temperature : Temperature;
        attribute pH : Real;
        attribute targetIonConcentration : Concentration;
    }
    item def CalibrationSolution {
        attribute knownConcentration : Concentration;
        attribute temperature : Temperature;
    }
    item def CleaningAgent {
        attribute solventType : String;
    }
    item def RawSignal {
        attribute voltage : Voltage;
        attribute timestamp : TimeValue;
    }
    item def ProcessedSignal {
        attribute voltage : Voltage;
        attribute noiseLevel : Real;
        attribute timestamp : TimeValue;
    }
    item def ConcentrationReading {
        attribute value : Concentration;
        attribute uncertainty : Concentration;
        attribute timestamp : TimeValue;
        attribute temperature : Temperature;
    }
    item def CalibrationData {
        attribute slope : SlopeFactor;
        attribute intercept : Voltage;
        attribute e0 : Voltage;
        attribute calibrationTime : TimeValue;
        attribute n : Real;
    }
    item def DiagnosticStatus {
        attribute code : Integer;
        attribute message : String;
        attribute severity : Integer;
    }

    // ===== Ports =====
    port def SamplePort {
        out item sample : LiquidSample;
    }
    port def CalibrationPort {
        out item calSolution : CalibrationSolution;
    }
    port def MaintenancePort {
        in item cleaningAgent : CleaningAgent;
    }
    port def ElectricalSignalPort {
        out item signal : RawSignal;
    }
    port def ProcessedSignalPort {
        out item signal : ProcessedSignal;
    }
    port def DataPort {
        out item reading : ConcentrationReading;
        out item diagnostics : DiagnosticStatus;
    }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ===== Parts =====
    part def SelectiveMembrane {
        attribute targetIon : String;
        attribute selectivityCoefficient : Real;
        attribute impedance : Impedance;
        port out membranePotential : ElectricalSignalPort;
        
        action generatePotential {
            in sample : LiquidSample;
            out potential : RawSignal;
        }
    }
    part def ReferenceElectrode {
        attribute electrodeType : String;
        attribute stability : Voltage;
        attribute fillingSolution : String;
        port out referencePotential : ElectricalSignalPort;
        
        action provideStablePotential {
            out potential : RawSignal;
        }
    }
    part def ElectrodeAssembly {
        part selectiveMembrane : SelectiveMembrane {
            attribute targetIon := "Na+";
        }
        part referenceElectrode : ReferenceElectrode {
            attribute electrodeType := "Ag/AgCl";
            attribute fillingSolution := "KCl saturated";
        }
        port sampleInterface : SamplePort;
        port differentialOutput : ElectricalSignalPort;
        port maintenanceInterface : MaintenancePort;
        
        action combinePotentials {
            in membraneSignal : RawSignal;
            in referenceSignal : RawSignal;
            out differentialSignal : RawSignal;
        }
    }
    part def HighImpedanceMeter {
        attribute inputImpedance : Impedance;
        attribute bandwidth : Real;
        port signalInput : ElectricalSignalPort;
        port signalOutput : ElectricalSignalPort;
        
        action measurePotential {
            in inputSignal : RawSignal;
            out measuredSignal : RawSignal;
        }
    }
    part def SignalProcessor {
        attribute gain : Gain;
        attribute filterCutoff : Real;
        attribute noiseFloor : Voltage;
        port processorInput : ElectricalSignalPort;
        port processorOutput : ProcessedSignalPort;
        
        action processSignal {
            in rawSignal : RawSignal;
            out processedSignal : ProcessedSignal;
        }
    }
    part def CalculatorUnit {
        attribute temperature : Temperature;
        attribute faradayConstant : Real;
        attribute gasConstant : Real;
        attribute calibrationData : CalibrationData;
        port calculationInput : ProcessedSignalPort;
        port dataOutput : DataPort;
        
        action applyNernstEquation {
            in processedSignal : ProcessedSignal;
            in calibration : CalibrationData;
            in temp : Temperature;
            out concentrationReading : ConcentrationReading;
        }
    }
    part def SystemController {
        port controlInterface : ControlPort;
        attribute currentState : String;
        
        action executeCommand {
            in cmd : String;
            out status : String;
        }
    }
    part def DisplayUnit {
        port displayInput : DataPort;
        
        action displayReading {
            in reading : ConcentrationReading;
        }
    }
    part def ISEInstrument {
        part electrodeAssembly : ElectrodeAssembly;
        part meter : HighImpedanceMeter;
        part processor : SignalProcessor;
        part calculator : CalculatorUnit;
        part controller : SystemController;
        part display : DisplayUnit;
        
        port samplePort : SamplePort;
        port calibrationPort : CalibrationPort;
        port maintenancePort : MaintenancePort;
        port controlPort : ControlPort;
        port dataPort : DataPort;
        
        connection sampleToElectrode connect samplePort to electrodeAssembly.sampleInterface;
        connection calToElectrode connect calibrationPort to electrodeAssembly.sampleInterface;
        connection maintenanceToElectrode connect maintenancePort to electrodeAssembly.maintenanceInterface;
        connection electrodeToMeter connect electrodeAssembly.differentialOutput to meter.signalInput;
        connection meterToProcessor connect meter.signalOutput to processor.processorInput;
        connection processorToCalculator connect processor.processorOutput to calculator.calculationInput;
        connection calculatorToDisplay connect calculator.dataOutput to display.displayInput;
        connection calculatorToDataPort connect calculator.dataOutput to dataPort;
        connection controlToController connect controlPort to controller.controlInterface;
    }

    // ===== State Machine =====
    state def ISEOperatingStates {
        entry action initializeSystem;
        
        state Initialization {
            entry action performSelfCheck {
                out status : DiagnosticStatus;
            }
            do action checkComponents {
                out diagnostics : DiagnosticStatus;
            }
            exit action logInitializationComplete;
            transition to Calibration
                if self.checkComponents.diagnostics.code == 0
                accept "calibrate";
        }
        
        state Calibration {
            entry action startCalibration;
            do action measureCalibrationPoints {
                in calSolution : CalibrationSolution;
                out calibrationData : CalibrationData;
            }
            exit action storeCalibrationData;
            transition to Ready
                if self.measureCalibrationPoints.calibrationData.slope > 50
                accept "complete";
            transition to Maintenance
                if self.measureCalibrationPoints.calibrationData.slope < 50
                accept "fail";
        }
        
        state Ready {
            entry action setReadyIndicator;
            do action waitForSample;
            transition to Measuring accept "measure";
            transition to Maintenance accept "maintain";
        }
        
        state Measuring {
            entry action startMeasurement;
            
            state Stabilizing {
                entry action monitorStability {
                    in signal : RawSignal;
                    out stable : Boolean;
                }
                do action waitForSteadyState {
                    in signal : RawSignal;
                    out stabilityAchieved : Boolean;
                }
                transition to Calculating
                    if self.waitForSteadyState.stabilityAchieved == true;
            }
            
            state Calculating {
                entry action calculateConcentration {
                    in processedSignal : ProcessedSignal;
                    in calibration : CalibrationData;
                    out reading : ConcentrationReading;
                }
                exit action storeResult;
                transition to Ready accept "complete";
                transition to Maintenance
                    if self.calculateConcentration.reading.uncertainty > 0.1
                    accept "drift";
            }
            
            transition to Stabilizing accept "stabilize";
            transition to Ready accept "cancel";
        }
        
        state Maintenance {
            entry action enterMaintenanceMode;
            do action performMaintenance {
                in cleaningAgent : CleaningAgent;
                out status : DiagnosticStatus;
            }
            exit action logMaintenanceComplete;
            transition to Initialization accept "reinitialize";
        }
        
        transition to Maintenance
            if driftDetected == true;
        transition to Maintenance
            if cleaningRequired == true;
    }

    // ===== Requirements =====
    requirement def MeasurementAccuracyRequirement {
        doc "The ISE system shall measure ion concentration within specified accuracy."
        attribute targetAccuracy : Concentration := 0.01;
        subject instrument : ISEInstrument;
        require instrument.calculator.applyNernstEquation.concentrationReading.uncertainty <= targetAccuracy;
    }
    requirement def ResponseTimeRequirement {
        doc "The system shall complete a measurement within the specified time."
        attribute maxResponseTime : TimeValue := 30.0;
        subject instrument : ISEInstrument;
        require instrument.calculator.applyNernstEquation.concentrationReading.timestamp <= maxResponseTime;
    }
    requirement def StabilityRequirement {
        doc "The reference electrode shall maintain stable potential."
        attribute maxDrift : Voltage := 0.001;
        subject electrode : ReferenceElectrode;
        require electrode.stability <= maxDrift;
    }
    requirement def SelectivityRequirement {
        doc "The selective membrane shall respond preferentially to the target ion."
        attribute minSelectivity : Real := 1000.0;
        subject membrane : SelectiveMembrane;
        require membrane.selectivityCoefficient >= minSelectivity;
    }
    requirement def ImpedanceRequirement {
        doc "The high-impedance meter shall have input impedance above threshold."
        attribute minImpedance : Impedance := 1e12;
        subject meter : HighImpedanceMeter;
        require meter.inputImpedance >= minImpedance;
    }
    requirement def CalibrationRequirement {
        doc "System shall be calibrated before measurements."
        subject instrument : ISEInstrument;
        require instrument.controller.currentState == "Calibrated" or instrument.controller.currentState == "Ready";
    }
    requirement def NernstSlopeRequirement {
        doc "Calibration slope shall be within acceptable range of theoretical value."
        attribute minSlope : SlopeFactor := 54.0;
        attribute maxSlope : SlopeFactor := 60.0;
        subject calculator : CalculatorUnit;
        require calculator.calibrationData.slope >= minSlope and calculator.calibrationData.slope <= maxSlope;
    }
    requirement def NoiseRejectionRequirement {
        doc "Signal processor shall reduce noise below threshold."
        attribute maxNoise : Voltage := 0.0001;
        subject processor : SignalProcessor;
        require processor.noiseFloor <= maxNoise;
    }
    requirement def MaintenanceRequirement {
        doc "System shall enter maintenance when drift exceeds threshold."
        attribute driftThreshold : DriftIndicator := 0.05;
        subject instrument : ISEInstrument;
        require instrument.controller.currentState == "Maintenance" when driftDetected == true;
    }
}
