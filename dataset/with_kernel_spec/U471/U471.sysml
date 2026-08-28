package HydraulicPowerSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        private import ScalarValues::*;
        private import ISQ::*;

        attribute def PressureValue :> ISQ::pressure;
        attribute def TemperatureValue :> ISQ::temperature;
        attribute def FlowRateValue :> ISQ::volumeFlowRate;
        attribute def VolumeValue :> ISQ::volume;
        attribute def AngleValue :> ISQ::planeAngle;
        attribute def AngularVelocityValue :> ISQ::angularVelocity;
        attribute def TorqueValue :> ISQ::torque;
        attribute def PowerValue :> ISQ::power;
        attribute def LengthValue :> ISQ::length;
        attribute def ForceValue :> ISQ::force;
        attribute def MassValue :> ISQ::mass;

        attribute def StartCommand;
        attribute def ShutdownCommand;
        attribute def EmergencyStopCommand;
        attribute def OverPressureAlert;
        attribute def OverTemperatureAlert;
        attribute def ReturnToNormal;
        attribute def StartupComplete;
        attribute def ShutdownComplete;
        attribute def EmergencyComplete;

        enum def PumpStatus {
            normal;
            degraded;
            critical;
        }

        item def HydraulicFluid {
            attribute pressure :> ISQ::pressure;
            attribute temperature :> ISQ::temperature;
            attribute flowRate :> ISQ::volumeFlowRate;
        }

        port def FluidPort {
            attribute pressure :> ISQ::pressure;
            attribute flowRate :> ISQ::volumeFlowRate;
        }
        port def MechanicalPort {
            attribute torque :> ISQ::torque;
            attribute angularVelocity :> ISQ::angularVelocity;
        }
        port def ControlPort;

        action def ProvidePressure;
        action def StartupSequence;
        action def ShutdownSequence;
        action def EmergencyStop;
        action def Actuate;
        action def MonitorPressure {
            out pressure :> ISQ::pressure;
        }
        action def MonitorTemperature {
            out temperature :> ISQ::temperature;
        }
        action def AssessPerformance {
            out status : PumpStatus;
        }

        part def Pump {
            attribute displacement :> ISQ::volume;
            attribute maxDisplacement :> ISQ::volume;
            attribute ratedSpeed :> ISQ::angularVelocity;
            attribute efficiency :> Real;
            port suctionPort : FluidPort;
            port pressurePort : FluidPort;
            port mechanicalInputPort : MechanicalPort;
            part cylinderBlock : CylinderBlock;
            part swashPlate : SwashPlate;
            part housing;
        }

        part def CylinderBlock {
            attribute pistonCount :> Integer = 9;
            attribute rotationSpeed :> ISQ::angularVelocity;
            part pistons[9] : Piston;
        }

        part def Piston {
            attribute stroke :> ISQ::length;
            attribute diameter :> ISQ::length;
            attribute mass :> ISQ::mass;
        }

        part def SwashPlate {
            attribute angle :> ISQ::planeAngle;
            attribute maxAngle :> ISQ::planeAngle;
        }

        part def Motor {
            attribute ratedPower :> ISQ::power;
            attribute ratedSpeed :> ISQ::angularVelocity;
            port mechanicalOutputPort : MechanicalPort;
        }

        part def DriveShaft {
            attribute torque :> ISQ::torque;
            attribute angularVelocity :> ISQ::angularVelocity;
            port inputEnd : MechanicalPort;
            port outputEnd : MechanicalPort;
        }

        part def Reservoir {
            attribute capacity :> ISQ::volume;
            attribute fluidVolume :> ISQ::volume;
            attribute temperature :> ISQ::temperature;
            port supplyPort : FluidPort;
            port returnPort : FluidPort;
        }

        part def SuctionFilter {
            attribute micronRating :> Real;
            attribute flowCapacity :> ISQ::volumeFlowRate;
            port inletPort : FluidPort;
            port outletPort : FluidPort;
        }

        part def PressureFilter {
            attribute micronRating :> Real;
            attribute flowCapacity :> ISQ::volumeFlowRate;
            attribute burstPressure :> ISQ::pressure;
            port inletPort : FluidPort;
            port outletPort : FluidPort;
        }

        part def HydraulicActuator {
            attribute boreDiameter :> ISQ::length;
            attribute strokeLength :> ISQ::length;
            attribute maxForce :> ISQ::force;
            port inletPort : FluidPort;
            port outletPort : FluidPort;
        }

        part def PressureReliefValve {
            attribute crackingPressure :> ISQ::pressure;
            attribute maxFlow :> ISQ::volumeFlowRate;
            attribute isOpen :> Boolean;
            port inletPort : FluidPort;
            port outletPort : FluidPort;
        }

        part def Cooler {
            attribute coolingCapacity :> ISQ::power;
            port inletPort : FluidPort;
            port outletPort : FluidPort;
        }

        part def SystemController {
            attribute currentPressure :> ISQ::pressure;
            attribute currentTemperature :> ISQ::temperature;
            attribute pumpStatus : PumpStatus;
            port controlPort : ControlPort;
        }

        part def HydraulicPowerSystem {
            attribute systemPressure :> ISQ::pressure;
            attribute systemTemperature :> ISQ::temperature;
            attribute maxSafePressure :> ISQ::pressure;
            attribute maxSafeTemperature :> ISQ::temperature;
            part reservoir : Reservoir;
            part suctionFilter : SuctionFilter;
            part pump : Pump;
            part motor : Motor;
            part driveShaft : DriveShaft;
            part pressureFilter : PressureFilter;
            part actuator : HydraulicActuator;
            part reliefValve : PressureReliefValve;
            part cooler : Cooler;
            part controller : SystemController;
        }

        requirement def PerformanceRequirements {
            doc /* The hydraulic power system must provide adequate high-pressure fluid to power the hydraulic actuator under all normal operating conditions. */
            attribute minOperatingPressure :> ISQ::pressure = 20e6 [Pa];
            attribute minFlowRate :> ISQ::volumeFlowRate = 8.3e-4 [m^3/s];
        }

        requirement def SafetyRequirements {
            doc /* The system must include provisions to prevent over-pressurization and overheating, and must provide emergency stop capability. */
            attribute maxSafePressureLimit :> ISQ::pressure = 21e6 [Pa];
            attribute maxSafeTemperatureLimit :> ISQ::temperature = 353.15 [K];
        }

        requirement def PumpDesignRequirements {
            doc /* The pump must be a variable-displacement axial piston type with nine pistons and an adjustable swash plate. */
            attribute requiredPistonCount :> Integer = 9;
            attribute maxSwashPlateAngle :> ISQ::planeAngle = 0.35 [rad];
        }
    }

    package Usages {
        private import Definitions::*;

        action providePressure : ProvidePressure;
        action startupSequence : StartupSequence;
        action shutdownSequence : ShutdownSequence;
        action emergencyStopAction : EmergencyStop;
        action monitorPressure : MonitorPressure;
        action monitorTemperature : MonitorTemperature;
        action assessPerformance : AssessPerformance;

        part hydraulicPowerSystem : HydraulicPowerSystem {
            attribute maxSafePressure :> ISQ::pressure = 20e6 [Pa];
            attribute maxSafeTemperature :> ISQ::temperature = 353.15 [K];
            attribute systemPressure :> ISQ::pressure;
            attribute systemTemperature :> ISQ::temperature;

            part reservoir : Reservoir {
                attribute capacity :> ISQ::volume = 0.1 [m^3];
                attribute fluidVolume :> ISQ::volume = 0.08 [m^3];
                attribute temperature :> ISQ::temperature = 300 [K];
                port supplyPort : FluidPort;
                port returnPort : FluidPort;
            }

            part suctionFilter : SuctionFilter {
                attribute micronRating :> Real = 10;
                attribute flowCapacity :> ISQ::volumeFlowRate = 2e-3 [m^3/s];
                port inletPort : FluidPort;
                port outletPort : FluidPort;
            }

            part pump : Pump {
                attribute maxDisplacement :> ISQ::volume = 5e-5 [m^3];
                attribute ratedSpeed :> ISQ::angularVelocity = 188.5 [rad/s];
                attribute efficiency :> Real = 0.9;
                port suctionPort : FluidPort;
                port pressurePort : FluidPort;
                port mechanicalInputPort : MechanicalPort;
                part cylinderBlock : CylinderBlock {
                    attribute pistonCount :> Integer = 9;
                    attribute rotationSpeed :> ISQ::angularVelocity = 188.5 [rad/s];
                    part pistons[9] : Piston {
                        attribute diameter :> ISQ::length = 0.02 [m];
                        attribute stroke :> ISQ::length = 0.03 [m];
                        attribute mass :> ISQ::mass = 0.5 [kg];
                    }
                }
                part swashPlate : SwashPlate {
                    attribute angle :> ISQ::planeAngle = 0.35 [rad];
                    attribute maxAngle :> ISQ::planeAngle = 0.35 [rad];
                }
            }

            part motor : Motor {
                attribute ratedPower :> ISQ::power = 15000 [W];
                attribute ratedSpeed :> ISQ::angularVelocity = 188.5 [rad/s];
                port mechanicalOutputPort : MechanicalPort;
            }

            part driveShaft : DriveShaft {
                port inputEnd : MechanicalPort;
                port outputEnd : MechanicalPort;
            }

            part pressureFilter : PressureFilter {
                attribute micronRating :> Real = 5;
                attribute flowCapacity :> ISQ::volumeFlowRate = 2e-3 [m^3/s];
                attribute burstPressure :> ISQ::pressure = 35e6 [Pa];
                port inletPort : FluidPort;
                port outletPort : FluidPort;
            }

            part actuator : HydraulicActuator {
                attribute boreDiameter :> ISQ::length = 0.08 [m];
                attribute strokeLength :> ISQ::length = 0.5 [m];
                attribute maxForce :> ISQ::force = 100000 [N];
                port inletPort : FluidPort;
                port outletPort : FluidPort;
            }

            part reliefValve : PressureReliefValve {
                attribute crackingPressure :> ISQ::pressure = 21e6 [Pa];
                attribute maxFlow :> ISQ::volumeFlowRate = 2e-3 [m^3/s];
                attribute isOpen :> Boolean = false;
                port inletPort : FluidPort;
                port outletPort : FluidPort;
            }

            part cooler : Cooler {
                attribute coolingCapacity :> ISQ::power = 5000 [W];
                port inletPort : FluidPort;
                port outletPort : FluidPort;
            }

            part controller : SystemController {
                attribute currentPressure :> ISQ::pressure;
                attribute currentTemperature :> ISQ::temperature;
                attribute pumpStatus : PumpStatus = PumpStatus::normal;
                port controlPort : ControlPort;
            }

            connect motor.mechanicalOutputPort to driveShaft.inputEnd;
            connect driveShaft.outputEnd to pump.mechanicalInputPort;

            flow of HydraulicFluid
                from reservoir.supplyPort
                to suctionFilter.inletPort;
            flow of HydraulicFluid
                from suctionFilter.outletPort
                to pump.suctionPort;
            flow of HydraulicFluid
                from pump.pressurePort
                to pressureFilter.inletPort;
            flow of HydraulicFluid
                from pressureFilter.outletPort
                to actuator.inletPort;
            flow of HydraulicFluid
                from pressureFilter.outletPort
                to reliefValve.inletPort;
            flow of HydraulicFluid
                from actuator.outletPort
                to cooler.inletPort;
            flow of HydraulicFluid
                from reliefValve.outletPort
                to cooler.inletPort;
            flow of HydraulicFluid
                from cooler.outletPort
                to reservoir.returnPort;

            assert constraint { systemPressure <= maxSafePressure }
            assert constraint { systemTemperature <= maxSafeTemperature }
            assert constraint { reliefValve.crackingPressure <= maxSafePressure + 1e6 [Pa] }
            assert constraint { pump.cylinderBlock.pistonCount == 9 }
            assert constraint { pump.swashPlate.angle >= 0 [rad] }
            assert constraint { pump.swashPlate.angle <= pump.swashPlate.maxAngle }

            exhibit state systemStates parallel {
                state operationalStates {
                    entry action initial;
                    state Off;
                    state Starting;
                    state On {
                        entry startupSequence;
                        do providePressure;
                        exit shutdownSequence;
                    }
                    state Stopping;
                    state Emergency {
                        entry emergencyStopAction;
                    }
                    transition initial then Off;
                    transition Off_to_Starting
                        first Off
                        accept startCmd : StartCommand via controller.controlPort
                        then Starting;
                    transition Starting_to_On
                        first Starting
                        accept StartupComplete
                        then On;
                    transition On_to_Stopping
                        first On
                        accept shutdownCmd : ShutdownCommand via controller.controlPort
                        then Stopping;
                    transition Stopping_to_Off
                        first Stopping
                        accept ShutdownComplete
                        then Off;
                    transition On_to_Emergency
                        first On
                        accept emergencyCmd : EmergencyStopCommand via controller.controlPort
                        then Emergency;
                    transition Emergency_to_Off
                        first Emergency
                        accept EmergencyComplete
                        then Off;
                }
                state healthStates {
                    entry action initial;
                    do monitorPressure { out pressure; }
                    do monitorTemperature { out temperature; }
                    do assessPerformance { out status; }
                    state Normal;
                    state Degraded;
                    state Critical;
                    transition initial then Normal;
                    transition Normal_to_Degraded
                        first Normal
                        accept when monitorPressure.pressure > maxSafePressure
                        do send new OverPressureAlert() to controller
                        then Degraded;
                    transition Normal_to_Critical
                        first Normal
                        accept when monitorTemperature.temperature > maxSafeTemperature
                        do send new OverTemperatureAlert() to controller
                        then Critical;
                    transition Degraded_to_Critical
                        first Degraded
                        accept when monitorTemperature.temperature > maxSafeTemperature
                        do send new OverTemperatureAlert() to controller
                        then Critical;
                    transition Degraded_to_Normal
                        first Degraded
                        accept ReturnToNormal
                        then Normal;
                    transition Critical_to_Degraded
                        first Critical
                        accept ReturnToNormal
                        then Degraded;
                    transition Critical_to_Normal
                        first Critical
                        accept ReturnToNormal
                        then Normal;
                }
            }
        }

        requirement performanceReq : PerformanceRequirements {
            subject hydraulicPowerSystem;
        }

        requirement safetyReq : SafetyRequirements {
            subject hydraulicPowerSystem;
        }

        requirement pumpDesignReq : PumpDesignRequirements {
            subject hydraulicPowerSystem.pump;
        }
    }
}
