package WindTurbineSystem {
    public import ScalarValues::*;
    public import ISQ::*;
    public import SI::*;
    public import Definitions::*;

    package Definitions {
        public import ItemDefinitions::*;
        public import AttributeDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            private import ISQ::*;

            item def WindFlow {
                attribute speed :> ISQ::speed;
                attribute direction :> ISQ::planeAngle;
            }
            item def MechanicalTorque {
                attribute value :> ISQ::torque;
            }
            item def RotationalSpeed {
                attribute value :> ISQ::angularVelocity;
            }
            item def ElectricalPower {
                attribute value :> ISQ::power;
            }
        }

        package AttributeDefinitions {
            private import ISQ::*;
            attribute def StartSignal;
            attribute def StopSignal;
            attribute def EmergencyStopSignal;
            attribute def StartupCompleteSignal;
            attribute def StoppedSignal;
            attribute def ResetSignal;
            attribute def CutInSpeed :> ISQ::speed;
            attribute def CutOutSpeed :> ISQ::speed;
            attribute def RatedPower :> ISQ::power;
        }

        package PortDefinitions {
            private import ItemDefinitions::*;
            private import AttributeDefinitions::*;
            private import ISQ::*;

            port def WindSensorPort {
                out wind : WindFlow;
            }
            port def MechanicalTorquePort {
                out torque : MechanicalTorque;
                out speed : RotationalSpeed;
            }
            port def RotationalSpeedPort {
                out rotation : RotationalSpeed;
            }
            port def PowerOutputPort {
                out power : ElectricalPower;
            }
            port def ControlCmdPort {
                in startCmd : StartSignal;
                in stopCmd : StopSignal;
                in emergencyStopCmd : EmergencyStopSignal;
                in resetCmd : ResetSignal;
            }
            port def PitchCmdPort {
                out pitchAngle :> ISQ::planeAngle;
            }
            port def YawCmdPort {
                out yawAngle :> ISQ::planeAngle;
            }
            port def BrakeCmdPort {
                out brakeEngaged : Boolean;
            }
        }

        package ActionDefinitions {
            private import ItemDefinitions::*;
            private import ISQ::*;

            action def CaptureWind {
                in wind : WindFlow;
                out rotorTorque : MechanicalTorque;
                out rotorSpeed : RotationalSpeed;
            }
            action def AmplifyRotation {
                in inputTorque : MechanicalTorque;
                in inputSpeed : RotationalSpeed;
                out outputTorque : MechanicalTorque;
                out outputSpeed : RotationalSpeed;
            }
            action def GenerateElectricity {
                in inputTorque : MechanicalTorque;
                in inputSpeed : RotationalSpeed;
                out electricalPower : ElectricalPower;
            }
            action def ProvidePower {
                in wind : WindFlow;
                out gridPower : ElectricalPower;
            }
            action def ApplyBrake;
            action def ApplyEmergencyBrake;
            action def YawNacelle {
                in targetDirection :> ISQ::planeAngle;
            }
            action def AdjustPitch {
                in wind : WindFlow;
                out pitchAngle :> ISQ::planeAngle;
            }
            action def PerformStartupSequence;
        }

        package StateDefinitions {
            state def TurbineStates;
        }

        package PartDefinitions {
            private import PortDefinitions::*;
            private import ActionDefinitions::*;
            private import ItemDefinitions::*;
            private import AttributeDefinitions::*;
            private import StateDefinitions::*;
            private import ISQ::*;
            private import SI::*;

            part def Tower {
                attribute height :> ISQ::length;
            }
            part def RotorBlade {
                attribute length :> ISQ::length;
                attribute pitchAngle :> ISQ::planeAngle;
            }
            part def RotorHub {
                attribute diameter :> ISQ::length;
            }
            part def RotorAssembly {
                part hub : RotorHub;
                part blade1 : RotorBlade;
                part blade2 : RotorBlade;
                part blade3 : RotorBlade;
                port windInputPort : WindSensorPort;
                port mechanicalOutputPort : MechanicalTorquePort;
                perform action captureWind : CaptureWind;
            }
            part def Gearbox {
                attribute gearRatio : Real;
                port mechanicalInputPort : MechanicalTorquePort;
                port mechanicalOutputPort : MechanicalTorquePort;
                perform action amplifyRotation : AmplifyRotation;
            }
            part def Generator {
                port mechanicalInputPort : MechanicalTorquePort;
                port powerOutputPort : PowerOutputPort;
                perform action generateElectricity : GenerateElectricity;
            }
            part def Drivetrain {
                part gearbox : Gearbox;
                part generator : Generator;
                connect gearbox.mechanicalOutputPort to generator.mechanicalInputPort;
            }
            part def YawSystem {
                attribute currentYawAngle :> ISQ::planeAngle;
                port yawCmdPort : YawCmdPort;
                perform action yawNacelle : YawNacelle;
            }
            part def BrakeSystem {
                attribute brakeEngaged : Boolean;
                port brakeCmdPort : BrakeCmdPort;
                perform action applyBrake : ApplyBrake;
                perform action applyEmergencyBrake : ApplyEmergencyBrake;
            }
            part def Nacelle {
                part rotor : RotorAssembly;
                part drivetrain : Drivetrain;
                part yawSystem : YawSystem;
                part brakeSystem : BrakeSystem;
                port powerOutputPort : PowerOutputPort;
                port windInputPort : WindSensorPort;
                port pitchCmdPort : PitchCmdPort;
                port yawCmdPort : YawCmdPort;
                port brakeCmdPort : BrakeCmdPort;

                connect windInputPort to rotor.windInputPort;
                connect rotor.mechanicalOutputPort to drivetrain.gearbox.mechanicalInputPort;
                connect drivetrain.generator.powerOutputPort to powerOutputPort;
                connect yawCmdPort to yawSystem.yawCmdPort;
                connect brakeCmdPort to brakeSystem.brakeCmdPort;
            }
            part def TurbineController {
                attribute cutInSpeed :> ISQ::speed = 3.0 [m/s];
                attribute cutOutSpeed :> ISQ::speed = 25.0 [m/s];
                attribute ratedPower :> ISQ::power = 5000 [kW];
                attribute currentWindSpeed :> ISQ::speed;
                attribute gridReady : Boolean;

                port windSensorPort : WindSensorPort;
                port controlCmdPort : ControlCmdPort;
                port pitchCmdPort : PitchCmdPort;
                port yawCmdPort : YawCmdPort;
                port brakeCmdPort : BrakeCmdPort;

                perform action adjustPitch : AdjustPitch;
                perform action yawNacelle : YawNacelle;
            }
            part def WindTurbine {
                attribute ratedPower :> ISQ::power = 5000 [kW];
                attribute cutInSpeed :> ISQ::speed = 3.0 [m/s];
                attribute cutOutSpeed :> ISQ::speed = 25.0 [m/s];
                attribute currentWindSpeed :> ISQ::speed;

                part tower : Tower;
                part nacelle : Nacelle;
                ref controller : TurbineController;

                port powerOutputPort : PowerOutputPort;
                port windSensorPort : WindSensorPort;
                port controlCmdPort : ControlCmdPort;

                perform action providePower : ProvidePower;
                perform action applyBrake : ApplyBrake;
                perform action applyEmergencyBrake : ApplyEmergencyBrake;
                perform action performStartupSequence : PerformStartupSequence;

                connect nacelle.powerOutputPort to powerOutputPort;
                connect windSensorPort to nacelle.windInputPort;
                connect controller.pitchCmdPort to nacelle.pitchCmdPort;
                connect controller.yawCmdPort to nacelle.yawCmdPort;
                connect controller.brakeCmdPort to nacelle.brakeCmdPort;

                exhibit state turbineStates : TurbineStates parallel {
                    state operationalStates {
                        entry; then idle;
                        state idle;
                        accept StartSignal
                            if currentWindSpeed >= cutInSpeed and currentWindSpeed < cutOutSpeed
                            then startup;
                        state startup {
                            do performStartupSequence;
                        }
                        accept StartupCompleteSignal
                            then generating;
                        state generating {
                            do providePower;
                            constraint { ratedPower <= 5000 [kW] }
                        }
                        accept StopSignal
                            then normalStopping;
                        accept when currentWindSpeed >= cutOutSpeed
                            then normalStopping;
                        state normalStopping {
                            do applyBrake;
                        }
                        accept StoppedSignal
                            then idle;
                    }
                    state safetyStates {
                        entry; then safe;
                        state safe;
                        accept EmergencyStopSignal
                            do applyEmergencyBrake
                            then emergencyShutdown;
                        state emergencyShutdown {
                            do applyEmergencyBrake;
                        }
                        accept ResetSignal
                            then safe;
                    }
                }
            }
        }

        package RequirementDefinitions {
            private import PartDefinitions::*;
            private import ISQ::*;
            private import SI::*;

            requirement def PowerGenerationRequirement {
                doc "The turbine shall generate electrical power when wind speed is within operating range.";
                subject turbine : WindTurbine;
                assume {
                    turbine.currentWindSpeed >= turbine.cutInSpeed
                }
                require {
                    turbine.ratedPower > 0.0 [W]
                }
            }
            requirement def SafetyRequirement {
                doc "The brake system shall engage during emergency shutdown.";
                subject turbine : WindTurbine;
                require {
                    turbine.nacelle.brakeSystem.brakeEngaged == true
                }
            }
            requirement def WindSpeedOperatingRange {
                doc "The turbine shall operate within safe wind speed limits.";
                subject turbine : WindTurbine;
                require {
                    turbine.cutInSpeed >= 3.0 [m/s] and turbine.cutOutSpeed <= 25.0 [m/s]
                }
            }
        }
    }

    action providePower : ProvidePower {
        in wind : WindFlow;
        out gridPower : ElectricalPower;

        action captureWind : CaptureWind {
            in wind = providePower::wind;
        }
        action amplifyRotation : AmplifyRotation;
        action generateElectricity : GenerateElectricity {
            out electricalPower = providePower::gridPower;
        }

        flow captureWind.rotorTorque to amplifyRotation.inputTorque;
        flow captureWind.rotorSpeed to amplifyRotation.inputSpeed;
        flow amplifyRotation.outputTorque to generateElectricity.inputTorque;
        flow amplifyRotation.outputSpeed to generateElectricity.inputSpeed;

        first start;
        then captureWind;
        then amplifyRotation;
        then generateElectricity;
        then done;
    }
}
