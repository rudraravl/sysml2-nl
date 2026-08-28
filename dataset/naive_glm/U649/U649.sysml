package DTISystemModel {
    import ScalarValues::*;

    // ===== Value Definitions and Units =====
    value def MagneticFluxDensity :> Real;
    unit T of MagneticFluxDensity;

    value def GradientSlope :> Real;
    unit T_per_m of GradientSlope;

    value def Frequency :> Real;
    unit Hz of Frequency;
    unit MHz of Frequency = 1000000 [Hz];

    value def Time :> Real;
    unit s of Time;
    unit ms of Time = 0.001 [s];
    unit us of Time = 0.000001 [s];

    value def Length :> Real;
    unit mm of Length;

    value def Dimensionless :> Real;
    unit ppm of Dimensionless = 0.000001;

    value def Angle :> Real;
    unit deg of Angle;

    value def Volume :> Real;
    unit mm3 of Volume;

    // ===== Item Definitions =====
    item def Vector3D {
        attribute x : Dimensionless;
        attribute y : Dimensionless;
        attribute z : Dimensionless;
    }

    item def Patient {
        attribute id : String;
        attribute position : Length;
    }

    item def RFPulse {
        attribute frequency : Frequency;
        attribute duration : Time;
    }

    item def RawSignal;

    item def DiffusionWeightedImage {
        attribute direction : Vector3D;
        attribute bValue : Dimensionless;
    }

    item def DiffusionTensor {
        attribute fa : Dimensionless;
        attribute principalDirection : Vector3D;
    }

    item def Voxel {
        attribute position : Vector3D;
        attribute tensor : DiffusionTensor;
    }

    item def FiberTract {
        attribute voxels : Voxel[*];
    }

    item def CalibrationReport {
        attribute magnetStability : Dimensionless;
        attribute gradientLinearity : Dimensionless;
    }

    // ===== Port Definitions =====
    port def RawSignalOutPort {
        out rawSignal : RawSignal;
    }

    port def RawSignalInPort {
        in rawSignal : RawSignal;
    }

    port def DWIOutPort {
        out dwi : DiffusionWeightedImage;
    }

    port def DWIInPort {
        in dwi : DiffusionWeightedImage;
    }

    port def TensorOutPort {
        out tensor : DiffusionTensor;
    }

    port def TensorInPort {
        in tensor : DiffusionTensor;
    }

    port def TractOutPort {
        out tract : FiberTract;
    }

    port def TractInPort {
        in tract : FiberTract;
    }

    port def PatientInPort {
        in patient : Patient;
    }

    port def RFPulseOutPort {
        out pulse : RFPulse;
    }

    port def GradientOutPort {
        out gradientDirection : Vector3D;
        out gradientStrength : GradientSlope;
    }

    // ===== Occurrence Definitions for State Transitions =====
    occurrence def StartScan;
    occurrence def CalibrationComplete;
    occurrence def AcquisitionComplete;
    occurrence def ReconstructionComplete;
    occurrence def TensorsComputed;
    occurrence def TractographyComplete;
    occurrence def Reset;

    // ===== Action Definitions =====
    action def CalibrateSystem {
        out report : CalibrationReport;
    }

    action def PositionPatientAction {
        in patient : Patient;
        in position : Length;
    }

    action def AcquireDWIAction {
        out images : DiffusionWeightedImage[*];
    }

    action def ReconstructImagesAction {
        in rawSignals : RawSignal[*];
        out images : DiffusionWeightedImage[*];
    }

    action def ComputeTensorsAction {
        in images : DiffusionWeightedImage[*];
        out tensors : DiffusionTensor[*];
    }

    action def PerformTractographyAction {
        in tensors : DiffusionTensor[*];
        out tract : FiberTract;
    }

    // ===== Part Definitions =====
    part def MainMagnet {
        attribute fieldStrength : MagneticFluxDensity = 3.0 [T];
        attribute stability : Dimensionless = 0.1 [ppm];
        attribute providesStableField : Boolean = true;
    }

    part def GradientCoilSystem {
        attribute maxSlope : GradientSlope = 80 [T_per_m];
        attribute riseTime : Time = 200 [us];
        attribute providesDirectionalGradients : Boolean = true;
        port gradientOut : GradientOutPort;

        action def ApplyGradientPulse {
            in direction : Vector3D;
            in strength : GradientSlope;
        }
    }

    part def RFTransceiver {
        attribute frequency : Frequency = 128 [MHz];
        attribute providesTxRx : Boolean = true;
        port txOut : RFPulseOutPort;
        port rxOut : RawSignalOutPort;

        action def TransmitPulse {
            in pulse : RFPulse;
        }

        action def ReceiveSignal {
            out signal : RawSignal;
        }
    }

    part def PatientTable {
        attribute maxTravel : Length = 500 [mm];
        attribute positionsPrecisely : Boolean = true;
        port patientIn : PatientInPort;

        action def PositionPatient {
            in patient : Patient;
            in position : Length;
        }
    }

    part def ImageReconstructionUnit {
        attribute providesDWI : Boolean = true;
        port rawIn : RawSignalInPort;
        port dwiOut : DWIOutPort;

        action def Reconstruct {
            in rawSignals : RawSignal[*];
            out images : DiffusionWeightedImage[*];
        }
    }

    part def TensorComputationEngine {
        attribute computesFA : Boolean = true;
        port dwiIn : DWIInPort;
        port tensorOut : TensorOutPort;

        action def ComputeTensor {
            in images : DiffusionWeightedImage[*];
            out tensor : DiffusionTensor;
        }

        action def ComputeFA {
            in tensor : DiffusionTensor;
            out fa : Dimensionless;
        }
    }

    part def TractographyEngine {
        attribute generatesTractMap : Boolean = true;
        port tensorIn : TensorInPort;
        port tractOut : TractOutPort;

        action def TraceFibers {
            in tensors : DiffusionTensor[*];
            out tract : FiberTract;
        }
    }

    part def DTIController {
        attribute hasOperationalStates : Boolean = true;

        state machine dtiStateMachine {
            state idle;
            state calibrating;
            state acquiring;
            state reconstructing;
            state computingTensors;
            state tractography;
            state complete;

            transition idle_to_calibrating
                from idle to calibrating
                accept StartScan;

            transition calibrating_to_acquiring
                from calibrating to acquiring
                accept CalibrationComplete;

            transition acquiring_to_reconstructing
                from acquiring to reconstructing
                accept AcquisitionComplete;

            transition reconstructing_to_computing
                from reconstructing to computingTensors
                accept ReconstructionComplete;

            transition computing_to_tractography
                from computingTensors to tractography
                accept TensorsComputed;

            transition tractography_to_complete
                from tractography to complete
                accept TractographyComplete;

            transition complete_to_idle
                from complete to idle
                accept Reset;

            state calibrating {
                do CalibrateSystem;
            }

            state acquiring {
                do AcquireDWIAction;
            }

            state reconstructing {
                do ReconstructImagesAction;
            }

            state computingTensors {
                do ComputeTensorsAction;
            }

            state tractography {
                do PerformTractographyAction;
            }
        }
    }

    part def DTISystem {
        attribute hasOperationalStates : Boolean = true;

        part mainMagnet : MainMagnet;
        part gradientCoils : GradientCoilSystem;
        part rfTransceiver : RFTransceiver;
        part patientTable : PatientTable;
        part reconstructionUnit : ImageReconstructionUnit;
        part tensorEngine : TensorComputationEngine;
        part tractographyEngine : TractographyEngine;
        part controller : DTIController;

        port patientPort : PatientInPort;
        port tractResultPort : TractOutPort;

        connection patientFlow from patientPort to patientTable.patientIn;
        connection rawSignalFlow from rfTransceiver.rxOut to reconstructionUnit.rawIn;
        connection dwiFlow from reconstructionUnit.dwiOut to tensorEngine.dwiIn;
        connection tensorFlow from tensorEngine.tensorOut to tractographyEngine.tensorIn;
        connection tractFlow from tractographyEngine.tractOut to tractResultPort;
    }

    // ===== Requirements =====
    requirement def DTISystemRequirements {
        requirement def MagneticFieldStabilityRequirement {
            subject magnet : MainMagnet;
            requirement { magnet.fieldStrength >= 1.5 [T] }
            requirement { magnet.providesStableField == true }
        }

        requirement def GradientPerformanceRequirement {
            subject coils : GradientCoilSystem;
            requirement { coils.maxSlope >= 40 [T_per_m] }
            requirement { coils.providesDirectionalGradients == true }
        }

        requirement def RFTransceiverRequirement {
            subject rf : RFTransceiver;
            requirement { rf.frequency >= 64 [MHz] }
            requirement { rf.providesTxRx == true }
        }

        requirement def PatientPositioningRequirement {
            subject table : PatientTable;
            requirement { table.maxTravel >= 300 [mm] }
            requirement { table.positionsPrecisely == true }
        }

        requirement def ReconstructionRequirement {
            subject recon : ImageReconstructionUnit;
            requirement { recon.providesDWI == true }
        }

        requirement def TensorComputationRequirement {
            subject engine : TensorComputationEngine;
            requirement { engine.computesFA == true }
        }

        requirement def TractographyRequirement {
            subject tract : TractographyEngine;
            requirement { tract.generatesTractMap == true }
        }

        requirement def OperationalStatesRequirement {
            subject system : DTISystem;
            requirement { system.hasOperationalStates == true }
        }
    }

    // ===== Top-Level Configuration =====
    part dtiSystem : DTISystem;
}
