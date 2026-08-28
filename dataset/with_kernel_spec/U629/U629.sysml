package CarbonPasteElectrodeSystem {
    private import ScalarValues::*;
    private import Collections::*;
    private import SequenceFunctions::*;
    private import ControlFunctions::*;

    attribute def Voltage :> Real {
        doc /* Electrical potential in volts (V). */
    }

    attribute def Current :> Real {
        doc /* Electrical current in amperes (A). */
    }

    attribute def Concentration :> Real {
        doc /* Molar concentration in moles per liter (mol/L). */
    }

    attribute def ScanRate :> Real {
        doc /* Rate of potential sweep in volts per second (V/s). */
    }

    attribute def Duration :> Real {
        doc /* Time duration in seconds (s). */
    }

    attribute def Area :> Real {
        doc /* Surface area in square centimeters (cm^2). */
    }

    attribute def Volume :> Real {
        doc /* Volume in liters (L). */
    }

    attribute def MassFraction :> Real {
        doc /* Mass fraction of a component in a mixture (dimensionless). */
    }

    item def GraphitePowder {
        doc /* Conductive carbon powder for electrode fabrication. */
        attribute purity : MassFraction;
    }

    item def Binder {
        doc /* Insulating binder material for carbon paste. */
        attribute kind : String;
    }

    item def CarbonPaste {
        doc /* Homogeneous mixture of graphite powder and binder. */
        item graphite : GraphitePowder;
        item binder : Binder;
        attribute graphiteFraction : MassFraction;
        attribute binderFraction : MassFraction;
        assert constraint { graphiteFraction + binderFraction == 1.0 }
    }

    item def Analyte {
        doc /* Electroactive substance whose concentration is measured. */
        attribute name : String;
        attribute concentration : Concentration;
    }

    item def Solution {
        doc /* Liquid sample containing analyte and supporting electrolyte. */
        item analytes : Analyte[0..*];
        attribute volume : Volume;
    }

    attribute def VoltammogramPoint {
        doc /* Single data point: applied potential and measured current. */
        attribute potential : Voltage;
        attribute current : Current;
    }

    attribute def Voltammogram {
        doc /* Ordered collection of voltammogram data points from a potential scan. */
        attribute points : VoltammogramPoint[0..*] ordered;
    }

    port def ElectricalPort {
        doc /* Port for electrical signal between potentiostat and electrode. */
        attribute potential : Voltage;
        attribute current : Current;
    }

    port def ElectrodeSolutionPort {
        doc /* Port representing the electrode-solution interface. */
        ref item solution : Solution;
    }

    part def WorkingElectrode {
        doc /* Carbon paste electrode where electrochemical reactions occur. */
        port solutionInterface : ElectrodeSolutionPort;
        port electricalConnection : ElectricalPort;
        item paste : CarbonPaste;
        attribute surfaceArea : Area;
    }

    part def ReferenceElectrode {
        doc /* Provides a stable reference potential for the measurement. */
        port solutionInterface : ElectrodeSolutionPort;
        port electricalConnection : ElectricalPort;
        attribute referencePotential : Voltage;
    }

    part def CounterElectrode {
        doc /* Completes the electrical circuit through the solution. */
        port solutionInterface : ElectrodeSolutionPort;
        port electricalConnection : ElectricalPort;
    }

    part def ElectrochemicalCell {
        doc /* Container holding the solution sample and three-electrode setup. */
        part workingElectrode : WorkingElectrode;
        part referenceElectrode : ReferenceElectrode;
        part counterElectrode : CounterElectrode;
        item sampleSolution : Solution;

        connection workingToSolution connect workingElectrode.solutionInterface to referenceElectrode.solutionInterface;
        connection counterToSolution connect counterElectrode.solutionInterface to workingElectrode.solutionInterface;
    }

    part def Potentiostat {
        doc /* Electronic instrument that controls electrode potential and measures current. */
        port workingPort : ElectricalPort;
        port referencePort : ElectricalPort;
        port counterPort : ElectricalPort;

        attribute scanStart : Voltage;
        attribute scanEnd : Voltage;
        attribute scanRate : ScanRate;

        action def PerformScan {
            doc /* Sweeps the applied potential and records the current response. */
            in startPotential : Voltage;
            in endPotential : Voltage;
            in rate : ScanRate;
            out voltammogram : Voltammogram;
        }

        action def MeasureCurrent {
            doc /* Measures the current at a given applied potential. */
            in appliedPotential : Voltage;
            out measuredCurrent : Current;
        }
    }

    calc def FindPeakCurrent {
        doc /* Identifies the peak current from a voltammogram. */
        in voltammogram : Voltammogram;
        return peakCurrent : Current;
    }

    calc def CalculateConcentration {
        doc /* Calculates analyte concentration from peak current using calibration sensitivity. */
        in peakCurrent : Current;
        in sensitivity : Real;
        return concentration : Concentration;
    }

    action def ElectrochemicalAnalysis {
        doc /* Overall analysis process from electrode preparation to concentration result. */
        in sample : Solution;
        out result : Concentration;

        action prepareElectrode {
            doc /* Polish and activate the carbon paste electrode surface. */
        }

        action runScan {
            doc /* Sweep potential and record current response. */
            in startPotential : Voltage;
            in endPotential : Voltage;
            in rate : ScanRate;
            out voltammogram : Voltammogram;
        }

        action analyzeData {
            doc /* Extract peak current from the voltammogram. */
            in voltammogram : Voltammogram;
            out peakCurrent : Current;
        }

        action calculateResult {
            doc /* Compute concentration from peak current. */
            in peakCurrent : Current;
            out concentration : Concentration;
        }

        succession first prepareElectrode then runScan;
        succession first runScan then analyzeData;
        succession first analyzeData then calculateResult;
    }

    state def ElectrochemicalAnalysisStates {
        doc /* States of the electrochemical analysis process. */

        entry; then Idle;

        state Idle {
            doc /* System waiting for analysis command. */
        }

        state PreparingElectrode {
            doc /* Carbon paste surface is polished and activated. */
        }

        state RunningScan {
            doc /* Potentiostat sweeps potential and records current. */
        }

        state AnalyzingData {
            doc /* Voltammogram is analyzed to extract peak current. */
        }

        state CalculatingConcentration {
            doc /* Concentration is computed from peak current. */
        }

        transition from Idle to PreparingElectrode;
        transition from PreparingElectrode to RunningScan;
        transition from RunningScan to AnalyzingData;
        transition from AnalyzingData to CalculatingConcentration;
        transition from CalculatingConcentration to Idle;
    }

    requirement def SensitivityRequirement {
        doc /* The system must detect analytes at low concentrations. */
        attribute detectionLimit : Concentration;
        constraint { detectionLimit <= 1e-6 }
    }

    requirement def StabilityRequirement {
        doc /* The system must maintain stable measurements over extended operation. */
        attribute stabilityDuration : Duration;
        attribute driftLimit : Current;
        constraint { driftLimit <= 1e-9 }
    }

    requirement def ReproducibilityRequirement {
        doc /* The system must produce reproducible results across repeated measurements. */
        attribute relativeStandardDeviation : Real;
        constraint { relativeStandardDeviation <= 0.05 }
    }

    requirement def AccuracyRequirement {
        doc /* The calculated concentration shall be within 5 percent of the true value. */
        attribute maxErrorPercent : Real;
        constraint { maxErrorPercent <= 0.05 }
    }

    part def AnalysisSystem {
        doc /* Complete system for quantitative electrochemical analysis using carbon paste electrodes. */

        part potentiostat : Potentiostat {
            attribute scanStart : Voltage = -0.5;
            attribute scanEnd : Voltage = 0.5;
            attribute scanRate : ScanRate = 0.05;
        }

        part cell : ElectrochemicalCell {
            part workingElectrode : WorkingElectrode {
                item paste : CarbonPaste {
                    item graphite : GraphitePowder {
                        attribute purity : MassFraction = 0.99;
                    }
                    item binder : Binder {
                        attribute kind : String = "mineral oil";
                    }
                    attribute graphiteFraction : MassFraction = 0.7;
                    attribute binderFraction : MassFraction = 0.3;
                }
                attribute surfaceArea : Area = 0.07;
            }
            part referenceElectrode : ReferenceElectrode {
                attribute referencePotential : Voltage = 0.0;
            }
            part counterElectrode : CounterElectrode;
            item sampleSolution : Solution {
                item analytes : Analyte[1] {
                    attribute name : String = "target analyte";
                    attribute concentration : Concentration;
                }
            }
        }

        connection workingConnection connect potentiostat.workingPort to cell.workingElectrode.electricalConnection;
        connection referenceConnection connect potentiostat.referencePort to cell.referenceElectrode.electricalConnection;
        connection counterConnection connect potentiostat.counterPort to cell.counterElectrode.electricalConnection;

        requirement sensitivity : SensitivityRequirement {
            attribute detectionLimit : Concentration = 1e-6;
        }

        requirement stability : StabilityRequirement {
            attribute stabilityDuration : Duration = 3600;
            attribute driftLimit : Current = 1e-9;
        }

        requirement reproducibility : ReproducibilityRequirement {
            attribute relativeStandardDeviation : Real = 0.05;
        }

        requirement accuracy : AccuracyRequirement {
            attribute maxErrorPercent : Real = 0.05;
        }

        state analysisStateMachine : ElectrochemicalAnalysisStates;
    }

    analysis def ConcentrationAnalysis {
        doc /* Analysis case to verify concentration measurement capability. */
        subject system : AnalysisSystem;
        objective sensitivity : SensitivityRequirement {
            subject = result;
        }
        objective reproducibility : ReproducibilityRequirement {
            subject = result;
        }

        action measureConcentration : ElectrochemicalAnalysis {
            in sample = system.cell.sampleSolution;
            out result;
        }

        return measureConcentration.result;
    }

    part analysisContext {
        doc /* Context in which the analysis system is subjected to the concentration analysis. */
        part systemUnderTest : AnalysisSystem;
        analysis concentrationAnalysis : ConcentrationAnalysis {
            subject system = systemUnderTest;
        }
    }
}
