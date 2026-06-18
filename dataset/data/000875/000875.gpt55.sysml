package FirePumpingSubsystemModel {
    import ScalarValues::*;

    attribute def VolumeFlowRate {
        attribute value: Real;
        attribute unit: String = "L/min";
    }

    attribute def Pressure {
        attribute value: Real;
        attribute unit: String = "kPa";
    }

    attribute def Temperature {
        attribute value: Real;
        attribute unit: String = "degC";
    }

    attribute def RotationalSpeed {
        attribute value: Real;
        attribute unit: String = "rpm";
    }

    attribute def Power {
        attribute value: Real;
        attribute unit: String = "kW";
    }

    attribute def Voltage {
        attribute value: Real;
        attribute unit: String = "V";
    }

    attribute def Current {
        attribute value: Real;
        attribute unit: String = "A";
    }

    attribute def Percent {
        attribute value: Real;
        attribute unit: String = "%";
    }

    attribute def Duration {
        attribute value: Real;
        attribute unit: String = "s";
    }

    attribute def Length {
        attribute value: Real;
        attribute unit: String = "m";
    }

    attribute def Diameter {
        attribute value: Real;
        attribute unit: String = "mm";
    }

    item def FireWater {
        attribute temperature: Temperature;
        attribute contaminationLevel: Percent;
    }

    item def PressurizedFireWater :> FireWater {
        attribute staticPressure: Pressure;
        attribute flowRate: VolumeFlowRate;
    }

    item def ElectricalPower {
        attribute voltage: Voltage;
        attribute current: Current;
        attribute power: Power;
    }

    item def ControlSignal {
        attribute asserted: Boolean;
    }

    item def StartCommand :> ControlSignal;
    item def StopCommand :> ControlSignal;
    item def FaultSignal :> ControlSignal;
    item def SpeedCommand :> ControlSignal {
        attribute commandedSpeed: RotationalSpeed;
    }

    port def FluidInletPort {
        in item incomingFluid: FireWater;
        attribute measuredPressure: Pressure;
        attribute nominalDiameter: Diameter;
    }

    port def FluidOutletPort {
        out item outgoingFluid: PressurizedFireWater;
        attribute measuredPressure: Pressure;
        attribute nominalDiameter: Diameter;
    }

    port def ElectricalPowerInPort {
        in item powerIn: ElectricalPower;
    }

    port def ControlInPort {
        in item start: StartCommand;
        in item stop: StopCommand;
        in item speed: SpeedCommand;
    }

    port def StatusOutPort {
        out item fault: FaultSignal;
        out item running: ControlSignal;
    }

    port def SensorSignalOutPort {
        out item signal: ControlSignal;
    }

    interface def FluidTransferInterface {
        end source: FluidOutletPort;
        end sink: FluidInletPort;
        flow source.outgoingFluid to sink.incomingFluid;
    }

    interface def ElectricalSupplyInterface {
        end source;
        end load: ElectricalPowerInPort;
        flow source.powerOut to load.powerIn;
    }

    interface def ControlInterface {
        end controller;
        end controlled: ControlInPort;
        flow controller.startCommand to controlled.start;
        flow controller.stopCommand to controlled.stop;
        flow controller.speedCommand to controlled.speed;
    }

    constraint def MinimumPressureRise {
        in inletPressure: Pressure;
        in outletPressure: Pressure;
        in minimumRise: Pressure;
        outletPressure.value - inletPressure.value >= minimumRise.value;
    }

    constraint def FlowWithinRatedEnvelope {
        in actualFlow: VolumeFlowRate;
        in minimumFlow: VolumeFlowRate;
        in maximumFlow: VolumeFlowRate;
        actualFlow.value >= minimumFlow.value and actualFlow.value <= maximumFlow.value;
    }

    constraint def NetPositiveSuctionPressureAvailable {
        in suctionPressure: Pressure;
        in minimumSuctionPressure: Pressure;
        suctionPressure.value >= minimumSuctionPressure.value;
    }

    action def PrimePump {
        in item inletWater: FireWater;
        out item primedWater: FireWater;
        attribute maximumPrimingTime: Duration {
            :>> value = 30.0;
            :>> unit = "s";
        }
    }

    action def MoveFluidWithFirePump {
        in item suctionFluid: FireWater;
        in setpointFlow: VolumeFlowRate;
        in setpointDischargePressure: Pressure;
        out item dischargeFluid: PressurizedFireWater;
        attribute achievedFlow: VolumeFlowRate;
        attribute achievedPressure: Pressure;

        assert constraint FlowWithinRatedEnvelope {
            actualFlow = achievedFlow;
            minimumFlow = VolumeFlowRate {
                value = 500.0;
                unit = "L/min";
            };
            maximumFlow = VolumeFlowRate {
                value = 2400.0;
                unit = "L/min";
            };
        }
    }

    action def StopPump {
        in item stopCommand: StopCommand;
        out item stoppedStatus: ControlSignal;
    }

    state def FirePumpOperatingState {
        entry; then Standby;

        state Standby;
        state Priming;
        state Running;
        state Shutdown;
        state Faulted;

        transition startRequested
            first Standby
            accept StartCommand
            then Priming;

        transition primed
            first Priming
            then Running;

        transition stopRequestedFromRunning
            first Running
            accept StopCommand
            then Shutdown;

        transition stopped
            first Shutdown
            then Standby;

        transition primingFault
            first Priming
            accept FaultSignal
            then Faulted;

        transition runningFault
            first Running
            accept FaultSignal
            then Faulted;

        transition faultCleared
            first Faulted
            accept StopCommand
            then Standby;
    }

    part def WaterSource {
        port outlet: FluidOutletPort;
        attribute availableVolume: VolumeFlowRate {
            :>> value = 10000.0;
            :>> unit = "L/min";
        }
        attribute supplyPressure: Pressure {
            :>> value = 150.0;
            :>> unit = "kPa";
        }
    }

    part def SuctionPipe {
        port inlet: FluidInletPort;
        port outlet: FluidOutletPort;

        attribute length: Length {
            :>> value = 4.0;
            :>> unit = "m";
        }

        attribute insideDiameter: Diameter {
            :>> value = 150.0;
            :>> unit = "mm";
        }

        attribute pressureDropAtRatedFlow: Pressure {
            :>> value = 20.0;
            :>> unit = "kPa";
        }
    }

    part def DischargePipe {
        port inlet: FluidInletPort;
        port outlet: FluidOutletPort;

        attribute length: Length {
            :>> value = 8.0;
            :>> unit = "m";
        }

        attribute insideDiameter: Diameter {
            :>> value = 125.0;
            :>> unit = "mm";
        }

        attribute pressureDropAtRatedFlow: Pressure {
            :>> value = 35.0;
            :>> unit = "kPa";
        }
    }

    part def ElectricMotor {
        port powerInput: ElectricalPowerInPort;
        port controlInput: ControlInPort;
        port statusOutput: StatusOutPort;

        attribute ratedPower: Power {
            :>> value = 75.0;
            :>> unit = "kW";
        }

        attribute nominalVoltage: Voltage {
            :>> value = 480.0;
            :>> unit = "V";
        }

        attribute ratedCurrent: Current {
            :>> value = 110.0;
            :>> unit = "A";
        }

        attribute nominalSpeed: RotationalSpeed {
            :>> value = 3560.0;
            :>> unit = "rpm";
        }
    }

    part def PumpImpeller {
        attribute diameter: Diameter {
            :>> value = 260.0;
            :>> unit = "mm";
        }

        attribute nominalSpeed: RotationalSpeed {
            :>> value = 3560.0;
            :>> unit = "rpm";
        }

        attribute hydraulicEfficiency: Percent {
            :>> value = 78.0;
            :>> unit = "%";
        }
    }

    part def PumpCasing {
        port suction: FluidInletPort;
        port discharge: FluidOutletPort;

        attribute maximumWorkingPressure: Pressure {
            :>> value = 1600.0;
            :>> unit = "kPa";
        }

        attribute nominalSuctionDiameter: Diameter {
            :>> value = 150.0;
            :>> unit = "mm";
        }

        attribute nominalDischargeDiameter: Diameter {
            :>> value = 125.0;
            :>> unit = "mm";
        }
    }

    part def FirePump {
        port suctionInlet: FluidInletPort;
        port dischargeOutlet: FluidOutletPort;
        port electricalInput: ElectricalPowerInPort;
        port controlInput: ControlInPort;
        port statusOutput: StatusOutPort;

        part motor: ElectricMotor;
        part impeller: PumpImpeller;
        part casing: PumpCasing;

        attribute ratedFlow: VolumeFlowRate {
            :>> value = 1900.0;
            :>> unit = "L/min";
        }

        attribute minimumStableFlow: VolumeFlowRate {
            :>> value = 500.0;
            :>> unit = "L/min";
        }

        attribute maximumFlow: VolumeFlowRate {
            :>> value = 2400.0;
            :>> unit = "L/min";
        }

        attribute ratedPressureRise: Pressure {
            :>> value = 850.0;
            :>> unit = "kPa";
        }

        attribute minimumSuctionPressure: Pressure {
            :>> value = 100.0;
            :>> unit = "kPa";
        }

        attribute maximumDischargePressure: Pressure {
            :>> value = 1400.0;
            :>> unit = "kPa";
        }

        perform action prime: PrimePump;
        perform action pumpFluid: MoveFluidWithFirePump;
        perform action stop: StopPump;
        exhibit state behavior: FirePumpOperatingState;

        connect suctionInlet to casing.suction;
        connect casing.discharge to dischargeOutlet;
        connect electricalInput to motor.powerInput;
        connect controlInput to motor.controlInput;
        connect motor.statusOutput to statusOutput;

        assert constraint MinimumPressureRise {
            inletPressure = suctionInlet.measuredPressure;
            outletPressure = dischargeOutlet.measuredPressure;
            minimumRise = ratedPressureRise;
        }

        assert constraint NetPositiveSuctionPressureAvailable {
            suctionPressure = suctionInlet.measuredPressure;
            minimumSuctionPressure = minimumSuctionPressure;
        }
    }

    part def PressureSensor {
        port sensedFluid: FluidInletPort;
        port signalOut: SensorSignalOutPort;

        attribute measurementRangeMinimum: Pressure {
            :>> value = 0.0;
            :>> unit = "kPa";
        }

        attribute measurementRangeMaximum: Pressure {
            :>> value = 2000.0;
            :>> unit = "kPa";
        }

        attribute accuracy: Percent {
            :>> value = 1.0;
            :>> unit = "%";
        }
    }

    part def FlowSensor {
        port sensedFluid: FluidInletPort;
        port signalOut: SensorSignalOutPort;

        attribute measurementRangeMinimum: VolumeFlowRate {
            :>> value = 0.0;
            :>> unit = "L/min";
        }

        attribute measurementRangeMaximum: VolumeFlowRate {
            :>> value = 3000.0;
            :>> unit = "L/min";
        }

        attribute accuracy: Percent {
            :>> value = 2.0;
            :>> unit = "%";
        }
    }

    part def CheckValve {
        port inlet: FluidInletPort;
        port outlet: FluidOutletPort;

        attribute crackingPressure: Pressure {
            :>> value = 10.0;
            :>> unit = "kPa";
        }

        attribute maximumReverseLeakage: VolumeFlowRate {
            :>> value = 1.0;
            :>> unit = "L/min";
        }
    }

    part def IsolationValve {
        port inlet: FluidInletPort;
        port outlet: FluidOutletPort;

        attribute fullOpenPressureDrop: Pressure {
            :>> value = 5.0;
            :>> unit = "kPa";
        }
    }

    part def PumpController {
        port pumpControlOutput;
        port pumpStatusInput: StatusOutPort;
        port suctionPressureInput: SensorSignalOutPort;
        port dischargePressureInput: SensorSignalOutPort;
        port flowInput: SensorSignalOutPort;

        attribute startPressureThreshold: Pressure {
            :>> value = 450.0;
            :>> unit = "kPa";
        }

        attribute stopPressureThreshold: Pressure {
            :>> value = 950.0;
            :>> unit = "kPa";
        }

        attribute commandedFlow: VolumeFlowRate {
            :>> value = 1900.0;
            :>> unit = "L/min";
        }

        attribute commandedDischargePressure: Pressure {
            :>> value = 1000.0;
            :>> unit = "kPa";
        }
    }

    part def ElectricalSupply {
        port powerOut;

        attribute outputVoltage: Voltage {
            :>> value = 480.0;
            :>> unit = "V";
        }

        attribute availablePower: Power {
            :>> value = 100.0;
            :>> unit = "kW";
        }
    }

    part def FirePumpingSubsystem {
        part waterSource: WaterSource;
        part suctionIsolationValve: IsolationValve;
        part suctionPipe: SuctionPipe;
        part firePump: FirePump;
        part dischargeCheckValve: CheckValve;
        part dischargePipe: DischargePipe;
        part dischargeIsolationValve: IsolationValve;
        part suctionPressureSensor: PressureSensor;
        part dischargePressureSensor: PressureSensor;
        part flowSensor: FlowSensor;
        part controller: PumpController;
        part electricalSupply: ElectricalSupply;

        port systemFluidInlet: FluidInletPort;
        port systemFluidOutlet: FluidOutletPort;

        attribute requiredFlow: VolumeFlowRate {
            :>> value = 1900.0;
            :>> unit = "L/min";
        }

        attribute requiredDischargePressure: Pressure {
            :>> value = 1000.0;
            :>> unit = "kPa";
        }

        attribute maximumStartTime: Duration {
            :>> value = 45.0;
            :>> unit = "s";
        }

        connection waterToSuctionValve: FluidTransferInterface
            connect waterSource.outlet to suctionIsolationValve.inlet;

        connection suctionValveToSuctionPipe: FluidTransferInterface
            connect suctionIsolationValve.outlet to suctionPipe.inlet;

        connection suctionPipeToPump: FluidTransferInterface
            connect suctionPipe.outlet to firePump.suctionInlet;

        connection pumpToCheckValve: FluidTransferInterface
            connect firePump.dischargeOutlet to dischargeCheckValve.inlet;

        connection checkValveToDischargePipe: FluidTransferInterface
            connect dischargeCheckValve.outlet to dischargePipe.inlet;

        connection dischargePipeToDischargeValve: FluidTransferInterface
            connect dischargePipe.outlet to dischargeIsolationValve.inlet;

        connection dischargeValveToSystemOutlet: FluidTransferInterface
            connect dischargeIsolationValve.outlet to systemFluidOutlet;

        connect systemFluidInlet to waterSource.outlet;
        connect suctionPipe.inlet to suctionPressureSensor.sensedFluid;
        connect dischargePipe.inlet to dischargePressureSensor.sensedFluid;
        connect dischargePipe.outlet to flowSensor.sensedFluid;

        connect electricalSupply.powerOut to firePump.electricalInput;
        connect controller.pumpControlOutput to firePump.controlInput;
        connect firePump.statusOutput to controller.pumpStatusInput;
        connect suctionPressureSensor.signalOut to controller.suctionPressureInput;
        connect dischargePressureSensor.signalOut to controller.dischargePressureInput;
        connect flowSensor.signalOut to controller.flowInput;

        assert constraint FlowWithinRatedEnvelope {
            actualFlow = firePump.ratedFlow;
            minimumFlow = firePump.minimumStableFlow;
            maximumFlow = firePump.maximumFlow;
        }

        assert constraint MinimumPressureRise {
            inletPressure = firePump.suctionInlet.measuredPressure;
            outletPressure = firePump.dischargeOutlet.measuredPressure;
            minimumRise = firePump.ratedPressureRise;
        }
    }

    requirement def PumpingSubsystemMovesFluidRequirement {
        subject subsystem: FirePumpingSubsystem;

        require constraint {
            subsystem.firePump.ratedFlow.value >= subsystem.requiredFlow.value
        }

        require constraint {
            subsystem.firePump.ratedPressureRise.value + subsystem.waterSource.supplyPressure.value >= subsystem.requiredDischargePressure.value
        }

        require constraint {
            subsystem.firePump.minimumSuctionPressure.value <= subsystem.waterSource.supplyPressure.value - subsystem.suctionPipe.pressureDropAtRatedFlow.value
        }
    }

    requirement def FirePumpUsedRequirement {
        subject subsystem: FirePumpingSubsystem;

        require constraint {
            subsystem.firePump.ratedFlow.value > 0.0
        }

        require constraint {
            subsystem.firePump.ratedPressureRise.value > 0.0
        }
    }

    requirement def AutomaticControlRequirement {
        subject subsystem: FirePumpingSubsystem;

        require constraint {
            subsystem.controller.startPressureThreshold.value < subsystem.controller.stopPressureThreshold.value
        }

        require constraint {
            subsystem.maximumStartTime.value <= 45.0
        }
    }

    requirement def SafeDischargePressureRequirement {
        subject subsystem: FirePumpingSubsystem;

        require constraint {
            subsystem.requiredDischargePressure.value <= subsystem.firePump.maximumDischargePressure.value
        }

        require constraint {
            subsystem.firePump.maximumDischargePressure.value <= subsystem.firePump.casing.maximumWorkingPressure.value
        }
    }

    part firePumpingSubsystem: FirePumpingSubsystem;

    requirement moveFluidUsingFirePump: PumpingSubsystemMovesFluidRequirement {
        subject subsystem = firePumpingSubsystem;
    }

    requirement useFirePump: FirePumpUsedRequirement {
        subject subsystem = firePumpingSubsystem;
    }

    requirement automaticControl: AutomaticControlRequirement {
        subject subsystem = firePumpingSubsystem;
    }

    requirement safePressure: SafeDischargePressureRequirement {
        subject subsystem = firePumpingSubsystem;
    }

    satisfy moveFluidUsingFirePump by firePumpingSubsystem.firePump;
    satisfy useFirePump by firePumpingSubsystem.firePump;
    satisfy automaticControl by firePumpingSubsystem.controller;
    satisfy safePressure by firePumpingSubsystem.firePump;
}
