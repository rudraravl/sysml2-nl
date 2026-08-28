package PET_Imaging_System {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;

    package Definitions {
        attribute def EnergyValue :> Real;
        attribute def TimeValue :> Real;
        attribute def LengthValue :> Real;
        attribute def ActivityValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def MassValue :> Real;
        attribute def CoincidenceWindowValue :> Real;
        attribute def CountsValue :> Integer;
        attribute def EfficiencyValue :> Real;

        attribute def Position3D {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
        }

        attribute def DetectorIdentifier {
            attribute ringIndex : Integer;
            attribute blockIndex : Integer;
            attribute crystalIndex : Integer;
        }

        attribute def ScanEvent;
        attribute def PatientReadyEvent :> ScanEvent;
        attribute def TracerPreparedEvent :> ScanEvent;
        attribute def InjectionCompleteEvent :> ScanEvent;
        attribute def UptakeCompleteEvent :> ScanEvent;
        attribute def ScanCompleteEvent :> ScanEvent;
        attribute def ImageReadyEvent :> ScanEvent;
        attribute def AnalysisCompleteEvent :> ScanEvent;
        attribute def ResetEvent :> ScanEvent;

        item def Radiopharmaceutical {
            attribute isotopeName : String;
            attribute activity : ActivityValue;
            attribute volume : VolumeValue;
            attribute halfLife : TimeValue;
        }

        item def GammaPhoton {
            attribute energy : EnergyValue;
            attribute origin : Position3D;
        }

        item def LightFlash {
            attribute intensity : Real;
            attribute wavelength : LengthValue;
        }

        item def ElectricalSignal {
            attribute amplitude : Real;
            attribute timestamp : TimeValue;
            attribute detectorId : DetectorIdentifier;
        }

        item def CoincidenceEvent {
            attribute signal1 : ElectricalSignal;
            attribute signal2 : ElectricalSignal;
            attribute detector1Pos : Position3D;
            attribute detector2Pos : Position3D;
            attribute timestamp : TimeValue;
        }

        item def Sinogram {
            attribute projectionData : CountsValue[0..*];
            attribute numberOfProjections : Integer;
            attribute numberOfBins : Integer;
            attribute scanDuration : TimeValue;
        }

        item def PETImage {
            attribute voxelData : Real[0..*];
            attribute xDimension : Integer;
            attribute yDimension : Integer;
            attribute zDimension : Integer;
            attribute voxelSize : LengthValue;
            attribute attenuationCorrected : Boolean;
        }

        item def DiagnosisReport {
            attribute findings : String;
            attribute measuredSUV : Real;
            attribute regionOfInterest : String;
        }

        port def TracerPort {
            out item tracer : Radiopharmaceutical;
        }
        port def PhotonPort {
            out item photon : GammaPhoton;
        }
        port def LightPort {
            out item light : LightFlash;
        }
        port def SignalPort {
            out item signal : ElectricalSignal;
        }
        port def EventPort {
            out item coincidenceEvent : CoincidenceEvent;
        }
        port def SinogramPort {
            out item sinogram : Sinogram;
        }
        port def ImagePort {
            out item image : PETImage;
        }
        port def ReportPort {
            out item report : DiagnosisReport;
        }

        action def AdministerTracer {
            in tracer : Radiopharmaceutical;
            out administeredTracer : Radiopharmaceutical;
        }

        action def AccumulateTracer {
            in tracer : Radiopharmaceutical;
            out photons : GammaPhoton[0..*];
            attribute uptakeDuration : TimeValue;
        }

        action def DetectPhoton {
            in photon : GammaPhoton;
            out light : LightFlash;
        }

        action def ConvertLight {
            in light : LightFlash;
            out signal : ElectricalSignal;
        }

        action def DetectPhotons {
            in photons : GammaPhoton[0..*];
            out signals : ElectricalSignal[0..*];
        }

        action def DetectCoincidences {
            in signals : ElectricalSignal[0..*];
            out coincidenceEvents : CoincidenceEvent[0..*];
            attribute window : CoincidenceWindowValue;
        }

        action def AcquireData {
            in coincidenceEvents : CoincidenceEvent[0..*];
            out sinogram : Sinogram;
            attribute acquisitionDuration : TimeValue;
        }

        action def ReconstructImage {
            in sinogram : Sinogram;
            out image : PETImage;
            attribute applyAttenuationCorrection : Boolean;
        }

        action def AnalyzeImage {
            in image : PETImage;
            out report : DiagnosisReport;
        }

        action def PETScanWorkflow {
            in tracer : Radiopharmaceutical;
            out image : PETImage;
            out report : DiagnosisReport;
        }

        state def PETScanStateMachine {
            state idle;
            state preparing;
            state injecting;
            state uptake;
            state scanning;
            state reconstructing;
            state analyzing;
            state complete;
            transition from idle to preparing accept patientReady : PatientReadyEvent;
            transition from preparing to injecting accept tracerPrepared : TracerPreparedEvent;
            transition from injecting to uptake accept injectionComplete : InjectionCompleteEvent;
            transition from uptake to scanning accept uptakeComplete : UptakeCompleteEvent;
            transition from scanning to reconstructing accept scanComplete : ScanCompleteEvent;
            transition from reconstructing to analyzing accept imageReady : ImageReadyEvent;
            transition from analyzing to complete accept analysisComplete : AnalysisCompleteEvent;
            transition from complete to idle accept reset : ResetEvent;
        }

        part def InjectionSystem {
            port tracerOut : TracerPort;
            attribute administeredActivity : ActivityValue;
            attribute injectionVolume : VolumeValue;
            item loadedDose : Radiopharmaceutical;
            perform action administer : AdministerTracer {
                in tracer = loadedDose;
                out administeredTracer = tracerOut.tracer;
            }
        }

        part def Patient {
            port tracerIn : ~TracerPort;
            port photonOut : PhotonPort;
            attribute weight : MassValue;
            attribute uptakeDuration : TimeValue;
            item administeredTracer : Radiopharmaceutical;
            perform action accumulate : AccumulateTracer {
                in tracer = tracerIn.tracer;
                out photons = photonOut.photon;
            }
        }

        part def PatientTable {
            attribute currentPosition : LengthValue;
            attribute maxTravelRange : LengthValue;
        }

        part def ScintillationCrystal {
            port photonIn : ~PhotonPort;
            port lightOut : LightPort;
            attribute material : String;
            attribute thickness : LengthValue;
            perform action detect : DetectPhoton {
                in photon = photonIn.photon;
                out light = lightOut.light;
            }
        }

        part def PhotomultiplierTube {
            port lightIn : ~LightPort;
            port signalOut : SignalPort;
            attribute gain : Real;
            perform action convert : ConvertLight {
                in light = lightIn.light;
                out signal = signalOut.signal;
            }
        }

        part def DetectorBlock {
            port photonIn : ~PhotonPort;
            port signalOut : SignalPort;
            part crystals : ScintillationCrystal[4..*];
            part pmts : PhotomultiplierTube[4..*];
            flow photonIn.photon to crystals.photonIn.photon;
            flow crystals.lightOut.light to pmts.lightIn.light;
            flow pmts.signalOut.signal to signalOut.signal;
        }

        part def DetectorRing {
            port photonIn : ~PhotonPort;
            port signalOut : SignalPort;
            part blocks : DetectorBlock[8..*];
            attribute ringRadius : LengthValue;
            flow photonIn.photon to blocks.photonIn.photon;
            flow blocks.signalOut.signal to signalOut.signal;
        }

        part def GantryAssembly {
            port photonIn : ~PhotonPort;
            port signalOut : SignalPort;
            part rings : DetectorRing[1..*];
            attribute boreDiameter : LengthValue = 700;
            attribute numberOfRings : Integer = 24;
            flow photonIn.photon to rings.photonIn.photon;
            flow rings.signalOut.signal to signalOut.signal;
            perform action detectPhotons : DetectPhotons {
                in photons = photonIn.photon;
                out signals = signalOut.signal;
            }
        }

        part def CoincidenceDetectionUnit {
            port signalIn : ~SignalPort;
            port eventOut : EventPort;
            attribute coincidenceWindow : CoincidenceWindowValue = 6.0;
            perform action detectCoincidences : DetectCoincidences {
                in signals = signalIn.signal;
                out coincidenceEvents = eventOut.coincidenceEvent;
                attribute window = coincidenceWindow;
            }
        }

        part def DataAcquisitionSystem {
            port eventIn : ~EventPort;
            port sinogramOut : SinogramPort;
            attribute acquisitionTime : TimeValue;
            perform action acquireData : AcquireData {
                in coincidenceEvents = eventIn.coincidenceEvent;
                out sinogram = sinogramOut.sinogram;
            }
        }

        part def ImageReconstructionUnit {
            port sinogramIn : ~SinogramPort;
            port imageOut : ImagePort;
            perform action reconstructImage : ReconstructImage {
                in sinogram = sinogramIn.sinogram;
                out image = imageOut.image;
                attribute applyAttenuationCorrection = true;
            }
        }

        part def OperatorWorkstation {
            port imageIn : ~ImagePort;
            port reportOut : ReportPort;
            perform action analyzeImage : AnalyzeImage {
                in image = imageIn.image;
                out report = reportOut.report;
            }
        }

        part def PETScanner {
            part injectionSystem : InjectionSystem;
            part patient : Patient;
            part patientTable : PatientTable;
            part gantry : GantryAssembly;
            part coincidenceUnit : CoincidenceDetectionUnit;
            part dataAcquisition : DataAcquisitionSystem;
            part reconstructionUnit : ImageReconstructionUnit;
            part workstation : OperatorWorkstation;

            flow injectionSystem.tracerOut.tracer to patient.tracerIn.tracer;
            flow patient.photonOut.photon to gantry.photonIn.photon;
            flow gantry.signalOut.signal to coincidenceUnit.signalIn.signal;
            flow coincidenceUnit.eventOut.coincidenceEvent to dataAcquisition.eventIn.coincidenceEvent;
            flow dataAcquisition.sinogramOut.sinogram to reconstructionUnit.sinogramIn.sinogram;
            flow reconstructionUnit.imageOut.image to workstation.imageIn.image;

            state scanStates : PETScanStateMachine;
        }

        requirement def CoincidenceTimingRequirement {
            doc /* The PET system shall detect coincident photon pairs within a specified timing window. */
            attribute maxCoincidenceWindow : CoincidenceWindowValue;
            require { maxCoincidenceWindow <= 12.0; }
        }

        requirement def ImageResolutionRequirement {
            doc /* The reconstructed 3D image shall meet minimum spatial resolution specifications. */
            attribute requiredVoxelSize : LengthValue;
            require { requiredVoxelSize <= 4.0; }
        }

        requirement def AttenuationCorrectionRequirement {
            doc /* Image reconstruction shall apply correction for photon attenuation within the patient body. */
            attribute attenuationCorrectionApplied : Boolean;
            require { attenuationCorrectionApplied == true; }
        }

        requirement def TracerSafetyRequirement {
            doc /* The administered radiopharmaceutical activity shall not exceed the maximum safe dose. */
            attribute maxSafeActivity : ActivityValue;
            require { maxSafeActivity <= 740.0; }
        }

        requirement def DetectionEfficiencyRequirement {
            doc /* The detector crystals shall achieve minimum detection efficiency for 511 keV gamma photons. */
            attribute minDetectionEfficiency : Real;
            require { minDetectionEfficiency >= 0.70; }
        }
    }

    package Usages {
        private import Definitions::*;

        requirement coincidenceTimingReq : CoincidenceTimingRequirement {
            attribute maxCoincidenceWindow = 6.0;
        }
        requirement imageResolutionReq : ImageResolutionRequirement {
            attribute requiredVoxelSize = 2.0;
        }
        requirement attenuationCorrectionReq : AttenuationCorrectionRequirement {
            attribute attenuationCorrectionApplied = true;
        }
        requirement tracerSafetyReq : TracerSafetyRequirement {
            attribute maxSafeActivity = 740.0;
        }
        requirement detectionEfficiencyReq : DetectionEfficiencyRequirement {
            attribute minDetectionEfficiency = 0.85;
        }

        part petScanner : PETScanner {
            attribute scannerId : String = "PET-001";
        }

        satisfy coincidenceTimingReq by petScanner.coincidenceUnit;
        satisfy imageResolutionReq by petScanner.reconstructionUnit;
        satisfy attenuationCorrectionReq by petScanner.reconstructionUnit;
        satisfy tracerSafetyReq by petScanner.injectionSystem;
        satisfy detectionEfficiencyReq by petScanner.gantry;

        action petScanWorkflow : PETScanWorkflow {
            in tracer : Radiopharmaceutical;
            out image : PETImage;
            out report : DiagnosisReport;

            action administer : AdministerTracer {
                in tracer = petScanWorkflow::tracer;
            }
            action accumulate : AccumulateTracer;
            action detect : DetectPhotons;
            action coincide : DetectCoincidences;
            action acquire : AcquireData;
            action reconstruct : ReconstructImage {
                out image = petScanWorkflow::image;
            }
            action analyze : AnalyzeImage {
                out report = petScanWorkflow::report;
            }

            flow administer.administeredTracer to accumulate.tracer;
            flow accumulate.photons to detect.photons;
            flow detect.signals to coincide.signals;
            flow coincide.coincidenceEvents to acquire.coincidenceEvents;
            flow acquire.sinogram to reconstruct.sinogram;
            flow reconstruct.image to analyze.image;

            first start;
            then administer;
            then accumulate;
            then detect;
            then coincide;
            then acquire;
            then reconstruct;
            then analyze;
            then done;
        }
    }
}
