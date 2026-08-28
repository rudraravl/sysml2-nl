package 'Ring Transport System' {

    attribute def RadiusValue :> Real;
    attribute def MassCapacityValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def PositionValue :> Real;
    attribute def TimestampValue :> Real;
    attribute def RotationalSpeedValue :> Real;
    attribute def TorqueValue :> Real;

    item def Payload {
        attribute mass : MassCapacityValue;
    }
    item def PositionData {
        attribute position : PositionValue;
        attribute timestamp : TimestampValue;
    }
    item def MotorCommand {
        attribute torque : TorqueValue;
    }
    item def HighVoltagePower {
        attribute voltage : VoltageValue = 480;
    }
    item def LowVoltagePower {
        attribute voltage : VoltageValue = 24;
    }
    item def StartSignal;
    item def EmergencyStopSignal;
    item def ResetSignal;
    item def TargetSpeedReached;

    port def PowerOutPort {
        out item power : HighVoltagePower;
    }
    port def PowerInPort {
        in item power : HighVoltagePower;
    }
    port def LowVoltageOutPort {
        out item power : LowVoltagePower;
    }
    port def LowVoltageInPort {
        in item power : LowVoltagePower;
    }
    port def MotorControlInPort {
        in item command : MotorCommand;
    }
    port def MotorControlOutPort {
        out item command : MotorCommand;
    }
    port def PositionSensorOutPort {
        out item data : PositionData;
    }
    port def PositionSensorInPort {
        in item data : PositionData;
    }
    port def PayloadPort {
        in item load : Payload;
        out item unload : Payload;
    }

    action def RampMotor {
        in targetSpeed : RotationalSpeedValue;
        out torqueCmd : MotorCommand;
    }
    action def RegulateSpeed {
        in sensorData : PositionData;
        in targetSpeed : RotationalSpeedValue;
        out torqueCmd : MotorCommand;
    }
    action def EmergencyHalt {
        out torqueCmd : MotorCommand;
    }

    part def PositionSensor {
        port sensorOutput : PositionSensorOutPort;
    }

    part def Carrier {
        attribute capacity : MassCapacityValue = 200;
        attribute currentPayload : MassCapacityValue[0..1];
        port loadPort : PayloadPort;
        part positionSensor : PositionSensor;
    }

    part def Motor {
        port powerIn : PowerInPort;
        port controlIn : MotorControlInPort;
        attribute targetSpeed : RotationalSpeedValue;
    }

    state machine def ControllerBehavior {
        state idle;
        state starting;
        state running;
        state emergencyStop;

        transition from idle to starting accept StartSignal;
        transition from starting to running accept TargetSpeedReached;
        transition from starting to emergencyStop accept EmergencyStopSignal;
        transition from running to emergencyStop accept EmergencyStopSignal;
        transition from running to idle accept ResetSignal;
        transition from emergencyStop to idle accept ResetSignal;
    }

    part def Controller {
        port powerIn : LowVoltageInPort;
        port sensorIn : PositionSensorInPort;
        port commandOut : MotorControlOutPort;
        attribute targetSpeed : RotationalSpeedValue = 10;
        state machine :>> ControllerBehavior;
    }

    part def PowerSupply {
        port highVoltageOutput : PowerOutPort;
        port lowVoltageOutput : LowVoltageOutPort;
    }

    part def Track {
        attribute radius : RadiusValue = 5;
        part motor : Motor;
        part carriers : Carrier[4];
        part controller : Controller;
        part powerSupply : PowerSupply;
    }

    requirement def TrackRadiusRequirement {
        doc "The circular track shall have a radius of exactly 5 meters.";
    }
    requirement def PayloadCapacityRequirement {
        doc "Each carrier shall support a maximum payload of up to 200 kg.";
    }
    requirement def NumberOfCarriersRequirement {
        doc "The system shall include four individual carriers.";
    }
    requirement def EmergencyStopRequirement {
        doc "The system shall provide an emergency stop capability that brings the system to a halt.";
    }
    requirement def SpeedLimitRequirement {
        doc "The operational speed shall not exceed a defined safe limit to ensure safe transport.";
    }

    part ringTransportSystem : Track {
        attribute radius : RadiusValue = 5;

        part motor : Motor {
            attribute targetSpeed : RotationalSpeedValue = 10;
        }
        part carriers : Carrier[4];
        part controller : Controller;
        part powerSupply : PowerSupply;

        connect powerSupply.highVoltageOutput to motor.powerIn;
        connect powerSupply.lowVoltageOutput to controller.powerIn;
        connect carriers[1].positionSensor.sensorOutput to controller.sensorIn;
        connect controller.commandOut to motor.controlIn;

        flow highVoltageFlow of HighVoltagePower
            from powerSupply.highVoltageOutput.power to motor.powerIn.power;
        flow lowVoltageFlow of LowVoltagePower
            from powerSupply.lowVoltageOutput.power to controller.powerIn.power;
        flow positionDataFlow of PositionData
            from carriers[1].positionSensor.sensorOutput.data to controller.sensorIn.data;
        flow motorCommandFlow of MotorCommand
            from controller.commandOut.command to motor.controlIn.command;

        requirement trackRadiusReq : TrackRadiusRequirement;
        requirement payloadCapacityReq : PayloadCapacityRequirement;
        requirement numberOfCarriersReq : NumberOfCarriersRequirement;
        requirement emergencyStopReq : EmergencyStopRequirement;
        requirement speedLimitReq : SpeedLimitRequirement;
    }
}
