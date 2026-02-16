package SlipFactorControlSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;

    attribute def SlipRatio :> Real {
        doc /* Dimensionless ratio representing the relative difference between 
             * theoretical and actual velocity in a traction or transmission system.
             * Typical range: 0.0 (no slip) to 1.0 (complete slip).
             */
    }

    attribute def RotationalSpeedValue :> AngularVelocityValue;
    attribute def LinearVelocityValue :> SpeedValue;
    attribute def TorqueValue :> TorqueMagnitude;
    attribute def ForceValue :> ForceMagnitude;
    attribute def LengthValue :> LengthMagnitude;
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def PressureValue :> PressureMagnitude;

    item def SensorData {
        attribute timestamp : Real;
        attribute valid : Boolean;
    }

    item def SlipMeasurement :> SensorData {
        attribute slipValue : SlipRatio;
        attribute confidence : Real;
    }

    item def VelocityMeasurement :> SensorData {
        attribute wheelSpeed : RotationalSpeedValue;
        attribute vehicleSpeed : LinearVelocityValue;
    }

    item def TorqueCommand {
        attribute requestedTorque : TorqueValue;
        attribute rampRate : Real;
    }

    port def SlipSensorPort {
        out measurement : SlipMeasurement;
    }

    port def VelocitySensorPort {
        out velocityData : VelocityMeasurement;
    }

    port def TorqueControlPort {
        in command : TorqueCommand;
    }

    port def DiagnosticPort {
        out status : Real;
        out temperature : TemperatureValue;
    }

    part def WheelAssembly {
        attribute radius : LengthValue;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute appliedTorque : TorqueValue;
        attribute contactPressure : PressureValue;
        attribute surfaceTemperature : TemperatureValue;

        part tire {
            attribute treadDepth : LengthValue;
            attribute stiffness : Real;
        }

        part hub {
            attribute bearingTemp : TemperatureValue;
        }

        port mechanicalInterface {
            attribute transmittedForce : ForceValue;
        }
    }

    part def VelocitySensor {
        attribute sampleRate : Real;
        attribute accuracy : Real;

        port wheelSpeedOut : VelocitySensorPort;
        port vehicleSpeedOut : VelocitySensorPort;
    }

    part def SlipEstimator {
        attribute wheelRadius : LengthValue;
        attribute currentSlip : SlipRatio;

        port velocityIn : VelocitySensorPort;
        port slipOut : SlipSensorPort;

        perform action estimateSlip : SlipEstimationAction;
    }

    part def TractionController {
        attribute targetSlip : SlipRatio;
        attribute maxTorque : TorqueValue;
        attribute minTorque : TorqueValue;
        attribute controlGain : Real;
        attribute integralGain : Real;
        attribute derivativeGain : Real;
        attribute errorIntegral : Real;
        attribute previousError : Real;

        port slipInput : SlipSensorPort;
        port torqueOutput : TorqueControlPort;
        port diagnosticOut : DiagnosticPort;

        perform action controlTraction : TractionControlAction;
        exhibit state controlStateMachine : TractionControlStateMachine;
    }

    part def TorqueActuator {
        attribute currentTorque : TorqueValue;
        attribute maxRate : Real;
        attribute position : Real;
        attribute actuatorTemp : TemperatureValue;

        port commandIn : TorqueControlPort;
        port mechanicalOut {
            attribute outputTorque : TorqueValue;
        }

        perform action applyTorque : TorqueApplicationAction;
    }

    part def PowertrainUnit {
        attribute inputPower : PowerValue;
        attribute outputPower : PowerValue;
        attribute efficiency : Real;
        attribute operatingTemp : TemperatureValue;

        part gearbox {
            attribute ratio : Real;
            attribute oilTemp : TemperatureValue;
        }

        part differential {
            attribute lockingFactor : Real;
        }
    }

    action def SlipEstimationAction {
        in wheelSpeed : RotationalSpeedValue;
        in vehicleSpeed : LinearVelocityValue;
        in wheelRadius : LengthValue;
        out estimatedSlip : SlipRatio;

        first start;
        then action calculateWheelVelocity {
            in speed = wheelSpeed;
            in radius = wheelRadius;
            out wheelLinearVelocity : LinearVelocityValue;
        }
        then action computeSlip {
            in wheelVel = calculateWheelVelocity.wheelLinearVelocity;
            in vehicleVel = vehicleSpeed;
            out slip : SlipRatio;
        }
        then action validateSlip {
            in slip = computeSlip.slip;
            out validatedSlip : SlipRatio = slip;
        }
        then done;
    }

    action def TractionControlAction {
        in measuredSlip : SlipRatio;
        in targetSlip : SlipRatio;
        in maxTorque : TorqueValue;
        in minTorque : TorqueValue;
        in controlGain : Real;
        out torqueCommand : TorqueValue;

        first start;
        then action calculateError {
            in measured = measuredSlip;
            in target = targetSlip;
            out error : Real = target - measured;
        }
        then decide;
            if calculateError.error > 0.05 then increaseTorque;
            if calculateError.error < -0.05 then decreaseTorque;
            if calculateError.error >= -0.05 and calculateError.error <= 0.05 then maintainTorque;

        action increaseTorque {
            in error = calculateError.error;
            in gain = controlGain;
            in max = maxTorque;
            out torque : TorqueValue;
        }
        then merge outputTorque;

        action decreaseTorque {
            in error = calculateError.error;
            in gain = controlGain;
            in min = minTorque;
            out torque : TorqueValue;
        }
        then outputTorque;

        action maintainTorque {
            out torque : TorqueValue;
        }
        then outputTorque;

        action outputTorque {
            in torque : TorqueValue;
            out finalTorque : TorqueValue = torque;
        }
        then done;
    }

    action def TorqueApplicationAction {
        in commandedTorque : TorqueValue;
        in currentTorque : TorqueValue;
        in maxRate : Real;
        out appliedTorque : TorqueValue;

        first start;
        then action rampTorque {
            in target = commandedTorque;
            in current = currentTorque;
            in rate = maxRate;
            out newTorque : TorqueValue;
        }
        then action updateOutput {
            in torque = rampTorque.newTorque;
            out output : TorqueValue = torque;
        }
        then done;
    }

    state def TractionControlStateMachine {
        entry; then inactive;

        state inactive;
        
        transition inactive_to_monitoring
            first inactive
            accept ActivationRequest
            then monitoring;

        state monitoring;
        
        transition monitoring_to_active
            first monitoring
            then activeControl;

        state activeControl;
        
        transition active_to_monitoring
            first activeControl
            then monitoring;

        transition active_to_emergency
            first activeControl
            then emergencyMode;

        state emergencyMode;
        
        transition emergency_to_inactive
            first emergencyMode
            accept SystemReset
            then inactive;

        transition monitoring_to_inactive
            first monitoring
            accept DeactivationRequest
            then inactive;
    }

    part slipControlSystem {
        doc /* Primary function: Continuously monitor and regulate the slip ratio 
             * between wheel speed and vehicle speed to optimize traction and prevent 
             * wheel spin. The system maintains optimal slip for maximum force transfer 
             * while avoiding loss of control through closed-loop torque modulation.
             */

        attribute systemTargetSlip : SlipRatio = 0.12;
        attribute maxAllowableSlip : SlipRatio = 0.80;
        attribute systemEfficiency : Real;
        attribute totalMass : MassValue;

        part frontLeftWheel : WheelAssembly {
            attribute :>> radius = 0.32 [SI::m];
        }

        part frontRightWheel : WheelAssembly {
            attribute :>> radius = 0.32 [SI::m];
        }

        part rearLeftWheel : WheelAssembly {
            attribute :>> radius = 0.32 [SI::m];
        }

        part rearRightWheel : WheelAssembly {
            attribute :>> radius = 0.32 [SI::m];
        }

        part velocitySensor : VelocitySensor {
            attribute :>> sampleRate = 100.0;
            attribute :>> accuracy = 0.98;
        }

        part slipEstimator : SlipEstimator {
            attribute :>> wheelRadius = 0.32 [SI::m];
        }

        part tractionController : TractionController {
            attribute :>> targetSlip = slipControlSystem.systemTargetSlip;
            attribute :>> maxTorque = 500 [SI::'N·m'];
            attribute :>> minTorque = 0 [SI::'N·m'];
            attribute :>> controlGain = 3.5;
            attribute :>> integralGain = 0.8;
            attribute :>> derivativeGain = 1.2;
        }

        part torqueActuator : TorqueActuator {
            attribute :>> maxRate = 100.0;
        }

        part powertrain : PowertrainUnit {
            attribute :>> efficiency = 0.88;
        }

        connection velocityToEstimator connect
            velocitySensor.wheelSpeedOut to slipEstimator.velocityIn;

        connection estimatorToController connect
            slipEstimator.slipOut to tractionController.slipInput;

        connection controllerToActuator connect
            tractionController.torqueOutput to torqueActuator.commandIn;

        assert constraint slipWithinBounds {
            slipEstimator.currentSlip >= 0.0 and
            slipEstimator.currentSlip <= maxAllowableSlip
        }

        assert constraint torqueLimits {
            torqueActuator.currentTorque >= tractionController.minTorque and
            torqueActuator.currentTorque <= tractionController.maxTorque
        }
    }

    requirement <'REQ-SC-001'> slipMonitoring {
        doc /* The system shall continuously monitor the slip ratio with 
             * a minimum sampling rate of 50 Hz to ensure real-time 
             * detection and response to traction conditions.
             */
        subject system :> slipControlSystem;
        require constraint {
            system.velocitySensor.sampleRate >= 50.0
        }
    }

    requirement <'REQ-SC-002'> slipRegulation {
        doc /* The system shall maintain the slip ratio within ±5% of 
             * the target value during normal operation to optimize 
             * traction force transfer.
             */
        subject system :> slipControlSystem;
        require constraint {
            system.slipEstimator.currentSlip >= system.systemTargetSlip - 0.05 and
            system.slipEstimator.currentSlip <= system.systemTargetSlip + 0.05
        }
    }

    requirement <'REQ-SC-003'> maximumSlipProtection {
        doc /* The system shall prevent slip ratio from exceeding 80% 
             * to avoid complete loss of traction and maintain vehicle 
             * stability.
             */
        subject system :> slipControlSystem;
        require constraint {
            system.slipEstimator.currentSlip <= system.maxAllowableSlip
        }
    }

    requirement <'REQ-SC-004'> torqueResponseTime {
        doc /* The torque actuator shall respond to control commands 
             * within 50 milliseconds to maintain effective slip control.
             */
        subject actuator :> slipControlSystem.torqueActuator;
    }

    requirement <'REQ-SC-005'> systemEfficiency {
        doc /* The powertrain shall maintain minimum 85% efficiency 
             * when operating at target slip ratio to maximize energy 
             * utilization.
             */
        subject powertrain :> slipControlSystem.powertrain;
        require constraint {
            powertrain.efficiency >= 0.85
        }
    }

    requirement <'REQ-SC-006'> sensorAccuracy {
        doc /* Velocity sensors shall maintain minimum 95% accuracy 
             * to ensure reliable slip estimation.
             */
        subject sensor :> slipControlSystem.velocitySensor;
        require constraint {
            sensor.accuracy >= 0.95
        }
    }

    requirement primaryMissionRequirement {
        doc /* The slip factor control system shall optimize traction force 
             * transfer between wheels and surface by maintaining slip ratio 
             * within optimal range through continuous monitoring and active 
             * torque modulation, preventing wheel spin while maximizing 
             * acceleration and vehicle stability.
             */
        subject system :> slipControlSystem;
    }

    satisfy primaryMissionRequirement by slipControlSystem;
}
