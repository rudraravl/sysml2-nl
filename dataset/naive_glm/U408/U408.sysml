package GSXS_Motorcycle_Model {

    import ScalarValues::*;
    import ISQ::*;
    import ISQMass::*;
    import ISQVolume::*;
    import ISQEnergyTime::*;
    import ISQForce::*;
    import ISQLength::*;
    import ISQSpeed::*;
    import ISQAngle::*;
    import ISQTorque::*;

    // ===== Value Types =====

    value def TorsionalStiffnessValue :> Real {
        :>> unit = "N*m/deg";
    }

    value def VibrationLevel :> Real {
        :>> unit = "m/s^2";
    }

    // ===== Item Types =====

    item def Fuel {
        attribute fuelType : String = "premium_gasoline";
        attribute octaneRating : Integer = 91;
    }

    item def Air;

    item def DriveTorque {
        attribute magnitude : TorqueValue;
    }

    item def Vibration {
        attribute frequency : Real;
        attribute amplitude : Real;
    }

    item def ThrottleCommand {
        attribute position : Real = 0;
    }

    item def BrakeCommand {
        attribute pressure : Real = 0;
    }

    item def SteeringCommand {
        attribute angle : Angle;
    }

    item def RiderFeedback {
        attribute handlebarForce : Force;
        attribute footpegVibration : VibrationLevel;
        attribute seatVibration : VibrationLevel;
    }

    item def RoadForce :> Force;

    // ===== Port Definitions =====

    port def MechanicalMountPort {
        out item vibration : Vibration;
        in item structuralForce : Force;
    }

    port def PowerPort {
        out item driveTorque : DriveTorque;
    }

    port def WheelPort {
        in item roadForce : RoadForce;
        out item tractionForce : Force;
        in item driveTorque : DriveTorque;
        in item brakingForce : Force;
    }

    port def BrakePort {
        out item brakingForce : Force;
    }

    port def RiderCommandPort {
        out item throttle : ThrottleCommand;
        out item brake : BrakeCommand;
        out item steering : SteeringCommand;
    }

    port def RiderFeedbackPort {
        out item feedback : RiderFeedback;
    }

    // ===== Requirement Definitions =====

    requirement def StructuralIntegrityReq {
        doc /* The frame must support a maximum load of 195 kg */
        subject frame : Frame;
        constraint { frame.maxLoadCapacity >= 195 [kg] }
    }

    requirement def FrameMassReq {
        doc /* Frame mass should be just over 14 kg to optimize handling */
        subject frame : Frame;
        constraint { frame.mass > 14 [kg] and frame.mass < 15 [kg] }
    }

    requirement def EngineDisplacementReq {
        doc /* Engine displacement is 749cc */
        subject engine : Engine;
        constraint { engine.displacement == 749 [mL] }
    }

    requirement def VibrationDampeningReq {
        doc /* Vibrations from engine must be dampened for comfortable ride */
        subject frame : Frame;
        constraint { frame.vibrationDampening >= 0.7 }
    }

    requirement def SingleRiderReq {
        doc /* Designed for safe transportation of a single rider */
        subject vehicle : Motorcycle;
        constraint { vehicle.maxRiders == 1 }
    }

    requirement def StableHandlingReq {
        doc /* Suspension must maintain tire contact with road for stability */
        subject frontSusp : FrontSuspension;
        subject rearSusp : RearSuspension;
        constraint { frontSusp.travel > 100 [mm] and rearSusp.travel > 100 [mm] }
    }

    // ===== Part Definitions =====

    part def Frame {
        attribute material : String = "high_tensile_steel_alloy";
        attribute torsionalStiffness : TorsionalStiffnessValue = 1200;
        attribute maxLoadCapacity : Mass = 195 [kg];
        attribute mass : Mass = 14.2 [kg];
        attribute vibrationDampening : Real = 0.85;

        port engineMount : ~MechanicalMountPort;
        port frontSuspensionMount : ~MechanicalMountPort;
        port rearSuspensionMount : ~MechanicalMountPort;
        port riderStationMount : ~MechanicalMountPort;
    }

    part def Engine {
        attribute configuration : String = "inline_4_DOHC";
        attribute displacement : Volume = 749 [mL];
        attribute maxPower : Power = 70 [kW];
        attribute maxTorque : TorqueValue = 60 [N*m];
        attribute mass : Mass = 55 [kg];
        attribute coolingSystem : String = "liquid_cooled";

        port frameMount : MechanicalMountPort;
        port powerOutput : PowerPort;

        action generatePower {
            in item fuel : Fuel;
            in item air : Air;
            out item driveTorque : DriveTorque;
        }

        action combust {
            in item fuel : Fuel;
            in item air : Air;
            out item driveTorque : DriveTorque;
            out item vibration : Vibration;
        }
    }

    part def FrontFork {
        attribute type : String = "inverted_telescopic";
        attribute travel : Length = 120 [mm];
        attribute springRate : Real = 9.5;
        attribute dampingAdjustable : Boolean = true;

        port frameMount : MechanicalMountPort;
        port wheelMount : WheelPort;
    }

    part def FrontSuspension {
        part leftFork : FrontFork;
        part rightFork : FrontFork;

        port frameMount : MechanicalMountPort;
        port wheelMount : WheelPort;
    }

    part def Swingarm {
        attribute material : String = "aluminum_alloy";
        attribute length : Length = 580 [mm];

        port frameMount : MechanicalMountPort;
        port wheelMount : WheelPort;
    }

    part def ShockAbsorber {
        attribute type : String = "monoshock_gas_charged";
        attribute travel : Length = 130 [mm];
        attribute dampingRate : Real = 8.0;
        attribute preloadAdjustable : Boolean = true;

        port topMount : MechanicalMountPort;
        port bottomMount : WheelPort;
    }

    part def RearSuspension {
        part swingarm : Swingarm;
        part shockAbsorber : ShockAbsorber;

        port frameMount : MechanicalMountPort;
        port wheelMount : WheelPort;
    }

    part def Wheel {
        attribute diameter : Length = 430 [mm];
        attribute tireWidth : Length = 180 [mm];
        attribute tireType : String = "radial_sport";

        port hubMount : WheelPort;
    }

    part def Seat {
        attribute height : Length = 810 [mm];
        attribute paddingType : String = "high_density_foam";

        port mount : MechanicalMountPort;
    }

    part def Handlebar {
        attribute width : Length = 800 [mm];
        attribute rise : Length = 30 [mm];

        port mount : MechanicalMountPort;
        port riderInterface : ~RiderCommandPort;
    }

    part def Footpeg {
        attribute position : Length = 300 [mm];
        attribute material : String = "steel";

        port mount : MechanicalMountPort;
    }

    part def RiderStation {
        part seat : Seat;
        part handlebar : Handlebar;
        part leftFootpeg : Footpeg;
        part rightFootpeg : Footpeg;

        port frameMount : MechanicalMountPort;
        port commandOutput : RiderCommandPort;
        port riderFeedback : RiderFeedbackPort;
    }

    part def BrakeSystem {
        attribute frontBrakeType : String = "dual_hydraulic_disc";
        attribute rearBrakeType : String = "single_hydraulic_disc";
        attribute frontDiscDiameter : Length = 310 [mm];
        attribute rearDiscDiameter : Length = 250 [mm];

        port controlInput : ~RiderCommandPort;
        port frontBrakeOutput : BrakePort;
        port rearBrakeOutput : BrakePort;
    }

    // ===== State Machine Definition =====

    state def MotorcycleStates {

        state parked {
            entry action {
                /* Motorcycle is stationary, engine off, side stand down */
            }
            transition to starting
                when startCommand;
        }

        state starting {
            entry action {
                /* Systems initialize, fuel pump primes, engine cranks */
            }
            transition to moving
                when engineStarted;
        }

        state moving {
            entry action {
                /* Motorcycle is in motion, clutch engaged, gear selected */
            }

            state accelerating {
                entry action {
                    /* Throttle applied, speed increasing */
                }
                transition to cruising
                    when targetSpeedReached;
            }

            state cruising {
                entry action {
                    /* Steady speed maintained, throttle steady */
                }
                transition to decelerating
                    when brakeOrThrottleReleased;
            }

            state decelerating {
                entry action {
                    /* Speed reducing, brakes or engine braking applied */
                }
                transition to stopping
                    when speedBelowThreshold;
            }

            transition first to accelerating;
        }

        state stopping {
            entry action {
                /* Coming to complete stop, brakes fully applied */
            }
            transition to parked
                when fullyStopped;
        }

        transition first to parked;
    }

    // ===== Motorcycle Part Definition =====

    part def Motorcycle {
        attribute make : String = "Suzuki";
        attribute model : String = "GSX-S";
        attribute modelYear : Integer = 2024;
        attribute maxRiders : Integer = 1;
        attribute topSpeed : Speed = 200 [km/h];
        attribute curbMass : Mass = 214 [kg];

        part frame : Frame;
        part engine : Engine;
        part frontSuspension : FrontSuspension;
        part rearSuspension : RearSuspension;
        part frontWheel : Wheel;
        part rearWheel : Wheel;
        part riderStation : RiderStation;
        part brakeSystem : BrakeSystem;

        connection engineToFrame connect engine.frameMount to frame.engineMount;
        connection frontSuspToFrame connect frontSuspension.frameMount to frame.frontSuspensionMount;
        connection rearSuspToFrame connect rearSuspension.frameMount to frame.rearSuspensionMount;
        connection frontWheelToSusp connect frontSuspension.wheelMount to frontWheel.hubMount;
        connection rearWheelToSusp connect rearSuspension.wheelMount to rearWheel.hubMount;
        connection riderStationToFrame connect riderStation.frameMount to frame.riderStationMount;
        connection powerToRearWheel connect engine.powerOutput to rearWheel.hubMount;
        connection brakeToFrontWheel connect brakeSystem.frontBrakeOutput to frontWheel.hubMount;
        connection brakeToRearWheel connect brakeSystem.rearBrakeOutput to rearWheel.hubMount;
        connection riderCommandsToBrake connect riderStation.commandOutput to brakeSystem.controlInput;

        behavior stateMachine : MotorcycleStates;
    }

    // ===== Part Usage =====

    part gsxs : Motorcycle;

    // ===== Requirement Usages =====

    requirement req_structural : StructuralIntegrityReq {
        subject frame = gsxs.frame;
    }

    requirement req_frameMass : FrameMassReq {
        subject frame = gsxs.frame;
    }

    requirement req_engineDisplacement : EngineDisplacementReq {
        subject engine = gsxs.engine;
    }

    requirement req_vibrationDampening : VibrationDampeningReq {
        subject frame = gsxs.frame;
    }

    requirement req_singleRider : SingleRiderReq {
        subject vehicle = gsxs;
    }

    requirement req_stableHandling : StableHandlingReq {
        subject frontSusp = gsxs.frontSuspension;
        subject rearSusp = gsxs.rearSuspension;
    }

    // ===== Satisfaction Relationships =====

    satisfy req_structural by gsxs.frame;
    satisfy req_frameMass by gsxs.frame;
    satisfy req_engineDisplacement by gsxs.engine;
    satisfy req_vibrationDampening by gsxs.frame;
    satisfy req_singleRider by gsxs;
    satisfy req_stableHandling by gsxs.frontSuspension, gsxs.rearSuspension;
}
