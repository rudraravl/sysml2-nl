package SPECTSystemModel {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value types with units ----
    attribute def EnergyKeV :> Real { 
        attribute unit : String = "keV"; 
    }
    attribute def AngleDeg :> Real { 
        attribute unit : String = "deg"; 
    }
    attribute def TimeS :> Real { 
        attribute unit : String = "s"; 
    }
    attribute def Counts :> Integer;
    attribute def PositionMM :> Real { 
        attribute unit : String = "mm"; 
    }
    attribute def RotationSpeed :> Real { 
        attribute unit : String = "deg/s"; 
    }
    attribute def VoxelValue :> Real {
        attribute unit : String = "counts/voxel";
    }

    // ---- Item definitions ----
    item def GammaPhoton {
        attribute energy : EnergyKeV;
        attribute directionX : Real;
        attribute directionY : Real;
        attribute directionZ : Real;
        attribute isScattered : Boolean;
    }
    item def LightFlash {
        attribute intensity : Real;
        attribute wavelength : Real;
    }
    item def ElectricalSignal {
        attribute amplitude : Real;
        attribute timestamp : TimeS;
        attribute pmtIndex : Integer;
    }
    item def PositionEvent {
        attribute x : PositionMM;
        attribute y : PositionMM;
        attribute energy : EnergyKeV;
        attribute timestamp : TimeS;
    }
    item def ProjectionData {
        attribute angle : AngleDeg;
        attribute events : PositionEvent[0..*];
        attribute acquisitionTime : TimeS;
    }
    item def ReconstructedVolume {
        attribute voxelArray : VoxelValue[0..*];
        attribute dimensionX : Integer;
        attribute dimensionY : Integer;
        attribute dimensionZ : Integer;
    }
    item def ScanProtocol {
        attribute name : String;
        attribute energyCenter : EnergyKeV;
        attribute energyWindowWidth : EnergyKeV;
        attribute rotationSteps : Integer;
        attribute rotationRange : AngleDeg;
        attribute timePerView : TimeS;
    }
    item def CalibrationResult {
        attribute uniformity : Real;
        attribute peakingEnergy : EnergyKeV;
        attribute timestamp : TimeS;
    }
    item def StatusMessage {
        attribute text : String;
        attribute severity : Integer;
    }

    // ---- Port definitions ----
    port def GammaPhotonInPort {
        in item photons : GammaPhoton;
    }
    port def GammaPhotonOutPort {
        out item photons : GammaPhoton;
    }
    port def LightFlowPort {
        out item flashes : LightFlash;
    }
    port def SignalFlowPort {
        out item signals : ElectricalSignal;
    }
    port def EventFlowPort {
        out item events : PositionEvent;
    }
    port def ProjectionFlowPort {
        out item projections : ProjectionData;
    }
    port def VolumeFlowPort {
        out item volume : ReconstructedVolume;
    }
    port def CommandPort {
        in item protocol : ScanProtocol;
        in item startCommand : Boolean;
        in item stopCommand : Boolean;
        out item status : StatusMessage;
    }
    port def DisplayPort {
        out item volume : ReconstructedVolume;
    }

    // ---- Part definitions ----
    part def Collimator {
        attribute holeDiameter : PositionMM;
        attribute holeLength : PositionMM;
        attribute septalThickness : PositionMM;
        port photonIn : GammaPhotonInPort;
        port photonOut : GammaPhotonOutPort;
        
        action def FilterPhotons {
            in photon : GammaPhoton;
            out filtered : GammaPhoton;
        }
        perform FilterPhotons;
    }

    part def ScintillationCrystal {
        attribute material : String = "NaI(Tl)";
        attribute thickness : PositionMM;
        attribute area : Real;
        port lightIn : GammaPhotonInPort;
        port lightOut : LightFlowPort;
        
        action def ConvertGammaToLight {
            in photon : GammaPhoton;
            out flash : LightFlash;
        }
        perform ConvertGammaToLight;
    }

    part def PhotomultiplierTube {
        attribute index : Integer;
        attribute gain : Real;
        port lightIn : LightFlowPort;
        port signalOut : SignalFlowPort;
        
        action def AmplifyLight {
            in flash : LightFlash;
            out signal : ElectricalSignal;
        }
        perform AmplifyLight;
    }

    part def PMTArray {
        attribute tubeCount : Integer;
        port lightIn : LightFlowPort;
        port signalOut : SignalFlowPort;
        part tubes : PhotomultiplierTube[1..*];
    }

    part def PositionLogicCircuit {
        port signalIn : SignalFlowPort;
        port eventOut : EventFlowPort;
        
        action def CalculatePosition {
            in signals : ElectricalSignal[1..*];
            out event : PositionEvent;
        }
        perform CalculatePosition;
    }

    part def GammaCamera {
        attribute cameraId : String;
        port photonIn : GammaPhotonInPort;
        port eventOut : EventFlowPort;
        
        part collimator : Collimator;
        part crystal : ScintillationCrystal;
        part pmtArray : PMTArray;
        part positionLogic : PositionLogicCircuit;
        
        connection collimator.photonOut to crystal.lightIn;
        connection crystal.lightOut to pmtArray.lightIn;
        connection pmtArray.signalOut to positionLogic.signalIn;
    }

    part def Gantry {
        attribute rotationAngle : AngleDeg;
        attribute rotationSpeed : RotationSpeed;
        port cameraMount : GammaPhotonInPort[1..*];
        
        part cameras : GammaCamera[1..*];
        
        action def RotateGantry {
            in targetAngle : AngleDeg;
            out currentAngle : AngleDeg;
        }
        perform RotateGantry;
    }

    part def EnergyDiscriminator {
        attribute centerEnergy : EnergyKeV;
        attribute windowWidth : EnergyKeV;
        port eventIn : EventFlowPort;
        port eventOut : EventFlowPort;
        
        action def DiscriminateEnergy {
            in event : PositionEvent;
            out accepted : PositionEvent;
            decision acceptedEvent {
                if (event.energy >= centerEnergy - windowWidth/2 
                    and event.energy <= centerEnergy + windowWidth/2) 
                then { emit accepted; }
                else { reject; }
            }
        }
        perform DiscriminateEnergy;
    }

    part def DataAcquisitionSystem {
        port eventIn : EventFlowPort;
        port projectionOut : ProjectionFlowPort;
        attribute currentAngle : AngleDeg;
        
        part energyDiscriminator : EnergyDiscriminator;
        
        action def AcquireProjection {
            in angle : AngleDeg;
            in events : PositionEvent[0..*];
            out projection : ProjectionData;
        }
        perform AcquireProjection;
    }

    part def ImageReconstructionSystem {
        attribute algorithm : String;
        attribute attenuationCorrection : Boolean = true;
        attribute scatterCorrection : Boolean = true;
        port projectionIn : ProjectionFlowPort;
        port volumeOut : VolumeFlowPort;
        
        action def ReconstructVolume {
            in projections : ProjectionData[1..*];
            out volume : ReconstructedVolume;
        }
        perform ReconstructVolume;
    }

    part def OperatorConsole {
        port commandOut : CommandPort;
        port displayIn : DisplayPort;
        attribute displayResolution : String;
        
        action def SelectProtocol {
            out protocol : ScanProtocol;
        }
        action def InitiateScan {
            out start : Boolean;
        }
        action def ReviewImage {
            in volume : ReconstructedVolume;
        }
        perform SelectProtocol;
        perform InitiateScan;
        perform ReviewImage;
    }

    part def PatientTable {
        attribute position : PositionMM;
        attribute weightCapacity : Real;
        action def PositionPatient {
            in targetPosition : PositionMM;
            out currentPosition : PositionMM;
        }
        perform PositionPatient;
    }

    // ---- Top-level SPECT system ----
    part def SPECTSystem {
        attribute systemId : String;
        port operatorInterface : CommandPort;
        port imageOutput : DisplayPort;
        
        part gantry : Gantry;
        part dataAcquisition : DataAcquisitionSystem;
        part reconstruction : ImageReconstructionSystem;
        part console : OperatorConsole;
        part patientTable : PatientTable;
        
        connection gantry.cameras.eventOut to dataAcquisition.eventIn;
        connection dataAcquisition.projectionOut to reconstruction.projectionIn;
        connection reconstruction.volumeOut to console.displayIn;
        connection console.commandOut to operatorInterface;
        connection reconstruction.volumeOut to imageOutput;
        
        // State machine governing system operation
        state def SPECTSystemStates {
            entry action { send StatusMessage{text="System initialized", severity=0}; }
            
            state idle {
                entry action { send StatusMessage{text="Idle, awaiting protocol", severity=0}; }
                transition on operatorInterface.startCommand to calibrating;
            }
            
            state calibrating {
                entry action { 
                    send StatusMessage{text="Calibration in progress", severity=0}; 
                }
                do action { 
                    // Perform uniformity and energy peaking calibration
                    gantry.rotationAngle = 0.0;
                }
                transition on operatorInterface.protocol to activeScanning;
            }
            
            state activeScanning {
                entry action { send StatusMessage{text="Scan initiated", severity=0}; }
                
                state acquiring {
                    entry action { send StatusMessage{text="Acquiring projections", severity=0}; }
                    do action {
                        gantry.RotateGantry(targetAngle = operatorInterface.protocol.rotationRange);
                        dataAcquisition.AcquireProjection(
                            angle = gantry.rotationAngle,
                            events = gantry.cameras.eventOut.events
                        );
                    }
                    transition when (gantry.rotationAngle >= operatorInterface.protocol.rotationRange) 
                        to reconstructing;
                }
                
                state reconstructing {
                    entry action { send StatusMessage{text="Reconstructing volume", severity=0}; }
                    do action {
                        reconstruction.ReconstructVolume(
                            projections = dataAcquisition.projectionOut.projections
                        );
                    }
                    transition to ready;
                }
                
                transition acquiring to reconstructing;
                transition reconstructing to ready;
            }
            
            state ready {
                entry action { send StatusMessage{text="Ready for next patient", severity=0}; }
                transition on operatorInterface.startCommand to calibrating;
            }
            
            transition idle to calibrating;
            transition calibrating to activeScanning;
            transition activeScanning to ready;
            transition ready to idle;
        }
        perform SPECTSystemStates;
    }

    // ---- Requirements ----
    requirement def DetectGammaPhotons {
        subject spect : SPECTSystem;
        objective {
            The SPECT system shall detect gamma photons emitted by a radiopharmaceutical 
            within the patient's body from multiple angular positions.
        }
        attribute minDetectionAngles : Integer = 64;
        attribute energyRange : EnergyKeV = 140.0;
    }

    requirement def FilterScatteredPhotons {
        subject collimator : Collimator;
        objective {
            The collimator shall reject scattered gamma photons and only allow photons 
            traveling in a direction parallel to the collimator holes to reach the scintillation crystal.
        }
        attribute maxAcceptanceAngle : AngleDeg = 1.5;
    }

    requirement def ConvertGammaToLight {
        subject crystal : ScintillationCrystal;
        objective {
            The scintillation crystal shall convert incident gamma photons into visible light flashes 
            proportional to the photon energy.
        }
        attribute conversionEfficiency : Real;
    }

    requirement def AmplifyAndPosition {
        subject pmtArray : PMTArray;
        objective {
            The PMT array shall amplify light flashes and the position logic circuit shall compute 
            the (x, y) coordinates of each photon interaction with spatial accuracy.
        }
        attribute spatialResolution : PositionMM = 3.0;
    }

    requirement def EnergyDiscrimination {
        subject discriminator : EnergyDiscriminator;
        objective {
            The energy discriminator shall accept only photon events within a defined energy window 
            centered on the photopeak to reject scatter.
        }
        attribute windowWidth : EnergyKeV = 20.0;
    }

    requirement def Reconstruct3DImage {
        subject reconstruction : ImageReconstructionSystem;
        objective {
            The image reconstruction system shall reconstruct a 3D volumetric dataset from 2D projection 
            data using filtered backprojection or iterative algorithms, applying attenuation and scatter corrections.
        }
        attribute supportedAlgorithms : String = "FBP, OSEM";
    }

    requirement def OperatorControl {
        subject console : OperatorConsole;
        objective {
            The operator console shall allow selection of scanning protocols, initiation of calibration 
            and scanning, and display of reconstructed 3D images for diagnostic review.
        }
        attribute minDisplayResolution : String = "1920x1080";
    }

    requirement def GantryRotation {
        subject gantry : Gantry;
        objective {
            The gantry shall rotate the gamma camera(s) around the patient through a configurable 
            angular range at a controlled speed while the patient remains stationary.
        }
        attribute maxRotationRange : AngleDeg = 360.0;
        attribute maxRotationSpeed : RotationSpeed = 1.0;
    }

    // ---- Requirement satisfaction ----
    satisfaction DetectGammaPhotons by SPECTSystem;
    satisfaction FilterScatteredPhotons by Collimator;
    satisfaction ConvertGammaToLight by ScintillationCrystal;
    satisfaction AmplifyAndPosition by PMTArray;
    satisfaction EnergyDiscrimination by EnergyDiscriminator;
    satisfaction Reconstruct3DImage by ImageReconstructionSystem;
    satisfaction OperatorControl by OperatorConsole;
    satisfaction GantryRotation by Gantry;
}
