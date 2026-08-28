package SSM_Model {

    // --- Value Types ---
    value def VoltageValue :> Real {
        attribute unit : String = "V";
    }
    value def TemperatureValue :> Real {
        attribute unit : String = "K";
    }
    value def LengthValue :> Real {
        attribute unit : String = "m";
    }
    value def MagneticFluxValue :> Real {
        attribute unit : String = "Wb";
    }
    value def MagneticFluxDensityValue :> Real {
        attribute unit : String = "T";
    }
    value def VibrationAmplitudeValue :> Real {
        attribute unit : String = "m";
    }
    value def DampingCoefficientValue :> Real {
        attribute unit : String = "N*s/m";
    }
    value def ShieldingFactorValue :> Real;

    // --- Items ---
    item def LiquidHelium;
    item def SampleMaterial;

    item def RawVoltageSignal {
        attribute amplitude : VoltageValue;
    }

    item def CalibratedFluxSignal {
        attribute flux : MagneticFluxValue;
    }

    item def Position2D {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }

    item def DataPoint {
        attribute position : Position2D;
        attribute flux : MagneticFluxValue;
    }

    item def MagneticFieldImage {
        attribute dataPoints : DataPoint[0..*];
    }

    // --- Ports ---
    port def HeliumOutPort {
        out item helium : LiquidHelium;
    }

    port def HeliumInPort {
        in item helium : LiquidHelium;
    }

    port def RawSignalOutPort {
        out item signal : RawVoltageSignal;
    }

    port def RawSignalInPort {
        in item signal : RawVoltageSignal;
    }

    port def CalibratedFluxOutPort {
        out item fluxSignal : CalibratedFluxSignal;
    }

    port def CalibratedFluxInPort {
        in item fluxSignal : CalibratedFluxSignal;
    }

    port def PositionOutPort {
        out item position : Position2D;
    }

    port def PositionInPort {
        in item position : Position2D;
    }

    port def ImageOutPort {
        out item image : MagneticFieldImage;
    }

    port def MechanicalMountPort;

    // --- Actions ---
    action def RasterScanAction {
        attribute stepSize : LengthValue;
        attribute gridSizeX : Integer;
        attribute gridSizeY : Integer;
        out item currentPosition : Position2D;
    }

    action def CalibrateFluxAction {
        in item rawSignal : RawVoltageSignal;
        out item calibratedSignal : CalibratedFluxSignal;
    }

    action def AssembleImageAction {
        in item fluxes : CalibratedFluxSignal[0..*];
        in item positions : Position2D[0..*];
        out item image : MagneticFieldImage;
    }

    // --- Component Part Definitions ---
    part def SQUIDSensorHead {
        attribute operatingTemp : TemperatureValue = 4.2;
        attribute sensitivity : MagneticFluxValue;
        
        port heliumIn : HeliumInPort;
        port voltageOut : RawSignalOutPort;
    }

    part def CryogenicDewar {
        attribute targetTemp : TemperatureValue = 4.2;
        attribute currentTemp : TemperatureValue;
        attribute heliumVolume : Real;
        
        port heliumOut : HeliumOutPort;
        port baseMount : MechanicalMountPort;
    }

    part def SampleStage {
        attribute stageArea : LengthValue;
        item mountedSample : SampleMaterial;
        
        port mount : MechanicalMountPort;
    }

    part def PiezoelectricScanner {
        attribute stepSize : LengthValue;
        attribute maxScanRange : LengthValue;
        
        port stageConnection : MechanicalMountPort;
        port baseMount : MechanicalMountPort;
        port positionOut : PositionOutPort;
        
        action performScan : RasterScanAction;
    }

    part def VibrationIsolationSystem {
        attribute dampingCoefficient : DampingCoefficientValue;
        
        port groundMount : MechanicalMountPort;
        port isoMount : MechanicalMountPort;
    }

    part def MagneticShieldingEnclosure {
        attribute shieldingFactor : ShieldingFactorValue;
        attribute material : String = "Mu-metal";
        attribute externalFieldStrength : MagneticFluxDensityValue;
    }

    part def FeedbackElectronics {
        attribute gain : Real;
        attribute calibrationFactor : Real;
        
        port rawSignalIn : RawSignalInPort;
        port fluxOut : CalibratedFluxOutPort;
        
        action calibrate : CalibrateFluxAction;
    }

    part def DataAcquisitionUnit {
        attribute samplingRate : Real;
        attribute isDataReady : Boolean;
        attribute isImageAssembled : Boolean;
        
        port fluxIn : CalibratedFluxInPort;
        port positionIn : PositionInPort;
        port imageOut : ImageOutPort;
        
        action assemble : AssembleImageAction;
        
        state machine def AcquisitionStateMachine {
            state Idle;
            state Acquiring;
            state Processing;
            
            transition Idle -> Acquiring when isDataReady == true;
            transition Acquiring -> Processing when isDataReady == false;
            transition Processing -> Idle when isImageAssembled == true;
        }
    }

    // --- Connections ---
    connection def HeliumFlowConnection {
        end source : HeliumOutPort;
        end target : HeliumInPort;
    }

    connection def VoltageFlowConnection {
        end source : RawSignalOutPort;
        end target : RawSignalInPort;
    }

    connection def FluxFlowConnection {
        end source : CalibratedFluxOutPort;
        end target : CalibratedFluxInPort;
    }

    connection def PositionFlowConnection {
        end source : PositionOutPort;
        end target : PositionInPort;
    }

    connection def MechanicalConnection {
        end source : MechanicalMountPort;
        end target : MechanicalMountPort;
    }

    // --- System Definition ---
    part def ScanningSQUIDMicroscope {
        attribute isRunning : Boolean;
        attribute sampleOnStage : Boolean;
        attribute coolingComplete : Boolean;
        attribute scanComplete : Boolean;
        attribute imageComplete : Boolean;
        
        part sensorHead : SQUIDSensorHead;
        part dewar : CryogenicDewar;
        part sampleStage : SampleStage;
        part scanner : PiezoelectricScanner;
        part vibrationIsolation : VibrationIsolationSystem;
        part magneticShielding : MagneticShieldingEnclosure;
        part feedbackElectronics : FeedbackElectronics;
        part dataAcquisition : DataAcquisitionUnit;
        
        connection cryoConnection : HeliumFlowConnection connect dewar.heliumOut to sensorHead.heliumIn;
        connection signalConnection : VoltageFlowConnection connect sensorHead.voltageOut to feedbackElectronics.rawSignalIn;
        connection fluxConnection : FluxFlowConnection connect feedbackElectronics.fluxOut to dataAcquisition.fluxIn;
        connection posConnection : PositionFlowConnection connect scanner.positionOut to dataAcquisition.positionIn;
        connection stageConnection : MechanicalConnection connect scanner.stageConnection to sampleStage.mount;
        connection isoConnection : MechanicalConnection connect vibrationIsolation.isoMount to scanner.baseMount;
        connection dewarIsoConnection : MechanicalConnection connect vibrationIsolation.isoMount to dewar.baseMount;
        
        state machine def SystemOperation {
            state Idle;
            state Initializing;
            state Scanning;
            state PostProcessing;
            
            transition Idle -> Initializing when isRunning == true && sampleOnStage == true;
            transition Initializing -> Scanning when coolingComplete == true;
            transition Scanning -> PostProcessing when scanComplete == true;
            transition PostProcessing -> Idle when imageComplete == true;
        }
    }

    // --- Requirements ---
    requirement def CryogenicCoolingRequirement {
        attribute targetTemp : TemperatureValue = 4.2;
        doc /* The sensor must be cooled to 4.2 Kelvin using liquid helium. */
    }

    requirement def VibrationIsolationRequirement {
        attribute maxVibrationAmplitude : VibrationAmplitudeValue;
        doc /* The system must damp physical vibrations to prevent image blur. */
    }

    requirement def MagneticShieldingRequirement {
        attribute minShieldingFactor : ShieldingFactorValue;
        doc /* The enclosure must block external magnetic fields such as the Earth's. */
    }

    requirement def RasterScanningRequirement {
        attribute maxStepSize : LengthValue;
        doc /* The scanner must move in a fine grid-like pattern. */
    }

    requirement def DataAcquisitionRequirement {
        doc /* The DAU must assemble individual data points into a final magnetic field image. */
    }

    requirement cryoReq : CryogenicCoolingRequirement;
    requirement vibReq : VibrationIsolationRequirement;
    requirement shieldReq : MagneticShieldingRequirement;
    requirement scanReq : RasterScanningRequirement;
    requirement daqReq : DataAcquisitionRequirement;

    part ssm : ScanningSQUIDMicroscope;

    satisfy cryoReq by ssm.dewar.targetTemp;
    satisfy vibReq by ssm.vibrationIsolation.dampingCoefficient;
    satisfy shieldReq by ssm.magneticShielding.shieldingFactor;
    satisfy scanReq by ssm.scanner.stepSize;
    satisfy daqReq by ssm.dataAcquisition.assemble;

}
