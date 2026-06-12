package ISFET_pH_Measurement_System {

    import ScalarValues::*;
    import SI::*;

    item def HydrogenIonActivity {
        attribute pH : Real;
        attribute activity : Real;
    }

    item def ElectrolyteSample {
        attribute temperature : Real;
        attribute volume : Real;
        attribute ionicStrength : Real;
        attribute hydrogenIonActivity : HydrogenIonActivity;
    }

    item def GateSurfacePotential {
        attribute voltage : Real;
        attribute temperature : Real;
    }

    item def DrainSourceCurrent {
        attribute current : Real;
        attribute voltageBias : Real;
    }

    item def MeasuredPH {
        attribute pH : Real;
        attribute confidence : Real;
        attribute temperatureCompensated : Boolean;
    }

    item def CalibrationSolution {
        attribute knownPH : Real;
        attribute temperature : Real;
    }

    item def DiagnosticStatus {
        attribute sensorReady : Boolean;
        attribute referenceElectrodeStable : Boolean;
        attribute calibrationValid : Boolean;
        attribute faultCode : String;
    }

    value def Volt :> SI::Unit {
        symbol = "V";
    }

    value def MilliVolt :> SI::Unit {
        symbol = "mV";
    }

    value def Ampere :> SI::Unit {
        symbol = "A";
    }

    value def MicroAmpere :> SI::Unit {
        symbol = "uA";
    }

    value def Celsius :> SI::Unit {
        symbol = "degC";
    }

    value def Milliliter :> SI::Unit {
        symbol = "mL";
    }

    value def Second :> SI::Unit {
        symbol = "s";
    }

    value def PHUnit :> SI::Unit {
        symbol = "pH";
    }

    port def FluidPort {
        in item sample : ElectrolyteSample;
    }

    port def ElectricalBiasPort {
        out attribute drainVoltage : Real;
        out attribute sourceVoltage : Real;
        out attribute referenceVoltage : Real;
        in item drainSourceCurrent : DrainSourceCurrent;
    }

    port def SurfacePotentialPort {
        in item hydrogenIonActivity : HydrogenIonActivity;
        out item gateSurfacePotential : GateSurfacePotential;
    }

    port def SignalPort {
        out item signal : DrainSourceCurrent;
    }

    port def DigitalPHPort {
        out item measuredPH : MeasuredPH;
        out item diagnosticStatus : DiagnosticStatus;
    }

    port def CalibrationPort {
        in item calibrationSolution : CalibrationSolution;
        out attribute calibrationAccepted : Boolean;
    }

    part def ISFETChip {
        attribute gateInsulatorMaterial : String = "silicon nitride";
        attribute sensingArea : Real;
        attribute thresholdVoltageAtPH7 : Real;
        attribute sensitivity : Real;
        attribute drainSourceBias : Real;
        attribute operatingTemperature : Real;

        port fluidInterface : FluidPort;
        port biasInterface : ElectricalBiasPort;
        port surfaceInterface : SurfacePotentialPort;
        port signalOutput : SignalPort;

        action senseIonActivity {
            in item sample : ElectrolyteSample;
            out item surfacePotential : GateSurfacePotential;

            first start;
            then calculatePotential;
            then emitPotential;
            then done;

            action calculatePotential {
                in item h : HydrogenIonActivity;
                out item potential : GateSurfacePotential;
            }
        }

        action transducePotentialToCurrent {
            in item surfacePotential : GateSurfacePotential;
            out item drainCurrent : DrainSourceCurrent;

            first biasChannel;
            then modulateThreshold;
            then measureCurrent;
            then done;
        }
    }

    part def ReferenceElectrode {
        attribute electrodeMaterial : String = "Ag/AgCl";
        attribute referencePotential : Real;
        attribute junctionResistance : Real;
        attribute stable : Boolean;

        port fluidInterface : FluidPort;
        port biasInterface : ElectricalBiasPort;

        action stabilizeReferencePotential {
            in item sample : ElectrolyteSample;
            out attribute stablePotential : Real;

            first wetJunction;
            then settlePotential;
            then reportStability;
            then done;
        }
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Real;
        attribute accuracy : Real;
        attribute responseTime : Real;

        port fluidInterface : FluidPort;

        action measureTemperature {
            in item sample : ElectrolyteSample;
            out attribute temperature : Real;

            first sampleThermalState;
            then filterTemperature;
            then done;
        }
    }

    part def BiasAndReadoutCircuit {
        attribute drainBiasSetpoint : Real = 0.100;
        attribute sourceBiasSetpoint : Real = 0.000;
        attribute referenceBiasSetpoint : Real = 0.000;
        attribute transimpedanceGain : Real;
        attribute adcResolutionBits : Integer = 16;
        attribute sampleRate : Real;

        port biasOutput : ElectricalBiasPort;
        port analogInput : SignalPort;
        port digitalOutput : DigitalPHPort;

        action applyBiasAndAcquireCurrent {
            out attribute drainVoltage : Real;
            out attribute sourceVoltage : Real;
            out attribute referenceVoltage : Real;
            in item drainSourceCurrent : DrainSourceCurrent;
            out item conditionedSignal : DrainSourceCurrent;

            first applyStableBias;
            then acquireCurrent;
            then lowPassFilter;
            then digitize;
            then done;
        }
    }

    part def PHComputationUnit {
        attribute calibrationSlope : Real;
        attribute calibrationOffset : Real;
        attribute temperatureCoefficient : Real = 0.1984;
        attribute lastCalibrationAge : Real;
        attribute validPHMinimum : Real = 0.0;
        attribute validPHMaximum : Real = 14.0;

        port signalInput : SignalPort;
        port resultOutput : DigitalPHPort;
        port calibrationInput : CalibrationPort;

        action calculatePH {
            in item drainCurrent : DrainSourceCurrent;
            in attribute temperature : Real;
            out item measuredPH : MeasuredPH;

            first validateSignalRange;
            then convertCurrentToGateVoltage;
            then applyCalibrationCurve;
            then compensateTemperature;
            then boundPHRange;
            then publishPH;
            then done;
        }

        action calibrateTwoPoint {
            in item lowPHBuffer : CalibrationSolution;
            in item highPHBuffer : CalibrationSolution;
            out attribute calibrationAccepted : Boolean;

            first acquireLowPoint;
            then rinseAndStabilize;
            then acquireHighPoint;
            then computeSlopeAndOffset;
            then verifySlopeLimits;
            then storeCalibration;
            then done;
        }
    }

    part def SampleCell {
        attribute minimumSampleVolume : Real = 0.250;
        attribute wettedMaterial : String = "PEEK";
        attribute flowThrough : Boolean = true;

        port sampleInlet : FluidPort;
        port isfetContact : FluidPort;
        port referenceContact : FluidPort;
        port temperatureContact : FluidPort;

        action presentSampleToSensors {
            in item sample : ElectrolyteSample;
            out item conditionedSample : ElectrolyteSample;

            first fillCell;
            then removeAirBubbles;
            then wetGateSurface;
            then stabilizeFluid;
            then done;
        }
    }

    part def UserInterface {
        attribute displayedPH : Real;
        attribute displayedTemperature : Real;
        attribute alarmActive : Boolean;

        port measurementInput : DigitalPHPort;

        action displayMeasurement {
            in item measuredPH : MeasuredPH;
            in item status : DiagnosticStatus;

            first updateNumericDisplay;
            then updateStatusIndicators;
            then raiseAlarmIfFaulted;
            then done;
        }
    }

    part def ISFETPHAnalyzer {
        attribute primaryFunction : String = "Convert hydrogen ion activity at an ISFET gate surface into a temperature-compensated digital pH measurement.";
        attribute measurementRangeMinimum : Real = 0.0;
        attribute measurementRangeMaximum : Real = 14.0;
        attribute measurementAccuracy : Real = 0.05;
        attribute measurementUpdatePeriod : Real = 1.0;

        port sampleInput : FluidPort;
        port calibrationInput : CalibrationPort;
        port phOutput : DigitalPHPort;

        part sampleCell : SampleCell {
            attribute minimumSampleVolume = 0.250;
        }

        part isfet : ISFETChip {
            attribute sensingArea = 1.0;
            attribute thresholdVoltageAtPH7 = 0.750;
            attribute sensitivity = 58.0;
            attribute drainSourceBias = 0.100;
            attribute operatingTemperature = 25.0;
        }

        part referenceElectrode : ReferenceElectrode {
            attribute referencePotential = 0.000;
            attribute junctionResistance = 10000.0;
            attribute stable = false;
        }

        part temperatureSensor : TemperatureSensor {
            attribute accuracy = 0.2;
            attribute responseTime = 2.0;
        }

        part readoutCircuit : BiasAndReadoutCircuit {
            attribute transimpedanceGain = 1000000.0;
            attribute sampleRate = 10.0;
        }

        part phComputer : PHComputationUnit {
            attribute calibrationSlope = -58.0;
            attribute calibrationOffset = 7.0;
            attribute lastCalibrationAge = 0.0;
        }

        part userInterface : UserInterface;

        connection sampleToCell connect sampleInput to sampleCell.sampleInlet;
        connection cellToISFET connect sampleCell.isfetContact to isfet.fluidInterface;
        connection cellToReference connect sampleCell.referenceContact to referenceElectrode.fluidInterface;
        connection cellToTemperature connect sampleCell.temperatureContact to temperatureSensor.fluidInterface;
        connection biasToISFET connect readoutCircuit.biasOutput to isfet.biasInterface;
        connection biasToReference connect readoutCircuit.biasOutput to referenceElectrode.biasInterface;
        connection isfetSignalToReadout connect isfet.signalOutput to readoutCircuit.analogInput;
        connection readoutToPHComputer connect readoutCircuit.digitalOutput to phComputer.resultOutput;
        connection calibrationToComputer connect calibrationInput to phComputer.calibrationInput;
        connection phComputerToOutput connect phComputer.resultOutput to phOutput;
        connection outputToDisplay connect phOutput to userInterface.measurementInput;

        state def MeasurementStateMachine {
            state off;
            state initializing;
            state waitingForSample;
            state stabilizingReference;
            state measuring;
            state computingPH;
            state reporting;
            state calibrating;
            state faulted;

            transition powerOn first off then initializing;
            transition initialized first initializing then waitingForSample;
            transition sampleDetected first waitingForSample then stabilizingReference;
            transition referenceStable first stabilizingReference then measuring;
            transition currentAcquired first measuring then computingPH;
            transition phComputed first computingPH then reporting;
            transition nextCycle first reporting then waitingForSample;
            transition calibrationRequested first waitingForSample then calibrating;
            transition calibrationComplete first calibrating then waitingForSample;
            transition signalInvalid first measuring then faulted;
            transition referenceUnstable first stabilizingReference then faulted;
            transition resetFault first faulted then initializing;
        }

        action performMeasurementCycle {
            in item sample : ElectrolyteSample;
            out item measuredPH : MeasuredPH;
            out item status : DiagnosticStatus;

            first acceptSample;
            then presentSample;
            then stabilizeReference;
            then biasISFET;
            then senseHydrogenIonActivity;
            then acquireDrainSourceCurrent;
            then measureTemperature;
            then computeTemperatureCompensatedPH;
            then publishMeasurement;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall determine the pH of an electrolyte sample by using an ion-sensitive field-effect transistor whose gate surface potential changes with hydrogen ion activity. */
        subject analyzer : ISFETPHAnalyzer;
        require constraint {
            analyzer.primaryFunction == "Convert hydrogen ion activity at an ISFET gate surface into a temperature-compensated digital pH measurement."
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The analyzer shall report pH values from 0.0 pH to 14.0 pH. */
        subject analyzer : ISFETPHAnalyzer;
        require constraint {
            analyzer.measurementRangeMinimum <= 0.0 and analyzer.measurementRangeMaximum >= 14.0
        }
    }

    requirement def AccuracyRequirement {
        doc /* The analyzer shall provide pH accuracy of 0.05 pH or better after valid two-point calibration. */
        subject analyzer : ISFETPHAnalyzer;
        require constraint {
            analyzer.measurementAccuracy <= 0.05
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc /* The analyzer shall compensate the ISFET response for sample temperature before publishing pH. */
        subject computer : PHComputationUnit;
        require constraint {
            computer.temperatureCoefficient > 0.0
        }
    }

    requirement def ReferenceElectrodeRequirement {
        doc /* The analyzer shall maintain a stable liquid reference potential for the ISFET gate bias during measurement. */
        subject electrode : ReferenceElectrode;
        require constraint {
            electrode.junctionResistance < 50000.0
        }
    }

    requirement def SampleVolumeRequirement {
        doc /* The sample cell shall operate with no more than 0.250 mL of electrolyte sample. */
        subject cell : SampleCell;
        require constraint {
            cell.minimumSampleVolume <= 0.250
        }
    }

    requirement def UpdateRateRequirement {
        doc /* The analyzer shall publish a new pH result at least once per second during continuous measurement. */
        subject analyzer : ISFETPHAnalyzer;
        require constraint {
            analyzer.measurementUpdatePeriod <= 1.0
        }
    }

    satisfy PrimaryFunctionSatisfaction by ISFETPHAnalyzer;
    satisfy MeasurementRangeSatisfaction by ISFETPHAnalyzer;
    satisfy AccuracySatisfaction by ISFETPHAnalyzer;
    satisfy TemperatureCompensationSatisfaction by PHComputationUnit;
    satisfy ReferenceElectrodeSatisfaction by ReferenceElectrode;
    satisfy SampleVolumeSatisfaction by SampleCell;
    satisfy UpdateRateSatisfaction by ISFETPHAnalyzer;
}