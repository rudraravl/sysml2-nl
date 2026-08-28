package RingTransportSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ---- Value types with units ----
    value def Length :> ISQ::Length { unit m; }
    value def Mass :> ISQ::Mass { unit kg; }
    value def LinearSpeed :> ISQ::Speed { unit "m/s"; }
    value def AngularSpeed :> ISQ::AngularSpeed { unit "rad/s"; }
    value def Torque :> ISQ::Torque { unit "N*m"; }
    value def Voltage :> ISQ::ElectricPotential { unit V; }
    value def Current :> ISQ::ElectricCurrent { unit A; }
    value def Power :> ISQ::Power { unit W; }
    value def Duration :> ISQ::Time { unit s; }
    value def Angle :> ISQ::Angle { unit rad; }
    value def Frequency :> ISQ::Frequency { unit Hz; }

    // ---- Enumerations ----
    enum def OperationalState {
        literal idle;
        literal starting;
        literal running;
        literal emergencyStop;
    }

    // ---- Item types ----
    item def Payload {
        attribute mass : Mass;
        attribute destinationId : String;
    }

    item def ElectricPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def ControlSignal {
        attribute targetTorque : Torque;
        attribute targetAngularSpeed : AngularSpeed;
        attribute enable : Boolean;
    }

    item def FeedbackData {
        attribute position : Angle;
        attribute timestamp : Duration;
    }

    item def SensorData {
        attribute position : Angle;
        attribute timestamp : Duration;
        attribute carrierId : String;
    }

    item def DriveTorque {
        attribute magnitude : Torque;
    }

    // ---- Port definitions ----
    port def PowerPort {
        out item electricPower : ElectricPower;
    }

    port def ControlSignalPort {
        out item controlSignal : ControlSignal;
        in item feedback : FeedbackData;
    }

    port def SensorDataPort {
        out item sensorData : SensorData;
    }

    port def MechanicalDrivePort {
        out item driveTorque : DriveTorque;
    }

    port def PayloadPort {
        in item payloadIn : Payload;
        out item payloadOut : Payload;
    }

    // ---- Requirements ----
    requirement def TrackGeometryRequirement {
        subject track : CircularTrack;
        doc "The circular track shall have a radius of 5 meters."
        constraint { track.radius == 5 [m] }
    }

    requirement def CarrierCountRequirement {
        subject system : RingTransportSystem;
        doc "The system shall operate with exactly four carriers on the ring."
        constraint { system.carrierCount == 4 }
    }

    requirement def PayloadCapacityRequirement {
        subject carrier : Carrier;
        doc "Each carrier shall transport a payload of up to 200 kg."
        constraint { carrier.maxPayloadMass == 200 [kg] }
    }

    requirement def SingleDriveRequirement {
        subject system : RingTransportSystem;
        doc "The ring shall be driven by a single electric motor."
        constraint { system.motorCount == 1 }
    }

    requirement def EmergencyStopRequirement {
        subject controller : CentralController;
        doc "The controller shall provide an emergency stop capability."
        constraint { controller.supportsEmergencyStop == true }
    }

    requirement def SpeedLimitRequirement {
        subject system : RingTransportSystem;
        doc "The system shall operate within defined safe speed limits."
        constraint { system.maxLinearSpeed <= 2.0 ["m/s"] }
    }

    requirement def ContinuousRotationRequirement {
        subject controller : CentralController;
        doc "The controller shall maintain stable constant rotation using carrier feedback."
        constraint { controller.usesCarrierFeedback == true }
    }

    // ---- Part definitions ----
    part def PositionSensor {
        attribute samplingRate : Frequency = 100 [Hz];
        attribute resolution : Angle = 0.001 [rad];
        port sensorOut : SensorDataPort;

        action def sense {
            in currentAngle : Angle;
            out data : SensorData;
        }
    }

    part def Carrier {
        attribute id : String;
        attribute maxPayloadMass : Mass = 200 [kg];
        attribute currentPayloadMass : Mass = 0 [kg];
        attribute loaded : Boolean = false;
        port payloadPort : PayloadPort;
        part positionSensor : PositionSensor;

        action def loadPayload {
            in payload : Payload;
            constraint { payload.mass <= maxPayloadMass }
        }

        action def unloadPayload {
            out payload : Payload;
        }
    }

    part def CircularTrack {
        attribute radius : Length = 5 [m];
        attribute circumference : Length = 2 * 3.14159265358979 * radius;
        port driveInput : MechanicalDrivePort;
        port loadingStation : PayloadPort;
        port unloadingStation : PayloadPort;
    }

    part def DriveMotor {
        attribute ratedPower : Power = 7500 [W];
        attribute ratedVoltage : Voltage = 480 [V];
        attribute currentTorque : Torque = 0 ["N*m"];
        attribute currentAngularSpeed : AngularSpeed = 0 ["rad/s"];
        attribute maxAngularSpeed : AngularSpeed = 0.4 ["rad/s"];
        port powerIn : PowerPort;
        port controlIn : ControlSignalPort;
        port mechanicalOut : MechanicalDrivePort;

        action def rampUp {
            in targetSpeed : AngularSpeed;
            in rampDuration : Duration = 10 [s];
            out deliveredTorque : Torque;
        }

        action def regulate {
            in targetTorque : Torque;
            out deliveredTorque : Torque;
        }
    }

    part def CentralController {
        attribute supportsEmergencyStop : Boolean = true;
        attribute usesCarrierFeedback : Boolean = true;
        attribute targetAngularSpeed : AngularSpeed = 0.4 ["rad/s"];
        attribute rampDuration : Duration = 10 [s];
        attribute emergencyStopRequested : Boolean = false;
        attribute resetRequested : Boolean = false;
        attribute currentSpeed : AngularSpeed = 0 ["rad/s"];
        port controlOut : ControlSignalPort;
        port sensorIn : SensorDataPort;

        state machine ControllerStateMachine {
            attribute operationalState : OperationalState = OperationalState::idle;

            state idle {
                entry action { operationalState = OperationalState::idle; }
            }

            state starting {
                entry action { operationalState = OperationalState::starting; }
            }

            state running {
                entry action { operationalState = OperationalState::running; }
            }

            state emergencyStop {
                entry action { operationalState = OperationalState::emergencyStop; }
            }

            transition idle_to_starting
                from idle to starting
                when controlOut.controlSignal.enable == true;

            transition starting_to_running
                from starting to running
                when currentSpeed >= targetAngularSpeed;

            transition idle_to_emergency
                from idle to emergencyStop
                when emergencyStopRequested == true;

            transition starting_to_emergency
                from starting to emergencyStop
                when emergencyStopRequested == true;

            transition running_to_emergency
                from running to emergencyStop
                when emergencyStopRequested == true;

            transition emergency_to_idle
                from emergencyStop to idle
                when resetRequested == true;
        }

        action def regulateMotor {
            in sensorData : SensorData;
            out controlSignal : ControlSignal;
            constraint { controlSignal.targetAngularSpeed == targetAngularSpeed }
        }
    }

    part def PowerSupply {
        attribute outputVoltage : Voltage = 480 [V];
        attribute maxOutputPower : Power = 15000 [W];
        attribute outputFrequency : Frequency = 50 [Hz];
        port powerOut : PowerPort;
    }

    part def RingTransportSystem {
        attribute carrierCount : Integer = 4;
        attribute motorCount : Integer = 1;
        attribute trackRadius : Length = 5 [m];
        attribute maxLinearSpeed : LinearSpeed = 2.0 ["m/s"];
        attribute operational : Boolean = false;

        part powerSupply : PowerSupply;
        part controller : CentralController;
        part motor : DriveMotor;
        part track : CircularTrack;
        part carriers : Carrier[4] {
            redefines id = {"C1","C2","C3","C4"};
        }

        connections {
            connect powerSupply.powerOut to motor.powerIn;
            connect controller.controlOut to motor.controlIn;
            connect motor.mechanicalOut to track.driveInput;
            connect carriers[1].positionSensor.sensorOut to controller.sensorIn;
            connect track.loadingStation to carriers[1].payloadPort;
            connect carriers[1].payloadPort to track.unloadingStation;
        }

        satisfy TrackGeometryRequirement {
            subject track = self.track;
        }

        satisfy CarrierCountRequirement {
            subject system = self;
        }

        satisfy PayloadCapacityRequirement {
            subject carrier = self.carriers[1];
        }

        satisfy SingleDriveRequirement {
            subject system = self;
        }

        satisfy EmergencyStopRequirement {
            subject controller = self.controller;
        }

        satisfy SpeedLimitRequirement {
            subject system = self;
        }

        satisfy ContinuousRotationRequirement {
            subject controller = self.controller;
        }
    }
}
