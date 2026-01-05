package 'Ring Transport System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def RingMaterial;
    attribute def CarrierID;
    attribute def SystemCommand;
    
    enum def OperationalMode {
        idle;
        starting;
        running;
        stopping;
        emergency;
    }
    
    item def PowerSupply {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute powerOutput : PowerValue;
    }
    
    item def PositionData {
        attribute angle : AngleValue;
        attribute timestamp : TimeValue;
    }
    
    item def CarrierPayload {
        attribute payloadMass : MassValue;
        attribute payloadID : CarrierID;
    }
    
    port def PowerPort {
        out power : PowerSupply;
    }
    
    port def ControlPort {
        in command : SystemCommand;
        out status : OperationalMode;
    }
    
    port def SensorPort {
        out position : PositionData;
    }
    
    port def LoadPort {
        in payload : CarrierPayload;
        out deliveredPayload : CarrierPayload;
    }
    
    part def RingTrack {
        attribute radius : LengthValue;
        attribute circumference : LengthValue;
        attribute material : RingMaterial;
        attribute maxAngularVelocity : AngularVelocityValue;
        
        port trackInterface {
            attribute frictionCoefficient : Real;
            attribute wearLevel : Real;
        }
    }
    
    part def DriveMotor {
        attribute ratedTorque : TorqueValue;
        attribute ratedSpeed : AngularVelocityValue;
        attribute efficiency : Real;
        
        port motorPower : PowerPort;
        port motorControl : ControlPort;
        
        attribute currentTorque : TorqueValue;
        attribute currentSpeed : AngularVelocityValue;
    }
    
    part def Carrier {
        attribute carrierMass : MassValue;
        attribute maxPayload : MassValue;
        attribute currentPosition : AngleValue;
        
        port loadInterface : LoadPort;
        port positionSensor : SensorPort;
        
        attribute isLoaded : Boolean;
        attribute currentPayload : CarrierPayload;
    }
    
    part def ControlSystem {
        attribute targetVelocity : AngularVelocityValue;
        attribute operatingMode : OperationalMode;
        
        port systemControl : ControlPort;
        port motorCommand : ControlPort;
        port sensorInput : SensorPort;
        
        attribute safetyEnabled : Boolean;
        attribute emergencyStop : Boolean;
    }
    
    part def RingTransportSystem {
        doc /* 
            A continuous circular transport system that moves carriers along a ring-shaped track.
            The system's primary function is to circulate payloads continuously around the ring,
            enabling automated material handling in a closed-loop configuration.
        */
        
        part track : RingTrack {
            attribute :>> radius = 5.0 [m];
            attribute :>> circumference = 31.416 [m];
            attribute :>> maxAngularVelocity = 2.0 [SI::rad/SI::s];
        }
        
        part motor : DriveMotor {
            attribute :>> ratedTorque = 500.0 [SI::N*SI::m];
            attribute :>> ratedSpeed = 3.0 [SI::rad/SI::s];
            attribute :>> efficiency = 0.92;
        }
        
        part carrier : Carrier[4] {
            attribute :>> carrierMass = 50.0 [kg];
            attribute :>> maxPayload = 200.0 [kg];
        }
        
        part controller : ControlSystem {
            attribute :>> targetVelocity = 1.5 [SI::rad/SI::s];
            attribute :>> safetyEnabled = true;
            attribute :>> emergencyStop = false;
        }
        
        part powerSupply : PowerSupply {
            attribute :>> voltage = 480.0 [V];
            attribute :>> current = 30.0 [A];
            attribute :>> powerOutput = 14.4 [kW];
        }
        
        connect powerSupply to motor.motorPower;
        connect controller.motorCommand to motor.motorControl;
        connect carrier[1].positionSensor to controller.sensorInput;
        
        perform action operateSystem : OperateRingSystem;
    }
    
    action def MonitorPosition {
        in carrier : Carrier;
        out currentAngle : AngleValue;
        out velocity : AngularVelocityValue;
    }
    
    action def CalculateMotorCommand {
        in targetSpeed : AngularVelocityValue;
        in currentSpeed : AngularVelocityValue;
        in safetyStatus : Boolean;
        out torqueCommand : TorqueValue;
        out speedCommand : AngularVelocityValue;
    }
    
    action def ApplyMotorTorque {
        in torqueCommand : TorqueValue;
        in speedCommand : AngularVelocityValue;
        out appliedTorque : TorqueValue;
        out motorSpeed : AngularVelocityValue;
    }
    
    action def MoveCarriers {
        in motorSpeed : AngularVelocityValue;
        in trackRadius : LengthValue;
        in carriers : Carrier[*];
        out updatedPositions : AngleValue[*];
    }
    
    action def LoadCarrier {
        in carrier : Carrier;
        in payload : CarrierPayload;
        out loaded : Boolean;
    }
    
    action def UnloadCarrier {
        in carrier : Carrier;
        out deliveredPayload : CarrierPayload;
        out unloaded : Boolean;
    }
    
    action def ContinuousOperation {
        in ctrl : ControlSystem;
        in mot : DriveMotor;
        in track : RingTrack;
        in carriers : Carrier[*];
        out systemSpeed : AngularVelocityValue;
        
        private attribute targetSpeed := ctrl.targetVelocity;
        private attribute currentSpeed : AngularVelocityValue := 0.0 [SI::rad/SI::s];
        
        loop {
            perform action monitor : MonitorPosition {
                in carrier = carriers[1];
                out currentAngle;
                out velocity;
            }
            then assign currentSpeed := monitor.velocity;
            
            then perform action calculate : CalculateMotorCommand {
                in targetSpeed = targetSpeed;
                in currentSpeed = currentSpeed;
                in safetyStatus = ctrl.safetyEnabled;
                out torqueCommand;
                out speedCommand;
            }
            
            then perform action apply : ApplyMotorTorque {
                in torqueCommand = calculate.torqueCommand;
                in speedCommand = calculate.speedCommand;
                out appliedTorque;
                out motorSpeed;
            }
            
            then perform action move : MoveCarriers {
                in motorSpeed = apply.motorSpeed;
                in trackRadius = track.radius;
                in carriers = carriers;
                out updatedPositions;
            }
            
            then assign systemSpeed := apply.motorSpeed;
        }
    }
    
    action def OperateRingSystem {
        in attribute startCommand : SystemCommand;
        in attribute stopCommand : SystemCommand;
        in part system : RingTransportSystem;
        
        first start;
        then idle;
        
        loop {
            accept start : SystemCommand;
            
            then action initialize {
                assign system.controller.operatingMode := OperationalMode::starting;
                assign system.motor.currentSpeed := 0.0 [SI::rad/SI::s];
            }
            
            then action rampUp {
                private attribute rampSpeed : AngularVelocityValue := 0.0 [SI::rad/SI::s];
                loop {
                    assign rampSpeed := rampSpeed + 0.1 [SI::rad/SI::s];
                    assign system.motor.currentSpeed := rampSpeed;
                }
                until rampSpeed >= system.controller.targetVelocity;
            }
            
            then action run : ContinuousOperation {
                in ctrl = system.controller;
                in mot = system.motor;
                in track = system.track;
                in carriers = system.carrier;
                out systemSpeed;
            }
            
            then accept stop : SystemCommand;
            
            then action shutdown {
                assign system.controller.operatingMode := OperationalMode::stopping;
                assign system.motor.currentSpeed := 0.0 [SI::rad/SI::s];
            }
            
            then idle;
        }
    }
    
    state def SystemStateMachine {
        entry; then idle;
        
        state idle;
        accept StartCommand then starting;
        
        state starting;
        accept SpeedReached then running;
        
        state running;
        accept StopCommand then stopping;
        accept EmergencyStop then emergency;
        
        state stopping;
        accept SpeedZero then idle;
        
        state emergency;
        accept ResetCommand then idle;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The ring transport system shall continuously circulate carriers along a circular track,
            enabling automated payload transport in a closed-loop configuration.
        */
        
        subject system : RingTransportSystem;
        
        require constraint continuousMotion {
            system.motor.currentSpeed > 0.0 [SI::rad/SI::s]
        }
        
        require constraint carrierCapacity {
            system.carrier->forAll(c | c.maxPayload >= 200.0 [kg])
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* 
            The system shall maintain stable operation at the target velocity with minimal variation.
        */
        
        subject system : RingTransportSystem;
        
        require constraint motorEfficiency {
            system.motor.efficiency >= 0.90
        }
    }
    
    requirement def SafetyRequirement {
        doc /* 
            The system shall provide emergency stop capability and operate within safe speed limits.
        */
        
        subject system : RingTransportSystem;
        
        require constraint emergencyStopAvailable {
            system.controller.safetyEnabled == true
        }
        
        require constraint speedLimit {
            system.motor.currentSpeed <= system.track.maxAngularVelocity
        }
    }
    
    requirement <'RTS-001'> systemPrimaryFunction : PrimaryFunctionRequirement {
        doc /*
            The Ring Transport System's primary function is to provide continuous,
            automated circulation of multiple carriers around a ring-shaped track,
            enabling efficient material handling in manufacturing or distribution facilities.
        */
        
        subject theSystem = ringSystem;
        
        require continuousMotion;
        require carrierCapacity;
    }
    
    requirement <'RTS-002'> systemPerformance : PerformanceRequirement {
        subject theSystem = ringSystem;
        
        require motorEfficiency;
    }
    
    requirement <'RTS-003'> systemSafety : SafetyRequirement {
        subject theSystem = ringSystem;
        
        require emergencyStopAvailable;
        require speedLimit;
    }
    
    part ringSystem : RingTransportSystem {
        satisfy systemPrimaryFunction;
        satisfy systemPerformance;
        satisfy systemSafety;
        
        exhibit state behavior : SystemStateMachine;
    }
}
