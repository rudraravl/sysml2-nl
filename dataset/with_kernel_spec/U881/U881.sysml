package SPECT_System {
    private import ScalarValues::*;
    
    attribute def Energy :> Real;
    attribute def Time :> Real;
    attribute def Angle :> Real;
    attribute def Length :> Real;
    
    item def Radiopharmaceutical;
    item def GammaPhoton {
        attribute energy : Energy;
    }
    item def LightFlash;
    item def ElectricalSignal;
    item def GammaEvt {
        attribute position : Real[2];
        attribute energy : Energy;
        attribute timestamp : Time;
    }
    item def ProjectionData {
        attribute angle : Angle;
        attribute events : GammaEvt[*];
    }
    item def ReconstructedImage {
        attribute voxelSize : Length;
    }
    item def Command;
    item def CalibrateCmd :> Command;
    item def StartScanCmd :> Command;
    item def ResetCmd :> Command;
    item def ScanCompleteEvt;
    
    port def PhotonInPort { in item photon : GammaPhoton; }
    port def PhotonOutPort { out item photon : GammaPhoton; }
    port def LightInPort { in item light : LightFlash; }
    port def LightOutPort { out item light : LightFlash; }
    port def SignalInPort { in item signal : ElectricalSignal; }
    port def SignalOutPort { out item signal : ElectricalSignal; }
    port def EvtInPort { in item gammaEvt : GammaEvt; }
    port def EvtOutPort { out item gammaEvt : GammaEvt; }
    port def ProjectionInPort { in item projection : ProjectionData; }
    port def ProjectionOutPort { out item projection : ProjectionData; }
    port def ImageInPort { in item image : ReconstructedImage; }
    port def ImageOutPort { out item image : ReconstructedImage; }
    port def ControlInPort { in item cmd : Command; }
    port def ControlOutPort { out item cmd : Command; }
    
    part def Patient {
        attribute administeredDrug : Radiopharmaceutical;
        port emissionPort : PhotonOutPort;
    }
    
    part def Collimator {
        port photonIn : PhotonInPort;
        port photonOut : PhotonOutPort;
    }
    
    part def ScintillationCrystal {
        port photonIn : PhotonInPort;
        port lightOut : LightOutPort;
    }
    
    part def PhotomultiplierTube;
    
    part def PMTArray {
        part tube[16] : PhotomultiplierTube;
        port lightIn : LightInPort;
        port signalOut : SignalOutPort;
    }
    
    part def PositionLogicCircuit {
        port signalIn : SignalInPort;
        port evtOut : EvtOutPort;
    }
    
    part def GammaCamera {
        port photonIn : PhotonInPort;
        port evtOut : EvtOutPort;
        
        part collimator : Collimator;
        part crystal : ScintillationCrystal;
        part pmtArray : PMTArray;
        part positionLogic : PositionLogicCircuit;
        
        connect photonIn to collimator.photonIn;
        connect collimator.photonOut to crystal.photonIn;
        connect crystal.lightOut to pmtArray.lightIn;
        connect pmtArray.signalOut to positionLogic.signalIn;
        connect positionLogic.evtOut to evtOut;
    }
    
    part def Gantry {
        attribute currentAngle : Angle;
        part camera[1..*] : GammaCamera;
        port controlIn : ControlInPort;
        perform action rotate {
            out item angle : Angle;
        }
    }
    
    part def EnergyDiscriminator {
        attribute energyWindowMin : Energy;
        attribute energyWindowMax : Energy;
        port evtIn : EvtInPort;
        port evtOut : EvtOutPort;
    }
    
    part def DataAcquisitionSystem {
        port evtIn : EvtInPort;
        port projectionOut : ProjectionOutPort;
        part discriminator : EnergyDiscriminator;
        perform action acquireProjection {
            in item gammaEvt : GammaEvt;
            out item projection : ProjectionData;
        }
        connect evtIn to discriminator.evtIn;
    }
    
    part def ImageReconstructionSystem {
        port projectionIn : ProjectionInPort;
        port imageOut : ImageOutPort;
        attribute algorithm : String;
        perform action reconstruct {
            in item projection : ProjectionData;
            out item image : ReconstructedImage;
        }
    }
    
    part def OperatorConsole {
        port controlIn : ControlInPort;
        port controlOut : ControlOutPort;
        port imageIn : ImageInPort;
        attribute displayResolution : String;
        perform action displayImage {
            in item image : ReconstructedImage;
        }
    }
    
    part def Physician {
        port imageIn : ImageInPort;
    }
    
    part def Technician {
        port controlOut : ControlOutPort;
    }
    
    action def InjectRadiopharmaceutical {
        out item drug : Radiopharmaceutical;
    }
    action def EmitPhoton {
        in item drug : Radiopharmaceutical;
        out item photon : GammaPhoton;
    }
    action def DetectPhoton {
        in item photon : GammaPhoton;
        out item gammaEvt : GammaEvt;
    }
    action def AcquireProjections {
        in item angle : Angle;
        out item projections : ProjectionData[*];
    }
    action def ReconstructImage {
        in item projections : ProjectionData[*];
        out item image : ReconstructedImage;
    }
    action def PerformCalibration;
    action def DisplayImageAction {
        in item image : ReconstructedImage;
    }
    action def PerformScan {
        action acquireProjections : AcquireProjections;
        action reconstructImage : ReconstructImage;
        flow acquireProjections.projections to reconstructImage.projections;
    }
    
    state def SPECTOperationalState {
        entry; then idle;
        state idle;
        state calibrating {
            do action performCalibration : PerformCalibration;
        }
        state activeScanning {
            state acquiring {
                do action acquireProjections : AcquireProjections;
            }
            state reconstructing {
                do action reconstructImage : ReconstructImage;
            }
            transition first acquiring then reconstructing;
        }
        state ready {
            do action displayImage : DisplayImageAction;
        }
        
        transition first idle accept cmd : CalibrateCmd then calibrating;
        transition first calibrating accept cmd : StartScanCmd then activeScanning;
        transition first activeScanning accept evt : ScanCompleteEvt then ready;
        transition first ready accept cmd : ResetCmd then idle;
    }
    
    part def SPECTSystem {
        part gantry : Gantry;
        part daq : DataAcquisitionSystem;
        part irs : ImageReconstructionSystem;
        part console : OperatorConsole;
        
        perform action performScan : PerformScan;
        state operationalState : SPECTOperationalState;
        
        connect gantry.camera.evtOut to daq.evtIn;
        connect daq.projectionOut to irs.projectionIn;
        connect irs.imageOut to console.imageIn;
        connect console.controlOut to gantry.controlIn;
    }
    
    part spectSystem : SPECTSystem {
        part patient : Patient;
        part physician : Physician;
        part technician : Technician;
        
        connect patient.emissionPort to gantry.camera.photonIn;
        connect irs.imageOut to physician.imageIn;
        connect technician.controlOut to console.controlIn;
        
        allocate performScan.acquireProjections to gantry;
        allocate performScan.acquireProjections to daq;
        allocate performScan.reconstructImage to irs;
    }
    
    requirement def SPECTSystemFunction {
        subject spectSystem : SPECTSystem;
        doc /* The SPECT system shall detect gamma photons emitted from a radiopharmaceutical within the patient and reconstruct 3D images showing the drug distribution. */
    }
    
    requirement def GammaDetectionReq {
        subject camera : GammaCamera;
        doc /* Each Gamma Camera shall detect gamma photons through a collimator, scintillation crystal, PMT array, and position logic circuit. */
    }
    
    requirement def EnergyDiscriminationReq {
        subject discriminator : EnergyDiscriminator;
        doc /* The Data Acquisition System shall apply an energy discriminator to accept only photons within a specified energy window. */
    }
    
    requirement def ReconstructionReq {
        subject irs : ImageReconstructionSystem;
        doc /* The Image Reconstruction System shall reconstruct a 3D dataset from multiple 2D projections with attenuation and scatter corrections. */
    }
    
    requirement def StateManagementReq {
        subject spectSystem : SPECTSystem;
        doc /* The system shall operate through distinct states: idle, calibrating, active scanning, and ready. */
    }
    
    requirement def SpatialResolutionReq {
        subject spectSystem : SPECTSystem;
        doc /* Reconstructed image spatial resolution shall be <= 8 mm FWHM. */
        attribute maxFWHM : Length = 8.0;
    }
    
    requirement def EnergyResolutionReq {
        subject spectSystem : SPECTSystem;
        doc /* System energy resolution shall be <= 10% at 140 keV. */
        attribute referenceEnergy : Energy = 140.0;
        attribute maxResolution : Real = 0.10;
    }
    
    requirement spectReq : SPECTSystemFunction;
    requirement gammaDetReq : GammaDetectionReq {
        derivedFrom spectReq;
    }
    requirement energyDiscReq : EnergyDiscriminationReq {
        derivedFrom spectReq;
    }
    requirement reconReq : ReconstructionReq {
        derivedFrom spectReq;
    }
    requirement stateReq : StateManagementReq {
        derivedFrom spectReq;
        satisfiedBy spectSystem.operationalState;
    }
    requirement spatialReq : SpatialResolutionReq {
        derivedFrom spectReq;
    }
    requirement energyResReq : EnergyResolutionReq {
        derivedFrom spectReq;
    }
}
