package LAAO_System {
    import ScalarValues::*;
    import ISQ::*;

    value type Diameter :> Length { unit 'mm'; }
    value type Force :> Real { unit 'N'; }
    value type FlowRate :> Real { unit 'mL/s'; }

    enum ImagingModality { TEE = 1, Fluoroscopy = 2 }
    enum OcclusionStatus { FullyOccluded = 1, ResidualLeak = 2, Failed = 3 }

    item def Blood;
    item def Tissue;

    port def ControlPort;
    port def DeploymentPort;
    port def ImagingPort;
    port def MonitoringPort;

    part def OccluderDevice {
        attribute nominalDiameter : Diameter = 25 [mm];
        attribute compressedDiameter : Diameter = 8 [mm];
        attribute outwardForce : Force = 1.2 [N];
        attribute isAnchored : Boolean = false;
        attribute isReleased : Boolean = false;

        port deploymentPort : DeploymentPort;
        port monitoringPort : MonitoringPort;

        part anchoringMechanism {
            attribute anchorForce : Force = 2.0 [N];
        }

        state def OccluderLifecycle {
            state stowed;
            state advanced;
            state deployed;
            state anchored;
            state verified;
            state released;

            transition stowed -> advanced;
            transition advanced -> deployed;
            transition deployed -> anchored;
            transition anchored -> verified;
            transition verified -> released;
        }
    }

    part def DeliveryCatheter {
        attribute length : Length = 100 [mm];
        attribute flexibility : Real = 0.8;

        port proximalControl : ControlPort;
        port distalDeployment : DeploymentPort;

        action def DeliverAction {
            in occluder : OccluderDevice;
        }
    }

    part def ImagingSystem {
        attribute modality : ImagingModality = ImagingModality::TEE;
        port imagingOutput : ImagingPort;

        action def MeasureLAAAction {
            out laaDiameter : Diameter;
        }
        action def VerifySealAction {
            out status : OcclusionStatus;
        }
    }

    part def MonitoringSystem {
        port monitoringInput : MonitoringPort;

        action def AssessStabilityAction {
            out isStable : Boolean;
        }
        action def MeasureResidualLeakAction {
            out leakRate : FlowRate;
        }
    }

    requirement def PreventStrokeRequirement {
        subject patient;
        objective preventStroke;
    }

    requirement def OccluderSealRequirement :> PreventStrokeRequirement {
        subject occluder : OccluderDevice;
        constraint { occluder.outwardForce >= 0.5 [N] }
    }

    requirement def CatheterDeliveryRequirement :> PreventStrokeRequirement {
        subject catheter : DeliveryCatheter;
        constraint { catheter.length >= 80 [mm] }
    }

    part def LAAOSystem {
        part occluder : OccluderDevice;
        part catheter : DeliveryCatheter;
        part imaging : ImagingSystem;
        part monitoring : MonitoringSystem;

        connection def DeploymentConnection {
            end catheterPort : DeploymentPort;
            end occluderPort : DeploymentPort;
        }

        connection def MonitoringConnection {
            end monitorPort : MonitoringPort;
            end occluderPort : MonitoringPort;
        }

        connection deployConn : DeploymentConnection connect 
            catheter.distalDeployment to occluder.deploymentPort;

        connection monitorConn : MonitoringConnection connect 
            monitoring.monitoringInput to occluder.monitoringPort;
    }
}
