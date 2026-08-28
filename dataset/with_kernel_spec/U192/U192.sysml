package CranialDrillSystemModel {
    private import ScalarValues::*;

    package Definitions {
        value def RotationalSpeed :> Real;
        value def TorqueValue :> Real;
        value def TempValue :> Real;
        value def DepthValue :> Real;
        value def FlowRateValue :> Real;

        item def SterileCoolant;
        item def SensorReading;
        item def SafetyAlert;

        attribute def StartCommand;
        attribute def DrillCommand;
        attribute def StopCommand;
        attribute def ResetCommand;

        port def CommandPort {
            out startCmd: StartCommand;
            out drillCmd: DrillCommand;
            out stopCmd: StopCommand;
        }
        port def DataPort {
            out reading: SensorReading;
        }
        port def PowerPort {
            out speed: RotationalSpeed;
        }
        port def MechanicalPort {
            out torque: TorqueValue;
            out speed: RotationalSpeed;
        }
        port def CoolantPort {
            out coolant: SterileCoolant;
            out flowRate: FlowRateValue;
        }
        port def InterlockPort {
            out alert: SafetyAlert;
            out reduceSpeed: Boolean;
            out increaseCoolant: Boolean;
            out shutdown: Boolean;
        }

        action def DrillBone;
        action def DeliverCoolant;
        action def SenseParameters;
        action def EmergencyShutdown;
        action def RetractDrill;
        action def ProvideRotation;
        action def ReduceSpeed;
        action def IncreaseCoolantFlow;

        action def PreparationOps {
            perform action deliverCoolant: DeliverCoolant;
            perform action provideRotation: ProvideRotation;
        }
        action def DrillingOps {
            perform action drillBone: DrillBone;
            perform action deliverCoolant: DeliverCoolant;
            perform action senseDepth: SenseParameters;
            perform action senseTemp: SenseParameters;
            perform action senseTorque: SenseParameters;
        }

        state def DrillOperationalStates;
        state def InterlockStates;

        part def ElectricMotor {
            port powerIn: PowerPort;
            port mechOut: MechanicalPort;
            perform action provideRotation: ProvideRotation;
        }

        part def SpeedController {
            port cmdIn: CommandPort;
            port powerOut: PowerPort;
            port interlockIn: InterlockPort;
        }

        part def DrillBitAssembly {
            port mechIn: MechanicalPort;
            port coolantIn: CoolantPort;
            perform action 'drill bone': DrillBone;
        }

        part def Pump {
            port coolantIn: CoolantPort;
            port coolantOut: CoolantPort;
            port interlockIn: InterlockPort;
        }

        part def Reservoir {
            item coolant: SterileCoolant;
            port coolantOut: CoolantPort;
        }

        part def IrrigationSystem {
            part pump: Pump;
            part reservoir: Reservoir;
            connect reservoir.coolantOut to pump.coolantIn;
            port coolantOut: CoolantPort;
            connect pump.coolantOut to coolantOut;
            perform action 'deliver coolant': DeliverCoolant;
        }

        part def DepthSensor {
            port dataOut: DataPort;
            attribute depth: DepthValue;
            perform action 'sense parameters': SenseParameters;
        }

        part def TemperatureSensor {
            port dataOut: DataPort;
            attribute temperature: TempValue;
            perform action 'sense parameters': SenseParameters;
        }

        part def TorqueSensor {
            port dataOut: DataPort;
            attribute torque: TorqueValue;
            perform action 'sense parameters': SenseParameters;
        }

        part def ControlProcessor {
            port cmdIn: CommandPort;
            port depthIn: DataPort;
            port tempIn: DataPort;
            port torqueIn: DataPort;
            port speedCmdOut: CommandPort;
            port interlockIn: InterlockPort;
            attribute targetDepth: DepthValue;
            attribute currentDepth: DepthValue;
        }

        part def SafetyInterlockSystem {
            port depthIn: DataPort;
            port tempIn: DataPort;
            port torqueIn: DataPort;
            port interlockOut: InterlockPort;
            attribute maxDepth: DepthValue;
            attribute maxTemp: TempValue;
            attribute maxTorque: TorqueValue;
            perform action 'emergency shutdown': EmergencyShutdown;
            exhibit state interlockStates: InterlockStates;
        }

        part def CranialDrillSystem {
            part controlProcessor: ControlProcessor;
            part speedController: SpeedController;
            part motor: ElectricMotor;
            part drillBit: DrillBitAssembly;
            part irrigationSystem: IrrigationSystem;
            part depthSensor: DepthSensor;
            part tempSensor: TemperatureSensor;
            part torqueSensor: TorqueSensor;
            part safetyInterlock: SafetyInterlockSystem;

            connect controlProcessor.speedCmdOut to speedController.cmdIn;
            connect speedController.powerOut to motor.powerIn;
            connect motor.mechOut to drillBit.mechIn;
            connect irrigationSystem.coolantOut to drillBit.coolantIn;

            connect depthSensor.dataOut to controlProcessor.depthIn;
            connect tempSensor.dataOut to controlProcessor.tempIn;
            connect torqueSensor.dataOut to controlProcessor.torqueIn;

            connect depthSensor.dataOut to safetyInterlock.depthIn;
            connect tempSensor.dataOut to safetyInterlock.tempIn;
            connect torqueSensor.dataOut to safetyInterlock.torqueIn;

            connect safetyInterlock.interlockOut to controlProcessor.interlockIn;
            connect safetyInterlock.interlockOut to speedController.interlockIn;
            connect safetyInterlock.interlockOut to irrigationSystem.pump.interlockIn;

            exhibit state systemStates: DrillOperationalStates;
            exhibit state interlockStates: InterlockStates;
        }

        requirement def PreventThermalDamage {
            doc /* The system must prevent thermal damage to bone and neural tissues by maintaining temperature below the maximum limit. */
        }

        requirement def EnsureSafeSurgicalAccess {
            doc /* The system must provide controlled and safe surgical access to the cranial cavity. */
        }

        requirement def MaintainCoolantFlow {
            doc /* The irrigation system shall deliver continuous sterile coolant to the drill bit tip during operation. */
        }

        requirement def SafetyInterlockMonitoring {
            doc /* The safety interlock system shall independently monitor sensor data and trigger protective actions if limits are exceeded. */
        }

        requirement def DepthAccuracyRequirement {
            doc /* The system shall accurately track and limit penetration depth to the operator-defined target depth. */
        }
    }

    package Usages {
        private import Definitions::*;

        part cranialDrill: CranialDrillSystem {
            attribute maxDepth: DepthValue;
            attribute maxTemp: TempValue;
            attribute maxTorque: TorqueValue;

            state systemStates: DrillOperationalStates {
                entry; then standby;
                state standby;
                accept StartCommand then preparation;
                state preparation {
                    do action prepOps: PreparationOps;
                }
                accept DrillCommand then activeDrilling;
                state activeDrilling {
                    do action drillOps: DrillingOps;
                }
                accept when controlProcessor.currentDepth >= controlProcessor.targetDepth then controlledRetraction;
                state controlledRetraction {
                    do action retract: RetractDrill;
                }
                accept StopCommand then standby;
            }

            state interlockStates: InterlockStates {
                entry; then monitoring;
                state monitoring;
                accept when depthSensor.depth > safetyInterlock.maxDepth
                    do action es1: EmergencyShutdown
                    then emergency;
                accept when tempSensor.temperature > safetyInterlock.maxTemp
                    do action es2: EmergencyShutdown
                    then emergency;
                accept when torqueSensor.torque > safetyInterlock.maxTorque
                    do action es3: EmergencyShutdown
                    then emergency;
                state emergency;
                accept ResetCommand then monitoring;
            }
        }

        requirement preventThermalDamage: PreventThermalDamage;
        requirement ensureSafeAccess: EnsureSafeSurgicalAccess;
        requirement maintainCoolantFlow: MaintainCoolantFlow;
        requirement safetyInterlockMonitoring: SafetyInterlockMonitoring;
        requirement depthAccuracy: DepthAccuracyRequirement;

        satisfy preventThermalDamage by cranialDrill.tempSensor;
        satisfy ensureSafeAccess by cranialDrill;
        satisfy maintainCoolantFlow by cranialDrill.irrigationSystem;
        satisfy safetyInterlockMonitoring by cranialDrill.safetyInterlock;
        satisfy depthAccuracy by cranialDrill.depthSensor;
    }
}
