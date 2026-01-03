package 'PET Scanner System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DetectorCount :> Integer;
    attribute def CoincidenceWindow :> ISQ::TimeValue;
    attribute def EnergyThreshold :> ISQ::EnergyValue;
    attribute def SpatialResolution :> ISQ::LengthValue;
    attribute def AxialFOV :> ISQ::LengthValue;
    attribute def ActivityConcentration :> Real;
    
    item def Radiopharmaceutical {
        attribute isotope : String;
        attribute halfLife : ISQ::TimeValue;
        attribute injectedActivity : Real;
        attribute uptakeTime : ISQ::TimeValue;
    }
    
    item def GammaPhoton {
        attribute energy : ISQ::EnergyValue;
        attribute emissionTime : ISQ::TimeValue;
        attribute detectorID : Integer;
        attribute positionX : Real;
        attribute positionY : Real;
        attribute positionZ : Real;
    }
    
    item def CoincidenceEvent {
        attribute photon1 : GammaPhoton;
        attribute photon2 : GammaPhoton;
        attribute timeDifference : ISQ::TimeValue;
        attribute isValid : Boolean;
    }
    
    item def SinogramData {
        attribute radialBins : Integer;
        attribute angularBins : Integer;
    }
    
    item def ReconstructedImage {
        attribute voxelSize : ISQ::LengthValue;
        attribute dimX : Integer;
        attribute dimY : Integer;
        attribute dimZ : Integer;
        attribute acquisitionDuration : ISQ::TimeValue;
    }
    
    port def TracerPort {
        out item tracer : Radiopharmaceutical;
    }
    
    port def PhotonDetectionPort {
        out item photon : GammaPhoton;
    }
    
    port def CoincidencePort {
        out item coincidences : CoincidenceEvent;
    }
    
    port def DataPort {
        out item sinogram : SinogramData;
    }
    
    port def ImagePort {
        out item image : ReconstructedImage;
    }
    
    port def DisplayPort {
        in item image : ReconstructedImage;
    }
    
    part def Patient {
        attribute patientID : String;
        attribute bodyMass : ISQ::MassValue;
        attribute metabolicActivity : ActivityConcentration;
        port injectionSite : TracerPort;
    }
    
    part def InjectionSystem {
        attribute dosageCalibrator : Boolean;
        attribute shieldedSyringe : Boolean;
        port tracerOutput : TracerPort;
        
        action administerRadiopharmaceutical {
            in patientMass : ISQ::MassValue;
            in targetActivity : Real;
            out administeredTracer : Radiopharmaceutical;
        }
    }
    
    part def ScintillationCrystal {
        attribute material : String;
        attribute lightYield : Real;
        attribute decayTime : ISQ::TimeValue;
        
        action convertGammaToLight {
            in gammaEnergy : ISQ::EnergyValue;
            out scintillationPhotons : Integer;
        }
    }
    
    part def PhotomultiplierTube {
        attribute gain : Real;
        attribute quantumEfficiency : Real;
        attribute timeResolution : ISQ::TimeValue;
        
        action amplifySignal {
            in lightPhotons : Integer;
            out electricalPulse : Real;
        }
    }
    
    part def DetectorBlock {
        attribute blockID : Integer;
        attribute crystalArray : DetectorCount;
        port photonOutput : PhotonDetectionPort;
        
        part crystals : ScintillationCrystal[64];
        part pmts : PhotomultiplierTube[4];
        
        action detectGammaPhoton {
            in incidentPhoton : ISQ::EnergyValue;
            out detectedEvent : GammaPhoton;
        }
    }
    
    part def DetectorRing {
        attribute ringID : Integer;
        attribute ringDiameter : ISQ::LengthValue;
        attribute blocksPerRing : Integer;
        
        part blocks : DetectorBlock[48];
        
        action collectPhotons {
            out photonStream : GammaPhoton;
        }
    }
    
    part def GantryAssembly {
        attribute numberOfRings : Integer;
        attribute axialCoverage : AxialFOV;
        attribute boreSize : ISQ::LengthValue;
        
        part rings : DetectorRing[4];
        part patientTable;
        
        action positionPatient {
            in targetPosition : ISQ::LengthValue;
        }
    }
    
    part def CoincidenceDetectionUnit {
        attribute coincidenceWindow : CoincidenceWindow;
        port eventInput : CoincidencePort;
        
        action identifyCoincidences {
            out coincidentPairs : CoincidenceEvent;
        }
        
        action validateCoincidence {
            in event : CoincidenceEvent;
            out isValid : Boolean;
        }
        
        action filterScatterAndRandom {
            out trueCoincidences : CoincidenceEvent;
        }
    }
    
    part def DataAcquisitionSystem {
        attribute samplingRate : Real;
        attribute bufferCapacity : Integer;
        port dataOutput : DataPort;
        
        action sortCoincidences {
            out sinogram : SinogramData;
        }
        
        action applyCorrections {
            in rawSinogram : SinogramData;
            out correctedSinogram : SinogramData;
        }
    }
    
    part def ImageReconstructionUnit {
        attribute algorithm : String;
        attribute iterationCount : Integer;
        attribute voxelResolution : SpatialResolution;
        port imageOutput : ImagePort;
        
        action performReconstruction {
            in sinogramData : SinogramData;
            out volumeImage : ReconstructedImage;
        }
        
        action applyAttenuationCorrection {
            in rawImage : ReconstructedImage;
            out correctedImage : ReconstructedImage;
        }
        
        action normalizeActivity {
            in image : ReconstructedImage;
            out normalizedImage : ReconstructedImage;
        }
    }
    
    part def OperatorWorkstation {
        port imageDisplay : DisplayPort;
        
        action displayImage {
            in reconstructedImage : ReconstructedImage;
        }
        
        action performQuantitativeAnalysis {
            in image : ReconstructedImage;
            out suvMean : Real;
            out roiMean : Real;
        }
    }
    
    state def PETScanStateMachine {
        entry; then Idle;
        
        state Idle;
        state PatientPreparation;
        state TracerUptake;
        state DataAcquisition;
        state ImageReconstruction;
        state Analysis;
        state Complete;
        
        transition IdleToPreparation
            first Idle
            accept startScan
            then PatientPreparation;
        
        transition PreparationToUptake
            first PatientPreparation
            accept tracerInjected
            then TracerUptake;
        
        transition UptakeToAcquisition
            first TracerUptake
            accept uptakeComplete
            then DataAcquisition;
        
        transition AcquisitionToReconstruction
            first DataAcquisition
            accept scanComplete
            then ImageReconstruction;
        
        transition ReconstructionToAnalysis
            first ImageReconstruction
            accept imageReady
            then Analysis;
        
        transition AnalysisToComplete
            first Analysis
            accept analysisComplete
            then Complete;
    }
    
    action def PerformPETImaging {
        in radiopharmaceutical : Radiopharmaceutical;
        in scanDuration : ISQ::TimeValue;
        out finalImage : ReconstructedImage;
        
        first start;
        
        then action preparePatient {
            out patientReady : Boolean;
        }
        
        then action injectTracer {
            in tracer : Radiopharmaceutical;
            out injectionComplete : Boolean;
        }
        
        then action waitForUptake {
            in uptakeDuration : ISQ::TimeValue;
        }
        
        then action acquireEmissionData {
            in duration : ISQ::TimeValue;
            out rawPhotonEvents : GammaPhoton;
        }
        
        then action detectCoincidences {
            in photons : GammaPhoton;
            out coincidenceEvents : CoincidenceEvent;
        }
        
        then action generateSinogram {
            in events : CoincidenceEvent;
            out sinogram : SinogramData;
        }
        
        then action reconstructVolume {
            in sinogramData : SinogramData;
            out volumeImage : ReconstructedImage;
        }
        
        then action applyImageCorrections {
            in rawImage : ReconstructedImage;
            out correctedImage : ReconstructedImage;
        }
        
        then assign finalImage := applyImageCorrections.correctedImage;
        
        then done;
    }
    
    part petScanner {
        part patient : Patient;
        part injectionSystem : InjectionSystem;
        part gantry : GantryAssembly;
        part coincidenceUnit : CoincidenceDetectionUnit;
        part dataAcquisition : DataAcquisitionSystem;
        part reconstruction : ImageReconstructionUnit;
        part workstation : OperatorWorkstation;
        
        connect patient.injectionSite to injectionSystem.tracerOutput;
        
        perform action imagingProcedure : PerformPETImaging;
    }
    
    requirement <'PET-REQ-001'> primaryFunctionRequirement {
        doc /* The PET scanner system shall detect pairs of gamma rays emitted 
             indirectly by a positron-emitting radionuclide tracer, which is 
             introduced into the body on a biologically active molecule, to 
             produce three-dimensional images of functional processes in the body. */
        
        subject petScanner;
        
        require constraint detectAnnihilationPhotons {
            doc /* The system shall detect coincident 511 keV gamma photons 
                 resulting from positron-electron annihilation events. */
        }
        
        require constraint reconstructSpatialDistribution {
            doc /* The system shall reconstruct the three-dimensional spatial 
                 distribution of radiotracer concentration from detected 
                 coincidence events. */
        }
        
        require constraint visualizeMetabolicActivity {
            doc /* The system shall produce images that represent metabolic 
                 and functional activity within the patient's body. */
        }
    }
    
    requirement <'PET-REQ-002'> spatialResolutionRequirement {
        doc /* The PET scanner shall achieve spatial resolution of 4 mm or 
             better at the center of the field of view. */
        
        subject petScanner;
    }
    
    requirement <'PET-REQ-003'> temporalResolutionRequirement {
        doc /* The coincidence detection unit shall have a timing resolution 
             of 500 picoseconds or better to accurately identify true 
             coincidence events. */
        
        subject petScanner.coincidenceUnit;
    }
    
    requirement <'PET-REQ-004'> imagingWorkflowRequirement {
        doc /* The system shall execute a complete imaging workflow from 
             radiopharmaceutical administration through image reconstruction 
             and display. */
        
        subject petScanner;
        
        require primaryFunctionRequirement;
        
        satisfy petScanner.imagingProcedure;
    }
    
    requirement <'PET-REQ-005'> sensitivityRequirement {
        doc /* The system shall maintain sufficient detection sensitivity 
             to image low concentrations of radiotracer for accurate 
             quantitative analysis. */
        
        subject petScanner.gantry;
        
        require constraint detectorCoverage {
            doc /* Detector rings shall provide adequate axial and 
                 transaxial coverage. */
        }
    }
}
