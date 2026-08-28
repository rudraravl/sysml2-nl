package WarehouseRampSystem {

    doc /* This model describes a warehouse ramp system designed to safely and efficiently
         * move heavy loads to a higher elevation, such as a loading dock or mezzanine.
         * It is a classic inclined plane that reduces the force needed to lift an object
         * by extending the distance over which the force is applied.
         */

    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def LengthValue :> ISQ::length;
    attribute def MassValue :> ISQ::mass;
    attribute def ForceValue :> ISQ::force;
    attribute def AngleValue :> ISQ::planeAngle;
    attribute def FrictionCoeff :> ScalarValues::Real;

    item def Load {
        attribute mass : MassValue;
        attribute positionOnRamp : LengthValue;
    }

    port def ForceFlowPort {
        attribute force : ForceValue;
    }

    port def ControlSignalPort {
        attribute engage : Boolean;
    }

    part def SupportFrame {
        attribute height : LengthValue;
        attribute maxLoadCapacity : MassValue;
        attribute materialStrength : ForceValue;
    }

    part def RampSurface {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute inclineAngle : AngleValue;
        attribute frictionCoeff : FrictionCoeff;
        port in forceIn : ForceFlowPort;
        port in brakeControl : ControlSignalPort;
    }

    part def ForceApplicationMechanism {
        attribute maxForce : ForceValue;
        attribute appliedForce : ForceValue;
        port out forceOutput : ForceFlowPort;
    }

    part def BrakeSystem {
        attribute brakeForce : ForceValue;
        attribute isEngaged : Boolean;
        port out controlOutput : ControlSignalPort;
    }

    state machine def LoadMovementStates {
        state AtBase;
        state Ascending;
        state AtTop;
        state Secured;

        transition from AtBase to Ascending;
        transition from Ascending to AtTop;
        transition from AtTop to Secured;
        transition from Secured to AtBase;
    }

    part def WarehouseRamp {
        attribute rampLength : LengthValue = 8 [m];
        attribute rampHeight : LengthValue = 2 [m];
        attribute maxLoadCapacity : MassValue = 750 [kg];
        attribute maxInclineAngle : AngleValue = 30 [deg];
        attribute inclineAngle : AngleValue = 14.5 [deg];

        part supportFrame : SupportFrame {
            attribute :>> height = rampHeight;
            attribute :>> maxLoadCapacity = 750 [kg];
            attribute :>> materialStrength = 20000 [N];
        }

        part rampSurface : RampSurface {
            attribute :>> length = rampLength;
            attribute :>> width = 2.5 [m];
            attribute :>> inclineAngle = 14.5 [deg];
            attribute :>> frictionCoeff = 0.15;
        }

        part forceMechanism : ForceApplicationMechanism {
            attribute :>> maxForce = 5000 [N];
            attribute :>> appliedForce = 0 [N];
        }

        part brake : BrakeSystem {
            attribute :>> brakeForce = 8000 [N];
            attribute :>> isEngaged = false;
        }

        state machine loadMovement : LoadMovementStates;

        assert constraint SafeInclineAngle {
            rampSurface.inclineAngle <= maxInclineAngle
        }
    }

    package RampRequirements {
        requirement <'REQ-001'> MaxLoadCapacity {
            doc /* The warehouse ramp shall support loads up to 750 kg. */
            subject ramp : WarehouseRampSystem::WarehouseRamp;
            assert constraint {
                ramp.maxLoadCapacity <= 750 [kg]
            }
        }

        requirement <'REQ-002'> RampDimensions {
            doc /* The ramp shall be 8 m long and raise loads by 2 m. */
            subject ramp : WarehouseRampSystem::WarehouseRamp;
            assert constraint {
                ramp.rampLength == 8 [m] and ramp.rampHeight == 2 [m]
            }
        }

        requirement <'REQ-003'> SafeInclineLimit {
            doc /* The ramp incline angle shall not exceed 30 degrees. */
            subject ramp : WarehouseRampSystem::WarehouseRamp;
            assert constraint {
                ramp.inclineAngle <= 30 [deg]
            }
        }

        requirement <'REQ-004'> BrakeHoldingCapability {
            doc /* The brake shall hold the load securely at any point on the ramp. */
            subject brake : WarehouseRampSystem::BrakeSystem;
            assert constraint {
                brake.brakeForce >= 2000 [N]
            }
        }

        requirement <'REQ-005'> ForceApplication {
            doc /* A force mechanism shall apply sufficient force to overcome gravity and friction. */
            subject forceMech : WarehouseRampSystem::ForceApplicationMechanism;
            assert constraint {
                forceMech.maxForce >= 3000 [N]
            }
        }

        requirement <'REQ-006'> OperationalStates {
            doc /* The system shall transition through states: AtBase, Ascending, AtTop, Secured. */
            subject ramp : WarehouseRampSystem::WarehouseRamp;
        }

        requirement <'REQ-007'> SurfaceFriction {
            doc /* The ramp surface friction shall balance ease of movement with control. */
            subject surface : WarehouseRampSystem::RampSurface;
            assert constraint {
                surface.frictionCoeff >= 0.1 and surface.frictionCoeff <= 0.3
            }
        }
    }

    part rampSystem : WarehouseRamp {
        part load : Load {
            attribute mass = 750 [kg];
            attribute positionOnRamp = 0 [m];
        }

        flow forceMechanism.forceOutput to rampSurface.forceIn;
        flow brake.controlOutput to rampSurface.brakeControl;
    }

    satisfy RampRequirements::MaxLoadCapacity by rampSystem;
    satisfy RampRequirements::RampDimensions by rampSystem;
    satisfy RampRequirements::SafeInclineLimit by rampSystem;
    satisfy RampRequirements::BrakeHoldingCapability by rampSystem.brake;
    satisfy RampRequirements::ForceApplication by rampSystem.forceMechanism;
    satisfy RampRequirements::OperationalStates by rampSystem.loadMovement;
    satisfy RampRequirements::SurfaceFriction by rampSystem.rampSurface;
}
