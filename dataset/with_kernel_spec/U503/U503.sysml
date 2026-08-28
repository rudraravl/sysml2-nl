package FluidPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        unit def L;
        unit def kPa;
        unit def V;
        unit def min;
        unit def K;
        
        item def Fluid;
        
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def ResetCommand;
        attribute def PrimingReady;
        attribute def PrimingComplete;
        attribute def OverPressureAlert;
        attribute def OverTemperatureAlert;
        attribute def CavitationAlert;
        attribute def PumpCommand;
        
        port def FluidPort {
            inout fluid: Fluid;
            attribute pressure: ISQ::pressure;
            attribute flowRate: ISQ::volumeFlowRate;
        }
        
        port def ElectricalPort {
            in voltage: ISQ::electricPotentialDifference;
        }
        
        port def ControlPort {
            in command: PumpCommand;
            out speedCommand: ISQ::angularVelocity;
        }
        
        port def MechanicalPort {
            out torque: ISQ::torque;
            out speed: ISQ::angularVelocity;
        }
        
        port def ThermalPort {
            inout temperature: ISQ::temperature;
        }
        
        port def SensorPort {
            out reading: Real;
        }
        
        part def SupplyTank {
            attribute capacity: ISQ::volume = 1000 [L];
            port outlet: FluidPort;
            port returnInlet: FluidPort;
        }
        
        part def ReceivingVessel {
            attribute capacity: ISQ::volume = 500 [L];
            port inlet: FluidPort;
        }
        
        part def CheckValve {
            port inlet: FluidPort;
            port outlet: FluidPort;
        }
        
        part def ReliefValve {
            attribute setPressure: ISQ::pressure = 650 [kPa];
            port inlet: FluidPort;
            port outlet: FluidPort;
        }
        
        part def ElectricMotor {
            attribute ratedVoltage: ISQ::electricPotentialDifference = 24 [V];
            port powerIn: ElectricalPort;
            port controlIn: ControlPort;
            port shaftOut: MechanicalPort;
        }
        
        part def PumpMechanism {
            port fluidIn: FluidPort;
            port fluidOut: FluidPort;
            port mechanicalIn: MechanicalPort;
            port thermalOut: ThermalPort;
            perform action pumpFluid;
        }
        
        part def FuelPump {
            attribute targetFlowRate: ISQ::volumeFlowRate = 150 [L/min];
            attribute maxPressure: ISQ::pressure = 600 [kPa];
            port fluidIn: FluidPort;
            port fluidOut: FluidPort;
            port controlPort: ControlPort;
            perform action transferFluid;
            perform action selfDiagnostic;
            exhibit state pumpStates {
                entry; then idle;
                state idle;
                transition idle_to_starting
                    first idle
                    accept StartCommand
                    then starting;
                state starting {
                    do selfDiagnostic;
                }
                transition starting_to_priming
                    first starting
                    accept PrimingReady
                    then priming;
                state priming;
                transition priming_to_running
                    first priming
                    accept PrimingComplete
                    then running;
                state running {
                    do transferFluid;
                }
                transition running_to_idle
                    first running
                    accept StopCommand
                    then idle;
                transition running_to_faulted_op
                    first running
                    accept OverPressureAlert
                    then faulted;
                transition running_to_faulted_ot
                    first running
                    accept OverTemperatureAlert
                    then faulted;
                transition running_to_faulted_cav
                    first running
                    accept CavitationAlert
                    then faulted;
                state faulted;
                transition faulted_to_idle
                    first faulted
                    accept ResetCommand
                    then idle;
            }
        }
        
        part def PumpController {
            attribute overPressureLimit: ISQ::pressure = 650 [kPa];
            attribute overTemperatureLimit: ISQ::temperature = 358.15 [K];
            attribute cavitationThreshold: ISQ::pressure = 50 [kPa];
            port sensorIn: SensorPort;
            port controlOut: ControlPort;
            perform action monitorSensors;
            perform action controlPumpSpeed;
            perform action detectFaults;
            exhibit state controllerStates {
                entry; then monitoring;
                state monitoring {
                    do monitorSensors;
                    do detectFaults;
                }
                state controlling {
                    do controlPumpSpeed;
                }
                state faultHandling;
                transition monitoring_to_controlling
                    first monitoring
                    accept PrimingComplete
                    then controlling;
                transition controlling_to_monitoring
                    first controlling
                    accept StopCommand
                    then monitoring;
                transition monitoring_to_faultHandling
                    first monitoring
                    accept OverPressureAlert
                    then faultHandling;
                transition controlling_to_faultHandling
                    first controlling
                    accept OverPressureAlert
                    then faultHandling;
                transition faultHandling_to_monitoring
                    first faultHandling
                    accept ResetCommand
                    then monitoring;
            }
        }
        
        part def PressureSensor {
            attribute pressure: ISQ::pressure;
            port fluidSense: FluidPort;
            port signalOut: SensorPort;
            perform action readPressure;
        }
        
        part def FlowMeter {
            attribute flowRate: ISQ::volumeFlowRate;
            port fluidSense: FluidPort;
            port signalOut: SensorPort;
            perform action readFlow;
        }
        
        part def TemperatureSensor {
            attribute temperature: ISQ::temperature;
            port thermalSense: ThermalPort;
            port signalOut: SensorPort;
            perform action readTemperature;
        }
        
        action def TransferFluid {
            in inletFluid: Fluid;
            out outletFluid: Fluid;
        }
        
        action def MonitorSensors {
            out inletPressure: ISQ::pressure;
            out outletPressure: ISQ::pressure;
            out flowRate: ISQ::volumeFlowRate;
            out temperature: ISQ::temperature;
        }
        
        action def ControlPumpSpeed {
            in targetFlowRate: ISQ::volumeFlowRate;
            in actualFlowRate: ISQ::volumeFlowRate;
            out speedCommand: ISQ::angularVelocity;
        }
        
        action def DetectFaults {
            in inletPressure: ISQ::pressure;
            in outletPressure: ISQ::pressure;
            in flowRate: ISQ::volumeFlowRate;
            in temperature: ISQ::temperature;
            out fault: String;
        }
        
        requirement def FlowRateRequirement {
            doc /* The system shall transfer fluid at a target flow rate of 150 L/min. */
            attribute targetFlowRate: ISQ::volumeFlowRate = 150 [L/min];
        }
        
        requirement def PressureRequirement {
            doc /* The system shall handle operating pressures up to 600 kPa. */
            attribute maxOperatingPressure: ISQ::pressure = 600 [kPa];
        }
        
        requirement def OverPressureProtection {
            doc /* A relief valve shall open at 650 kPa to prevent over-pressure. */
            attribute reliefSetPressure: ISQ::pressure = 650 [kPa];
        }
        
        requirement def TemperatureProtection {
            doc /* The system shall enter faulted state if temperature exceeds 85 degrees Celsius. */
            attribute maxTemperature: ISQ::temperature = 358.15 [K];
        }
        
        requirement def CavitationProtection {
            doc /* The system shall detect cavitation when inlet pressure drops below 50 kPa. */
            attribute minInletPressure: ISQ::pressure = 50 [kPa];
        }
        
        requirement def BackflowPrevention {
            doc /* Check valves shall prevent reverse fluid flow. */
        }
        
        requirement def FaultRecovery {
            doc /* The system shall require manual reset to recover from faulted state. */
        }
    }
    
    public import Definitions::*;
    
    package Usages {
        private import Definitions::*;
        
        part supplyTank: SupplyTank;
        part receivingVessel: ReceivingVessel;
        part inletCheckValve: CheckValve;
        part outletCheckValve: CheckValve;
        part reliefValve: ReliefValve;
        part inletPressureSensor: PressureSensor;
        part outletPressureSensor: PressureSensor;
        part flowMeter: FlowMeter;
        part temperatureSensor: TemperatureSensor;
        part motor: ElectricMotor;
        part pumpMechanism: PumpMechanism;
        part fuelPump: FuelPump;
        part pumpController: PumpController;
        
        requirement flowRateReq: FlowRateRequirement;
        requirement pressureReq: PressureRequirement;
        requirement overPressureReq: OverPressureProtection;
        requirement tempProtectReq: TemperatureProtection;
        requirement cavitationReq: CavitationProtection;
        requirement backflowReq: BackflowPrevention;
        requirement faultRecoveryReq: FaultRecovery;
        
        connect supplyTank.outlet to inletCheckValve.inlet;
        connect inletCheckValve.outlet to pumpMechanism.fluidIn;
        connect pumpMechanism.fluidOut to outletCheckValve.inlet;
        connect outletCheckValve.outlet to receivingVessel.inlet;
        
        connect pumpMechanism.fluidOut to reliefValve.inlet;
        connect reliefValve.outlet to supplyTank.returnInlet;
        
        connect inletPressureSensor.fluidSense to pumpMechanism.fluidIn;
        connect outletPressureSensor.fluidSense to pumpMechanism.fluidOut;
        connect flowMeter.fluidSense to pumpMechanism.fluidOut;
        connect temperatureSensor.thermalSense to pumpMechanism.thermalOut;
        
        connect inletPressureSensor.signalOut to pumpController.sensorIn;
        connect outletPressureSensor.signalOut to pumpController.sensorIn;
        connect flowMeter.signalOut to pumpController.sensorIn;
        connect temperatureSensor.signalOut to pumpController.sensorIn;
        
        connect pumpController.controlOut to motor.controlIn;
        connect motor.shaftOut to pumpMechanism.mechanicalIn;
        
        satisfy flowRateReq by fuelPump;
        satisfy pressureReq by fuelPump;
        satisfy overPressureReq by reliefValve;
        satisfy tempProtectReq by pumpController;
        satisfy cavitationReq by pumpController;
        satisfy backflowReq by inletCheckValve;
        satisfy backflowReq by outletCheckValve;
        satisfy faultRecoveryReq by fuelPump;
    }
}
