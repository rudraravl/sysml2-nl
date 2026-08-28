package ISESystem {
    private import ScalarValues::*;

    package Definitions {
        attribute def Voltage :> ScalarValues::Real;
        attribute def Concentration :> ScalarValues::Real;
        attribute def Temperature :> ScalarValues::Real;

        item def Ion {
            attribute name : String;
        }
        item def Solution {
            ref item targetIon : Ion;
            attribute concentration : Concentration;
        }
        item def KnownSolution :> Solution;

        attribute def CalibrationData {
            attribute slope : Voltage;
            attribute intercept : Voltage;
            attribute refTemp : Temperature;
        }

        item def SelfCheckComplete;
        item def CalibrationComplete;
        item def StartMeasurement;
        item def SignalStable;
        item def CalculationComplete;
        item def DriftDetected;
        item def MaintenanceComplete;

        port def VoltageOutPort {
            out voltage : Voltage;
        }
        port def VoltageInPort {
            in voltage : Voltage;
        }
        port def ConcentrationOutPort {
            out concentration : Concentration;
        }
        port def CommandInPort {
            in command : String;
        }

        part def SelectiveMembrane {
            attribute targetIon : String;
            port potentialOut : VoltageOutPort;
        }
        part def ReferenceElectrode {
            port potentialOut : VoltageOutPort;
        }
        part def ElectrodeAssembly {
            ref item sampleSolution : Solution;
            part selectiveMembrane : SelectiveMembrane;
            part referenceElectrode : ReferenceElectrode;
            port membranePort : VoltageOutPort;
            port referencePort : VoltageOutPort;
            connect selectiveMembrane.potentialOut to membranePort;
            connect referenceElectrode.potentialOut to referencePort;
        }
        part def PotentialMeter {
            port membraneIn : VoltageInPort;
            port referenceIn : VoltageInPort;
            port rawOut : VoltageOutPort;
            attribute measuredDiff : Voltage;
        }
        part def SignalProcessor {
            port rawIn : VoltageInPort;
            port processedOut : VoltageOutPort;
            attribute gain : Real = 1000.0;
        }
        part def CalculatorUnit {
            port voltageIn : VoltageInPort;
            port concentrationOut : ConcentrationOutPort;
            attribute calibrationData : CalibrationData;
        }

        action def SelfCheck {
            out status : Boolean;
        }
        action def RunCalibration {
            in knownSolution : KnownSolution;
            out calibrationData : CalibrationData;
        }
        action def Stabilize {
            in rawVoltage : Voltage;
            out stableVoltage : Voltage;
        }
        action def CalculateConcentration {
            in processedVoltage : Voltage;
            in calibrationData : CalibrationData;
            out concentration : Concentration;
        }
        action def Clean;

        state def ISEBehavior {
            entry; then initialization;

            state initialization;
            transition init_to_calib
                first initialization
                accept SelfCheckComplete
                then calibration;

            state calibration;
            transition calib_to_ready
                first calibration
                accept CalibrationComplete
                then ready;

            state ready;
            transition ready_to_stabilizing
                first ready
                accept StartMeasurement
                then stabilizing;
            transition ready_to_maintenance
                first ready
                accept DriftDetected
                then maintenance;

            state stabilizing;
            transition stab_to_calculating
                first stabilizing
                accept SignalStable
                then calculating;
            transition stab_to_maintenance
                first stabilizing
                accept DriftDetected
                then maintenance;

            state calculating;
            transition calc_to_ready
                first calculating
                accept CalculationComplete
                then ready;
            transition calc_to_maintenance
                first calculating
                accept DriftDetected
                then maintenance;

            state maintenance;
            transition maint_to_init
                first maintenance
                accept MaintenanceComplete
                then initialization;
        }

        requirement def MeasurementAccuracy {
            attribute maxError : Concentration;
            attribute measuredConcentration : Concentration;
            attribute expectedConcentration : Concentration;
            doc /* The measured ion concentration shall be within maxError of the expected concentration. */
            require constraint {
                measuredConcentration <= expectedConcentration + maxError &&
                measuredConcentration >= expectedConcentration - maxError
            }
        }
        requirement def NernstEquationRequirement {
            attribute temperature : Temperature;
            attribute slope : Voltage;
            attribute intercept : Voltage;
            doc /* The calculator unit shall apply the Nernst equation to convert processed voltage to ion concentration. */
        }
        requirement def CalibrationRequirement {
            doc /* The system shall be calibrated against known concentration standards before measurement. */
        }
        requirement def DriftDetectionRequirement {
            attribute driftThreshold : Voltage;
            doc /* The system shall detect signal drift exceeding threshold and enter maintenance. */
        }

        part def ISESystem {
            part electrodeAssembly : ElectrodeAssembly;
            part potentialMeter : PotentialMeter;
            part signalProcessor : SignalProcessor;
            part calculatorUnit : CalculatorUnit;

            port cmdPort : CommandInPort;
            port resultPort : ConcentrationOutPort;

            attribute calibrationData : CalibrationData;
            attribute driftThreshold : Voltage;
            attribute measuredConcentration : Concentration;

            perform action selfCheck : SelfCheck;
            perform action runCalibration : RunCalibration;
            perform action stabilize : Stabilize;
            perform action calculateConcentration : CalculateConcentration;
            perform action clean : Clean;

            exhibit state systemBehavior : ISEBehavior;

            connect electrodeAssembly.membranePort to potentialMeter.membraneIn;
            connect electrodeAssembly.referencePort to potentialMeter.referenceIn;
            connect potentialMeter.rawOut to signalProcessor.rawIn;
            connect signalProcessor.processedOut to calculatorUnit.voltageIn;
            connect calculatorUnit.concentrationOut to resultPort;
        }
    }

    import Definitions::*;

    package Usages {
        private import Definitions::*;

        part iseInstrument : ISESystem {
            :>> electrodeAssembly {
                :>> selectiveMembrane {
                    :>> targetIon = "Na+";
                }
            }
            :>> driftThreshold = 0.005;
        }

        requirement measurementAccuracy : MeasurementAccuracy {
            :>> maxError = 0.5;
            :>> expectedConcentration = 100.0;
            :>> measuredConcentration = iseInstrument.measuredConcentration;
        }

        requirement nernstEquation : NernstEquationRequirement {
            :>> temperature = 298.15;
            :>> slope = 0.05916;
            :>> intercept = 0.0;
        }

        requirement systemCalibration : CalibrationRequirement;

        requirement driftDetection : DriftDetectionRequirement {
            :>> driftThreshold = 0.005;
        }
    }
}
