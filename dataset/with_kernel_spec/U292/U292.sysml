package PowertrainModel {
    public import ISQ::*;
    public import ScalarValues::*;
    public import SI::*;
    public import Definitions::*;

    package Definitions {
        public import ValueDefinitions::*;
        public import AttributeDefinitions::*;
        public import PortDefinitions::*;
        public import InterfaceDefinitions::*;
        public import ItemDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package ValueDefinitions {
            attribute def Torque :> ISQ::TorqueValue;
            attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
            attribute def MechanicalPower :> ISQ::PowerValue;
            attribute def GearRatio :> ScalarValues::Real;
            attribute def Efficiency :> ScalarValues::Real;
            attribute def ThrottlePosition :> ScalarValues::Real;
            attribute def MomentOfInertia :> ISQ::MomentOfInertiaValue;
        }

        package AttributeDefinitions {
            attribute def ThrottleCmd {
                attribute position : ThrottlePosition;
            }
            attribute def SpeedSetpoint {
                attribute targetSpeed : RotationalSpeed;
            }
            attribute def SpeedFeedback {
                attribute actualSpeed : RotationalSpeed;
            }
            attribute def StartCmd;
            attribute def ShutdownCmd;
            attribute def LoadChangeDetected;
            attribute def SteadyStateReached;
            attribute def StartupComplete;
            attribute def ShutdownComplete;
        }

        package ItemDefinitions {
            item def ShaftPower {
                attribute speed : RotationalSpeed;
                attribute torque : Torque;
            }
        }

        package PortDefinitions {
            port def MechanicalPowerOutPort {
                out shaftPower : ShaftPower;
            }
            port def MechanicalPowerInPort {
                in shaftPower : ShaftPower;
            }
            port def ThrottleCmdInPort {
                in throttleCmd : ThrottleCmd;
            }
            port def ThrottleCmdOutPort {
                out throttleCmd : ThrottleCmd;
            }
            port def SpeedFeedbackOutPort {
                out speedFeedback : SpeedFeedback;
            }
            port def SpeedFeedbackInPort {
                in speedFeedback : SpeedFeedback;
            }
            port def SpeedSetpointInPort {
                in speedSetpoint : SpeedSetpoint;
            }
            port def SpeedSetpointOutPort {
                out speedSetpoint : SpeedSetpoint;
            }
            port def ControlCmdInPort {
                in startCmd : StartCmd;
                in shutdownCmd : ShutdownCmd;
            }
            port def ControlCmdOutPort {
                out startCmd : StartCmd;
                out shutdownCmd : ShutdownCmd;
            }
        }

        package InterfaceDefinitions {
            interface def PrimeMoverToTransmissionInterface {
                end primeMoverPort : MechanicalPowerOutPort;
                end transmissionPort : MechanicalPowerInPort;
                flow shaftPowerFlow of ShaftPower
                    from primeMoverPort.shaftPower to transmissionPort.shaftPower;
            }
            interface def TransmissionToLoadInterface {
                end transmissionPort : MechanicalPowerOutPort;
                end loadPort : MechanicalPowerInPort;
                flow shaftPowerFlow of ShaftPower
                    from transmissionPort.shaftPower to loadPort.shaftPower;
            }
            interface def ControlToPrimeMoverInterface {
                end controlPort : ThrottleCmdOutPort;
                end primeMoverPort : ThrottleCmdInPort;
                flow throttleFlow of ThrottleCmd
                    from controlPort.throttleCmd to primeMoverPort.throttleCmd;
            }
            interface def LoadToControlInterface {
                end loadPort : SpeedFeedbackOutPort;
                end controlPort : SpeedFeedbackInPort;
                flow speedFeedbackFlow of SpeedFeedback
                    from loadPort.speedFeedback to controlPort.speedFeedback;
            }
            interface def OperatorToControlInterface {
                end operatorPort : SpeedSetpointOutPort;
                end controlPort : SpeedSetpointInPort;
                flow setpointFlow of SpeedSetpoint
                    from operatorPort.speedSetpoint to controlPort.speedSetpoint;
            }
        }

        package ActionDefinitions {
            action def GeneratePower {
                in throttleCmd : ThrottleCmd;
                out shaftPower : ShaftPower;
            }
            action def TransmitPower {
                in inputPower : ShaftPower;
                out outputPower : ShaftPower;
            }
            action def DriveLoad {
                in shaftPower : ShaftPower;
                out speedFeedback : SpeedFeedback;
            }
            action def SenseSpeed {
                in shaftPower : ShaftPower;
                out speedFeedback : SpeedFeedback;
            }
            action def RegulateSpeed {
                in speedSetpoint : SpeedSetpoint;
                in speedFeedback : SpeedFeedback;
                out throttleCmd : ThrottleCmd;
            }
            action def OperatePowertrain {
                in speedSetpoint : SpeedSetpoint;
                out speedFeedback : SpeedFeedback;
                action generatePower : GeneratePower;
                action transmitPower : TransmitPower;
                action driveLoad : DriveLoad;
                action regulateSpeed : RegulateSpeed;
                flow generatePower.shaftPower to transmitPower.inputPower;
                flow transmitPower.outputPower to driveLoad.shaftPower;
                flow driveLoad.speedFeedback to regulateSpeed.speedFeedback;
                flow regulateSpeed.throttleCmd to generatePower.throttleCmd;
            }
        }

        package StateDefinitions {
            state def PowertrainOperationalStates {
                entry; then standby;
                state standby;
                transition standby_to_startup
                    first standby
                    accept StartCmd
                    then startup;
                state startup;
                transition startup_to_operational
                    first startup
                    accept StartupComplete
                    then operational;
                state operational {
                    entry; then steadyState;
                    state steadyState;
                    transition steadyState_to_transient
                        first steadyState
                        accept LoadChangeDetected
                        then transient;
                    state transient;
                    transition transient_to_steadyState
                        first transient
                        accept SteadyStateReached
                        then steadyState;
                }
                transition operational_to_shutdown
                    first operational
                    accept ShutdownCmd
                    then shutdown;
                state shutdown;
                transition shutdown_to_standby
                    first shutdown
                    accept ShutdownComplete
                    then standby;
            }
        }

        package PartDefinitions {
            part def PrimeMover {
                attribute ratedPower : MechanicalPower;
                attribute ratedSpeed : RotationalSpeed;
                attribute currentThrottle : ThrottlePosition;
                port throttleCmdPort : ThrottleCmdInPort;
                port powerOutPort : MechanicalPowerOutPort;
                port controlCmdPort : ControlCmdInPort;
                perform action generatePower : GeneratePower {
                    in throttleCmd = throttleCmdPort.throttleCmd;
                    out shaftPower = powerOutPort.shaftPower;
                }
                exhibit state primeMoverStates : PowertrainOperationalStates;
            }

            part def TransmissionSystem {
                attribute gearRatio : GearRatio = 4.0;
                attribute efficiency : Efficiency;
                attribute inputTorque : Torque;
                attribute outputTorque : Torque;
                attribute inputSpeed : RotationalSpeed;
                attribute outputSpeed : RotationalSpeed;
                port powerInPort : MechanicalPowerInPort;
                port powerOutPort : MechanicalPowerOutPort;
                part gearset {
                    attribute ratio : GearRatio = 4.0;
                    attribute toothCount : Integer;
                }
                part inputShaft {
                    attribute maxTorque : Torque;
                }
                part outputShaft {
                    attribute maxTorque : Torque;
                }
                perform action transmitPower : TransmitPower {
                    in inputPower = powerInPort.shaftPower;
                    out outputPower = powerOutPort.shaftPower;
                }
                constraint gearRatioConstraint { gearRatio == 4.0 }
                constraint efficiencyConstraint { efficiency > 0.90 }
            }

            part def LoadMechanism {
                attribute demandedTorque : Torque;
                attribute actualSpeed : RotationalSpeed;
                attribute inertia : MomentOfInertia;
                port powerInPort : MechanicalPowerInPort;
                port speedFeedbackPort : SpeedFeedbackOutPort;
                perform action driveLoad : DriveLoad {
                    in shaftPower = powerInPort.shaftPower;
                    out speedFeedback = speedFeedbackPort.speedFeedback;
                }
            }

            part def ControlSystem {
                attribute targetSpeed : RotationalSpeed;
                attribute measuredSpeed : RotationalSpeed;
                attribute speedError : RotationalSpeed;
                attribute proportionalGain : ScalarValues::Real;
                attribute integralGain : ScalarValues::Real;
                port speedSetpointPort : SpeedSetpointInPort;
                port speedFeedbackPort : SpeedFeedbackInPort;
                port throttleCmdPort : ThrottleCmdOutPort;
                port controlCmdPort : ControlCmdOutPort;
                perform action regulateSpeed : RegulateSpeed {
                    in speedSetpoint = speedSetpointPort.speedSetpoint;
                    in speedFeedback = speedFeedbackPort.speedFeedback;
                    out throttleCmd = throttleCmdPort.throttleCmd;
                }
                exhibit state controlStates : PowertrainOperationalStates;
            }

            part def PowerTrain {
                attribute totalEfficiency : Efficiency;
                attribute systemSpeed : RotationalSpeed;
                port operatorSetpointPort : SpeedSetpointInPort;
                port operatorControlPort : ControlCmdInPort;
                part primeMover : PrimeMover;
                part transmission : TransmissionSystem;
                part load : LoadMechanism;
                part controller : ControlSystem;

                interface primeMoverToTransmission : PrimeMoverToTransmissionInterface
                    connect primeMover.powerOutPort to transmission.powerInPort;
                interface transmissionToLoad : TransmissionToLoadInterface
                    connect transmission.powerOutPort to load.powerInPort;
                interface controlToPrimeMover : ControlToPrimeMoverInterface
                    connect controller.throttleCmdPort to primeMover.throttleCmdPort;
                interface loadToControl : LoadToControlInterface
                    connect load.speedFeedbackPort to controller.speedFeedbackPort;
                interface operatorToControl : OperatorToControlInterface
                    connect operatorSetpointPort to controller.speedSetpointPort;

                bind primeMover.controlCmdPort = operatorControlPort;

                exhibit state powerTrainStates : PowertrainOperationalStates;
            }
        }

        package RequirementDefinitions {
            requirement def GearRatioRequirement {
                subject transmission : TransmissionSystem;
                constraint { transmission.gearRatio == 4.0 }
            }
            requirement def EfficiencyRequirement {
                subject transmission : TransmissionSystem;
                constraint { transmission.efficiency > 0.90 }
            }
            requirement def SpeedControlRequirement {
                subject controller : ControlSystem;
                attribute tolerance : RotationalSpeed;
                constraint { controller.speedError <= tolerance }
                constraint { controller.speedError >= 0 - tolerance }
            }
            requirement def TorqueCapacityRequirement {
                subject transmission : TransmissionSystem;
                attribute maxInputTorque : Torque;
                constraint { transmission.inputShaft.maxTorque >= maxInputTorque }
            }
            requirement def PowertrainRequirements {
                requirement gearRatioReq : GearRatioRequirement;
                requirement efficiencyReq : EfficiencyRequirement;
                requirement speedControlReq : SpeedControlRequirement;
                requirement torqueCapacityReq : TorqueCapacityRequirement;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part powertrainSystem : PowerTrain {
            attribute totalEfficiency = 0.92;
            attribute systemSpeed = 0.0 [rad/s];

            part primeMover : PrimeMover {
                attribute ratedPower = 100.0 [W];
                attribute ratedSpeed = 3000.0 [rad/s];
                attribute currentThrottle = 0.0;
            }

            part transmission : TransmissionSystem {
                attribute gearRatio = 4.0;
                attribute efficiency = 0.93;
                part gearset {
                    attribute ratio = 4.0;
                    attribute toothCount = 40;
                }
                part inputShaft {
                    attribute maxTorque = 600.0 [N*m];
                }
                part outputShaft {
                    attribute maxTorque = 2400.0 [N*m];
                }
            }

            part load : LoadMechanism {
                attribute demandedTorque = 1200.0 [N*m];
                attribute actualSpeed = 0.0 [rad/s];
                attribute inertia = 2.5 [kg*m^2];
            }

            part controller : ControlSystem {
                attribute targetSpeed = 750.0 [rad/s];
                attribute measuredSpeed = 0.0 [rad/s];
                attribute speedError = 0.0 [rad/s];
                attribute proportionalGain = 0.8;
                attribute integralGain = 0.2;
            }

            requirement powertrainReqs : PowertrainRequirements;
            satisfy powertrainReqs.gearRatioReq by transmission;
            satisfy powertrainReqs.efficiencyReq by transmission;
            satisfy powertrainReqs.speedControlReq by controller;
            satisfy powertrainReqs.torqueCapacityReq by transmission;
        }

        action operatePowertrain : OperatePowertrain {
            in speedSetpoint : SpeedSetpoint;
            out speedFeedback : SpeedFeedback;

            action generatePower : GeneratePower;
            action transmitPower : TransmitPower;
            action driveLoad : DriveLoad;
            action regulateSpeed : RegulateSpeed;

            flow generatePower.shaftPower to transmitPower.inputPower;
            flow transmitPower.outputPower to driveLoad.shaftPower;
            flow driveLoad.speedFeedback to regulateSpeed.speedFeedback;
            flow regulateSpeed.throttleCmd to generatePower.throttleCmd;

            first start;
            then merge continue;
            then action standbyState accept StartCmd;
            then action startupState accept StartupComplete;
            then action operationalState accept ShutdownCmd;
            then continue;

            first standbyState then generatePower;
            first standbyState then transmitPower;
            first standbyState then driveLoad;
            first standbyState then regulateSpeed;

            first generatePower then operationalState;
            first transmitPower then operationalState;
            first driveLoad then operationalState;
            first regulateSpeed then operationalState;
        }
    }
}
