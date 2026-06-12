package ContinuousTrackSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MassValue :> ISQ::mass {
        :>> unit = SI::kg;
    }

    attribute def LengthValue :> ISQ::length {
        :>> unit = SI::m;
    }

    attribute def SpeedValue :> ISQ::speed {
        :>> unit = SI::m / SI::s;
    }

    attribute def ForceValue :> ISQ::force {
        :>> unit = SI::N;
    }

    attribute def TorqueValue :> ISQ::torque {
        :>> unit = SI::N * SI::m;
    }

    attribute def PowerValue :> ISQ::power {
        :>> unit = SI::W;
    }

    attribute def PressureValue :> ISQ::pressure {
        :>> unit = SI::Pa;
    }

    attribute def AngleValue :> ISQ::planeAngle {
        :>> unit = SI::rad;
    }

    attribute def RatioValue :> ScalarValues::Real;

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        :>> unit = SI::K;
    }

    item def MechanicalTorque {
        attribute magnitude : TorqueValue;
        attribute rotationalSpeed : ISQ::angularVelocity;
        attribute direction : Integer;
    }

    item def TrackGroundForce {
        attribute longitudinalForce : ForceValue;
        attribute normalForce : ForceValue;
        attribute lateralForce : ForceValue;
        attribute slipRatio : RatioValue;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute power : PowerValue;
    }

    item def HydraulicPressure {
        attribute pressure : PressureValue;
        attribute flowRate : ISQ::volumeFlowRate;
    }

    item def MotionCommand {
        attribute commandedSpeed : SpeedValue;
        attribute commandedYawRate : ISQ::angularVelocity;
        attribute emergencyStop : Boolean;
    }

    item def TrackHealthData {
        attribute trackTension : ForceValue;
        attribute beltTemperature : TemperatureValue;
        attribute lugWearRatio : RatioValue;
        attribute detectedDerailment : Boolean;
    }

    item def VehicleMotionEstimate {
        attribute forwardSpeed : SpeedValue;
        attribute yawRate : ISQ::angularVelocity;
        attribute heading : AngleValue;
        attribute distanceTravelled : LengthValue;
    }

    port def TorquePort {
        out item torque : MechanicalTorque;
    }

    port def TorqueReceiverPort {
        in item torque : MechanicalTorque;
    }

    port def GroundContactPort {
        out item groundForce : TrackGroundForce;
    }

    port def ElectricalPowerPort {
        in item powerIn : ElectricalPower;
    }

    port def HydraulicPort {
        in item hydraulicSupply : HydraulicPressure;
    }

    port def CommandPort {
        in item command : MotionCommand;
    }

    port def HealthPort {
        out item health : TrackHealthData;
    }

    port def MotionEstimatePort {
        out item motion : VehicleMotionEstimate;
    }

    part def ContinuousTrack {
        attribute trackWidth : LengthValue = 0.55 [SI::m];
        attribute groundContactLength : LengthValue = 2.80 [SI::m];
        attribute beltMass : MassValue = 420 [SI::kg];
        attribute nominalTension : ForceValue = 36000 [SI::N];
        attribute maximumAllowableTension : ForceValue = 52000 [SI::N];
        attribute terrainContactPressure : PressureValue;
        attribute tractionCoefficient : RatioValue;
        attribute currentSlipRatio : RatioValue;
        attribute currentTemperature : TemperatureValue;

        port driveTorqueIn : TorqueReceiverPort;
        port groundInterface : GroundContactPort;
        port healthOut : HealthPort;

        part driveSprocket {
            attribute pitchRadius : LengthValue = 0.34 [SI::m];
            attribute toothCount : Integer = 17;
        }

        part idlerWheel {
            attribute adjustmentStroke : LengthValue = 0.18 [SI::m];
        }

        part roadWheels[6] {
            attribute wheelRadius : LengthValue = 0.31 [SI::m];
            attribute wheelLoad : ForceValue;
        }

        part returnRollers[3] {
            attribute wheelRadius : LengthValue = 0.16 [SI::m];
        }

        action def ConvertTorqueToTrackForce {
            in item torqueIn : MechanicalTorque;
            out item forceOut : TrackGroundForce;

            attribute effectiveRadius : LengthValue = 0.34 [SI::m];
            attribute computedLongitudinalForce : ForceValue;

            action computeForce {
                computedLongitudinalForce = torqueIn.magnitude / effectiveRadius;
            }

            action limitBySlip {
                forceOut.longitudinalForce = computedLongitudinalForce;
                forceOut.slipRatio = currentSlipRatio;
            }
        }

        action convertTorque : ConvertTorqueToTrackForce;

        bind driveTorqueIn.torque = convertTorque.torqueIn;
        bind convertTorque.forceOut = groundInterface.groundForce;
    }

    part def TrackTensioner {
        attribute commandedTension : ForceValue = 36000 [SI::N];
        attribute measuredTension : ForceValue;
        attribute minimumTension : ForceValue = 28000 [SI::N];
        attribute maximumTension : ForceValue = 52000 [SI::N];

        port hydraulicIn : HydraulicPort;
        port healthOut : HealthPort;

        action def MaintainTrackTension {
            in item pressureSupply : HydraulicPressure;
            out attribute resultingTension : ForceValue;

            action regulatePressure {
                resultingTension = commandedTension;
            }
        }

        action maintainTension : MaintainTrackTension;

        bind hydraulicIn.hydraulicSupply = maintainTension.pressureSupply;
        bind measuredTension = maintainTension.resultingTension;
    }

    part def ElectricTractionDrive {
        attribute peakPower : PowerValue = 180000 [SI::W];
        attribute continuousPower : PowerValue = 95000 [SI::W];
        attribute maximumOutputTorque : TorqueValue = 7200 [SI::N * SI::m];
        attribute gearReductionRatio : RatioValue = 24.5;

        port electricalIn : ElectricalPowerPort;
        port torqueOut : TorquePort;

        action def GenerateTrackTorque {
            in item electricalInput : ElectricalPower;
            in attribute requestedTorque : TorqueValue;
            out item deliveredTorque : MechanicalTorque;

            action torqueControl {
                deliveredTorque.magnitude = requestedTorque;
                deliveredTorque.direction = 1;
            }
        }

        action generateTorque : GenerateTrackTorque;

        bind electricalIn.powerIn = generateTorque.electricalInput;
        bind generateTorque.deliveredTorque = torqueOut.torque;
    }

    part def PowerSubsystem {
        attribute storedEnergy : ISQ::energy;
        attribute nominalBusVoltage : ISQ::electricPotential = 650 [SI::V];
        attribute maximumDischargePower : PowerValue = 260000 [SI::W];

        port leftDrivePower : ElectricalPowerPort;
        port rightDrivePower : ElectricalPowerPort;
    }

    part def MotionController {
        attribute targetSpeed : SpeedValue;
        attribute targetYawRate : ISQ::angularVelocity;
        attribute leftTorqueCommand : TorqueValue;
        attribute rightTorqueCommand : TorqueValue;
        attribute tractionLimitRatio : RatioValue = 0.85;

        port commandIn : CommandPort;
        port motionEstimateOut : MotionEstimatePort;

        action def DifferentialTrackControl {
            in item driverCommand : MotionCommand;
            out attribute leftRequestedTorque : TorqueValue;
            out attribute rightRequestedTorque : TorqueValue;

            attribute baseTorque : TorqueValue;
            attribute steeringTorqueDelta : TorqueValue;

            action computeBaseTorque {
                baseTorque = driverCommand.commandedSpeed * 4000 [SI::N];
            }

            action computeSteeringDifferential {
                steeringTorqueDelta = driverCommand.commandedYawRate * 1600 [SI::N * SI::m * SI::s / SI::rad];
            }

            action allocateTorque {
                leftRequestedTorque = baseTorque - steeringTorqueDelta;
                rightRequestedTorque = baseTorque + steeringTorqueDelta;
            }
        }

        action differentialControl : DifferentialTrackControl;

        bind commandIn.command = differentialControl.driverCommand;
        bind leftTorqueCommand = differentialControl.leftRequestedTorque;
        bind rightTorqueCommand = differentialControl.rightRequestedTorque;
    }

    part def ContinuousTrackVehicle {
        attribute vehicleMass : MassValue = 7800 [SI::kg];
        attribute maximumSpeed : SpeedValue = 12.0 [SI::m / SI::s];
        attribute minimumTurningRadius : LengthValue = 0.0 [SI::m];
        attribute ratedGradeability : AngleValue = 0.524 [SI::rad];
        attribute groundPressure : PressureValue;
        attribute payloadCapacity : MassValue = 1800 [SI::kg];

        port operatorCommand : CommandPort;
        port vehicleMotion : MotionEstimatePort;

        part powerSubsystem : PowerSubsystem;

        part controller : MotionController;

        part leftDrive : ElectricTractionDrive;
        part rightDrive : ElectricTractionDrive;

        part leftTrack : ContinuousTrack {
            :>> trackWidth = 0.55 [SI::m];
            :>> groundContactLength = 2.80 [SI::m];
        }

        part rightTrack : ContinuousTrack {
            :>> trackWidth = 0.55 [SI::m];
            :>> groundContactLength = 2.80 [SI::m];
        }

        part leftTensioner : TrackTensioner;
        part rightTensioner : TrackTensioner;

        part chassis {
            attribute structuralMass : MassValue = 2300 [SI::kg];
            attribute torsionalStiffness : ISQ::torquePerAngle;
        }

        part suspension {
            attribute verticalTravel : LengthValue = 0.34 [SI::m];
            attribute dampingCoefficient : ISQ::mechanicalImpedance;
        }

        connect operatorCommand to controller.commandIn;
        connect controller.motionEstimateOut to vehicleMotion;

        connect powerSubsystem.leftDrivePower to leftDrive.electricalIn;
        connect powerSubsystem.rightDrivePower to rightDrive.electricalIn;

        connect leftDrive.torqueOut to leftTrack.driveTorqueIn;
        connect rightDrive.torqueOut to rightTrack.driveTorqueIn;

        bind leftDrive.generateTorque.requestedTorque = controller.leftTorqueCommand;
        bind rightDrive.generateTorque.requestedTorque = controller.rightTorqueCommand;

        action def ProvideTrackedMobility {
            in item command : MotionCommand;
            out item motion : VehicleMotionEstimate;

            action receiveCommand;
            action computeDifferentialTrackTorque;
            action driveContinuousTracks;
            action createGroundReactionForces;
            action estimateVehicleMotion;

            first start then receiveCommand;
            then computeDifferentialTrackTorque;
            then driveContinuousTracks;
            then createGroundReactionForces;
            then estimateVehicleMotion;
            then done;
        }

        action primaryFunction : ProvideTrackedMobility;

        bind operatorCommand.command = primaryFunction.command;
        bind primaryFunction.motion = vehicleMotion.motion;

        state def OperatingStateMachine {
            state Off;
            state Initializing;
            state Ready;
            state Propelling;
            state PivotTurning;
            state Braking;
            state Faulted;
            state EmergencyStop;

            transition first Off;
            transition Off_to_Initializing
                first Off
                then Initializing;

            transition Initializing_to_Ready
                first Initializing
                then Ready
                if leftTrack.healthOut.health.detectedDerailment == false and rightTrack.healthOut.health.detectedDerailment == false;

            transition Ready_to_Propelling
                first Ready
                then Propelling
                if operatorCommand.command.commandedSpeed > 0 [SI::m / SI::s];

            transition Propelling_to_PivotTurning
                first Propelling
                then PivotTurning
                if operatorCommand.command.commandedSpeed == 0 [SI::m / SI::s] and operatorCommand.command.commandedYawRate != 0 [SI::rad / SI::s];

            transition Propelling_to_Braking
                first Propelling
                then Braking
                if operatorCommand.command.commandedSpeed < vehicleMotion.motion.forwardSpeed;

            transition Braking_to_Ready
                first Braking
                then Ready
                if vehicleMotion.motion.forwardSpeed == 0 [SI::m / SI::s];

            transition Any_to_EmergencyStop
                first Ready
                then EmergencyStop
                if operatorCommand.command.emergencyStop == true;

            transition FaultDetection
                first Propelling
                then Faulted
                if leftTrack.healthOut.health.detectedDerailment == true or rightTrack.healthOut.health.detectedDerailment == true;
        }

        state operatingStates : OperatingStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject trackedSystem : ContinuousTrackVehicle;

        require constraint {
            trackedSystem.primaryFunction is performed;
        }

        doc /* The system shall provide high-level mobility by applying controlled torque to left and right continuous tracks so that track-ground interaction propels, brakes, and steers the vehicle over low-bearing or uneven terrain. */
    }

    requirement def ContinuousTrackTractionRequirement {
        subject trackedSystem : ContinuousTrackVehicle;

        require constraint {
            trackedSystem.leftTrack.currentSlipRatio <= 0.25 and
            trackedSystem.rightTrack.currentSlipRatio <= 0.25
        }

        doc /* Each continuous track shall maintain controlled slip during commanded propulsion to preserve tractive efficiency and terrain mobility. */
    }

    requirement def GroundPressureRequirement {
        subject trackedSystem : ContinuousTrackVehicle;

        require constraint {
            trackedSystem.groundPressure <= 65000 [SI::Pa]
        }

        doc /* The continuous track contact area shall distribute vehicle mass so that nominal static ground pressure does not exceed 65 kPa. */
    }

    requirement def DifferentialSteeringRequirement {
        subject trackedSystem : ContinuousTrackVehicle;

        require constraint {
            trackedSystem.controller.leftTorqueCommand != trackedSystem.controller.rightTorqueCommand
        }

        doc /* The system shall steer by commanding differential torque between the left and right continuous tracks. */
    }

    requirement def TrackTensionRequirement {
        subject trackedSystem : ContinuousTrackVehicle;

        require constraint {
            trackedSystem.leftTensioner.measuredTension >= trackedSystem.leftTensioner.minimumTension and
            trackedSystem.leftTensioner.measuredTension <= trackedSystem.leftTensioner.maximumTension and
            trackedSystem.rightTensioner.measuredTension >= trackedSystem.rightTensioner.minimumTension and
            trackedSystem.rightTensioner.measuredTension <= trackedSystem.rightTensioner.maximumTension
        }

        doc /* Track tension shall remain within allowable limits to prevent excessive wear, loss of traction, or derailment. */
    }

    requirement def EmergencyStopRequirement {
        subject trackedSystem : ContinuousTrackVehicle;

        require constraint {
            trackedSystem.operatorCommand.command.emergencyStop == true implies
            trackedSystem.controller.leftTorqueCommand == 0 [SI::N * SI::m] and
            trackedSystem.controller.rightTorqueCommand == 0 [SI::N * SI::m]
        }

        doc /* On emergency stop command, drive torque to both continuous tracks shall be removed. */
    }

    satisfy PrimaryFunctionRequirement by ContinuousTrackVehicle::primaryFunction;
    satisfy ContinuousTrackTractionRequirement by ContinuousTrackVehicle::leftTrack;
    satisfy ContinuousTrackTractionRequirement by ContinuousTrackVehicle::rightTrack;
    satisfy GroundPressureRequirement by ContinuousTrackVehicle;
    satisfy DifferentialSteeringRequirement by ContinuousTrackVehicle::controller;
    satisfy TrackTensionRequirement by ContinuousTrackVehicle::leftTensioner;
    satisfy TrackTensionRequirement by ContinuousTrackVehicle::rightTensioner;
    satisfy EmergencyStopRequirement by ContinuousTrackVehicle::controller;

    part trackedMobilitySystem : ContinuousTrackVehicle;
}