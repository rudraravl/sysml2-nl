package IndustrialRotorSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def StartCommand;
    item def StopCommand;
    item def SpeedMeasurement;
    item def TorqueCommand;
    item def MechanicalTorque;
    item def ElectricalPower;
    item def VibrationSample;
    item def TemperatureSample;

    attribute def RotationalSpeed :> ISQ::angularVelocity;
    attribute def TorqueValue :> ISQ::torque;
    attribute def PowerValue :> ISQ::power;
    attribute def VibrationValue :> ISQ::acceleration;
    attribute def TemperatureValue :> ISQ::temperature;
    attribute def MassValue :> ISQ::mass;
    attribute def LengthValue :> ISQ::length;

    port def SpeedOutPort { out speed : SpeedMeasurement; }
    port def SpeedInPort { in speed : SpeedMeasurement; }
    port def TorqueOutPort { out torque : TorqueCommand; }
    port def TorqueInPort { in torque : TorqueCommand; }
    port def MechanicalTorqueInPort { in torque : MechanicalTorque; }
    port def MechanicalTorqueOutPort { out torque : MechanicalTorque; }
    port def PowerInPort { in power : ElectricalPower; }
    port def VibrationOutPort { out vibration : VibrationSample; }
    port def VibrationInPort { in vibration : VibrationSample; }
    port def TemperatureOutPort { out temperature : TemperatureSample; }
    port def TemperatureInPort { in temperature : TemperatureSample; }
    port def CommandInPort { in start : StartCommand; in stop : StopCommand; }

    action def ComputeTorque {
        in measured : SpeedMeasurement;
        in target : RotationalSpeed;
        out command : TorqueCommand;
    }
    action def GenerateTorque {
        in command : TorqueCommand;
        in power : ElectricalPower;
        out torque : MechanicalTorque;
    }
    action def Rotate {
        in torque : MechanicalTorque;
        out speed : SpeedMeasurement;
        out vibration : VibrationSample;
        out temperature : TemperatureSample;
    }
    action def SenseSpeed {
        in rotorSpeed : SpeedMeasurement;
        out sample : SpeedMeasurement;
    }
    action def EmergencyStop {
        out command : TorqueCommand;
    }
    action def SpinDown {
        out command : TorqueCommand;
    }

    state def SystemStates;

    part def Rotor {
        attribute mass : MassValue = 15 [kg];
        attribute radius : LengthValue = 0.25 [m];
        attribute currentSpeed : RotationalSpeed;
        attribute currentVibration : VibrationValue;
        attribute currentTemperature : TemperatureValue;
        port mechanicalInputPort : MechanicalTorqueInPort;
        port speedOutputPort : SpeedOutPort;
        port vibrationOutputPort : VibrationOutPort;
        port temperatureOutputPort : TemperatureOutPort;
        perform action rotate : Rotate;
    }

    part def ElectricMotor {
        attribute efficiency : Real = 0.92;
        port electricalPowerPort : PowerInPort;
        port torqueCommandPort : TorqueInPort;
        port mechanicalOutputPort : MechanicalTorqueOutPort;
        perform action generateTorque : GenerateTorque;
    }

    part def SpeedSensor {
        port rotorSpeedPort : SpeedInPort;
        port measurementPort : SpeedOutPort;
        perform action senseSpeed : SenseSpeed;
    }

    part def VibrationSensor {
        port rotorVibrationPort : VibrationInPort;
        port measurementPort : VibrationOutPort;
    }

    part def TemperatureSensor {
        port rotorTemperaturePort : TemperatureInPort;
        port measurementPort : TemperatureOutPort;
    }

    part def DigitalController {
        attribute targetSpeed : RotationalSpeed = 314 [rad/s];
        attribute speedThresholdFactor : Real = 0.95;
        attribute vibrationThreshold : VibrationValue = 5.0 [m/s^2];
        attribute maxTemperature : TemperatureValue = 353.15 [K];
        port commandPort : CommandInPort;
        port speedInputPort : SpeedInPort;
        port vibrationInputPort : VibrationInPort;
        port temperatureInputPort : TemperatureInPort;
        port torqueOutputPort : TorqueOutPort;
        perform action computeTorque : ComputeTorque;
        perform action emergencyStop : EmergencyStop;
        perform action spinDown : SpinDown;
    }

    part def RotorSystem {
        part rotor : Rotor;
        part motor : ElectricMotor;
        part speedSensor : SpeedSensor;
        part vibrationSensor : VibrationSensor;
        part temperatureSensor : TemperatureSensor;
        part controller : DigitalController;

        port commandPort : CommandInPort;
        port electricalPowerPort : PowerInPort;

        bind commandPort = controller.commandPort;
        bind electricalPowerPort = motor.electricalPowerPort;

        interface torqueControl connect controller.torqueOutputPort to motor.torqueCommandPort {
            flow torqueCommandFlow of TorqueCommand
                from controller.torqueOutputPort.torque to motor.torqueCommandPort.torque;
        }
        interface mechanicalDrive connect motor.mechanicalOutputPort to rotor.mechanicalInputPort {
            flow mechanicalTorqueFlow of MechanicalTorque
                from motor.mechanicalOutputPort.torque to rotor.mechanicalInputPort.torque;
        }
        interface speedSensing connect rotor.speedOutputPort to speedSensor.rotorSpeedPort {
            flow rotorSpeedFlow of SpeedMeasurement
                from rotor.speedOutputPort.speed to speedSensor.rotorSpeedPort.speed;
        }
        interface speedFeedback connect speedSensor.measurementPort to controller.speedInputPort {
            flow speedFeedbackFlow of SpeedMeasurement
                from speedSensor.measurementPort.speed to controller.speedInputPort.speed;
        }
        interface vibrationSensing connect rotor.vibrationOutputPort to vibrationSensor.rotorVibrationPort {
            flow rotorVibrationFlow of VibrationSample
                from rotor.vibrationOutputPort.vibration to vibrationSensor.rotorVibrationPort.vibration;
        }
        interface vibrationFeedback connect vibrationSensor.measurementPort to controller.vibrationInputPort {
            flow vibrationFeedbackFlow of VibrationSample
                from vibrationSensor.measurementPort.vibration to controller.vibrationInputPort.vibration;
        }
        interface temperatureSensing connect rotor.temperatureOutputPort to temperatureSensor.rotorTemperaturePort {
            flow rotorTemperatureFlow of TemperatureSample
                from rotor.temperatureOutputPort.temperature to temperatureSensor.rotorTemperaturePort.temperature;
        }
        interface temperatureFeedback connect temperatureSensor.measurementPort to controller.temperatureInputPort {
            flow temperatureFeedbackFlow of TemperatureSample
                from temperatureSensor.measurementPort.temperature to controller.temperatureInputPort.temperature;
        }

        exhibit state systemStates : SystemStates {
            entry; then idle;
            state idle;
            accept StartCommand then starting;
            state starting;
            accept when rotor.currentSpeed >= controller.speedThresholdFactor * controller.targetSpeed
                then operating;
            state operating;
            accept when rotor.currentVibration > controller.vibrationThreshold
                then emergencyShutdown;
            accept StopCommand then stopping;
            state emergencyShutdown;
            accept when rotor.currentSpeed <= 0.1 [rad/s] then idle;
            state stopping;
            accept when rotor.currentSpeed <= 0.1 [rad/s] then idle;
        }
    }

    requirement def RotorMassRequirement {
        subject rotorSystem : RotorSystem;
        doc /* The rotor shall have a mass of 15 kg. */
        require { rotorSystem.rotor.mass == 15 [kg]; }
    }
    requirement def RotorRadiusRequirement {
        subject rotorSystem : RotorSystem;
        doc /* The rotor shall have a radius of 0.25 m. */
        require { rotorSystem.rotor.radius == 0.25 [m]; }
    }
    requirement def TargetSpeedRequirement {
        subject rotorSystem : RotorSystem;
        doc /* The system shall maintain a target rotational speed of 314 rad/s. */
        require { rotorSystem.controller.targetSpeed == 314 [rad/s]; }
    }
    requirement def MotorEfficiencyRequirement {
        subject rotorSystem : RotorSystem;
        doc /* The motor shall convert electrical power to mechanical torque with 92 percent efficiency. */
        require { rotorSystem.motor.efficiency == 0.92; }
    }
    requirement def VibrationSafetyRequirement {
        subject rotorSystem : RotorSystem;
        doc /* If vibration exceeds the critical threshold, the system shall trigger an emergency shutdown. */
        require { rotorSystem.controller.vibrationThreshold == 5.0 [m/s^2]; }
    }

    part industrialRotorSystem : RotorSystem {
        satisfy RotorMassRequirement;
        satisfy RotorRadiusRequirement;
        satisfy TargetSpeedRequirement;
        satisfy MotorEfficiencyRequirement;
        satisfy VibrationSafetyRequirement;
    }
}
