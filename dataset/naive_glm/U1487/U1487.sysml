package IndustrialRotorSystem {
    import SI::*;
    import ScalarValues::*;

    //=================================================================
    // VALUE TYPE DEFINITIONS
    //=================================================================

    value def RPM :> Real {
        doc /* Rotational speed in revolutions per minute. */;
    }

    value def VibrationLevel :> Real {
        doc /* Vibration acceleration level in m/s^2. */;
    }

    value def EfficiencyFactor :> Real {
        doc /* Dimensionless efficiency factor, range 0.0 to 1.0. */;
    }

    value def InertiaValue :> Real {
        doc /* Moment of inertia in kg*m^2. */;
    }

    //=================================================================
    // ITEM DEFINITIONS
    //=================================================================

    item def ElectricalPowerFlow {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power = voltage * current;
    }

    item def SpeedMeasurement {
        attribute measuredSpeed : AngularVelocity;
    }

    item def TorqueCommand {
        attribute commandedTorque : Torque;
    }

    item def VibrationMeasurement {
        attribute level : VibrationLevel;
    }

    item def TemperatureMeasurement {
        attribute value : ThermodynamicTemperature;
    }

    item def StartCommand {
        attribute targetSpeed : AngularVelocity = 314.159 [rad/s];
    }

    item def StopCommand;

    //=================================================================
    // PORT DEFINITIONS
    //=================================================================

    port def ElectricalInPort {
        in power : ElectricalPowerFlow;
    }

    port def TorqueOutPort {
        out torque : Torque;
    }

    port def TorqueInPort {
        in torque : Torque;
    }

    port def RawSpeedOutPort {
        out speed : AngularVelocity;
    }

    port def RawSpeedInPort {
        in speed : AngularVelocity;
    }

    port def RawVibrationOutPort {
        out level : VibrationLevel;
    }

    port def RawVibrationInPort {
        in level : VibrationLevel;
    }

    port def RawTempOutPort {
        out temperature : ThermodynamicTemperature;
    }

    port def RawTempInPort {
        in temperature : ThermodynamicTemperature;
    }

    port def SpeedMeasureOutPort {
        out reading : SpeedMeasurement;
    }

    port def SpeedMeasureInPort {
        in reading : SpeedMeasurement;
    }

    port def VibrationMeasureOutPort {
        out reading : VibrationMeasurement;
    }

    port def VibrationMeasureInPort {
        in reading : VibrationMeasurement;
    }

    port def TempMeasureOutPort {
        out reading : TemperatureMeasurement;
    }

    port def TempMeasureInPort {
        in reading : TemperatureMeasurement;
    }

    port def CmdOutPort {
        out command : TorqueCommand;
    }

    port def CmdInPort {
        in command : TorqueCommand;
    }

    port def SystemCommandPort {
        in start : StartCommand;
        in stop : StopCommand;
    }

    //=================================================================
    // ACTION DEFINITIONS
    //=================================================================

    action def ComputeControlTorque {
        in target : AngularVelocity;
        in measured : AngularVelocity;
        in gainKp : Real;
        in maxTorque : Torque;
        out cmd : TorqueCommand;

        local speedError : AngularVelocity = target - measured;
        local rawTorque : Torque = gainKp * speedError;

        if rawTorque > maxTorque {
            cmd.commandedTorque = maxTorque;
        } else if rawTorque < -maxTorque {
            cmd.commandedTorque = -maxTorque;
        } else {
            cmd.commandedTorque = rawTorque;
        }
    }

    //=================================================================
    // PART DEFINITIONS
    //=================================================================

    part def Rotor {
        doc /* Heavy mechanical rotor with defined mass and radius. */;

        attribute mass : Mass = 15 [kg];
        attribute radius : Length = 0.25 [m];
        attribute inertia : InertiaValue = 0.5 * mass * (radius * radius);
        attribute currentSpeed : AngularVelocity = 0 [rad/s];
        attribute currentVibration : VibrationLevel = 0;
        attribute currentTemperature : ThermodynamicTemperature = 293.15 [K];
        attribute maxSpeed : AngularVelocity = 400 [rad/s];
        attribute maxVibration : VibrationLevel = 10;
        attribute maxTemperature : ThermodynamicTemperature = 353.15 [K];

        port torqueIn : TorqueInPort;
        port speedOut : RawSpeedOutPort;
        port vibrationOut : RawVibrationOutPort;
        port tempOut : RawTempOutPort;
    }

    part def Motor {
        doc /* Electric motor converting electrical power to mechanical torque at 92% efficiency. */;

        attribute efficiency : EfficiencyFactor = 0.92;
        attribute maxPower : Power = 20000 [W];
        attribute maxTorque : Torque = 50 [N*m];
        attribute ratedVoltage : ElectricPotential = 400 [V];
        attribute ratedCurrent : ElectricCurrent = 50 [A];
        attribute currentTorqueOutput : Torque = 0 [N*m];

        port electricalIn : ElectricalInPort;
        port cmdIn : CmdInPort;
        port torqueOut : TorqueOutPort;
    }

    part def SpeedSensor {
        doc /* Dedicated speed sensor providing real-time angular velocity measurements. */;

        attribute measurementRange : AngularVelocity = 400 [rad/s];
        attribute accuracy : Real = 0.001;
        attribute samplingRate : Real = 1000;

        port speedIn : RawSpeedInPort;
        port measureOut : SpeedMeasureOutPort;
    }

    part def VibrationSensor {
        doc /* Vibration sensor monitoring rotor mechanical vibration levels. */;

        attribute measurementRange : VibrationLevel = 50;
        attribute samplingRate : Real = 500;
        attribute sensitivity : Real = 0.01;

        port vibrationIn : RawVibrationInPort;
        port measureOut : VibrationMeasureOutPort;
    }

    part def TemperatureSensor {
        doc /* Temperature sensor monitoring rotor thermal state. */;

        attribute measurementRange : ThermodynamicTemperature = 500 [K];
        attribute accuracy : Real = 0.5;
        attribute responseTime : Time = 1 [s];

        port tempIn : RawTempInPort;
        port measureOut : TempMeasureOutPort;
    }

    part def Controller {
        doc /* Digital controller implementing closed-loop speed control and safety monitoring. */;

        attribute proportionalGain : Real = 0.5;
        attribute maxTorqueCommand : Torque = 50 [N*m];
        attribute targetSpeed : AngularVelocity = 314.159 [rad/s];
        attribute speedThreshold95 : AngularVelocity = 0.95 * targetSpeed;
        attribute vibrationLimit : VibrationLevel = 7.1;
        attribute temperatureLimit : ThermodynamicTemperature = 353.15 [K];
        attribute safeStopSpeed : AngularVelocity = 0.01 [rad/s];
        attribute currentMeasuredSpeed : AngularVelocity = 0 [rad/s];
        attribute currentMeasuredVibration : VibrationLevel = 0;
        attribute currentMeasuredTemperature : ThermodynamicTemperature = 293.15 [K];
        attribute startRequested : Boolean = false;
        attribute stopRequested : Boolean = false;

        port speedIn : SpeedMeasureInPort;
        port vibrationIn : VibrationMeasureInPort;
        port tempIn : TempMeasureInPort;
        port cmdIn : SystemCommandPort;
        port cmdOut : CmdOutPort;

        state controllerStateMachine {
            state idle {
                doc /* System powered but not running. No torque output. */;
                entry { /* Initialize controller, zero torque output */ }
            }

            state starting {
                doc /* Accelerating rotor toward 95% of target speed. */;
                entry { /* Begin applying control torque for acceleration */ }
                do { /* Continuously compute and apply control torque */ }
            }

            state operating {
                doc /* Steady-state operation maintaining target speed. */;
                entry { /* Transition to fine speed maintenance mode */ }
                do { /* Maintain target speed with proportional control adjustments */ }
            }

            state emergencyShutdown {
                doc /* Emergency shutdown triggered by vibration or temperature fault. */;
                entry { /* Cut torque output, initiate safe deceleration */ }
                do { /* Monitor speed until rotor reaches safe stop */ }
            }

            transition from idle to starting when startRequested;

            transition from starting to operating
                when currentMeasuredSpeed >= speedThreshold95;

            transition from operating to idle when stopRequested;

            transition from starting to idle when stopRequested;

            transition from starting to emergencyShutdown
                when currentMeasuredVibration > vibrationLimit;

            transition from operating to emergencyShutdown
                when currentMeasuredVibration > vibrationLimit;

            transition from starting to emergencyShutdown
                when currentMeasuredTemperature > temperatureLimit;

            transition from operating to emergencyShutdown
                when currentMeasuredTemperature > temperatureLimit;

            transition from emergencyShutdown to idle
                when currentMeasuredSpeed <= safeStopSpeed;
        }
    }

    //=================================================================
    // SYSTEM ASSEMBLY
    //=================================================================

    part def IndustrialRotorSystem {
        doc /* Actively controlled industrial rotor system suitable for flywheel energy storage, large-scale pumps, or industrial centrifuges. */;

        port electrical : ElectricalInPort;
        port commands : SystemCommandPort;

        part motor : Motor {
            satisfy MotorEfficiencyRequirement;
        }

        part rotor : Rotor {
            satisfy RotorMassRequirement;
            satisfy RotorRadiusRequirement;
        }

        part speedSensor : SpeedSensor;

        part vibrationSensor : VibrationSensor;

        part tempSensor : TemperatureSensor;

        part controller : Controller;

        connect electrical to motor.electricalIn;
        connect motor.torqueOut to rotor.torqueIn;
        connect rotor.speedOut to speedSensor.speedIn;
        connect rotor.vibrationOut to vibrationSensor.vibrationIn;
        connect rotor.tempOut to tempSensor.tempIn;
        connect speedSensor.measureOut to controller.speedIn;
        connect vibrationSensor.measureOut to controller.vibrationIn;
        connect tempSensor.measureOut to controller.tempIn;
        connect commands to controller.cmdIn;
        connect controller.cmdOut to motor.cmdIn;
    }

    //=================================================================
    // REQUIREMENTS
    //=================================================================

    requirement def RotorMassRequirement {
        doc /* The rotor shall have a mass of 15 kg. */;
        subject rotor : Rotor;
        constraint massConstraint { rotor.mass == 15 [kg] }
    }

    requirement def RotorRadiusRequirement {
        doc /* The rotor shall have a radius of 0.25 meters. */;
        subject rotor : Rotor;
        constraint radiusConstraint { rotor.radius == 0.25 [m] }
    }

    requirement def TargetSpeedRequirement {
        doc /* The system shall maintain the rotor at a target speed of approximately 3000 RPM (314 rad/s). */;
        attribute targetRPM : RPM = 3000;
        attribute targetAngularSpeed : AngularVelocity = 314.159 [rad/s];
        constraint speedConstraint { targetAngularSpeed == 314.159 [rad/s] }
    }

    requirement def MotorEfficiencyRequirement {
        doc /* The motor shall convert electrical power to mechanical power at 92% efficiency. */;
        subject motor : Motor;
        constraint efficiencyConstraint { motor.efficiency == 0.92 }
    }

    requirement def StartingPhaseRequirement {
        doc /* Upon receiving a command, the system shall enter the starting state and accelerate until reaching 95% of target speed, then transition to the operating state. */;
        attribute accelerationThresholdFraction : Real = 0.95;
    }

    requirement def OperatingStateRequirement {
        doc /* In the operating state, the system shall actively maintain the rotor at the target speed through continuous closed-loop control. */;
    }

    requirement def VibrationSafetyRequirement {
        doc /* The system shall continuously monitor vibration levels and trigger an emergency shutdown when vibrations exceed the critical threshold. */;
        attribute criticalVibration : VibrationLevel = 7.1;
        constraint vibrationThreshold { criticalVibration == 7.1 }
    }

    requirement def TemperatureSafetyRequirement {
        doc /* The system shall continuously monitor temperature and trigger an emergency shutdown when temperature exceeds 80 degrees Celsius (353.15 K). */;
        attribute criticalTemperature : ThermodynamicTemperature = 353.15 [K];
    }

    requirement def EmergencyShutdownRequirement {
        doc /* During emergency shutdown, the system shall spin down to a safe stop to prevent mechanical failure. */;
    }

    requirement def ClosedLoopControlRequirement {
        doc /* The controller shall continuously receive speed measurements from the sensor, compare against the target speed, compute the required torque, and send a command to the motor. */;
    }
}
