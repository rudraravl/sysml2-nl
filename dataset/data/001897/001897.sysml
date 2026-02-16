package 'Wheel and Axle System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
    attribute def Torque :> ISQ::TorqueValue;
    attribute def Radius :> ISQ::LengthValue;
    attribute def LoadMass :> ISQ::MassValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def Efficiency :> Real;

    item def InputForce {
        attribute magnitude : ForceValue;
        attribute applicationPoint : Radius;
    }

    item def OutputForce {
        attribute magnitude : ForceValue;
        attribute applicationPoint : Radius;
    }

    item def TorqueTransfer {
        attribute torqueValue : Torque;
        attribute rotationalSpeed : RotationalSpeed;
    }

    port def ForceInputPort {
        in item appliedForce : InputForce;
    }

    port def ForceOutputPort {
        out item resultantForce : OutputForce;
    }

    port def RotationalPort {
        attribute torque : Torque;
        attribute angularVelocity : RotationalSpeed;
    }

    part def Wheel {
        attribute wheelRadius : Radius;
        attribute currentAngularVelocity : RotationalSpeed;
        attribute appliedTorque : Torque;

        port inputPort : ForceInputPort;
        port rotationPort : RotationalPort;

        action def ConvertForceToTorque {
            in force : ForceValue;
            in radius : Radius;
            out torque : Torque;
        }

        action def RotateWheel {
            in inputTorque : Torque;
            out outputAngularVelocity : RotationalSpeed;
        }
    }

    part def Axle {
        attribute axleRadius : Radius;
        attribute axleLength : ISQ::LengthValue;
        attribute transmittedTorque : Torque;
        attribute angularVelocity : RotationalSpeed;

        port wheelSide : RotationalPort;
        port loadSide : RotationalPort;

        action def TransmitTorque {
            in inputTorque : Torque;
            out outputTorque : Torque;
        }

        action def MaintainRotation {
            in inputSpeed : RotationalSpeed;
            out outputSpeed : RotationalSpeed;
        }
    }

    part def Load {
        attribute mass : LoadMass;
        attribute attachmentRadius : Radius;
        attribute liftHeight : ISQ::LengthValue;
        attribute liftVelocity : ISQ::SpeedValue;

        port connectionPort : RotationalPort;
        port outputPort : ForceOutputPort;

        action def ConvertTorqueToForce {
            in receivedTorque : Torque;
            in effectiveRadius : Radius;
            out liftingForce : ForceValue;
        }

        action def LiftLoad {
            in force : ForceValue;
            in currentHeight : ISQ::LengthValue;
            in currentVelocity : ISQ::SpeedValue;
            in deltaTime : ISQ::TimeValue;
            out newHeight : ISQ::LengthValue;
            out newVelocity : ISQ::SpeedValue;
        }
    }

    action def CalculateMechanicalAdvantage {
        in wheelRadius : Radius;
        in axleRadius : Radius;
        out mechanicalAdvantage : Real;
    }

    action def ComputeForceMultiplication {
        in inputForce : ForceValue;
        in wheelRadius : Radius;
        in axleRadius : Radius;
        in systemEfficiency : Efficiency;
        out outputForce : ForceValue;
        out inputTorque : Torque;
        out outputTorque : Torque;
    }

    part def WheelAndAxleSystem {
        attribute systemEfficiency : Efficiency;
        attribute mechanicalAdvantage : Real;

        part wheel : Wheel {
            attribute :>> wheelRadius = 0.6 [SI::m];
        }

        part axle : Axle {
            attribute :>> axleRadius = 0.08 [SI::m];
            attribute :>> axleLength = 0.4 [SI::m];
        }

        part load : Load {
            attribute :>> mass = 75.0 [SI::kg];
            attribute :>> attachmentRadius = axle.axleRadius;
            attribute :>> liftHeight = 0.0 [SI::m];
            attribute :>> liftVelocity = 0.0 [SI::'m/s'];
        }

        port effortInput : ForceInputPort;
        port resistanceOutput : ForceOutputPort;

        connect wheel.rotationPort to axle.wheelSide;
        connect axle.loadSide to load.connectionPort;
        connect effortInput to wheel.inputPort;
        connect load.outputPort to resistanceOutput;

        perform action operateSystem : OperateWheelAndAxle;
        exhibit state systemBehavior : WheelAndAxleStateMachine;
    }

    action def OperateWheelAndAxle {
        first start;

        then action applyInputForce : Wheel::ConvertForceToTorque {
            in force = 120.0 [SI::N];
            in radius = 0.6 [SI::m];
            out torque;
        }

        then action rotateWheel : Wheel::RotateWheel {
            in inputTorque = applyInputForce.torque;
            out outputAngularVelocity;
        }

        then action transmitThroughAxle : Axle::TransmitTorque {
            in inputTorque = applyInputForce.torque;
            out outputTorque;
        }

        then action calculateAdvantage : CalculateMechanicalAdvantage {
            in wheelRadius = 0.6 [SI::m];
            in axleRadius = 0.08 [SI::m];
            out mechanicalAdvantage;
        }

        then action convertToLiftForce : Load::ConvertTorqueToForce {
            in receivedTorque = transmitThroughAxle.outputTorque;
            in effectiveRadius = 0.08 [SI::m];
            out liftingForce;
        }

        then action raiseLoad : Load::LiftLoad {
            in force = convertToLiftForce.liftingForce;
            in currentHeight = 0.0 [SI::m];
            in currentVelocity = 0.0 [SI::'m/s'];
            in deltaTime = 1.0 [SI::s];
            out newHeight;
            out newVelocity;
        }

        then done;
    }

    event def ForceAppliedEvent;
    event def LoadAttachedEvent;
    event def TargetHeightReachedEvent;
    event def ForceReleasedEvent;

    state def WheelAndAxleStateMachine {
        entry; then idle;

        state idle;

        state engaged;

        state lifting {
            do action continuousLift;
        }

        state holding;

        transition idleToEngaged
            first idle
            accept ForceAppliedEvent
            then engaged;

        transition engagedToLifting
            first engaged
            accept LoadAttachedEvent
            then lifting;

        transition liftingToHolding
            first lifting
            accept TargetHeightReachedEvent
            then holding;

        transition holdingToIdle
            first holding
            accept ForceReleasedEvent
            then idle;
    }

    requirement def ForceMagnificationRequirement {
        doc /* The wheel and axle system shall magnify the input force applied at the wheel 
                by the ratio of wheel radius to axle radius, enabling the lifting of heavy loads 
                with reduced effort. */

        subject system : WheelAndAxleSystem;

        require constraint mechanicalAdvantageConstraint {
            system.wheel.wheelRadius / system.axle.axleRadius >= 5.0
        }
    }

    requirement def EfficiencyRequirement {
        doc /* The system shall maintain a mechanical efficiency of at least 85% 
                to minimize energy loss during force transmission. */

        subject system : WheelAndAxleSystem;

        require constraint efficiencyConstraint {
            system.systemEfficiency >= 0.85
        }
    }

    requirement def LoadCapacityRequirement {
        doc /* The wheel and axle system shall be capable of lifting loads 
                up to 100 kilograms. */

        subject system : WheelAndAxleSystem;

        require constraint maxLoadConstraint {
            system.load.mass <= 100.0 [SI::kg]
        }
    }

    requirement def StructuralIntegrityRequirement {
        doc /* The axle shall maintain structural integrity under maximum torque conditions. */

        subject axle : Axle;

        require constraint torqueLimit {
            axle.transmittedTorque <= 200.0 [SI::'N*m']
        }
    }

    requirement primaryFunctionRequirement : ForceMagnificationRequirement {
        doc /* Primary system requirement: The wheel and axle shall function as a simple machine 
                to multiply force and enable mechanical advantage for lifting operations. */

        assume constraint inputForceAvailable {
            doc /* Operator can apply force at the wheel perimeter. */
        }

        require mechanicalAdvantageConstraint;
        require efficiencyReq : EfficiencyRequirement;
        require loadCapacityReq : LoadCapacityRequirement;
        require structuralReq : StructuralIntegrityRequirement;
    }

    part wheelAndAxleMachine : WheelAndAxleSystem {
        attribute :>> systemEfficiency = 0.90;
        satisfy primaryFunctionRequirement;
    }
}
