package BiomimeticAdhesionSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit N;
    unit m;
    unit deg;
    unit Pa;
    unit m2;
    unit m_per_s;
    unit inv_m2;
    unit kg;

    // ===== Value Types =====
    value def Force :> Real;
    value def NormalForce :> Force;
    value def ShearForce :> Force;
    value def PeelAngle :> Real;
    value def ContactArea :> Real;
    value def PressureValue :> Real;
    value def LengthValue :> Real;
    value def VelocityValue :> Real;
    value def SetaeDensityValue :> Real;
    value def AdhesionStrengthValue :> Real;

    // ===== Enumerations =====
    enum def GripperState {
        detached;
        approaching;
        engaging;
        adhered;
        releasing;
        emergencyReleased;
    }

    // ===== Item Definitions =====
    item def Surface {
        attribute roughness : Real;
        attribute materialType : String;
        attribute isFlat : Boolean;
    }

    item def ContactPatch {
        attribute area : ContactArea;
        attribute isActive : Boolean;
    }

    // ===== Port Definitions =====
    port def UserCommandPort {
        out command : String;
        in stateReport : GripperState;
    }

    port def ControlCommandPort {
        in command : String;
        out stateReport : GripperState;
    }

    port def ActuatorPort {
        out normalForceCmd : NormalForce;
        out shearForceCmd : ShearForce;
        out peelAngleCmd : PeelAngle;
        out approachCmd : VelocityValue;
        in actualAngle : PeelAngle;
    }

    port def PadActuationPort {
        in normalForceCmd : NormalForce;
        in shearForceCmd : ShearForce;
    }

    port def AngleControlPort {
        in peelAngleCmd : PeelAngle;
        out actualAngle : PeelAngle;
    }

    port def ToeControlPort {
        out peelAngle : PeelAngle;
    }

    port def PadAnglePort {
        in peelAngle : PeelAngle;
    }

    port def SurfacePort {
        out surface : Surface;
    }

    port def PadSurfacePort {
        in surface : Surface;
    }

    port def PadFeedbackPort {
        out adhesionForce : Force;
    }

    port def MeasurementPort {
        in adhesionForce : Force;
    }

    port def SensorReportPort {
        out load : Force;
        out overload : Boolean;
        out adhesion : Force;
    }

    port def ControlSensorPort {
        in load : Force;
        in overload : Boolean;
        in adhesion : Force;
    }

    // ===== Part Definitions =====

    part def SetaeArray {
        attribute fiberCount : Integer = 1000000;
        attribute fiberLength : LengthValue = 100e-6 [m];
        attribute fiberDiameter : LengthValue = 0.2e-6 [m];
        attribute density : SetaeDensityValue = 10000000000 [inv_m2];
        attribute adhesionStrength : AdhesionStrengthValue = 100000 [Pa];

        port contactPort {
            in surface : Surface;
            out patches : ContactPatch[*];
        }

        action def engageSetae {
            in normalForce : NormalForce;
            in shearForce : ShearForce;
            out totalAdhesion : Force;
        }

        action def disengageSetae {
            in peelAngle : PeelAngle;
            out releaseForce : Force;
        }
    }

    part def Lamella {
        attribute thickness : LengthValue = 50e-6 [m];
        attribute layerCount : Integer = 5;
        attribute flexibility : Real = 0.8;

        part setaeArray : SetaeArray;

        port surfacePort : PadSurfacePort;

        action def conform {
            in surface : Surface;
            out conformed : Boolean;
        }
    }

    part def Toe {
        attribute length : LengthValue = 20e-3 [m];
        attribute width : LengthValue = 5e-3 [m];
        attribute currentPeelAngle : PeelAngle = 0.0 [deg];

        part lamellae : Lamella[8];

        port contactPort {
            in surface : Surface;
            out adhesionForce : Force;
        }

        port anglePort : PadAnglePort;

        action def engage {
            in normalForce : NormalForce;
            in shearForce : ShearForce;
        }

        action def peel {
            in angle : PeelAngle;
        }
    }

    part def AdhesivePad {
        attribute padArea : ContactArea = 0.01 [m2];
        attribute maxLoad : Force = 25.0 [N];
        attribute currentAdhesion : Force = 0.0 [N];

        part toes : Toe[6];

        port surfacePort : PadSurfacePort;
        port actuationPort : PadActuationPort;
        port anglePort : PadAnglePort;
        port feedbackPort : PadFeedbackPort;

        action def attach {
            in normalForce : NormalForce;
            in shearForce : ShearForce;
        }

        action def detach {
            in peelAngle : PeelAngle;
        }
    }

    part def AngleController {
        attribute currentPeelAngle : PeelAngle = 0.0 [deg];
        attribute maxPeelAngle : PeelAngle = 30.0 [deg];
        attribute stepAngle : PeelAngle = 5.0 [deg];

        port controlPort : AngleControlPort;
        port toeControlPort : ToeControlPort;

        action def setPeelAngle {
            in target : PeelAngle;
            out achieved : PeelAngle;
        }

        action def incrementPeel {
            out newAngle : PeelAngle;
        }
    }

    part def LoadSensor {
        attribute currentLoad : Force = 0.0 [N];
        attribute maxCapacity : Force = 100.0 [N];
        attribute overloadThreshold : Force = 90.0 [N];

        port measurementPort : MeasurementPort;
        port reportPort : SensorReportPort;

        action def measureLoad {
            out load : Force;
        }

        action def checkOverload {
            in load : Force;
            out overload : Boolean;
        }
    }

    part def ControlUnit {
        attribute maxNormalForce : NormalForce = 5.0 [N];
        attribute maxShearForce : ShearForce = 2.0 [N];
        attribute approachVelocity : VelocityValue = 0.01 [m_per_s];
        attribute currentState : GripperState = GripperState::detached;

        port commandPort : ControlCommandPort;
        port actuatorPort : ActuatorPort;
        port sensorPort : ControlSensorPort;

        action def approachSurface {
            in velocity : VelocityValue;
        }

        action def engageGrip {
            in normalForce : NormalForce;
            in shearForce : ShearForce;
        }

        action def releaseGrip {
            in peelAngle : PeelAngle;
        }

        action def emergencyReleaseAction {
        }

        action def resetSystem {
        }

        state machine gripperBehavior {
            state detached;
            state approaching;
            state engaging;
            state adhered;
            state releasing;
            state emergencyReleased;

            transition init first then detached;

            transition t_detached_to_approaching
                first detached then approaching
                when commandPort.command == "approach";

            transition t_approaching_to_engaging
                first approaching then engaging
                when commandPort.command == "engage";

            transition t_engaging_to_adhered
                first engaging then adhered
                when sensorPort.adhesion > 0.0 [N];

            transition t_adhered_to_releasing
                first adhered then releasing
                when commandPort.command == "release";

            transition t_releasing_to_detached
                first releasing then detached
                when sensorPort.adhesion == 0.0 [N];

            transition t_adhered_to_emergency
                first adhered then emergencyReleased
                when sensorPort.overload == true;

            transition t_engaging_to_emergency
                first engaging then emergencyReleased
                when sensorPort.overload == true;

            transition t_emergency_to_detached
                first emergencyReleased then detached
                when sensorPort.adhesion == 0.0 [N];

            state detached {
                entry {
                    currentState = GripperState::detached;
                    commandPort.stateReport = GripperState::detached;
                }
            }

            state approaching {
                entry {
                    currentState = GripperState::approaching;
                    actuatorPort.approachCmd = approachVelocity;
                    commandPort.stateReport = GripperState::approaching;
                }
            }

            state engaging {
                entry {
                    currentState = GripperState::engaging;
                    actuatorPort.normalForceCmd = maxNormalForce;
                    actuatorPort.shearForceCmd = maxShearForce;
                    commandPort.stateReport = GripperState::engaging;
                }
            }

            state adhered {
                entry {
                    currentState = GripperState::adhered;
                    commandPort.stateReport = GripperState::adhered;
                }
            }

            state releasing {
                entry {
                    currentState = GripperState::releasing;
                    actuatorPort.peelAngleCmd = 30.0 [deg];
                    commandPort.stateReport = GripperState::releasing;
                }
            }

            state emergencyReleased {
                entry {
                    currentState = GripperState::emergencyReleased;
                    actuatorPort.peelAngleCmd = 30.0 [deg];
                    commandPort.stateReport = GripperState::emergencyReleased;
                }
            }
        }
    }

    part def GeckoGripper {
        attribute totalMaxLoad : Force = 100.0 [N];
        attribute padCount : Integer = 4;

        port userPort : UserCommandPort;
        port surfaceInterface : SurfacePort;

        part controlUnit : ControlUnit {
            :>> maxNormalForce = 5.0 [N];
            :>> maxShearForce = 2.0 [N];
            :>> approachVelocity = 0.01 [m_per_s];
        }

        part pads : AdhesivePad[4] {
            :>> maxLoad = 25.0 [N];
            :>> padArea = 0.01 [m2];
        }

        part angleController : AngleController {
            :>> maxPeelAngle = 30.0 [deg];
            :>> stepAngle = 5.0 [deg];
        }

        part loadSensor : LoadSensor {
            :>> maxCapacity = 100.0 [N];
            :>> overloadThreshold = 90.0 [N];
        }

        connection userToControl connect userPort to controlUnit.commandPort;
        connection controlToAngle connect controlUnit.actuatorPort to angleController.controlPort;
        connection angleToPads connect angleController.toeControlPort to pads.anglePort;
        connection controlToPads connect controlUnit.actuatorPort to pads.actuationPort;
        connection surfaceToPads connect surfaceInterface to pads.surfacePort;
        connection padsToSensor connect pads.feedbackPort to loadSensor.measurementPort;
        connection sensorToControl connect loadSensor.reportPort to controlUnit.sensorPort;
    }

    // ===== Requirements =====

    requirement def AdhesionMechanismRequirement {
        doc /* The gripper shall achieve adhesion through van der Waals forces without adhesives or suction. */
        subject gripper : GeckoGripper;
        constraint { gripper.pads.toes.lamellae.setaeArray.fiberCount >= 1000000 }
    }

    requirement def HierarchicalStructureRequirement {
        doc /* Each pad shall consist of multiple toes, each toe covered with lamellae, each lamella coated with dense setae arrays. */
        subject pad : AdhesivePad;
        constraint { pad.toes->size() >= 4 }
        constraint { pad.toes.lamellae->size() >= 4 }
        constraint { pad.toes.lamellae.setaeArray.fiberCount >= 1000000 }
    }

    requirement def AttachmentProcedureRequirement {
        doc /* Attachment shall be achieved by applying normal force and slight shear force to engage setae. */
        subject gripper : GeckoGripper;
        constraint { gripper.controlUnit.maxNormalForce >= 5.0 [N] }
        constraint { gripper.controlUnit.maxShearForce >= 1.0 [N] }
    }

    requirement def DetachmentProcedureRequirement {
        doc /* Detachment shall use peel angle control to sequentially break contact points from an edge. */
        subject gripper : GeckoGripper;
        constraint { gripper.angleController.maxPeelAngle <= 30.0 [deg] }
        constraint { gripper.angleController.stepAngle <= 10.0 [deg] }
    }

    requirement def LoadCapacityRequirement {
        doc /* The gripper shall securely support loads up to its maximum rated capacity. */
        subject gripper : GeckoGripper;
        constraint { gripper.totalMaxLoad >= 100.0 [N] }
    }

    requirement def OverloadProtectionRequirement {
        doc /* If the load exceeds maximum capacity, the system shall trigger an emergency release to prevent failure. */
        subject gripper : GeckoGripper;
        constraint { gripper.loadSensor.overloadThreshold < gripper.loadSensor.maxCapacity }
    }

    requirement def StateControlRequirement {
        doc /* The system shall operate through the states: detached, approaching, engaging, adhered, releasing, and emergencyReleased. */
        subject gripper : GeckoGripper;
        constraint { gripper.controlUnit.currentState in GripperState }
    }

    requirement def SurfaceConformanceRequirement {
        doc /* The hierarchical pad structure shall conform to non-flat surfaces maximizing contact area. */
        subject pad : AdhesivePad;
        constraint { pad.toes.lamellae.layerCount >= 3 }
        constraint { pad.toes.lamellae.flexibility >= 0.5 }
    }

    // ===== Satisfaction =====
    satisfaction satisfyAdhesionMechanism by gripper : GeckoGripper satisfies AdhesionMechanismRequirement;
    satisfaction satisfyHierarchy by pad : AdhesivePad satisfies HierarchicalStructureRequirement;
    satisfaction satisfyAttachment by gripper : GeckoGripper satisfies AttachmentProcedureRequirement;
    satisfaction satisfyDetachment by gripper : GeckoGripper satisfies DetachmentProcedureRequirement;
    satisfaction satisfyLoadCapacity by gripper : GeckoGripper satisfies LoadCapacityRequirement;
    satisfaction satisfyOverloadProtection by gripper : GeckoGripper satisfies OverloadProtectionRequirement;
    satisfaction satisfyStateControl by gripper : GeckoGripper satisfies StateControlRequirement;
    satisfaction satisfyConformance by pad : AdhesivePad satisfies SurfaceConformanceRequirement;
}
