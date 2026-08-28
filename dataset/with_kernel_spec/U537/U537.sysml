package PaddleWheelSystem {
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        public import ISQ::*;
        public import ScalarValues::*;

        package ItemDefinitions {
            item def WaterFlow {
                attribute flowRate :> ISQ::VolumeFlowRate;
                attribute temperature :> ISQ::Temperature;
            }
            item def DischargedWater {
                attribute flowRate :> ISQ::VolumeFlowRate;
            }
        }

        package AttributeDefinitions {
            attribute def StartCmd;
            attribute def StopCmd;
            attribute def EmergencyStopCmd;
            attribute def ResetCmd;
            attribute def HighLoadSignal;
            attribute def LowLoadSignal;
            attribute def NormalLoadSignal;
            attribute def OverspeedAlert;
            attribute def OverloadAlert;

            attribute def WheelDiameter :> ISQ::LengthValue;
            attribute def PaddleCount :> Integer;
            attribute def MaxFlowRate :> ISQ::VolumeFlowRateValue;
            attribute def MinFlowRate :> ISQ::VolumeFlowRateValue;
            attribute def MaxRotSpeed :> ISQ::AngularVelocityValue;
            attribute def MaxTorque :> ISQ::TorqueValue;
        }

        package PortDefinitions {
            port def WaterInPort {
                in waterFlow : WaterFlow;
            }
            port def WaterOutPort {
                out dischargedWater : DischargedWater;
            }
            port def MechanicalPowerPort {
                out axleTorque :> ISQ::TorqueValue;
                out axleSpeed :> ISQ::AngularVelocityValue;
            }
            port def ControlPort {
                in startCmd : StartCmd;
                in stopCmd : StopCmd;
                in emergencyStopCmd : EmergencyStopCmd;
                in resetCmd : ResetCmd;
            }
            port def StatusPort {
                out overspeedAlert : OverspeedAlert;
                out overloadAlert : OverloadAlert;
                out currentSpeed :> ISQ::AngularVelocityValue;
                out currentTorque :> ISQ::TorqueValue;
            }
            port def PaddleForcePort {
                out paddleForce :> ISQ::ForceValue;
            }
            port def HubTorquePort {
                in hubTorque :> ISQ::TorqueValue;
                out axleTorque :> ISQ::TorqueValue;
            }
            port def AxleDrivePort {
                out axleTorque :> ISQ::TorqueValue;
                out axleSpeed :> ISQ::AngularVelocityValue;
            }
        }

        package ActionDefinitions {
            action def 'Capture Water Energy' {
                in waterFlow : WaterFlow;
                out paddleForce :> ISQ::ForceValue;
            }
            action def 'Generate Torque' {
                in paddleForce :> ISQ::ForceValue;
                out hubTorque :> ISQ::TorqueValue;
            }
            action def 'Transmit Torque' {
                in hubTorque :> ISQ::TorqueValue;
                out axleTorque :> ISQ::TorqueValue;
                out axleSpeed :> ISQ::AngularVelocityValue;
            }
            action def 'Discharge Water' {
                in waterFlow : WaterFlow;
                out dischargedWater : DischargedWater;
            }
            action def 'Provide Mechanical Power' {
                in waterFlow : WaterFlow;
                out axleTorque :> ISQ::TorqueValue;
                out axleSpeed :> ISQ::AngularVelocityValue;
                out dischargedWater : DischargedWater;
            }
            action def 'Monitor Speed and Torque' {
                in axleSpeed :> ISQ::AngularVelocityValue;
                in axleTorque :> ISQ::TorqueValue;
                out overspeedAlert : OverspeedAlert;
                out overloadAlert : OverloadAlert;
            }
            action def 'Coast to Halt' {
                in axleSpeed :> ISQ::AngularVelocityValue;
            }
            action def 'Ramp Up' {
                in waterFlow : WaterFlow;
                out targetSpeed :> ISQ::AngularVelocityValue;
            }
        }

        package StateDefinitions {
            state def 'Paddle Wheel States';
            state def 'Controller States';
        }

        package PartDefinitions {
            part def PaddleWheelSystem {
                attribute wheelDiameter : WheelDiameter = 5 [m];
                attribute paddleCount : PaddleCount = 16;
                attribute maxFlowRate : MaxFlowRate = 10.0 [m^3/s];
                attribute minFlowRate : MinFlowRate = 0.5 [m^3/s];
                attribute maxRotSpeed : MaxRotSpeed = 30 [rev/min];
                attribute maxTorque : MaxTorque = 50000 [N*m];

                port waterInPort : WaterInPort;
                port waterOutPort : WaterOutPort;
                port mechPowerPort : MechanicalPowerPort;
                port controlPort : ControlPort;
                port statusPort : StatusPort;

                perform action 'provide mechanical power' : 'Provide Mechanical Power';
                perform action 'monitor speed and torque' : 'Monitor Speed and Torque';
                exhibit state 'paddle wheel states' : 'Paddle Wheel States';
            }

            part def CentralAxle {
                attribute material : String = "Carbon Steel";
                attribute diameter :> ISQ::LengthValue;
                attribute length :> ISQ::LengthValue;
                port axleDrivePort : AxleDrivePort;
            }

            part def Hub {
                attribute diameter :> ISQ::LengthValue;
                attribute material : String = "Carbon Steel";
                port hubTorquePort : HubTorquePort;
            }

            part def Paddle {
                attribute angle :> ISQ::PlaneAngleValue;
                attribute width :> ISQ::LengthValue;
                attribute height :> ISQ::LengthValue;
                attribute material : String = "Reinforced Steel";
                port paddleForcePort : PaddleForcePort;
            }

            part def PaddleAssembly {
                attribute paddleCount : PaddleCount = 16;
                part paddles : Paddle[paddleCount];
                port paddleAssemblyPort {
                    out totalPaddleForce :> ISQ::ForceValue;
                }
            }

            part def SupportFrame {
                attribute material : String = "Reinforced Steel";
                attribute loadCapacity :> ISQ::ForceValue;
            }

            part def RollerBearing {
                attribute material : String = "Heavy-Duty Steel";
                attribute loadRating :> ISQ::ForceValue;
            }

            part def RollerBearingAssembly {
                attribute loadRating :> ISQ::ForceValue;
                part bearing1 : RollerBearing;
                part bearing2 : RollerBearing;
            }

            part def PaddleWheelController {
                port controlPort : ControlPort;
                port statusPort : StatusPort;
                exhibit state 'controller states' : 'Controller States';
            }
        }

        package RequirementDefinitions {
            requirement def 'Durability Requirement' {
                doc /* The frame, axle, and bearings must withstand continuous operation forces. */
                ref frame : SupportFrame;
                ref axle : CentralAxle;
                ref bearings : RollerBearingAssembly;
                constraint { frame.loadCapacity >= 200000 [N] }
                constraint { bearings.loadRating >= 100000 [N] }
            }

            requirement def 'Flow Rate Requirement' {
                doc /* The system must handle water flow rates from 0.5 to 10.0 cubic meters per second. */
                ref system : PaddleWheelSystem;
                constraint { system.minFlowRate <= 0.5 [m^3/s] }
                constraint { system.maxFlowRate >= 10.0 [m^3/s] }
            }

            requirement def 'Safety Requirement' {
                doc /* The system must trigger emergency shutdown if speed or torque exceeds safe limits. */
                ref system : PaddleWheelSystem;
                constraint { system.maxRotSpeed <= 30 [rev/min] }
                constraint { system.maxTorque <= 50000 [N*m] }
            }

            requirement def 'Power Output Requirement' {
                doc /* The system must provide rotational torque and speed at the axle for external use. */
                ref system : PaddleWheelSystem;
            }

            requirement def 'Wheel Configuration Requirement' {
                doc /* The wheel must be 5 meters in diameter with 16 angled paddles. */
                ref system : PaddleWheelSystem;
                constraint { system.wheelDiameter == 5 [m] }
                constraint { system.paddleCount == 16 }
            }
        }
    }

    package Usages {
        private import Definitions::*;

        action 'provide mechanical power' : 'Provide Mechanical Power' {
            in waterFlow : WaterFlow;
            out axleTorque :> ISQ::TorqueValue;
            out axleSpeed :> ISQ::AngularVelocityValue;
            out dischargedWater : DischargedWater;

            action 'capture water energy' : 'Capture Water Energy' {
                in waterFlow = 'provide mechanical power'.waterFlow;
                out paddleForce :> ISQ::ForceValue;
            }
            flow 'capture water energy'.paddleForce
                to 'generate torque'.paddleForce;
            action 'generate torque' : 'Generate Torque' {
                in paddleForce :> ISQ::ForceValue;
                out hubTorque :> ISQ::TorqueValue;
            }
            flow 'generate torque'.hubTorque
                to 'transmit torque'.hubTorque;
            action 'transmit torque' : 'Transmit Torque' {
                in hubTorque :> ISQ::TorqueValue;
                out axleTorque :> ISQ::TorqueValue;
                out axleSpeed :> ISQ::AngularVelocityValue;
            }
            flow 'transmit torque'.axleTorque
                to 'provide mechanical power'.axleTorque;
            flow 'transmit torque'.axleSpeed
                to 'provide mechanical power'.axleSpeed;
            action 'discharge water' : 'Discharge Water' {
                in waterFlow = 'provide mechanical power'.waterFlow;
                out dischargedWater : DischargedWater;
            }
            flow 'discharge water'.dischargedWater
                to 'provide mechanical power'.dischargedWater;
        }

        action 'monitor speed and torque' : 'Monitor Speed and Torque' {
            in axleSpeed :> ISQ::AngularVelocityValue;
            in axleTorque :> ISQ::TorqueValue;
            out overspeedAlert : OverspeedAlert;
            out overloadAlert : OverloadAlert;
        }

        state 'paddle wheel states' : 'Paddle Wheel States' parallel {
            state 'operational states' {
                entry; then idle;
                state idle {
                    doc /* System remains idle until a start command is received. */
                }
                transition idle_to_startup
                    first idle
                    accept startCmd : StartCmd via paddleWheelSystem.controlPort
                    then startup;
                state startup {
                    doc /* Ramp up to operational speed. */
                    do 'ramp up' : 'Ramp Up' {
                        in waterFlow : WaterFlow;
                        out targetSpeed :> ISQ::AngularVelocityValue;
                    }
                }
                transition startup_to_operational
                    first startup
                    accept NormalLoadSignal
                    then operational;
                state operational {
                    doc /* Normal operation adapting to high and low load conditions. */
                    do 'provide mechanical power';
                    state lowLoad;
                    state highLoad;
                    transition operational_to_lowLoad
                        first operational
                        then lowLoad;
                    transition lowLoad_to_highLoad
                        first lowLoad
                        accept HighLoadSignal
                        then highLoad;
                    transition highLoad_to_lowLoad
                        first highLoad
                        accept LowLoadSignal
                        then lowLoad;
                }
                transition operational_to_shutdown
                    first operational
                    accept stopCmd : StopCmd via paddleWheelSystem.controlPort
                    then shutdown;
                state shutdown {
                    doc /* Coast to a halt. */
                    do 'coast to halt' : 'Coast to Halt' {
                        in axleSpeed :> ISQ::AngularVelocityValue;
                    }
                }
                transition shutdown_to_idle
                    first shutdown
                    then idle;
            }
            state 'safety states' {
                entry; then monitoring;
                state monitoring {
                    doc /* Continuously monitor rotational speed and torque. */
                    do 'monitor speed and torque';
                }
                transition monitoring_to_emergency_overspeed
                    first monitoring
                    when 'monitor speed and torque'.axleSpeed > paddleWheelSystem.maxRotSpeed
                    do send new OverspeedAlert() to paddleWheelSystem.statusPort
                    then emergency;
                transition monitoring_to_emergency_overload
                    first monitoring
                    when 'monitor speed and torque'.axleTorque > paddleWheelSystem.maxTorque
                    do send new OverloadAlert() to paddleWheelSystem.statusPort
                    then emergency;
                state emergency {
                    doc /* Emergency shutdown triggered by overspeed or overload. */
                    do 'coast to halt' : 'Coast to Halt' {
                        in axleSpeed :> ISQ::AngularVelocityValue;
                    }
                }
                transition emergency_to_monitoring
                    first emergency
                    accept resetCmd : ResetCmd via paddleWheelSystem.controlPort
                    then monitoring;
            }
        }

        part paddleWheelSystem : PaddleWheelSystem {
            part centralAxle : CentralAxle {
                attribute diameter = 0.3 [m];
                attribute length = 6.0 [m];
                port axleDrivePort : AxleDrivePort;
            }
            part hub : Hub {
                attribute diameter = 1.0 [m];
                port hubTorquePort : HubTorquePort;
            }
            part paddleAssembly : PaddleAssembly {
                attribute paddleCount = 16;
                part paddles : Paddle[16] {
                    attribute angle = 30 ['°'];
                    attribute width = 1.5 [m];
                    attribute height = 5.0 [m];
                    port paddleForcePort : PaddleForcePort;
                }
                port paddleAssemblyPort {
                    out totalPaddleForce :> ISQ::ForceValue;
                }
            }
            part supportFrame : SupportFrame {
                attribute loadCapacity = 250000 [N];
            }
            part rollerBearingAssembly : RollerBearingAssembly {
                attribute loadRating = 150000 [N];
                part bearing1 : RollerBearing {
                    attribute loadRating = 150000 [N];
                }
                part bearing2 : RollerBearing {
                    attribute loadRating = 150000 [N];
                }
            }
            part controller : PaddleWheelController {
                port controlPort : ControlPort;
                port statusPort : StatusPort;
            }

            port waterInPort : WaterInPort;
            port waterOutPort : WaterOutPort;
            port mechPowerPort : MechanicalPowerPort;
            port controlPort : ControlPort;
            port statusPort : StatusPort;

            connection waterFlowConn
                connect waterInPort.waterFlow
                to 'provide mechanical power'.waterFlow;
            connection torqueOutputConn
                connect 'provide mechanical power'.axleTorque
                to mechPowerPort.axleTorque;
            connection speedOutputConn
                connect 'provide mechanical power'.axleSpeed
                to mechPowerPort.axleSpeed;
            connection dischargeConn
                connect 'provide mechanical power'.dischargedWater
                to waterOutPort.dischargedWater;
            connection paddleForceConn
                connect paddleAssembly.paddleAssemblyPort.totalPaddleForce
                to 'provide mechanical power'.'capture water energy'.paddleForce;
            connection hubTorqueConn
                connect 'provide mechanical power'.'generate torque'.hubTorque
                to hub.hubTorquePort.hubTorque;
            connection axleTorqueConn
                connect hub.hubTorquePort.axleTorque
                to centralAxle.axleDrivePort.axleTorque;
            connection controlConn
                connect controlPort
                to controller.controlPort;
            connection statusConn
                connect controller.statusPort
                to statusPort;
        }

        requirement 'durability requirement' : 'Durability Requirement' {
            ref frame = paddleWheelSystem.supportFrame;
            ref axle = paddleWheelSystem.centralAxle;
            ref bearings = paddleWheelSystem.rollerBearingAssembly;
        }
        requirement 'flow rate requirement' : 'Flow Rate Requirement' {
            ref system = paddleWheelSystem;
        }
        requirement 'safety requirement' : 'Safety Requirement' {
            ref system = paddleWheelSystem;
        }
        requirement 'power output requirement' : 'Power Output Requirement' {
            ref system = paddleWheelSystem;
        }
        requirement 'wheel configuration requirement' : 'Wheel Configuration Requirement' {
            ref system = paddleWheelSystem;
        }
    }
}
