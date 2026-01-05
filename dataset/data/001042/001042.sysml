package 'EDS_System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package ValueDefinitions {
        attribute def ElectronEnergy :> ISQ::EnergyValue;
        attribute def XRayEnergy :> ISQ::EnergyValue;
        attribute def AcceleratingVoltage :> Real;
        attribute def BeamCurrent :> Real;
        attribute def CountRate :> Real;
        attribute def AtomicNumber :> Integer;
        attribute def ConcentrationPercent :> Real;
        
        attribute def BeamParameters {
            attribute voltage : AcceleratingVoltage;
            attribute current : BeamCurrent;
            attribute energy : ElectronEnergy;
        }
        
        attribute def XRayPhoton {
            attribute energy : XRayEnergy;
            attribute intensity : CountRate;
        }
        
        attribute def SpectrumData {
            attribute energyChannels : XRayEnergy[*] ordered;
            attribute intensityCounts : CountRate[*] ordered;
            attribute acquisitionTime : Real;
        }
        
        attribute def ElementIdentification {
            attribute elementSymbol : String;
            attribute atomicNumber : AtomicNumber;
            attribute characteristicEnergy : XRayEnergy;
            attribute concentration : ConcentrationPercent;
        }
    }
    
    package ComponentDefinitions {
        import ValueDefinitions::*;
        
        port def ElectronBeamPort {
            out beamParams : BeamParameters;
        }
        
        port def XRayEmissionPort {
            out xRayPhotons : XRayPhoton[*];
        }
        
        port def DetectorSignalPort {
            in xRayInput : XRayPhoton[*];
            out rawSpectrum : SpectrumData;
        }
        
        port def ProcessedDataPort {
            in spectrum : SpectrumData;
            out elementalData : ElementIdentification[*];
        }
        
        part def ElectronGun {
            attribute operatingVoltage : AcceleratingVoltage;
            attribute emissionCurrent : BeamCurrent;
            attribute focusedBeamDiameter : Real;
            port beamOutput : ElectronBeamPort;
        }
        
        part def SampleChamber {
            attribute vacuumPressure : Real;
            attribute samplePosition : Real[3];
            port beamInput : ~ElectronBeamPort;
            port xRayOutput : XRayEmissionPort;
        }
        
        part def SiliconDriftDetector {
            attribute activeArea : Real;
            attribute energyResolution : XRayEnergy;
            attribute detectionEfficiency : Real;
            attribute maxCountRate : CountRate;
            port xRayInput : ~XRayEmissionPort;
            port signalOutput : DetectorSignalPort;
        }
        
        part def DigitalSignalProcessor {
            attribute processingSpeed : CountRate;
            attribute deadTimeCorrection : Boolean;
            port signalInput : ~DetectorSignalPort;
            port dataOutput : ProcessedDataPort;
        }
        
        part def AnalysisWorkstation {
            attribute quantificationMethod : String;
            attribute calibrationStandards : String[*];
            port dataInput : ~ProcessedDataPort;
        }
    }
    
    package ActionDefinitions {
        import ValueDefinitions::*;
        
        action def GenerateElectronBeam {
            in voltage : AcceleratingVoltage;
            in current : BeamCurrent;
            out electronBeam : BeamParameters;
        }
        
        action def BombardSample {
            in electronBeam : BeamParameters;
            out characteristicXRays : XRayPhoton[*];
            out continuumXRays : XRayPhoton[*];
        }
        
        action def DetectXRayPhotons {
            in xRayPhotons : XRayPhoton[*];
            out pulseSignals : SpectrumData;
        }
        
        action def ProcessSignals {
            in rawPulses : SpectrumData;
            out calibratedSpectrum : SpectrumData;
        }
        
        action def IdentifyPeaks {
            in spectrum : SpectrumData;
            out peakEnergies : XRayEnergy[*];
            out peakIntensities : CountRate[*];
        }
        
        action def DetermineElements {
            in peakEnergies : XRayEnergy[*];
            out identifiedElements : ElementIdentification[*];
        }
        
        action def QuantifyComposition {
            in spectrum : SpectrumData;
            in elements : ElementIdentification[*];
            out quantifiedComposition : ElementIdentification[*];
        }
        
        action def PerformEDSAnalysis {
            in acceleratingVoltage : AcceleratingVoltage;
            in beamCurrent : BeamCurrent;
            in acquisitionTime : Real;
            out elementalComposition : ElementIdentification[*];
            
            first start;
            then action generateBeam : GenerateElectronBeam {
                in voltage = acceleratingVoltage;
                in current = beamCurrent;
                out electronBeam : BeamParameters;
            }
            flow generateBeam.electronBeam to bombardSample.electronBeam;
            then action bombardSample : BombardSample {
                in electronBeam : BeamParameters;
                out characteristicXRays : XRayPhoton[*];
                out continuumXRays : XRayPhoton[*];
            }
            flow bombardSample.characteristicXRays to detectPhotons.xRayPhotons;
            then action detectPhotons : DetectXRayPhotons {
                in xRayPhotons : XRayPhoton[*];
                out pulseSignals : SpectrumData;
            }
            flow detectPhotons.pulseSignals to processSignals.rawPulses;
            then action processSignals : ProcessSignals {
                in rawPulses : SpectrumData;
                out calibratedSpectrum : SpectrumData;
            }
            flow processSignals.calibratedSpectrum to identifyPeaks.spectrum;
            then action identifyPeaks : IdentifyPeaks {
                in spectrum : SpectrumData;
                out peakEnergies : XRayEnergy[*];
                out peakIntensities : CountRate[*];
            }
            flow identifyPeaks.peakEnergies to determineElements.peakEnergies;
            then action determineElements : DetermineElements {
                in peakEnergies : XRayEnergy[*];
                out identifiedElements : ElementIdentification[*];
            }
            flow processSignals.calibratedSpectrum to quantifyComposition.spectrum;
            flow determineElements.identifiedElements to quantifyComposition.elements;
            then action quantifyComposition : QuantifyComposition {
                in spectrum : SpectrumData;
                in elements : ElementIdentification[*];
                out quantifiedComposition : ElementIdentification[*];
            }
            then done;
            
            bind quantifyComposition.quantifiedComposition = elementalComposition;
        }
    }
    
    package StateDefinitions {
        import ValueDefinitions::*;
        
        state def EDSOperationalStates {
            entry; then standby;
            
            state standby;
            
            transition standby_to_setup
                first standby
                accept SetupCommand
                then setup;
            
            state setup {
                entry; then configuringBeam;
                
                state configuringBeam;
                transition beam_to_detector
                    first configuringBeam
                    then configuringDetector;
                
                state configuringDetector;
            }
            
            transition setup_to_acquiring
                first setup
                accept StartAcquisition
                then acquiring;
            
            state acquiring {
                entry; then beamOn;
                
                state beamOn;
                
                state collectingPhotons;
                
                transition beam_to_collecting
                    first beamOn
                    then collectingPhotons;
            }
            
            transition acquiring_to_processing
                first acquiring
                accept AcquisitionComplete
                then processing;
            
            state processing {
                entry; then calibrating;
                
                state calibrating;
                transition calibrating_to_identifying
                    first calibrating
                    then identifying;
                
                state identifying;
                transition identifying_to_quantifying
                    first identifying
                    then quantifying;
                
                state quantifying;
            }
            
            transition processing_to_complete
                first processing
                then analysisComplete;
            
            state analysisComplete;
            
            transition complete_to_standby
                first analysisComplete
                accept ResetCommand
                then standby;
            
            transition any_to_error
                first standby
                accept ErrorDetected
                then error;
            
            state error;
            
            transition error_to_standby
                first error
                accept ErrorCleared
                then standby;
        }
    }
    
    package SystemRequirements {
        import ComponentDefinitions::*;
        import ValueDefinitions::*;
        
        requirement def EDSSystemRequirements;
        
        requirement <'REQ-EDS-001'> primaryFunction : EDSSystemRequirements {
            doc /* The EDS system shall determine the elemental composition 
                 * of a sample by analyzing characteristic X-ray photons emitted 
                 * when the sample is bombarded with a focused electron beam.
                 */
            subject system : EDSInstrument;
        }
        
        requirement <'REQ-EDS-002'> energyRange : EDSSystemRequirements {
            doc /* The system shall detect and measure X-ray energies 
                 * from 0.1 keV to 20 keV with sufficient resolution 
                 * to distinguish characteristic peaks.
                 */
            subject detector : SiliconDriftDetector;
            assert constraint {
                detector.energyResolution <= 130.0
            }
        }
        
        requirement <'REQ-EDS-003'> elementalCoverage : EDSSystemRequirements {
            doc /* The system shall identify elements from Beryllium (Z=4) 
                 * through Uranium (Z=92) based on their characteristic 
                 * X-ray emission lines.
                 */
            subject system : EDSInstrument;
        }
        
        requirement <'REQ-EDS-004'> quantificationAccuracy : EDSSystemRequirements {
            doc /* The system shall quantify elemental concentrations 
                 * with a relative accuracy of ±5% for major elements 
                 * (>10 wt%) under standard operating conditions.
                 */
            subject workstation : AnalysisWorkstation;
        }
        
        requirement <'REQ-EDS-005'> spatialResolution : EDSSystemRequirements {
            doc /* The system shall achieve spatial resolution better than 
                 * 1 micrometer for elemental mapping applications.
                 */
            subject gun : ElectronGun;
            assert constraint {
                gun.focusedBeamDiameter <= 1.0e-6
            }
        }
        
        requirement <'REQ-EDS-006'> countRate : EDSSystemRequirements {
            doc /* The detector and processing system shall handle 
                 * count rates up to 500,000 counts per second 
                 * with dead time correction.
                 */
            subject detector : SiliconDriftDetector;
            assert constraint {
                detector.maxCountRate >= 500000.0
            }
        }
        
        requirement <'REQ-EDS-007'> vacuumEnvironment : EDSSystemRequirements {
            doc /* The sample chamber shall maintain a vacuum pressure 
                 * below 1e-4 Pa to minimize X-ray absorption and 
                 * electron scattering.
                 */
            subject chamber : SampleChamber;
            assert constraint {
                chamber.vacuumPressure <= 1.0e-4
            }
        }
    }
    
    package SystemArchitecture {
        import ComponentDefinitions::*;
        import ActionDefinitions::*;
        import StateDefinitions::*;
        import ValueDefinitions::*;
        import SystemRequirements::*;
        
        part def EDSInstrument {
            attribute instrumentName : String = "Energy-Dispersive X-ray Spectrometer";
            
            part electronGun : ElectronGun {
                attribute operatingVoltage = 20000.0;
                attribute emissionCurrent = 1.0e-9;
                attribute focusedBeamDiameter = 5.0e-7;
            }
            
            part sampleChamber : SampleChamber {
                attribute vacuumPressure = 5.0e-5;
                attribute samplePosition = (0.0, 0.0, 0.0);
            }
            
            part detector : SiliconDriftDetector {
                attribute activeArea = 30.0e-6;
                attribute energyResolution = 125.0;
                attribute detectionEfficiency = 0.95;
                attribute maxCountRate = 500000.0;
            }
            
            part signalProcessor : DigitalSignalProcessor {
                attribute processingSpeed = 500000.0;
                attribute deadTimeCorrection = true;
            }
            
            part workstation : AnalysisWorkstation {
                attribute quantificationMethod = "ZAF Correction";
                attribute calibrationStandards = ("Cu", "Si", "Al");
            }
            
            connection beamPath : ElectronBeamPort
                connect electronGun.beamOutput to sampleChamber.beamInput;
            
            connection xRayPath : XRayEmissionPort
                connect sampleChamber.xRayOutput to detector.xRayInput;
            
            connection detectorSignal : DetectorSignalPort
                connect detector.signalOutput to signalProcessor.signalInput;
            
            connection processedData : ProcessedDataPort
                connect signalProcessor.dataOutput to workstation.dataInput;
            
            perform action edsAnalysis : PerformEDSAnalysis {
                in acceleratingVoltage = electronGun.operatingVoltage;
                in beamCurrent = electronGun.emissionCurrent;
                in acquisitionTime = 60.0;
                out elementalComposition : ElementIdentification[*];
            }
            
            exhibit state operationalStates : EDSOperationalStates;
        }
        
        part edsInstrument : EDSInstrument;
        
        satisfy primaryFunction by edsInstrument;
        satisfy energyRange by edsInstrument.detector;
        satisfy elementalCoverage by edsInstrument;
        satisfy quantificationAccuracy by edsInstrument.workstation;
        satisfy spatialResolution by edsInstrument.electronGun;
        satisfy countRate by edsInstrument.detector;
        satisfy vacuumEnvironment by edsInstrument.sampleChamber;
    }
}
