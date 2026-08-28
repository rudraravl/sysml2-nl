package IndustrialFluidPumpingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    public import Definitions::*;

    package Definitions {
        item def Fluid;

        attribute def PressureValue :> ISQ::Pressure;
        attribute def FlowRateValue :> ISQ::VolumeFlowRate;
        attribute def RotationalSpeedValue :> ISQ::AngularVelocity;
        attribute def VoltageValue :> ISQ::ElectricPotential;
        attribute def CurrentValue :> ISQ::ElectricCurrent;
        attribute def TorqueValue :> ISQ::Torque;

        enum def ControlMode {
            CONSTANT_FLOW;
            CONSTANT_PRESSURE;
        }

        attribute def StartCommand;
        attribute def StopCommand;
        attribute def ResetCommand;
        attribute def PumpReady;
        attribute def ShutdownComplete;
        attribute def FaultSignal {
            attribute faultCode : Integer;
        }

        port def FluidPort {
            out item fluid : Fluid;
        }
        port def PressureSignalPort {
            out attribute pressure : PressureValue;
        }
        port def FlowSignalPort {
            out attribute flowRate : FlowRateValue;
        }
        port def SpeedCommandPort {
            out attribute speedSetpoint : RotationalSpeedValue;
        }
        port def PowerCommandPort {
            out attribute powerOn : Boolean;
        }
        port def ElectricalPowerPort {
            out attribute voltage : VoltageValue;
            out attribute current : CurrentValue;
        }
        port def MechanicalPort {
            out attribute torque : TorqueValue;
            out attribute rotationalSpeed : RotationalSpeedValue;
        }
        port def ControlPort {
            out attribute startCmd : StartCommand;
            out attribute stopCmd : StopCommand;
            out attribute resetCmd : ResetCommand;
        }
        port def FaultPort {
            out attribute fault : FaultSignal;
        }

        action def PumpFluid {
            in fluidIn : Fluid;
            out fluidOut : Fluid;
        }
        action def Drive {
            out rotationalSpeed : RotationalSpeedValue;
        }
        action def StartupSequence;
        action def ShutdownSequence;
        action def FaultResponse;
        action def MonitorAndAdjust {
            in pressure : PressureValue;
            in flowRate : FlowRateValue;
            in mode : ControlMode;
            out speedSetpoint : RotationalSpeedValue;
        }

        part def StorageReservoir {
            port fluidOutPort : FluidPort;
            attribute fluidVolume : ISQ::Volume;
            attribute minVolume : ISQ::Volume;
            item storedFluid : Fluid;
        }

        part def SuctionPipe {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
        }

        part def IsolationValve {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute isOpen : Boolean = true;
        }

        part def FlowSensor {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port flowSignalPort : FlowSignalPort;
            attribute measuredFlowRate : FlowRateValue;
        }

        part def ElectricMotor {
            port electricalPowerPort : ~ElectricalPowerPort;
            port speedCommandPort : ~SpeedCommandPort;
            port powerCommandPort : ~PowerCommandPort;
            port shaftOut : MechanicalPort;
            attribute rotationalSpeed : RotationalSpeedValue;
            attribute ratedSpeed : RotationalSpeedValue;
            perform action drive : Drive;
        }

        part def DriveShaft {
            port shaftIn : ~MechanicalPort;
            port shaftOut : MechanicalPort;
            attribute torque : TorqueValue;
            attribute rotationalSpeed : RotationalSpeedValue;
        }

        part def Impeller {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port shaftIn : ~MechanicalPort;
            attribute rotationalSpeed : RotationalSpeedValue;
            attribute diameter : ISQ::Length;
        }

        part def Casing {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute maxPressure : PressureValue;
        }

        part def SealAssembly {
            attribute leakRate : FlowRateValue;
            attribute maxLeakRate : FlowRateValue;
        }

        part def DowntonPump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port electricalPowerPort : ~ElectricalPowerPort;
            port speedCommandPort : ~SpeedCommandPort;
            port powerCommandPort : ~PowerCommandPort;
            attribute inletPressure : PressureValue;
            attribute outletPressure : PressureValue;
            attribute ratedSpeed : RotationalSpeedValue;
            attribute designFlowRate : FlowRateValue;
            attribute designHeadPressure : PressureValue;

            part motor : ElectricMotor;
            part driveShaft : DriveShaft;
            part impeller : Impeller;
            part casing : Casing;
            part sealAssembly : SealAssembly;

            perform action pumpFluid : PumpFluid;

            flow of fluid : Fluid
                from fluidInPort.fluid to impeller.fluidInPort.fluid;
            flow of fluid : Fluid
                from impeller.fluidOutPort.fluid to casing.fluidInPort.fluid;
            flow of fluid : Fluid
                from casing.fluidOutPort.fluid to fluidOutPort.fluid;

            connect motor.shaftOut to driveShaft.shaftIn;
            connect driveShaft.shaftOut to impeller.shaftIn;
            connect speedCommandPort to motor.speedCommandPort;
            connect powerCommandPort to motor.powerCommandPort;
            connect electricalPowerPort to motor.electricalPowerPort;
        }

        part def DischargePipe {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
        }

        part def PressureSensor {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port pressureSignalPort : PressureSignalPort;
            attribute measuredPressure : PressureValue;
        }

        part def DischargeValve {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute isOpen : Boolean = true;
        }

        part def PressureVessel {
            port fluidInPort : ~FluidPort;
            attribute maxPressure : PressureValue;
            attribute currentPressure : PressureValue;
            attribute fluidVolume : ISQ::Volume;
            attribute maxVolume : ISQ::Volume;
            item storedFluid : Fluid;
        }

        part def PowerSource {
            port electricalPowerPort : ElectricalPowerPort;
            attribute outputVoltage : VoltageValue;
            attribute outputCurrent : CurrentValue;
        }

        part def PumpController {
            port pressureSignalPort : ~PressureSignalPort;
            port flowSignalPort : ~FlowSignalPort;
            port speedCommandPort : SpeedCommandPort;
            port powerCommandPort : PowerCommandPort;
            port controlPort : ~ControlPort;
            port faultPort : FaultPort;
            attribute controlMode : ControlMode;
            attribute pressureSetpoint : PressureValue;
            attribute flowSetpoint : FlowRateValue;
            attribute maxPressure : PressureValue;
            attribute maxFlowRate : FlowRateValue;
            attribute currentPressure : PressureValue;
            attribute currentFlowRate : FlowRateValue;
            attribute speedOutput : RotationalSpeedValue;

            perform action startupSequence : StartupSequence;
            perform action shutdownSequence : ShutdownSequence;
            perform action faultResponse : FaultResponse;
            perform action monitorAndAdjust : MonitorAndAdjust;

            exhibit state controllerStates {
                entry; then idle;
                state idle;
                transition idle_to_startup
                    first idle
                    accept StartCommand
                    then startup;
                state startup {
                    entry startupSequence;
                }
                transition startup_to_operational
                    first startup
                    accept PumpReady
                    then operational;
                state operational {
                    entry; then constant_flow;
                    do monitorAndAdjust;
                    state constant_flow;
                    transition constant_flow_to_constant_pressure
                        first constant_flow
                        accept when controlMode == ControlMode::CONSTANT_PRESSURE
                        then constant_pressure;
                    state constant_pressure;
                    transition constant_pressure_to_constant_flow
                        first constant_pressure
                        accept when controlMode == ControlMode::CONSTANT_FLOW
                        then constant_flow;
                }
                transition operational_to_shutdown
                    first operational
                    accept StopCommand
                    then shutdown;
                state shutdown {
                    entry shutdownSequence;
                }
                transition shutdown_to_idle
                    first shutdown
                    accept ShutdownComplete
                    then idle;
                transition idle_to_faulted
                    first idle
                    accept FaultSignal
                    then faulted;
                transition startup_to_faulted
                    first startup
                    accept FaultSignal
                    then faulted;
                transition operational_to_faulted
                    first operational
                    accept FaultSignal
                    then faulted;
                transition shutdown_to_faulted
                    first shutdown
                    accept FaultSignal
                    then faulted;
                state faulted {
                    entry faultResponse;
                }
                transition faulted_to_idle
                    first faulted
                    accept ResetCommand
                    then idle;
            }
        }

        part def FluidPumpingSystem {
            port controlPort : ~ControlPort;
            port faultPort : FaultPort;

            part storageReservoir : StorageReservoir;
            part suctionPipe : SuctionPipe;
            part isolationValve : IsolationValve;
            part inletFlowSensor : FlowSensor;
            part downtonPump : DowntonPump;
            part dischargePipe : DischargePipe;
            part outletPressureSensor : PressureSensor;
            part outletFlowSensor : FlowSensor;
            part dischargeValve : DischargeValve;
            part pressureVessel : PressureVessel;
            part powerSource : PowerSource;
            part pumpController : PumpController;

            flow of fluid : Fluid
                from storageReservoir.fluidOutPort.fluid to suctionPipe.fluidInPort.fluid;
            flow of fluid : Fluid
                from suctionPipe.fluidOutPort.fluid to isolationValve.fluidInPort.fluid;
            flow of fluid : Fluid
                from isolationValve.fluidOutPort.fluid to inletFlowSensor.fluidInPort.fluid;
            flow of fluid : Fluid
                from inletFlowSensor.fluidOutPort.fluid to downtonPump.fluidInPort.fluid;
            flow of fluid : Fluid
                from downtonPump.fluidOutPort.fluid to dischargePipe.fluidInPort.fluid;
            flow of fluid : Fluid
                from dischargePipe.fluidOutPort.fluid to outletPressureSensor.fluidInPort.fluid;
            flow of fluid : Fluid
                from outletPressureSensor.fluidOutPort.fluid to outletFlowSensor.fluidInPort.fluid;
            flow of fluid : Fluid
                from outletFlowSensor.fluidOutPort.fluid to dischargeValve.fluidInPort.fluid;
            flow of fluid : Fluid
                from dischargeValve.fluidOutPort.fluid to pressureVessel.fluidInPort.fluid;

            connect outletPressureSensor.pressureSignalPort to pumpController.pressureSignalPort;
            connect outletFlowSensor.flowSignalPort to pumpController.flowSignalPort;
            connect pumpController.speedCommandPort to downtonPump.speedCommandPort;
            connect pumpController.powerCommandPort to downtonPump.powerCommandPort;
            connect powerSource.electricalPowerPort to downtonPump.electricalPowerPort;
            connect controlPort to pumpController.controlPort;
            connect pumpController.faultPort to faultPort;
        }

        requirement def PumpCapacityRequirement {
            doc /* The Downton Pump shall transfer fluid at the design flow rate under nominal conditions. */
            subject pump : DowntonPump;
            attribute requiredFlowRate : FlowRateValue = 0.1 [m^3/s];
            require { pump.designFlowRate >= requiredFlowRate }
        }

        requirement def PressureControlRequirement {
            doc /* The pump controller shall maintain outlet pressure within the setpoint tolerance. */
            subject controller : PumpController;
            attribute pressureSetpoint : PressureValue = 400000 [Pa];
            attribute pressureTolerance : PressureValue = 10000 [Pa];
            require { controller.currentPressure <= controller.pressureSetpoint + pressureTolerance }
        }

        requirement def FlowControlRequirement {
            doc /* The pump controller shall maintain outlet flow within the setpoint tolerance. */
            subject controller : PumpController;
            attribute flowSetpoint : FlowRateValue = 0.05 [m^3/s];
            attribute flowTolerance : FlowRateValue = 0.005 [m^3/s];
            require { controller.currentFlowRate <= controller.flowSetpoint + flowTolerance }
        }

        requirement def SafetyRequirement {
            doc /* The system shall enter a faulted state upon detecting over-pressure or over-flow conditions. */
            subject controller : PumpController;
            require { controller.currentPressure <= controller.maxPressure }
        }

        requirement def VesselIntegrityRequirement {
            doc /* The pressure vessel shall not exceed its maximum rated pressure. */
            subject vessel : PressureVessel;
            require { vessel.currentPressure <= vessel.maxPressure }
        }
    }

    package Usages {
        private import Definitions::*;

        part pumpingSystem : FluidPumpingSystem;

        requirement pumpCapacityReq : PumpCapacityRequirement;
        requirement pressureControlReq : PressureControlRequirement;
        requirement flowControlReq : FlowControlRequirement;
        requirement safetyReq : SafetyRequirement;
        requirement vesselIntegrityReq : VesselIntegrityRequirement;

        satisfy pumpCapacityReq by pumpingSystem;
        satisfy pressureControlReq by pumpingSystem;
        satisfy flowControlReq by pumpingSystem;
        satisfy safetyReq by pumpingSystem;
        satisfy vesselIntegrityReq by pumpingSystem;
    }
}
