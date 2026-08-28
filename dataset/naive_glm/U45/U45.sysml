package LaboratoryCentrifugeSystem {
    import ScalarValues::*;
    import ISQ::*;

    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def Duration :> Real { unit 'min'; }
    value def Temperature :> Real { unit 'degC'; }
    value def VibrationLevel :> Real { unit 'mm/s'; }
    value def ImbalanceMass :> Real { unit 'g'; }
    value def Torque :> Real { unit 'N*m'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }

    enum def OperationalState {
        idle;
        loading;
        accelerating;
        separating;
        decelerating;
        unloading;
    }

    item def LiquidSample;

    port def PowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def CommandPort {
        attribute start : Boolean;
        attribute stop : Boolean;
        attribute emergencyStop : Boolean;
        attribute setSpeed : RotationalSpeed;
        attribute setDuration : Duration;
        attribute setTemp : Temperature;
    }

    port def ControlSignalPort {
        attribute state : OperationalState;
        attribute speed : RotationalSpeed;
        attribute temperature : Temperature;
        attribute duration : Duration;
    }

    port def DrivePort {
        attribute torque : Torque;
        attribute speed : RotationalSpeed;
    }

    port def VibrationSensorPort {
        attribute level : VibrationLevel;
        attribute limitExceeded : Boolean;
    }

    port def ImbalanceSensorPort {
        attribute level : ImbalanceMass;
        attribute limitExceeded : Boolean;
    }

    port def LidSensorPort {
        attribute isLocked : Boolean;
    }

    requirement def SeparationReq {
        doc /* The system shall separate liquid samples based on density using centrifugal force. */
        requirement req1 { doc /* The system shall spin samples at a defined RotationalSpeed for a specified Duration. */ }
        requirement req2 { doc /* The system shall maintain samples at a defined Temperature during operation. */ }
    }

    requirement def SafetyReq {
        doc /* The system must operate safely. */
        requirement req1 { doc /* The lid shall be locked before the motor starts. */ }
        requirement req2 { doc /* The lid shall remain locked until the rotor stops. */ }
        requirement req3 { doc /* The system shall trigger an emergency stop if VibrationLevel or ImbalanceMass exceeds limits. */ }
    }

    part def Motor {
        attribute targetSpeed : RotationalSpeed;
        attribute currentSpeed : RotationalSpeed;
        in port powerIn : PowerPort;
        in port controlIn : CommandPort;
        out port driveOut : DrivePort;
        out port feedbackOut : ControlSignalPort;

        action def Spin {
            in speed : RotationalSpeed;
            out achieved : Boolean;
        }
    }

    part def Rotor {
        attribute bucketCount : Integer = 6;
        part buckets : SampleTube[6];
        attribute imbalance : ImbalanceMass;
        attribute vibration : VibrationLevel;
        in port driveIn : DrivePort;
        out port vibrationOut : VibrationSensorPort;
        out port imbalanceOut : ImbalanceSensorPort;
    }

    part def SampleTube {
        item sample : LiquidSample;
    }

    part def ControlUnit {
        attribute setSpeed : RotationalSpeed;
        attribute setDuration : Duration;
        attribute setTemp : Temperature;
        attribute currentState : OperationalState;
        attribute imbalanceLimit : ImbalanceMass = 10 [g];
        attribute vibrationLimit : VibrationLevel = 5 [mm/s];

        in port userIn : CommandPort;
        out port userOut : ControlSignalPort;
        out port motorCmd : CommandPort;
        in port motorFb : ControlSignalPort;
        out port tempCmd : CommandPort;
        out port safetyCmd : CommandPort;
        in port safetyFb : CommandPort;
        in port vibrationFb : VibrationSensorPort;
        in port imbalanceFb : ImbalanceSensorPort;
        in port lidFb : LidSensorPort;

        action def ExecuteProtocol {
            in speed : RotationalSpeed;
            in duration : Duration;
        }

        exhibit state CentrifugeStateMachine {
            state idle;
            state loading;
            state accelerating;
            state separating;
            state decelerating;
            state unloading;

            transition from idle to loading when userIn.start;
            transition from loading to accelerating when lidFb.isLocked && !imbalanceFb.limitExceeded;
            transition from accelerating to separating when motorFb.speed >= setSpeed;
            transition from separating to decelerating when userIn.stop;
            transition from decelerating to unloading when motorFb.speed == 0;
            transition from unloading to idle when userIn.stop;
            transition from * to idle when safetyFb.emergencyStop || vibrationFb.limitExceeded || imbalanceFb.limitExceeded;
        }
    }

    part def TemperatureControl {
        attribute setpoint : Temperature;
        attribute currentTemp : Temperature;
        in port controlIn : CommandPort;

        action def CoolChamber {
            in target : Temperature;
        }
    }

    part def SafetySystem {
        attribute lidLocked : Boolean;
        attribute vibrationLimit : VibrationLevel;
        attribute imbalanceLimit : ImbalanceMass;
        in port controlIn : CommandPort;
        out port controlOut : CommandPort;
        out port lidCmd : CommandPort;

        action def MonitorVibration {
            in level : VibrationLevel;
        }
        action def MonitorImbalance {
            in level : ImbalanceMass;
        }
    }

    part def Lid {
        attribute isLocked : Boolean;
        in port cmdIn : CommandPort;
        out port sensorOut : LidSensorPort;

        action def Lock {}
        action def Unlock {}
    }

    part def LaboratoryCentrifuge :> SeparationReq, SafetyReq {
        part motor : Motor;
        part rotor : Rotor;
        part controlUnit : ControlUnit;
        part tempControl : TemperatureControl;
        part safetySystem : SafetySystem;
        part lid : Lid;

        in port powerInterface : PowerPort;
        in port userInterfaceIn : CommandPort;
        out port userInterfaceOut : ControlSignalPort;

        connection powerConn connect powerInterface to motor.powerIn;
        connection userCmdConn connect userInterfaceIn to controlUnit.userIn;
        connection userFbConn connect controlUnit.userOut to userInterfaceOut;
        connection motorCmdConn connect controlUnit.motorCmd to motor.controlIn;
        connection motorFbConn connect motor.feedbackOut to controlUnit.motorFb;
        connection driveConn connect motor.driveOut to rotor.driveIn;
        connection tempCmdConn connect controlUnit.tempCmd to tempControl.controlIn;
        connection safetyCmdConn connect controlUnit.safetyCmd to safetySystem.controlIn;
        connection safetyFbConn connect safetySystem.controlOut to controlUnit.safetyFb;
        connection lidCmdConn connect safetySystem.lidCmd to lid.cmdIn;
        connection lidConn connect lid.sensorOut to controlUnit.lidFb;
        connection vibrationConn connect rotor.vibrationOut to controlUnit.vibrationFb;
        connection imbalanceConn connect rotor.imbalanceOut to controlUnit.imbalanceFb;
    }
}
