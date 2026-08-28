package LungCounterSystem {
    import ScalarValues::*;
    
    attribute def Count :> Integer;
    attribute def Becquerel :> Real;
    attribute def ElectronVolt :> Real;
    attribute def Second :> Real;
    attribute def Centimeter :> Real;
    
    item def GammaPhoton {
        attribute energy : ElectronVolt;
    }
    
    item def ElectricalPulse {
        attribute amplitude : Real;
        attribute timestamp : Second;
    }
    
    item def EnergySpectrum {
        attribute channelCount : Integer;
        attribute binCounts : Count[*];
    }
    
    item def Nuclide {
        attribute name : String;
        attribute characteristicEnergy : ElectronVolt;
    }
    
    item def AnalysisResult {
        attribute totalRadiationCounts : Count;
        attribute calculatedActivity : Becquerel;
        attribute detectedMaterials : Nuclide[*];
        attribute timestamp : Second;
    }
    
    enum def OperatorCommand {
        START;
        ABORT;
    }
    
    port def PhotonOutPort {
        out photon : GammaPhoton;
    }
    
    port def PhotonInPort {
        in photon : GammaPhoton;
    }
    
    port def PulseOutPort {
        out pulse : ElectricalPulse;
    }
    
    port def PulseInPort {
        in pulse : ElectricalPulse;
    }
    
    port def SpectrumOutPort {
        out spectrum : EnergySpectrum;
    }
    
    port def SpectrumInPort {
        in spectrum : EnergySpectrum;
    }
    
    port def ResultOutPort {
        out result : AnalysisResult;
    }
    
    port def ResultInPort {
        in result : AnalysisResult;
    }
    
    port def CommandOutPort {
        out cmd : OperatorCommand;
    }
    
    port def CommandInPort {
        in cmd : OperatorCommand;
    }
    
    part def Patient {
        port lungRadiation : PhotonOutPort;
    }
    
    part def PositioningChair {
        attribute isAdjustable : Boolean = true;
        attribute isPositioned : Boolean = false;
        attribute currentHeight : Centimeter;
        attribute backAngle : Real;
        
        action adjustPosition {
            in targetHeight : Centimeter;
            in targetAngle : Real;
            out success : Boolean;
        }
    }
    
    part def ScintillationDetector {
        port photonIn : PhotonInPort;
        port pulseOut : PulseOutPort;
        attribute detectionEfficiency : Real;
        
        action detectPhoton {
            in photon : GammaPhoton;
            out pulse : ElectricalPulse;
        }
    }
    
    part def DetectorArray {
        port photonIn : PhotonInPort;
        port pulseOut : PulseOutPort;
        part detectors : ScintillationDetector[4];
        connect photonIn to detectors.photonIn;
        connect detectors.pulseOut to pulseOut;
    }
    
    part def LeadShielding {
        attribute material : String = "Lead";
        attribute thickness : Centimeter;
        attribute backgroundReductionFactor : Real;
        
        part chair : PositioningChair;
        part patient : Patient;
        part detectorArray : DetectorArray;
        
        connect patient.lungRadiation to detectorArray.photonIn;
    }
    
    part def MultiChannelAnalyzer {
        port pulseIn : PulseInPort;
        port spectrumOut : SpectrumOutPort;
        
        attribute currentSpectrum : EnergySpectrum;
        attribute acquisitionComplete : Boolean = false;
        attribute acquisitionTime : Second;
        
        action acquireSpectrum {
            in pulses : ElectricalPulse[*];
            in duration : Second;
            out spectrum : EnergySpectrum;
            
            action sortPulsesByEnergy;
            action countPulses;
        }
    }
    
    part def AnalysisComputer {
        port spectrumIn : SpectrumInPort;
        port resultOut : ResultOutPort;
        
        attribute backgroundSpectrum : EnergySpectrum;
        attribute calibrationFactors : Real[*];
        attribute nuclideLibrary : Nuclide[*];
        attribute analysisComplete : Boolean = false;
        
        action analyzeSpectrum {
            in subjectSpectrum : EnergySpectrum;
            in background : EnergySpectrum;
            in calFactors : Real[*];
            in library : Nuclide[*];
            out result : AnalysisResult;
            
            action subtractBackground {
                in subjectSpectrum;
                in background;
                out netSpectrum : EnergySpectrum;
            }
            action identifyPeaks {
                in netSpectrum;
                in library;
                out detectedNuclides : Nuclide[*];
            }
            action calculateActivity {
                in netSpectrum;
                in detectedNuclides;
                in calFactors;
                out totalRadiationCounts : Count;
                out calculatedActivity : Becquerel;
            }
        }
    }
    
    part def DisplayConsole {
        port resultIn : ResultInPort;
        port cmdOut : CommandOutPort;
        
        attribute displayComplete : Boolean = false;
        
        action displayResults {
            in result : AnalysisResult;
        }
        action getOperatorCommand {
            out cmd : OperatorCommand;
        }
    }
    
    part def LungCounterSystem {
        port sysCmdIn : CommandInPort;
        
        part shielding : LeadShielding;
        part mca : MultiChannelAnalyzer;
        part computer : AnalysisComputer;
        part console : DisplayConsole;
        
        connect shielding.detectorArray.pulseOut to mca.pulseIn;
        connect mca.spectrumOut to computer.spectrumIn;
        connect computer.resultOut to console.resultIn;
        connect console.cmdOut to sysCmdIn;
        
        state machine : SystemBehavior {
            state idle;
            state positioningSubject;
            state acquiringBackground;
            state acquiringSubject;
            state analyzingData;
            state reportingResults;
            
            transition idle -> positioningSubject on sysCmdIn;
            transition positioningSubject -> acquiringBackground when shielding.chair.isPositioned == true;
            transition acquiringBackground -> acquiringSubject when mca.acquisitionComplete == true;
            transition acquiringSubject -> analyzingData when mca.acquisitionComplete == true;
            transition analyzingData -> reportingResults when computer.analysisComplete == true;
            transition reportingResults -> idle when console.displayComplete == true;
        }
    }
    
    requirement def LungCounterSystemRequirements {
        subject system : LungCounterSystem;
        
        requirement ProvideShielding {
            constraint { system.shielding.backgroundReductionFactor > 0.95 }
        }
        
        requirement PositionPatient {
            constraint { system.shielding.chair.isPositioned == true }
        }
        
        requirement AcquireData {
            constraint { system.mca.acquisitionComplete == true }
        }
        
        requirement AnalyzeData {
            constraint { system.computer.analysisComplete == true }
        }
        
        requirement ReportResults {
            constraint { system.console.displayComplete == true }
        }
    }
}
