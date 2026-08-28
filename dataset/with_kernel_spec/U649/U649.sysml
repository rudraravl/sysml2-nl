package DTI_System_Model {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;

    package DataTypes {
        attribute def Vector3 {
            attribute x : Real;
            attribute y : Real;
            attribute z : Real;
        }

        attribute def Position3D {
            attribute x :> ISQ::length;
            attribute y :> ISQ::length;
            attribute z :> ISQ::length;
        }

        item def RawSignal;

        item def DiffusionWeightedImage {
            attribute gradientDirection : Vector3;
            attribute bValue : Real;
        }

        item def DiffusionTensor {
            attribute Dxx : Real;
            attribute Dyy : Real;
            attribute Dzz : Real;
            attribute Dxy : Real;
            attribute Dxz : Real;
            attribute Dyz : Real;
        }

        item def FractionalAnisotropy {
            attribute value : Real;
        }

        item def FiberTractMap;
    }

    package Hardware {
        private import DataTypes::*;

        part def MainMagnet {
            attribute fieldStrength :> ISQ::magneticFluxDensity;
            out port magneticField : ISQ::magneticFluxDensity;
        }

        part def GradientCoils {
            in port controlSignal : Vector3;
            out port gradientField : ISQ::magneticFluxDensity;
        }

        part def RFTransceiver {
            attribute larmorFrequency :> ISQ::frequency;
            out port rfPulse : ISQ::frequency;
            in port receivedSignal : RawSignal;
            out port rawSignalOut : RawSignal;
        }

        part def PatientTable {
            attribute position : Position3D;
        }
    }

    package Computation {
        private import DataTypes::*;

        part def ImageReconstructionUnit {
            in port rawSignals : RawSignal[*];
            out port dwImages : DiffusionWeightedImage[*];

            action def Reconstruct {
                in signals : RawSignal[*];
                out images : DiffusionWeightedImage[*];
            }
            perform action reconstruct : Reconstruct;
        }

        part def TensorComputationEngine {
            in port dwImages : DiffusionWeightedImage[*];
            out port tensors : DiffusionTensor[*];
            out port faValues : FractionalAnisotropy[*];

            action def ComputeTensors {
                in images : DiffusionWeightedImage[*];
                out tensors : DiffusionTensor[*];
                out fa : FractionalAnisotropy[*];
            }
            perform action computeTensors : ComputeTensors;
        }

        part def TractographyEngine {
            in port tensors : DiffusionTensor[*];
            in port faValues : FractionalAnisotropy[*];
            out port tractMap : FiberTractMap;

            action def PerformTractography {
                in tensors : DiffusionTensor[*];
                in fa : FractionalAnisotropy[*];
                out map : FiberTractMap;
            }
            perform action performTractography : PerformTractography;
        }
    }

    package Behavior {
        private import Hardware::*;
        private import Computation::*;
        private import DataTypes::*;

        action def CalibrateSystem {
            out calibrationStatus : Boolean;
        }

        action def PositionPatient {
            in targetPosition : Position3D;
            out actualPosition : Position3D;
        }

        action def AcquireSignal {
            in direction : Vector3;
            out signal : RawSignal;
        }

        action def AcquireDiffusionData {
            in gradientDirections : Vector3[*] ordered;
            out raw : RawSignal[*];
            attribute signals : RawSignal[*] := ();
            for i in 1..gradientDirections->size() {
                perform action acquire : AcquireSignal {
                    in direction = gradientDirections#(i);
                }
                then assign signals := signals->including(acquire.signal);
            }
            then assign raw := signals;
        }

        state def DTIOperationalStates {
            entry; then idle;
            state idle;
            transition t1 first idle then calibrating;
            state calibrating;
            transition t2 first calibrating then acquiringData;
            state acquiringData;
            transition t3 first acquiringData then reconstructingImages;
            state reconstructingImages;
            transition t4 first reconstructingImages then computingTensors;
            state computingTensors;
            transition t5 first computingTensors then performingTractography;
            state performingTractography;
            transition t6 first performingTractography then scanComplete;
            final state scanComplete;
        }
    }

    package SystemArchitecture {
        private import Hardware::*;
        private import Computation::*;
        private import Behavior::*;
        private import DataTypes::*;

        part def DTIScanner {
            part mainMagnet : MainMagnet;
            part gradientCoils : GradientCoils;
            part rfTransceiver : RFTransceiver;
            part patientTable : PatientTable;
            part reconstructionUnit : ImageReconstructionUnit;
            part tensorEngine : TensorComputationEngine;
            part tractographyEngine : TractographyEngine;

            connect rfTransceiver.rawSignalOut to reconstructionUnit.rawSignals;
            connect reconstructionUnit.dwImages to tensorEngine.dwImages;
            connect tensorEngine.tensors to tractographyEngine.tensors;
            connect tensorEngine.faValues to tractographyEngine.faValues;

            exhibit state operationalStates : DTIOperationalStates;
        }

        part dtiScanner : DTIScanner;
    }

    package Requirements {
        requirement def MagneticFieldStrengthReq {
            text "The main magnet shall generate a static magnetic field of at least 3.0 Tesla.";
        }
        requirement def DiffusionDirectionsReq {
            text "The system shall acquire diffusion-weighted images along at least 6 non-collinear gradient directions.";
        }
        requirement def TensorComputationReq {
            text "The tensor computation engine shall compute a diffusion tensor for each voxel from the acquired images.";
        }
        requirement def TractographyReq {
            text "The tractography engine shall generate a 3D fiber tract map using the computed diffusion tensors.";
        }
        requirement def OperationalStatesReq {
            text "The system shall transition through idle, calibrating, acquiring, reconstructing, computing tensors, and tractography states before completion.";
        }

        satisfy MagneticFieldStrengthReq by Hardware::MainMagnet;
        satisfy DiffusionDirectionsReq by Behavior::AcquireDiffusionData;
        satisfy TensorComputationReq by Computation::TensorComputationEngine;
        satisfy TractographyReq by Computation::TractographyEngine;
        satisfy OperationalStatesReq by Behavior::DTIOperationalStates;
    }
}
