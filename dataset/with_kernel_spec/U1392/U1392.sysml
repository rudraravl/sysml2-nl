package IndustrialCentrifugalFan {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        alias Torque for ISQ::TorqueValue;
        alias RotationalSpeed for ISQ::AngularVelocityValue;
        alias FlowRate for ISQ::VolumeFlowRateValue;
        alias Pressure for ISQ::PressureValue;
        alias VibrationLevel for ISQ::AccelerationValue;
        alias Power for ISQ::PowerValue;

        item def Air;

        attribute def StartCmd;
        attribute def StopCmd;
        attribute def SpeedCmd { attribute speed : RotationalSpeed; }
        attribute def FaultSignal;
        attribute def ResetCmd;

        port def AirPort {
            in air : Air;
            attribute airFlow : FlowRate;
            attribute airPressure : Pressure;
        }
        port def DrivePort {
            attribute torque : Torque;
            attribute speed : RotationalSpeed;
        }
        port def ControlPort {
            in start : StartCmd;
            in stop : StopCmd;
            in speedCmd : SpeedCmd;
            out vibration : VibrationLevel;
            out speed : RotationalSpeed;
            out fault : FaultSignal;
        }

        part def Impeller {
            attribute numBlades : Integer;
            port driveIn : DrivePort;
            port airIn : AirPort;
            port airOut : AirPort;
        }

        part def ScrollHousing {
            port airIn : AirPort;
            port airOut : AirPort;
        }

        part def ElectricMotor {
            attribute ratedPower : Power;
            port driveOut : DrivePort;
            port controlIn : ControlPort;
        }

        part def DriveShaft {
            port shaftIn : DrivePort;
            port shaftOut : DrivePort;
        }

        part def BearingAssembly {
            port bearingIn : DrivePort;
            port bearingOut : DrivePort;
            attribute vibration : VibrationLevel;
        }

        part def ControlModule {
            port systemCmd : ControlPort;
            port motorCmd : ControlPort;
            attribute maxVibration : VibrationLevel;
        }

        action def 'Draw Air' { in air : Air; out airOut : Air; }
        action def 'Accelerate Air' { in air : Air; in torque : Torque; in speed : RotationalSpeed; out airOut : Air; }
        action def 'Diffuse Air' { in air : Air; out airOut : Air; }

        action def 'Provide Airflow' {
            in air : Air;
            out airOut : Air;
        }

        state def 'Fan Operational States';

        part def CentrifugalFanSystem {
            part impeller : Impeller;
            part housing : ScrollHousing;
            part motor : ElectricMotor;
            part driveShaft : DriveShaft;
            part bearings : BearingAssembly;
            part controller : ControlModule;

            port inlet : AirPort;
            port outlet : AirPort;
            port sysControl : ControlPort;

            perform action 'provide airflow' : 'Provide Airflow';
            exhibit state 'fan operational states' : 'Fan Operational States';
        }
    }

    package Usages {
        private import Definitions::*;

        action 'provide airflow' : 'Provide Airflow' {
            in air : Air;
            out airOut : Air;
            action 'draw air' : 'Draw Air' {
                in air = 'provide airflow'.air;
                out airOut : Air;
            }
            flow 'draw air'.airOut to 'accelerate air'.air;
            action 'accelerate air' : 'Accelerate Air' {
                in air : Air;
                in torque : Torque;
                in speed : RotationalSpeed;
                out airOut : Air;
            }
            flow 'accelerate air'.airOut to 'diffuse air'.air;
            action 'diffuse air' : 'Diffuse Air' {
                in air : Air;
                out airOut = 'provide airflow'.airOut;
            }
        }

        part 'centrifugal fan' : CentrifugalFanSystem {
            connect sysControl to controller.systemCmd;
            connect controller.motorCmd to motor.controlIn;
            connect motor.driveOut to driveShaft.shaftIn;
            connect driveShaft.shaftOut to bearings.bearingIn;
            connect bearings.bearingOut to impeller.driveIn;
            connect inlet to impeller.airIn;
            connect impeller.airOut to housing.airIn;
            connect housing.airOut to outlet;

            exhibit state 'fan operational states' : 'Fan Operational States' {
                entry; then off;
                state off;
                accept StartCmd then startup;
                state startup;
                accept when motor.driveOut.speed > 0 then normalOperation;
                state normalOperation {
                    do 'provide airflow';
                }
                accept StopCmd then shutdown;
                accept FaultSignal then fault;
                state shutdown;
                accept ResetCmd then off;
                state fault {
                    do send new StopCmd() to controller;
                }
                accept ResetCmd then off;
            }
        }

        requirement def 'Fan Performance Requirement' {
            subject fan : CentrifugalFanSystem;
            attribute requiredFlowRate : FlowRate;
            attribute requiredPressure : Pressure;
            require constraint { fan.outlet.airPressure >= requiredPressure and fan.outlet.airFlow >= requiredFlowRate }
        }

        requirement def 'Safety Requirement' {
            subject fan : CentrifugalFanSystem;
            attribute maxVibrationLimit : VibrationLevel;
            require constraint { fan.bearings.vibration <= maxVibrationLimit }
        }
    }
}
