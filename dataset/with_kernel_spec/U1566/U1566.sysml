package SpacecraftSolarPowerSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import PartDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            item def Sunlight {
                attribute intensity :> ISQ::irradiance;
                attribute azimuth :> ISQ::planeAngle;
                attribute elevation :> ISQ::planeAngle;
            }
            item def SunPosition {
                attribute azimuth :> ISQ::planeAngle;
                attribute elevation :> ISQ::planeAngle;
                attribute intensity :> ISQ::irradiance;
            }
            item def GimbalCommand {
                attribute targetAzimuth :> ISQ::planeAngle;
                attribute targetElevation :> ISQ::planeAngle;
            }
            item def RawPower {
                attribute voltage :> ISQ::electricPotential;
                attribute current :> ISQ::electricCurrent;
            }
            item def RegulatedPower {
                attribute voltage :> ISQ::electricPotential;
                attribute current :> ISQ::electricCurrent;
            }
            item def ChargePower {
                attribute voltage :> ISQ::electricPotential;
                attribute current :> ISQ::electricCurrent;
            }
            item def DeployCommand;
            item def DeployCompleteSignal;
            item def SunLockedSignal;
            item def EclipseStartSignal;
            item def EclipseEndSignal;
            item def FaultSignal;
            item def ResetSignal;
        }

        package PortDefinitions {
            port def SunlightInPort {
                in sunlight : Sunlight;
            }
            port def SunPositionOutPort {
                out sunPosition : SunPosition;
            }
            port def SunPositionInPort {
                in sunPosition : SunPosition;
            }
            port def GimbalCommandOutPort {
                out gimbalCommand : GimbalCommand;
            }
            port def GimbalCommandInPort {
                in gimbalCommand : GimbalCommand;
            }
            port def RawPowerOutPort {
                out rawPower : RawPower;
            }
            port def RawPowerInPort {
                in rawPower : RawPower;
            }
            port def RegulatedPowerOutPort {
                out regulatedPower : RegulatedPower;
            }
            port def RegulatedPowerInPort {
                in regulatedPower : RegulatedPower;
            }
            port def ChargePowerOutPort {
                out chargePower : ChargePower;
            }
            port def ChargePowerInPort {
                in chargePower : ChargePower;
            }
            port def DischargePowerOutPort {
                out dischargePower : ChargePower;
            }
            port def DischargePowerInPort {
                in dischargePower : ChargePower;
            }
        }

        package PartDefinitions {
            part def SpacecraftSolarPowerSystem {
                port externalSunlightPort : SunlightInPort;

                part solarArray : SolarArray;
                part sunSensor : SunSensor;
                part attitudeController : AttitudeController;
                part gimbalActuator : GimbalActuator;
                part powerRegulator : PowerRegulator;
                part pdu : PowerDistributionUnit;
                part battery : Battery;
                part loads : Loads;

                exhibit state systemStates : SystemStates;

                flow sunlightToArrayFlow of Sunlight
                    from externalSunlightPort.sunlight to solarArray.sunlightPort.sunlight;
                flow sunlightToSensorFlow of Sunlight
                    from externalSunlightPort.sunlight to sunSensor.sunlightPort.sunlight;
                flow rawPowerFlow of RawPower
                    from solarArray.rawPowerPort.rawPower to powerRegulator.rawPowerPort.rawPower;
                flow regulatedPowerFlow of RegulatedPower
                    from powerRegulator.regulatedPowerPort.regulatedPower to pdu.regulatedPowerPort.regulatedPower;
                flow sunPositionFlow of SunPosition
                    from sunSensor.sunPositionPort.sunPosition to attitudeController.sunPositionPort.sunPosition;
                flow gimbalCommandFlow of GimbalCommand
                    from attitudeController.gimbalCommandPort.gimbalCommand to gimbalActuator.gimbalCommandPort.gimbalCommand;
                flow arrayOrientationFlow of GimbalCommand
                    from gimbalActuator.gimbalCommandPort.gimbalCommand to solarArray.orientationPort.gimbalCommand;
                flow chargePowerFlow of ChargePower
                    from pdu.chargePowerPort.chargePower to battery.chargePowerPort.chargePower;
                flow dischargePowerFlow of ChargePower
                    from battery.dischargePowerPort.dischargePower to pdu.dischargePowerPort.dischargePower;
                flow loadPowerFlow of RegulatedPower
                    from pdu.loadPowerPort.regulatedPower to loads.loadPowerPort.regulatedPower;
            }

            part def SolarArray {
                port sunlightPort : SunlightInPort;
                port rawPowerPort : RawPowerOutPort;
                port orientationPort : GimbalCommandInPort;

                part panels : SolarPanel[4];

                connection sunlightConn connect sunlightPort to panels.sunlightPort;
                connection rawPowerConn connect panels.rawPowerPort to rawPowerPort;
                connection orientationConn connect orientationPort to panels.orientationPort;
            }

            part def SolarPanel {
                port sunlightPort : SunlightInPort;
                port rawPowerPort : RawPowerOutPort;
                port orientationPort : GimbalCommandInPort;

                part cells : SolarCell[32];

                connection panelSunlightConn connect sunlightPort to cells.sunlightPort;
                connection panelRawPowerConn connect cells.rawPowerPort to rawPowerPort;
            }

            part def SolarCell {
                port sunlightPort : SunlightInPort;
                port rawPowerPort : RawPowerOutPort;
                attribute efficiency : Real;
                attribute area :> ISQ::area;
            }

            part def SunSensor {
                port sunlightPort : SunlightInPort;
                port sunPositionPort : SunPositionOutPort;
                perform action senseSun;
            }

            part def AttitudeController {
                port sunPositionPort : SunPositionInPort;
                port gimbalCommandPort : GimbalCommandOutPort;
                perform action calculateOrientation;
            }

            part def GimbalActuator {
                port gimbalCommandPort : GimbalCommandInPort;
                perform action rotateArray;
            }

            part def PowerRegulator {
                port rawPowerPort : RawPowerInPort;
                port regulatedPowerPort : RegulatedPowerOutPort;
                attribute targetVoltage :> ISQ::electricPotential = 28 [V];
                perform action regulateVoltage;
            }

            part def PowerDistributionUnit {
                port regulatedPowerPort : RegulatedPowerInPort;
                port chargePowerPort : ChargePowerOutPort;
                port dischargePowerPort : DischargePowerInPort;
                port loadPowerPort : RegulatedPowerOutPort;
                perform action routePower;
                perform action manageBattery;
            }

            part def Battery {
                port chargePowerPort : ChargePowerInPort;
                port dischargePowerPort : DischargePowerOutPort;
                attribute stateOfCharge : Real;
                attribute capacity :> ISQ::energy;
                perform action charge;
                perform action discharge;
            }

            part def Loads {
                port loadPowerPort : RegulatedPowerInPort;
                part comms : Communications;
                part science : SciencePayload;
                part thermal : ThermalControl;

                connection loadCommsConn connect loadPowerPort to comms.powerIn;
                connection loadScienceConn connect loadPowerPort to science.powerIn;
                connection loadThermalConn connect loadPowerPort to thermal.powerIn;
            }

            part def Communications {
                port powerIn : RegulatedPowerInPort;
                attribute powerDemand :> ISQ::power;
            }

            part def SciencePayload {
                port powerIn : RegulatedPowerInPort;
                attribute powerDemand :> ISQ::power;
            }

            part def ThermalControl {
                port powerIn : RegulatedPowerInPort;
                attribute powerDemand :> ISQ::power;
            }
        }

        package StateDefinitions {
            state def SystemStates {
                entry action initial;
                state Stowed;
                state Deploying;
                state SunAcquisition;
                state NominalOperation;
                state Eclipse;
                state SafeMode;

                transition initial then Stowed;
                transition Stowed_to_Deploying
                    first Stowed
                    accept DeployCommand
                    then Deploying;
                transition Deploying_to_SunAcquisition
                    first Deploying
                    accept DeployCompleteSignal
                    then SunAcquisition;
                transition SunAcquisition_to_NominalOperation
                    first SunAcquisition
                    accept SunLockedSignal
                    then NominalOperation;
                transition NominalOperation_to_Eclipse
                    first NominalOperation
                    accept EclipseStartSignal
                    then Eclipse;
                transition Eclipse_to_NominalOperation
                    first Eclipse
                    accept EclipseEndSignal
                    then NominalOperation;
                transition NominalOperation_to_SafeMode
                    first NominalOperation
                    accept FaultSignal
                    then SafeMode;
                transition Eclipse_to_SafeMode
                    first Eclipse
                    accept FaultSignal
                    then SafeMode;
                transition SafeMode_to_SunAcquisition
                    first SafeMode
                    accept ResetSignal
                    then SunAcquisition;
            }
        }

        package RequirementDefinitions {
            requirement def PowerGenerationRequirement {
                text "The solar array shall generate at least 5 kW of raw power in full sunlight.";
                attribute minPower :> ISQ::power = 5000 [W];
                subject system : SpacecraftSolarPowerSystem;
                assert constraint {
                    system.solarArray.rawPowerPort.rawPower.current * system.solarArray.rawPowerPort.rawPower.voltage >= minPower
                }
            }

            requirement def VoltageRegulationRequirement {
                text "The power regulator shall stabilize output voltage to 28V ± 5%.";
                attribute targetVoltage :> ISQ::electricPotential = 28 [V];
                attribute tolerance :> ISQ::electricPotential = 1.4 [V];
                subject regulator : PowerRegulator;
                assert constraint {
                    regulator.regulatedPowerPort.regulatedPower.voltage >= targetVoltage - tolerance and
                    regulator.regulatedPowerPort.regulatedPower.voltage <= targetVoltage + tolerance
                }
            }

            requirement def EclipseSurvivalRequirement {
                text "The battery shall maintain a minimum state of charge of 20% during eclipse.";
                attribute minStateOfCharge : Real = 0.2;
                subject battery : Battery;
                assert constraint {
                    battery.stateOfCharge >= minStateOfCharge
                }
            }

            requirement def ArrayCompositionRequirement {
                text "The solar array shall consist of exactly four panels, each with 32 solar cells.";
                subject array : SolarArray;
            }

            requirement def AutonomousTrackingRequirement {
                text "The system shall autonomously track the sun using sensor feedback and gimbal actuation.";
                subject system : SpacecraftSolarPowerSystem;
            }

            requirement def SafeModeRequirement {
                text "Upon fault detection, the system shall transition to Safe Mode to minimize power consumption.";
                subject system : SpacecraftSolarPowerSystem;
            }
        }
    }

    public import Definitions::*;

    package Architecture {
        private import Definitions::*;

        part systemInstance : SpacecraftSolarPowerSystem {
            part :>> solarArray;
            part :>> sunSensor;
            part :>> attitudeController;
            part :>> gimbalActuator;
            part :>> powerRegulator;
            part :>> pdu;
            part :>> battery;
            part :>> loads;
        }
    }

    package Requirements {
        private import Definitions::RequirementDefinitions::*;

        requirement req1 :> PowerGenerationRequirement;
        requirement req2 :> VoltageRegulationRequirement;
        requirement req3 :> EclipseSurvivalRequirement;
        requirement req4 :> ArrayCompositionRequirement;
        requirement req5 :> AutonomousTrackingRequirement;
        requirement req6 :> SafeModeRequirement;
    }
}
