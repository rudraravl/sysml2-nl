package CarbonPasteElectrodeSystem {
    import ScalarValues::*;

    value def Potential :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Concentration :> Real { unit 'mol/L'; }
    value def ScanRate :> Real { unit 'V/s'; }
    value def MassFraction :> Real { unit '%'; }

    item def GraphitePowder;
    item def Binder;
    item def CarbonPaste {
        item graphite : GraphitePowder;
        item binder : Binder;
        attribute graphiteFraction : MassFraction = 70 [%];
    }
    item def Analyte;
    item def Solution {
        item analytes : Analyte[0..*];
    }
    item def Voltammogram {
        attribute potentials : Potential[0..*];
        attribute currents : Current[0..*];
    }

    port def ElectricalPort {
        out potential : Potential;
        in current : Current;
    }

    requirement def AccurateMeasurement {
        doc /* The system shall accurately measure the concentration of specific electroactive substances. */
        attribute targetAccuracy : Concentration = 0.01 [mol/L];
    }
    requirement def HighSensitivity {
        doc /* The system shall be highly sensitive. */
        attribute minDetectableCurrent : Current = 1e-9 [A];
    }
    requirement def LongTermStability {
        doc /* The system shall provide stable measurements over long periods. */
        attribute maxDriftRate : Potential = 0.001 [V/s];
    }
    requirement def Reproducibility {
        doc /* The system shall provide reproducible results. */
        attribute maxRSD : Real = 0.05;
    }

    action def PerformScan {
        in solution : Solution;
        out concentration : Concentration;
        
        action prepareElectrodeSurface;
        action performVoltageScan {
            out voltammogram : Voltammogram;
        }
        action analyzeRedoxReactions {
            in voltammogram : Voltammogram;
            out analyzedData : Voltammogram;
        }
        action extractPeakData {
            in analyzedData : Voltammogram;
            out peakCurrent : Current;
        }
        action calculateConcentration {
            in peakCurrent : Current;
            out concentration : Concentration;
        }
        
        succession prepareElectrodeSurface then performVoltageScan;
        flow performVoltageScan.voltammogram to analyzeRedoxReactions.voltammogram;
        flow analyzeRedoxReactions.analyzedData to extractPeakData.analyzedData;
        flow extractPeakData.peakCurrent to calculateConcentration.peakCurrent;
    }

    part def Potentiostat {
        port workingPort : ElectricalPort;
        port referencePort : ElectricalPort;
        port counterPort : ElectricalPort;
        
        attribute scanRate : ScanRate = 0.05 [V/s];
        attribute startPotential : Potential = -0.2 [V];
        attribute endPotential : Potential = 0.8 [V];
        
        action performScan : PerformScan;
    }

    part def WorkingElectrode {
        port port : ElectricalPort;
        item paste : CarbonPaste;
    }

    part def ReferenceElectrode {
        port port : ElectricalPort;
        attribute baselinePotential : Potential = 0.0 [V];
    }

    part def CounterElectrode {
        port port : ElectricalPort;
    }

    part def ElectrochemicalCell {
        port workingConnection : ElectricalPort;
        port referenceConnection : ElectricalPort;
        port counterConnection : ElectricalPort;
        
        item sampleSolution : Solution;
        
        part workingElectrode : WorkingElectrode;
        part referenceElectrode : ReferenceElectrode;
        part counterElectrode : CounterElectrode;
        
        connection workingCircuit connect workingConnection to workingElectrode.port;
        connection referenceCircuit connect referenceConnection to referenceElectrode.port;
        connection counterCircuit connect counterConnection to counterElectrode.port;
    }

    part def CarbonPasteElectrodeSystem {
        part potentiostat : Potentiostat;
        part cell : ElectrochemicalCell;
        
        connection w_connect connect potentiostat.workingPort to cell.workingConnection;
        connection r_connect connect potentiostat.referencePort to cell.referenceConnection;
        connection c_connect connect potentiostat.counterPort to cell.counterConnection;
        
        satisfy AccurateMeasurement by potentiostat.performScan.calculateConcentration.concentration;
        satisfy HighSensitivity by potentiostat.performScan.extractPeakData.peakCurrent;
        satisfy LongTermStability by cell.referenceElectrode.baselinePotential;
        satisfy Reproducibility by potentiostat.performScan.calculateConcentration.concentration;
    }
}
