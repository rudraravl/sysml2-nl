package InclinedPlaneSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def AngleValue :> Real;
    attribute def CoefficientValue :> Real;

    enum def LoadStatus {
        atBase;
        inTransit;
        atTop;
        secured;
    }

    item def Load {
        attribute mass : MassValue;
        attribute position : LengthValue;
        attribute status : LoadStatus;
    }

    port def MechanicalInterface;
    port def ControlInterface;
    port def SupportInterface;

    part def RampSurface {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute inclineAngle : AngleValue;
        attribute frictionCoefficient : CoefficientValue;
        attribute surfaceRoughness : LengthValue;
        port loadContact : MechanicalInterface;
        port baseSupport : SupportInterface;
        port topSupport : SupportInterface;
    }

    part def SupportFrame {
        attribute height : LengthValue;
        attribute baseWidth : LengthValue;
        attribute frameMass : MassValue;
        attribute maxLoadCapacity : MassValue;
        port groundConnection : SupportInterface;
        port rampMount : SupportInterface;
    }

    part def ForceApplicator {
        attribute appliedForce : ForceValue;
        attribute forceDirection : AngleValue;
        port loadInterface : MechanicalInterface;
    }

    part def SafetyBrake {
        attribute brakingForce : ForceValue;
        attribute engaged : Boolean;
        port controlInterface : ControlInterface;
    }

    constraint def MechanicalAdvantageConstraint {
        in rampLength : LengthValue;
        in rampHeight : LengthValue;
        out advantage : Real;
        advantage == rampLength / rampHeight
    }

    constraint def RequiredForceConstraint {
        in loadMass : MassValue;
        in angle : AngleValue;
        in friction : CoefficientValue;
        in gravity : AccelerationValue;
        out requiredForce : ForceValue;
        requiredForce == loadMass * gravity * (angle + friction * angle)
    }

    constraint def StabilityConstraint {
        in loadMass : MassValue;
        in maxCapacity : MassValue;
        in angle : AngleValue;
        in maxAngle : AngleValue;
        loadMass <= maxCapacity and angle <= maxAngle
    }

    action def CalculateForceRequirement {
        in load : Load;
        in rampAngle : AngleValue;
        in friction : CoefficientValue;
        in g : AccelerationValue;
        out force : ForceValue;

        assert constraint forceCalc : RequiredForceConstraint {
            in loadMass = load.mass;
            in angle = rampAngle;
            in friction = friction;
            in gravity = g;
            out requiredForce = force;
        }
    }

    action def MonitorLoadPosition {
        in load : Load;
        in rampLength : LengthValue;
        out position : LengthValue;
        out currentStatus : LoadStatus;
    }

    action def ApplyForceToLoad {
        in force : ForceValue;
        inout load : Load;
        out acceleration : AccelerationValue;
    }

    action def EngageBrake {
        inout brake : SafetyBrake;
        out brakeStatus : Boolean;
    }

    action def RaiseLoad {
        in targetLoad : Load;
        in rampAngle : AngleValue;
        in friction : CoefficientValue;
        in rampLength : LengthValue;
        in g : AccelerationValue;
        inout brake : SafetyBrake;

        first start;
        then merge checkPosition;

        then action monitor : MonitorLoadPosition {
            in load = targetLoad;
            in rampLength = rampLength;
            out position : LengthValue;
            out currentStatus : LoadStatus;
        }

        then decide;
            if monitor.currentStatus == LoadStatus::atBase then calculateRequired;
            if monitor.currentStatus == LoadStatus::inTransit then continueRaising;
            if monitor.currentStatus == LoadStatus::atTop then secureLoad;

        action calculateRequired : CalculateForceRequirement {
            in load = targetLoad;
            in rampAngle = rampAngle;
            in friction = friction;
            in g = g;
            out force : ForceValue;
        }
        then applyForce;

        action applyForce : ApplyForceToLoad {
            in force = calculateRequired.force;
            inout load = targetLoad;
            out acceleration : AccelerationValue;
        }
        then continueRaising;

        action continueRaising {
            doc /* Continue moving load up the ramp */
        }
        then checkPosition;

        action secureLoad {
            doc /* Secure load at top position */
        }
        then activateBrake;

        action activateBrake : EngageBrake {
            inout brake = brake;
            out brakeStatus : Boolean;
        }
        then done;
    }

    state def LoadMovementStates {
        entry; then idle;

        state idle {
            doc /* Load is stationary at base */
        }
        transition idle_to_positioning
            first idle
            then positioning;

        state positioning {
            doc /* Preparing to raise load */
        }
        transition positioning_to_ascending
            first positioning
            then ascending;

        state ascending {
            doc /* Load is moving up the ramp */
        }
        transition ascending_to_atTop
            first ascending
            then atTop;

        state atTop {
            doc /* Load has reached top position */
        }
        transition atTop_to_secured
            first atTop
            then secured;

        state secured {
            doc /* Load is secured at top */
        }
        transition secured_to_idle
            first secured
            then idle;
    }

    part def InclinedPlane {
        doc /* An inclined plane system that reduces the force required to elevate loads 
             * by distributing the work over a longer distance along an inclined surface. */

        attribute gravity : AccelerationValue = 9.81 [m/s^2];
        attribute mechanicalAdvantage : Real;
        attribute systemEfficiency : Real;

        part ramp : RampSurface {
            attribute :>> length : LengthValue;
            attribute :>> width : LengthValue;
            attribute :>> inclineAngle : AngleValue;
            attribute :>> frictionCoefficient : CoefficientValue;
            attribute :>> surfaceRoughness : LengthValue;
        }

        part frame : SupportFrame {
            attribute :>> height : LengthValue;
            attribute :>> baseWidth : LengthValue;
            attribute :>> frameMass : MassValue;
            attribute :>> maxLoadCapacity : MassValue;
        }

        part forceSystem : ForceApplicator {
            attribute :>> appliedForce : ForceValue;
            attribute :>> forceDirection : AngleValue;
        }

        part brake : SafetyBrake {
            attribute :>> brakingForce : ForceValue;
            attribute :>> engaged : Boolean;
        }

        connect ramp.baseSupport to frame.rampMount;
        connect ramp.topSupport to frame.rampMount;
        connect forceSystem.loadInterface to ramp.loadContact;
        connect brake.controlInterface to ramp.loadContact;

        assert constraint advantageCalc : MechanicalAdvantageConstraint {
            in rampLength = ramp.length;
            in rampHeight = frame.height;
            out advantage = mechanicalAdvantage;
        }

        assert constraint stability : StabilityConstraint {
            in loadMass : MassValue;
            in maxCapacity = frame.maxLoadCapacity;
            in angle = ramp.inclineAngle;
            in maxAngle : AngleValue;
        }

        perform action raiseOperation : RaiseLoad {
            in targetLoad : Load;
            in rampAngle = ramp.inclineAngle;
            in friction = ramp.frictionCoefficient;
            in rampLength = ramp.length;
            in g = gravity;
            inout brake = brake;
        }
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;

    requirement <'REQ-IP-001'> primaryFunction : FunctionalRequirement {
        doc /* The inclined plane system shall reduce the force required to elevate loads 
             * by distributing the lifting work over a longer distance along an inclined surface,
             * thereby providing mechanical advantage to the operator. */
        subject system : InclinedPlane;
    }

    requirement <'REQ-IP-002'> mechanicalAdvantageSpec : PerformanceRequirement {
        doc /* The inclined plane shall provide a mechanical advantage equal to the ratio 
             * of the ramp length to the vertical height. */
        subject system : InclinedPlane;
        assert constraint {
            system.mechanicalAdvantage == system.ramp.length / system.frame.height
        }
    }

    requirement <'REQ-IP-003'> forceReduction : PerformanceRequirement {
        doc /* The applied force required to move a load up the inclined plane shall be 
             * less than the weight of the load, accounting for friction losses. */
        subject system : InclinedPlane;
        assert constraint {
            system.forceSystem.appliedForce < 
                (system.frame.height / system.ramp.length) * 1000 [N]
        }
    }

    requirement <'REQ-IP-004'> angleLimit : SafetyRequirement {
        doc /* The incline angle shall not exceed 30 degrees to ensure safe operation 
             * and prevent uncontrolled sliding. */
        subject system : InclinedPlane;
        assert constraint {
            system.ramp.inclineAngle <= 30.0
        }
    }

    requirement <'REQ-IP-005'> loadCapacity : SafetyRequirement {
        doc /* The support frame shall safely support loads up to the maximum rated capacity 
             * without structural failure. */
        subject system : InclinedPlane;
        assert constraint {
            system.frame.maxLoadCapacity >= 500 [kg]
        }
    }

    requirement <'REQ-IP-006'> frictionControl : PerformanceRequirement {
        doc /* The ramp surface shall maintain a friction coefficient between 0.15 and 0.40 
             * to balance ease of movement with load control. */
        subject system : InclinedPlane;
        assert constraint {
            system.ramp.frictionCoefficient >= 0.15 and system.ramp.frictionCoefficient <= 0.40
        }
    }

    requirement <'REQ-IP-007'> brakingSystem : SafetyRequirement {
        doc /* The safety brake shall provide sufficient braking force to prevent 
             * uncontrolled descent of the load. */
        subject system : InclinedPlane;
        assert constraint {
            system.brake.brakingForce >= 1000 [N]
        }
    }

    part warehouseRamp : InclinedPlane {
        attribute :>> gravity = 9.81 [m/s^2];
        attribute :>> mechanicalAdvantage = 4.0;
        attribute :>> systemEfficiency = 0.85;

        part :>> ramp {
            attribute :>> length = 8.0 [m];
            attribute :>> width = 2.0 [m];
            attribute :>> inclineAngle = 14.04;
            attribute :>> frictionCoefficient = 0.25;
            attribute :>> surfaceRoughness = 0.002 [m];
        }

        part :>> frame {
            attribute :>> height = 2.0 [m];
            attribute :>> baseWidth = 7.75 [m];
            attribute :>> frameMass = 250 [kg];
            attribute :>> maxLoadCapacity = 750 [kg];
        }

        part :>> forceSystem {
            attribute :>> appliedForce = 600 [N];
            attribute :>> forceDirection = 14.04;
        }

        part :>> brake {
            attribute :>> brakingForce = 1500 [N];
            attribute :>> engaged = false;
        }
    }

    satisfy primaryFunction by warehouseRamp;
    satisfy mechanicalAdvantageSpec by warehouseRamp;
    satisfy forceReduction by warehouseRamp;
    satisfy angleLimit by warehouseRamp;
    satisfy loadCapacity by warehouseRamp;
    satisfy frictionControl by warehouseRamp;
    satisfy brakingSystem by warehouseRamp;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import InclinedPlaneSystem::*;

    part testSubject : RampSurface {
        exhibit state sm : LoadMovementStates;
    }

    action orchestrator {
        item testLoad : Load {
            attribute mass : MassValue;
            attribute position : LengthValue;
            attribute status = LoadStatus::atBase;
        }
        attribute testRampAngle : AngleValue = 0.0;
        attribute testFriction : CoefficientValue = 0.0;
        attribute testG : AccelerationValue;
        action calculateRequiredProbe : CalculateForceRequirement {
            in load = testLoad;
            in rampAngle = testRampAngle;
            in friction = testFriction;
            in g = testG;
        }
        first calculateRequiredProbe;
    }
}
