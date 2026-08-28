package PETImagingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ============ Value Types ============
    value type ActivityValue :> Real { unit "Bq"; }
    value type EnergyValue :> Real { unit "keV"; }
    value type TimeValue :> Real { unit "ns"; }
    value type DurationValue :> Real { unit "s"; }
    value type DistanceValue :> Real { unit "mm"; }
    value type VoltageValue :> Real { unit "mV"; }
    value type CountValue :> Integer;
    value type AngleValue :> Real { unit "deg"; }
    value type MassValue :> Real { unit "kg"; }

    // ============ Item Definitions ============
    item def Radiopharmaceutical {
        attribute isotope : String;
        attribute molecule : String;
        attribute halfLife : DurationValue;
        attribute activity : ActivityValue;
    }

    item def Positron {
        attribute energy : EnergyValue;
    }

    item def Electron;

    item def GammaPhoton {
        attribute energy : EnergyValue := 511;
        attribute emissionAngle : AngleValue;
    }

    item def LightFlash {
        attribute intensity : Real;
        attribute wavelength : DistanceValue;
    }

    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute timestamp : TimeValue;
        attribute detectorId : String;
        attribute energyReading : EnergyValue;
    }

    item def CoincidenceEvent {
        attribute signal1 : ElectricalSignal;
        attribute signal2 : ElectricalSignal;
        attribute timeDifference : TimeValue;
        attribute lineOfResponseId : String;
        attribute isTrue : Boolean;
    }

    item def Sinogram {
        attribute binData : CountValue[0..*];
        attribute projectionAngles : AngleValue[0..*];
        attribute radialPositions : DistanceValue[0..*];
        attribute sliceCount : Integer;
    }

    item def ReconstructedImage {
        attribute voxelData : Real[0..*];
        attribute dimensions : Integer[3];
        attribute voxelSize : DistanceValue;
        attribute attenuationCorrected : Boolean;
        attribute tracerConcentration : ActivityValue;
    }

    item def DiagnosticReport {
        attribute findings : String;
        attribute metabolicMeasurements : Real[0..*];
        attribute regionOfInterest : String;
        attribute diagnosis : String;
    }

    // ============ Port Definitions ============
    port def RadiopharmaceuticalOutPort {
        out radiopharmaceutical : Radiopharmaceutical;
    }

    port def RadiopharmaceuticalInPort {
        in radiopharmaceutical : Radiopharmaceutical;
    }

    port def GammaPhotonOutPort {
        out gammaPhoton : GammaPhoton;
    }

    port def GammaPhotonInPort {
        in gammaPhoton : GammaPhoton;
    }

    port def LightOutPort {
        out lightFlash : LightFlash;
    }

    port def LightInPort {
        in lightFlash : LightFlash;
    }

    port def SignalOutPort {
        out signal : ElectricalSignal;
    }

    port def SignalInPort {
        in signal : ElectricalSignal;
    }

    port def CoincidenceOutPort {
        out coincidenceEvent : CoincidenceEvent;
    }

    port def CoincidenceInPort {
        in coincidenceEvent : CoincidenceEvent;
    }

    port def SinogramOutPort {
        out sinogram : Sinogram;
    }

    port def SinogramInPort {
        in sinogram : Sinogram;
    }

    port def ImageOutPort {
        out image : ReconstructedImage;
    }

    port def ImageInPort {
        in image : ReconstructedImage;
    }

    port def ReportOutPort {
        out report : DiagnosticReport;
    }

    // ============ Part Definitions ============

    part def Patient {
        attribute weight : MassValue;
        attribute metabolicRate : Real;
        attribute injectedActivity : ActivityValue;
        port tracerIn : RadiopharmaceuticalInPort;
        port gammaOut : GammaPhotonOutPort;

        action def PositronEmission {
            in tracer : Radiopharmaceutical;
            out positron : Positron;
        }

        action def PositronAnnihilation {
            in positron : Positron;
            in electron : Electron;
            out gammaPair : GammaPhoton[2];
        }
    }

    part def ScintillationCrystal {
        attribute material : String := "LSO";
        attribute length : DistanceValue;
        attribute width : DistanceValue;
        attribute depth : DistanceValue;
        port gammaIn : GammaPhotonInPort;
        port lightOut : LightOutPort;

        action def ConvertGammaToLight {
            in gamma : GammaPhoton;
            out flash : LightFlash;
        }
    }

    part def PhotomultiplierTube {
        attribute gain : Real;
        attribute darkCurrent : VoltageValue;
        port lightIn : LightInPort;
        port signalOut : SignalOutPort;

        action def ConvertLightToSignal {
            in flash : LightFlash;
            out signal : ElectricalSignal;
        }
    }

    part def DetectorBlock {
        attribute blockId : String;
        part crystals : ScintillationCrystal[4..*];
        part pmts : PhotomultiplierTube[4..*];
        port gammaIn : GammaPhotonInPort;
        port signalOut : SignalOutPort;

        connection gammaToCrystals connect gammaIn to crystals.gammaIn;
        connection crystalToPmt connect crystals.lightOut to pmts.lightIn;
        connection pmtToOutput connect pmts.signalOut to signalOut;
    }

    part def DetectorRing {
        attribute ringId : String;
        attribute ringRadius : DistanceValue;
        part blocks : DetectorBlock[0..*];
        port gammaIn : GammaPhotonInPort;
        port signalOut : SignalOutPort;

        connection gammaToBlocks connect gammaIn to blocks.gammaIn;
        connection blockToOutput connect blocks.signalOut to signalOut;
    }

    part def GantryAssembly {
        attribute boreDiameter : DistanceValue;
        attribute ringCount : Integer;
        part detectorRings : DetectorRing[1..*];
        port gammaIn : GammaPhotonInPort;
        port signalOut : SignalOutPort;

        connection gammaToRings connect gammaIn to detectorRings.gammaIn;
        connection ringToOutput connect detectorRings.signalOut to signalOut;
    }

    part def PatientTable {
        attribute position : DistanceValue;
        attribute maxLoad : MassValue;
        attribute velocity : Real;

        action def MovePatient {
            in targetPosition : DistanceValue;
            out newPosition : DistanceValue;
        }
    }

    part def InjectionSystem {
        attribute dose : ActivityValue;
        attribute radiopharmaceutical : Radiopharmaceutical;
        port tracerOut : RadiopharmaceuticalOutPort;

        action def AdministerTracer {
            in tracer : Radiopharmaceutical;
            out administeredDose : ActivityValue;
        }
    }

    part def CoincidenceDetectionUnit {
        attribute coincidenceWindow : TimeValue := 6;
        attribute lowerEnergyThreshold : EnergyValue := 350;
        attribute upperEnergyThreshold : EnergyValue := 650;
        port signalIn : SignalInPort;
        port eventOut : CoincidenceOutPort;

        action def DetectCoincidence {
            in signals : ElectricalSignal[0..*];
            out events : CoincidenceEvent[0..*];

            action filterByEnergy {
                in inputSignals : ElectricalSignal[0..*];
                out acceptedSignals : ElectricalSignal[0..*];
            }
            action filterRandoms {
                in inputSignals : ElectricalSignal[0..*];
                out filteredSignals : ElectricalSignal[0..*];
            }
            action matchPairs {
                in filteredSignals : ElectricalSignal[0..*];
                out coincidenceEvents : CoincidenceEvent[0..*];
            }

            flow signals -> filterByEnergy.inputSignals;
            flow filterByEnergy.acceptedSignals -> filterRandoms.inputSignals;
            flow filterRandoms.filteredSignals -> matchPairs.filteredSignals;
            flow matchPairs.coincidenceEvents -> events;
        }
    }

    part def DataAcquisitionSystem {
        attribute acquisitionMode : String := "list";
        port eventIn : CoincidenceInPort;
        port sinogramOut : SinogramOutPort;

        action def AcquireData {
            in events : CoincidenceEvent[0..*];
            out sinogram : Sinogram;

            action binEvents {
                in coincidenceEvents : CoincidenceEvent[0..*];
                out binnedData : CountValue[0..*];
                out projectionAngles : AngleValue[0..*];
                out radialPositions : DistanceValue[0..*];
            }
            action organizeSinogram {
                in binnedData : CountValue[0..*];
                in projectionAngles : AngleValue[0..*];
                in radialPositions : DistanceValue[0..*];
                out organizedSinogram : Sinogram;
            }

            flow events -> binEvents.coincidenceEvents;
            flow binEvents.binnedData -> organizeSinogram.binnedData;
            flow binEvents.projectionAngles -> organizeSinogram.projectionAngles;
            flow binEvents.radialPositions -> organizeSinogram.radialPositions;
            flow organizeSinogram.organizedSinogram -> sinogram;
        }
    }

    part def ImageReconstructionUnit {
        attribute algorithm : String := "OSEM";
        attribute iterations : Integer := 3;
        attribute subsets : Integer := 21;
        port sinogramIn : SinogramInPort;
        port imageOut : ImageOutPort;

        action def ReconstructImage {
            in sinogram : Sinogram;
            out image : ReconstructedImage;

            action applyAttenuationCorrection {
                in inputSinogram : Sinogram;
                out correctedSinogram : Sinogram;
            }
            action applyScatterCorrection {
                in inputSinogram : Sinogram;
                out correctedSinogram : Sinogram;
            }
            action reconstruct3D {
                in correctedSinogram : Sinogram;
                out rawImage : ReconstructedImage;
            }
            action normalizeImage {
                in rawImage : ReconstructedImage;
                out normalizedImage : ReconstructedImage;
            }

            flow sinogram -> applyAttenuationCorrection.inputSinogram;
            flow applyAttenuationCorrection.correctedSinogram -> applyScatterCorrection.inputSinogram;
            flow applyScatterCorrection.correctedSinogram -> reconstruct3D.correctedSinogram;
            flow reconstruct3D.rawImage -> normalizeImage.rawImage;
            flow normalizeImage.normalizedImage -> image;
        }
    }

    part def OperatorWorkstation {
        attribute displayResolution : Integer;
        attribute softwareVersion : String;
        port imageIn : ImageInPort;
        port reportOut : ReportOutPort;

        action def AnalyzeImage {
            in image : ReconstructedImage;
            out report : DiagnosticReport;

            action viewImage {
                in inputImage : ReconstructedImage;
                out displayedImage : ReconstructedImage;
            }
            action performQuantitativeAnalysis {
                in displayedImage : ReconstructedImage;
                out measurements : Real[0..*];
                out regions : String[0..*];
            }
            action generateReport {
                in measurements : Real[0..*];
                in regions : String[0..*];
                out diagnosticReport : DiagnosticReport;
            }

            flow image -> viewImage.inputImage;
            flow viewImage.displayedImage -> performQuantitativeAnalysis.displayedImage;
            flow performQuantitativeAnalysis.measurements -> generateReport.measurements;
            flow performQuantitativeAnalysis.regions -> generateReport.regions;
            flow generateReport.diagnosticReport -> report;
        }
    }

    // ============ Top-Level PET System ============
    part def PETImagingSystem {
        attribute systemId : String;
        attribute manufacturer : String;
        attribute model : String;

        part injectionSystem : InjectionSystem {
            attribute dose := 370 [MBq];
        }
        part patient : Patient;
        part patientTable : PatientTable;
        part gantry : GantryAssembly {
            attribute boreDiameter := 700 [mm];
        }
        part coincidenceUnit : CoincidenceDetectionUnit;
        part dataAcquisition : DataAcquisitionSystem;
        part reconstructionUnit : ImageReconstructionUnit;
        part workstation : OperatorWorkstation;

        // Inter-component connections
        connection tracerFlow connect injectionSystem.tracerOut to patient.tracerIn;
        connection gammaFlow connect patient.gammaOut to gantry.gammaIn;
        connection signalFlow connect gantry.signalOut to coincidenceUnit.signalIn;
        connection eventFlow connect coincidenceUnit.eventOut to dataAcquisition.eventIn;
        connection sinogramFlow connect dataAcquisition.sinogramOut to reconstructionUnit.sinogramIn;
        connection imageFlow connect reconstructionUnit.imageOut to workstation.imageIn;

        // ============ State Machine ============
        state def PETWorkflow {
            entry; then PoweredOff;

            state PoweredOff {
                entry action powerOffSystem;
                transition powerOn first PoweredOff then Initializing
                    when systemPowerOn == true;
            }

            state Initializing {
                entry action performSelfTest;
                do action calibrateDetectors;
                transition initComplete first Initializing then Ready
                    when selfTestPassed == true;
            }

            state Ready {
                entry action preparePatient;
                do action positionPatientTable;
                transition startInjection first Ready then Injecting
                    when patientReady == true;
            }

            state Injecting {
                entry action administerRadiopharmaceutical;
                do action monitorUptake;
                transition uptakeComplete first Injecting then Scanning
                    after 1800 [s];
            }

            state Scanning {
                entry action startDataAcquisition;
                do action acquireCoincidenceEvents;
                transition scanComplete first Scanning then Reconstructing
                    when eventCount >= 1000000;
            }

            state Reconstructing {
                entry action startImageReconstruction;
                do action applyCorrectionsAndReconstruct;
                transition reconstructionComplete first Reconstructing then Analyzing
                    when reconstructionComplete == true;
            }

            state Analyzing {
                entry action displayReconstructedImage;
                do action performClinicalAnalysis;
                transition analysisComplete first Analyzing then Complete
                    when reportGenerated == true;
            }

            state Complete {
                entry action finalizeStudy;
                transition resetSystem first Complete then PoweredOff;
            }
        }

        attribute systemPowerOn : Boolean := false;
        attribute selfTestPassed : Boolean := false;
        attribute patientReady : Boolean := false;
        attribute eventCount : CountValue := 0;
        attribute reconstructionComplete : Boolean := false;
        attribute reportGenerated : Boolean := false;

        // ============ Top-Level Action ============
        action def PerformPETScan {
            in patientIn : Patient;
            in radiopharmaceutical : Radiopharmaceutical;
            out report : DiagnosticReport;

            action administerTracer {
                in tracer : Radiopharmaceutical;
                out dose : ActivityValue;
            }
            action waitForUptake {
                in dose : ActivityValue;
                out readyPatient : Patient;
            }
            action acquireData {
                in readyPatient : Patient;
                out sinogram : Sinogram;
            }
            action reconstruct {
                in sinogram : Sinogram;
                out image : ReconstructedImage;
            }
            action analyze {
                in image : ReconstructedImage;
                out diagnosticReport : DiagnosticReport;
            }

            flow radiopharmaceutical -> administerTracer.tracer;
            flow administerTracer.dose -> waitForUptake.dose;
            flow waitForUptake.readyPatient -> acquireData.readyPatient;
            flow acquireData.sinogram -> reconstruct.sinogram;
            flow reconstruct.image -> analyze.image;
            flow analyze.diagnosticReport -> report;
        }
    }

    // ============ Requirements ============
    requirement def TracerAdministrationRequirement {
        doc /* The system shall administer a radiopharmaceutical to the patient with a specified activity dose. */
        attribute requiredDose : ActivityValue;
        require requiredDose > 0 [Bq];
    }

    requirement def CoincidenceDetectionRequirement {
        doc /* The system shall detect coincidence events within a specified time window. */
        attribute maxCoincidenceWindow : TimeValue;
        require maxCoincidenceWindow <= 10 [ns];
    }

    requirement def EnergyFilteringRequirement {
        doc /* The system shall filter gamma photons by energy to reject scattered photons. */
        attribute lowerThreshold : EnergyValue;
        attribute upperThreshold : EnergyValue;
        require lowerThreshold >= 350 [keV];
        require upperThreshold <= 650 [keV];
    }

    requirement def ImageResolutionRequirement {
        doc /* The reconstructed image shall have sufficient spatial resolution for clinical diagnosis. */
        attribute maxVoxelSize : DistanceValue;
        require maxVoxelSize <= 4 [mm];
    }

    requirement def AttenuationCorrectionRequirement {
        doc /* The reconstruction unit shall apply attenuation correction to the image data. */
        attribute attenuationCorrected : Boolean;
        require attenuationCorrected == true;
    }

    requirement def UptakePeriodRequirement {
        doc /* The system shall allow a minimum uptake period of 30 minutes after tracer injection. */
        attribute minUptakePeriod : DurationValue;
        require minUptakePeriod >= 1800 [s];
    }

    requirement def DiagnosticOutputRequirement {
        doc /* The system shall produce a diagnostic report with quantitative metabolic measurements. */
        attribute measurementCount : Integer;
        require measurementCount > 0;
    }

    requirement def GantryBoreRequirement {
        doc /* The gantry bore shall accommodate standard patient sizes. */
        attribute minBoreDiameter : DistanceValue;
        require minBoreDiameter >= 700 [mm];
    }

    requirement def DetectorRingRequirement {
        doc /* The gantry shall contain at least one detector ring for 3D imaging. */
        attribute minRingCount : Integer;
        require minRingCount >= 1;
    }

    requirement def DetectorBlockRequirement {
        doc /* Each detector ring shall contain multiple detector blocks. */
        attribute minBlocksPerRing : Integer;
        require minBlocksPerRing >= 1;
    }

    requirement def CrystalRequirement {
        doc /* Each detector block shall contain scintillation crystals coupled with PMTs. */
        attribute minCrystalsPerBlock : Integer;
        attribute minPMTsPerBlock : Integer;
        require minCrystalsPerBlock >= 4;
        require minPMTsPerBlock >= 4;
    }

    requirement def ReconstructionAlgorithmRequirement {
        doc /* The image reconstruction unit shall use an iterative reconstruction algorithm. */
        attribute algorithmType : String;
        require algorithmType == "OSEM";
    }

    requirement def ScanSensitivityRequirement {
        doc /* The system shall acquire a minimum number of coincidence events for a clinically useful image. */
        attribute minEventCount : CountValue;
        require minEventCount >= 1000000;
    }

    // Requirement satisfaction
    part injectionSystemSatisfies : InjectionSystem satisfies TracerAdministrationRequirement {
        attribute requiredDose := 370 [MBq];
    }

    part coincidenceUnitSatisfies : CoincidenceDetectionUnit satisfies CoincidenceDetectionRequirement {
        attribute maxCoincidenceWindow := 6 [ns];
    }

    part gantrySatisfies : GantryAssembly satisfies GantryBoreRequirement {
        attribute minBoreDiameter := 700 [mm];
    }

    part reconstructionSatisfies : ImageReconstructionUnit satisfies ImageResolutionRequirement {
        attribute maxVoxelSize := 2 [mm];
    }
}
