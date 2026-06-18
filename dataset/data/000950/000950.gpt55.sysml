package PumpingSubsystemModel {

    import ScalarValues::*;

    attribute def PressureValue {
        attribute value : Real;
        attribute unit : String = "kPa";
    }

    attribute def TemperatureValue {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def DensityValue {
        attribute value : Real;
        attribute unit : String = "kg/m^3";
    }

    attribute def DynamicViscosityValue {
        attribute value : Real;
        attribute unit : String = "mPa*s";
    }

    attribute def VolumetricFlowRateValue {
        attribute value : Real;
        attribute unit : String = "m^3/s";
    }

    attribute def MassFlowRateValue {
        attribute value : Real;
        attribute unit : String = "kg/s";
    }

    attribute def HeadValue {
        attribute value : Real;
        attribute unit : String = "m";
    }

    attribute def RotationalSpeedValue {
        attribute value : Real;
        attribute unit : String = "rpm";
    }

    attribute def PowerValue {
        attribute value : Real;
        attribute unit : String = "kW";
    }

    attribute def TorqueValue {
        attribute value : Real;
        attribute unit : String = "N*m";
    }

    attribute def VoltageValue {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def CurrentValue {
        attribute value : Real;
        attribute unit : String = "A";
    }

    attribute def LengthValue {
        attribute value : Real;
        attribute unit : String = "m";
    }

    attribute def PercentValue {
        attribute value : Real;
        attribute unit : String = "%";
    }

    attribute def TimeValue {
        attribute value : Real;
        attribute unit : String = "s";
    }

    enum def ValvePositionKind {
        enum closed;
        enum opening;
        enum throttling;
        enum open;
        enum closing;
        enum failedClosed;
        enum failedOpen;
    }

    enum def PumpCommandKind {
        enum noCommand;
        enum start;
        enum stop;
        enum holdSpeed;
        enum setSpeed;
        enum emergencyStop;
        enum resetFault;
    }

    enum def PumpHealthKind {
        enum healthy;
        enum degraded;
        enum cavitationRisk;
        enum overspeed;
        enum overpressure;
        enum lossOfPrime;
        enum motorOverload;
        enum sensorFault;
        enum shutdown;
    }

    enum def FluidClassKind {
        enum water;
        enum fuel;
        enum oxidizer;
        enum coolant;
        enum processLiquid;
    }

    item def LiquidFluid {
        attribute fluidClass : FluidClassKind = FluidClassKind::processLiquid;
        attribute density : DensityValue {
            :>> value = 997.0;
            :>> unit = "kg/m^3";
        }
        attribute dynamicViscosity : DynamicViscosityValue {
            :>> value = 0.89;
            :>> unit = "mPa*s";
        }
        attribute temperature : TemperatureValue {
            :>> value = 20.0;
            :>> unit = "degC";
        }
        attribute vaporPressure : PressureValue {
            :>> value = 2.34;
            :>> unit = "kPa";
        }
        attribute allowableParticles_um : Real = 100.0;
    }

    item def FluidFlow {
        item fluid : LiquidFluid;
        attribute volumetricFlowRate : VolumetricFlowRateValue;
        attribute massFlowRate : MassFlowRateValue;
        attribute staticPressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    item def ShaftPower {
        attribute shaftSpeed : RotationalSpeedValue;
        attribute torque : TorqueValue;
        attribute mechanicalPower : PowerValue;
    }

    item def PumpCommand {
        attribute kind : PumpCommandKind;
        attribute targetSpeed : RotationalSpeedValue;
        attribute requestedFlow : VolumetricFlowRateValue;
    }

    item def PumpStatus {
        attribute health : PumpHealthKind;
        attribute measuredSpeed : RotationalSpeedValue;
        attribute measuredFlow : VolumetricFlowRateValue;
        attribute suctionPressure : PressureValue;
        attribute dischargePressure : PressureValue;
        attribute motorPower : PowerValue;
    }

    item def PressureSignal {
        attribute measuredPressure : PressureValue;
        attribute valid : Boolean;
    }

    item def FlowSignal {
        attribute measuredFlow : VolumetricFlowRateValue;
        attribute valid : Boolean;
    }

    item def SpeedSignal {
        attribute measuredSpeed : RotationalSpeedValue;
        attribute valid : Boolean;
    }

    port def FluidInletPort {
        in item inflow : FluidFlow;
        attribute nominalDiameter : LengthValue;
        attribute maxAllowablePressure : PressureValue;
    }

    port def FluidOutletPort {
        out item outflow : FluidFlow;
        attribute nominalDiameter : LengthValue;
        attribute maxAllowablePressure : PressureValue;
    }

    port def BidirectionalFluidPort {
        inout item flow : FluidFlow;
        attribute nominalDiameter : LengthValue;
        attribute maxAllowablePressure : PressureValue;
    }

    port def ElectricalPowerInputPort {
        in item electricalPower : ElectricalPower;
    }

    port def ShaftPowerInputPort {
        in item shaftPower : ShaftPower;
    }

    port def ShaftPowerOutputPort {
        out item shaftPower : ShaftPower;
    }

    port def CommandInputPort {
        in item command : PumpCommand;
    }

    port def StatusOutputPort {
        out item status : PumpStatus;
    }

    port def PressureSignalOutputPort {
        out item pressureSignal : PressureSignal;
    }

    port def FlowSignalOutputPort {
        out item flowSignal : FlowSignal;
    }

    port def SpeedSignalOutputPort {
        out item speedSignal : SpeedSignal;
    }

    port def PressureSignalInputPort {
        in item pressureSignal : PressureSignal;
    }

    port def FlowSignalInputPort {
        in item flowSignal : FlowSignal;
    }

    port def SpeedSignalInputPort {
        in item speedSignal : SpeedSignal;
    }

    port def CommandOutputPort {
        out item command : PumpCommand;
    }

    port def StatusInputPort {
        in item status : PumpStatus;
    }

    action def PrimeTurbopump {
        in item availableFluid : FluidFlow;
        in attribute minimumSuctionPressure : PressureValue;
        out attribute primed : Boolean;
        out item primedFlow : FluidFlow;
    }

    action def AccelerateRotor {
        in item shaftPowerInput : ShaftPower;
        in attribute commandedSpeed : RotationalSpeedValue;
        out attribute reachedCommandedSpeed : Boolean;
        out item rotatingShaftPower : ShaftPower;
    }

    action def AddEnergyToFluid {
        in item suctionFlow : FluidFlow;
        in item rotatingShaftPower : ShaftPower;
        in attribute pumpEfficiency : PercentValue;
        out item dischargeFlow : FluidFlow;
        out attribute developedHead : HeadValue;
    }

    action def RegulateDischargeFlow {
        in item measuredFlow : FlowSignal;
        in item measuredPressure : PressureSignal;
        in item operatorCommand : PumpCommand;
        out item speedCommand : PumpCommand;
        out attribute valveDemand : PercentValue;
    }

    action def StopTurbopump {
        in item currentStatus : PumpStatus;
        out item stoppedStatus : PumpStatus;
    }

    state def TurbopumpOperatingStates {
        state off;
        state priming;
        state accelerating;
        state running;
        state stopping;
        state faulted;

        transition initialTransition first off;
        transition startCommandTransition
            first off
            accept PumpCommand
            if command.kind == PumpCommandKind::start
            then priming;

        transition primedTransition
            first priming
            if primed == true
            then accelerating;

        transition accelerationCompleteTransition
            first accelerating
            if reachedCommandedSpeed == true
            then running;

        transition normalStopTransition
            first running
            accept PumpCommand
            if command.kind == PumpCommandKind::stop
            then stopping;

        transition stoppedTransition
            first stopping
            then off;

        transition emergencyStopFromPriming
            first priming
            accept PumpCommand
            if command.kind == PumpCommandKind::emergencyStop
            then faulted;

        transition emergencyStopFromAccelerating
            first accelerating
            accept PumpCommand
            if command.kind == PumpCommandKind::emergencyStop
            then faulted;

        transition emergencyStopFromRunning
            first running
            accept PumpCommand
            if command.kind == PumpCommandKind::emergencyStop
            then faulted;

        transition resetFaultTransition
            first faulted
            accept PumpCommand
            if command.kind == PumpCommandKind::resetFault
            then off;
    }

    part def FluidReservoir {
        attribute usableVolume_m3 : Real = 2.5;
        attribute minimumOperatingLevel : LengthValue {
            :>> value = 0.25;
            :>> unit = "m";
        }
        attribute ullagePressure : PressureValue {
            :>> value = 101.3;
            :>> unit = "kPa";
        }

        port outlet : FluidOutletPort {
            :>> nominalDiameter.value = 0.05;
            :>> nominalDiameter.unit = "m";
            :>> maxAllowablePressure.value = 900.0;
            :>> maxAllowablePressure.unit = "kPa";
        }
    }

    part def ProcessReceiver {
        attribute requiredInletPressure : PressureValue {
            :>> value = 450.0;
            :>> unit = "kPa";
        }
        attribute maximumInletPressure : PressureValue {
            :>> value = 850.0;
            :>> unit = "kPa";
        }

        port inlet : FluidInletPort {
            :>> nominalDiameter.value = 0.05;
            :>> nominalDiameter.unit = "m";
            :>> maxAllowablePressure.value = 900.0;
            :>> maxAllowablePressure.unit = "kPa";
        }
    }

    part def IsolationValve {
        attribute position : ValvePositionKind = ValvePositionKind::open;
        attribute fullOpenPressureDrop : PressureValue {
            :>> value = 5.0;
            :>> unit = "kPa";
        }

        port inlet : FluidInletPort {
            :>> nominalDiameter.value = 0.05;
            :>> nominalDiameter.unit = "m";
            :>> maxAllowablePressure.value = 1000.0;
            :>> maxAllowablePressure.unit = "kPa";
        }

        port outlet : FluidOutletPort {
            :>> nominalDiameter.value = 0.05;
            :>> nominalDiameter.unit = "m";
            :>> maxAllowablePressure.value = 1000.0;
            :>> maxAllowablePressure.unit = "kPa";
        }
    }

    part def CheckValve {
        attribute crackingPressure : PressureValue {
            :>> value = 10.0;
            :>> unit = "kPa";
        }
        attribute reverseLeakageRate : VolumetricFlowRateValue {
            :>> value = 0.000001;
            :>> unit = "m^3/s";
        }

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def InlineFilter {
        attribute filtrationRating_um : Real = 40.0;
        attribute cleanPressureDrop : PressureValue {
            :>> value = 8.0;
            :>> unit = "kPa";
        }
        attribute cloggedPressureDropLimit : PressureValue {
            :>> value = 80.0;
            :>> unit = "kPa";
        }

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue {
            :>> value = 18.0;
            :>> unit = "kW";
        }
        attribute ratedVoltage : VoltageValue {
            :>> value = 400.0;
            :>> unit = "V";
        }
        attribute ratedSpeed : RotationalSpeedValue {
            :>> value = 12000.0;
            :>> unit = "rpm";
        }
        attribute efficiency : PercentValue {
            :>> value = 94.0;
            :>> unit = "%";
        }

        port electricalInput : ElectricalPowerInputPort;
        port shaftOutput : ShaftPowerOutputPort;
        port speedFeedback : SpeedSignalOutputPort;
    }

    part def VariableFrequencyDrive {
        attribute maximumOutputPower : PowerValue {
            :>> value = 20.0;
            :>> unit = "kW";
        }
        attribute outputFrequency_Hz : Real = 200.0;

        port electricalInput : ElectricalPowerInputPort;
        port motorPowerOutput : ElectricalPowerInputPort;
        port commandInput : CommandInputPort;
        port statusOutput : StatusOutputPort;
    }

    part def PressureTransmitter {
        attribute rangeLow : PressureValue {
            :>> value = 0.0;
            :>> unit = "kPa";
        }
        attribute rangeHigh : PressureValue {
            :>> value = 1000.0;
            :>> unit = "kPa";
        }
        attribute accuracyPercentSpan : PercentValue {
            :>> value = 0.25;
            :>> unit = "%";
        }

        port processPort : BidirectionalFluidPort;
        port signalOut : PressureSignalOutputPort;
    }

    part def FlowMeter {
        attribute rangeLow : VolumetricFlowRateValue {
            :>> value = 0.0;
            :>> unit = "m^3/s";
        }
        attribute rangeHigh : VolumetricFlowRateValue {
            :>> value = 0.080;
            :>> unit = "m^3/s";
        }
        attribute accuracyPercentReading : PercentValue {
            :>> value = 1.0;
            :>> unit = "%";
        }

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port signalOut : FlowSignalOutputPort;
    }

    part def Turbopump {
        attribute designFlowRate : VolumetricFlowRateValue {
            :>> value = 0.035;
            :>> unit = "m^3/s";
        }
        attribute minimumContinuousFlowRate : VolumetricFlowRateValue {
            :>> value = 0.010;
            :>> unit = "m^3/s";
        }
        attribute maximumFlowRate : VolumetricFlowRateValue {
            :>> value = 0.060;
            :>> unit = "m^3/s";
        }
        attribute designDifferentialPressure : PressureValue {
            :>> value = 550.0;
            :>> unit = "kPa";
        }
        attribute maximumDischargePressure : PressureValue {
            :>> value = 900.0;
            :>> unit = "kPa";
        }
        attribute requiredNPSH : HeadValue {
            :>> value = 3.0;
            :>> unit = "m";
        }
        attribute nominalSpeed : RotationalSpeedValue {
            :>> value = 10000.0;
            :>> unit = "rpm";
        }
        attribute overspeedTrip : RotationalSpeedValue {
            :>> value = 12500.0;
            :>> unit = "rpm";
        }
        attribute hydraulicEfficiency : PercentValue {
            :>> value = 72.0;
            :>> unit = "%";
        }

        port suctionInlet : FluidInletPort {
            :>> nominalDiameter.value = 0.05;
            :>> nominalDiameter.unit = "m";
            :>> maxAllowablePressure.value = 1000.0;
            :>> maxAllowablePressure.unit = "kPa";
        }

        port dischargeOutlet : FluidOutletPort {
            :>> nominalDiameter.value = 0.04;
            :>> nominalDiameter.unit = "m";
            :>> maxAllowablePressure.value = 1000.0;
            :>> maxAllowablePressure.unit = "kPa";
        }

        port shaftPowerInput : ShaftPowerInputPort;
        port commandInput : CommandInputPort;
        port statusOutput : StatusOutputPort;

        perform action prime : PrimeTurbopump;
        perform action accelerate : AccelerateRotor;
        perform action pumpFluid : AddEnergyToFluid;
        perform action stop : StopTurbopump;

        exhibit state operatingState : TurbopumpOperatingStates;
    }

    part def PumpController {
        attribute flowSetpoint : VolumetricFlowRateValue {
            :>> value = 0.035;
            :>> unit = "m^3/s";
        }
        attribute dischargePressureSetpoint : PressureValue {
            :>> value = 650.0;
            :>> unit = "kPa";
        }
        attribute lowSuctionPressureTrip : PressureValue {
            :>> value = 75.0;
            :>> unit = "kPa";
        }
        attribute highDischargePressureTrip : PressureValue {
            :>> value = 900.0;
            :>> unit = "kPa";
        }
        attribute controlCycleTime : TimeValue {
            :>> value = 0.05;
            :>> unit = "s";
        }

        port operatorCommandIn : CommandInputPort;
        port suctionPressureIn : PressureSignalInputPort;
        port dischargePressureIn : PressureSignalInputPort;
        port flowIn : FlowSignalInputPort;
        port speedIn : SpeedSignalInputPort;
        port pumpStatusIn : StatusInputPort;
        port pumpCommandOut : CommandOutputPort;
        port driveCommandOut : CommandOutputPort;

        perform action regulate : RegulateDischargeFlow;
    }

    part def PumpingSubsystem {
        attribute ratedFlowRate : VolumetricFlowRateValue {
            :>> value = 0.035;
            :>> unit = "m^3/s";
        }
        attribute minimumDeliveredFlowRate : VolumetricFlowRateValue {
            :>> value = 0.025;
            :>> unit = "m^3/s";
        }
        attribute ratedDischargePressure : PressureValue {
            :>> value = 650.0;
            :>> unit = "kPa";
        }
        attribute maximumAllowableDischargePressure : PressureValue {
            :>> value = 900.0;
            :>> unit = "kPa";
        }
        attribute startTimeLimit : TimeValue {
            :>> value = 8.0;
            :>> unit = "s";
        }

        part supplyReservoir : FluidReservoir;
        part suctionIsolationValve : IsolationValve;
        part suctionPressureTransmitter : PressureTransmitter;
        part suctionFilter : InlineFilter;
        part turbopump : Turbopump;
        part dischargeCheckValve : CheckValve;
        part dischargeFlowMeter : FlowMeter;
        part dischargePressureTransmitter : PressureTransmitter;
        part dischargeIsolationValve : IsolationValve;
        part receiver : ProcessReceiver;
        part variableFrequencyDrive : VariableFrequencyDrive;
        part driveMotor : ElectricMotor;
        part controller : PumpController;

        port electricalSupply : ElectricalPowerInputPort;
        port operatorCommand : CommandInputPort;
        port deliveredFluid : FluidOutletPort;
        port subsystemStatus : StatusOutputPort;

        connect supplyToSuctionValve
            from supplyReservoir.outlet
            to suctionIsolationValve.inlet;

        connect suctionValveToSuctionPressureTap
            from suctionIsolationValve.outlet
            to suctionPressureTransmitter.processPort;

        connect suctionPressureTapToFilter
            from suctionPressureTransmitter.processPort
            to suctionFilter.inlet;

        connect filterToPump
            from suctionFilter.outlet
            to turbopump.suctionInlet;

        connect pumpToCheckValve
            from turbopump.dischargeOutlet
            to dischargeCheckValve.inlet;

        connect checkValveToFlowMeter
            from dischargeCheckValve.outlet
            to dischargeFlowMeter.inlet;

        connect flowMeterToDischargePressureTap
            from dischargeFlowMeter.outlet
            to dischargePressureTransmitter.processPort;

        connect dischargePressureTapToDischargeValve
            from dischargePressureTransmitter.processPort
            to dischargeIsolationValve.inlet;

        connect dischargeValveToReceiver
            from dischargeIsolationValve.outlet
            to receiver.inlet;

        connect dischargeToBoundary
            from dischargeIsolationValve.outlet
            to deliveredFluid;

        connect electricalSupplyToDrive
            from electricalSupply
            to variableFrequencyDrive.electricalInput;

        connect driveToMotor
            from variableFrequencyDrive.motorPowerOutput
            to driveMotor.electricalInput;

        connect motorToPumpShaft
            from driveMotor.shaftOutput
            to turbopump.shaftPowerInput;

        connect operatorCommandToController
            from operatorCommand
            to controller.operatorCommandIn;

        connect controllerToPump
            from controller.pumpCommandOut
            to turbopump.commandInput;

        connect controllerToDrive
            from controller.driveCommandOut
            to variableFrequencyDrive.commandInput;

        connect suctionPressureSignalToController
            from suctionPressureTransmitter.signalOut
            to controller.suctionPressureIn;

        connect dischargePressureSignalToController
            from dischargePressureTransmitter.signalOut
            to controller.dischargePressureIn;

        connect flowSignalToController
            from dischargeFlowMeter.signalOut
            to controller.flowIn;

        connect speedSignalToController
            from driveMotor.speedFeedback
            to controller.speedIn;

        connect pumpStatusToController
            from turbopump.statusOutput
            to controller.pumpStatusIn;

        connect pumpStatusToBoundary
            from turbopump.statusOutput
            to subsystemStatus;
    }

    constraint def FlowAtLeast {
        in attribute actualFlow : Real;
        in attribute requiredFlow : Real;
        actualFlow >= requiredFlow;
    }

    constraint def PressureNotAbove {
        in attribute actualPressure : Real;
        in attribute pressureLimit : Real;
        actualPressure <= pressureLimit;
    }

    constraint def PressureAtLeast {
        in attribute actualPressure : Real;
        in attribute requiredPressure : Real;
        actualPressure >= requiredPressure;
    }

    constraint def SpeedBelowTrip {
        in attribute actualSpeed : Real;
        in attribute tripSpeed : Real;
        actualSpeed < tripSpeed;
    }

    requirement def PumpingSubsystemFluidTransferRequirement {
        subject subsystem : PumpingSubsystem;

        attribute requiredFlow : VolumetricFlowRateValue {
            :>> value = 0.025;
            :>> unit = "m^3/s";
        }

        attribute requiredDischargePressure : PressureValue {
            :>> value = 450.0;
            :>> unit = "kPa";
        }

        require constraint flowRequirement : FlowAtLeast {
            actualFlow = subsystem.ratedFlowRate.value;
            requiredFlow = requiredFlow.value;
        }

        require constraint pressureRequirement : PressureAtLeast {
            actualPressure = subsystem.ratedDischargePressure.value;
            requiredPressure = requiredDischargePressure.value;
        }
    }

    requirement def PumpingSubsystemPressureProtectionRequirement {
        subject subsystem : PumpingSubsystem;

        attribute pressureLimit : PressureValue {
            :>> value = 900.0;
            :>> unit = "kPa";
        }

        require constraint dischargePressureLimit : PressureNotAbove {
            actualPressure = subsystem.maximumAllowableDischargePressure.value;
            pressureLimit = pressureLimit.value;
        }
    }

    requirement def TurbopumpOverspeedProtectionRequirement {
        subject pump : Turbopump;

        attribute speedLimit : RotationalSpeedValue {
            :>> value = 12500.0;
            :>> unit = "rpm";
        }

        require constraint overspeedLimit : SpeedBelowTrip {
            actualSpeed = pump.nominalSpeed.value;
            tripSpeed = speedLimit.value;
        }
    }

    requirement def TurbopumpHydraulicPerformanceRequirement {
        subject pump : Turbopump;

        attribute minimumDesignFlow : VolumetricFlowRateValue {
            :>> value = 0.035;
            :>> unit = "m^3/s";
        }

        attribute minimumDifferentialPressure : PressureValue {
            :>> value = 500.0;
            :>> unit = "kPa";
        }

        require constraint designFlowCapability : FlowAtLeast {
            actualFlow = pump.designFlowRate.value;
            requiredFlow = minimumDesignFlow.value;
        }

        require constraint designPressureCapability : PressureAtLeast {
            actualPressure = pump.designDifferentialPressure.value;
            requiredPressure = minimumDifferentialPressure.value;
        }
    }

    part pumpingSubsystem : PumpingSubsystem;

    requirement fluidTransferReq : PumpingSubsystemFluidTransferRequirement {
        subject = pumpingSubsystem;
    }

    requirement pressureProtectionReq : PumpingSubsystemPressureProtectionRequirement {
        subject = pumpingSubsystem;
    }

    requirement turbopumpOverspeedReq : TurbopumpOverspeedProtectionRequirement {
        subject = pumpingSubsystem.turbopump;
    }

    requirement turbopumpHydraulicReq : TurbopumpHydraulicPerformanceRequirement {
        subject = pumpingSubsystem.turbopump;
    }

    satisfy fluidTransferReq by pumpingSubsystem.turbopump;
    satisfy fluidTransferReq by pumpingSubsystem.controller;
    satisfy pressureProtectionReq by pumpingSubsystem.dischargePressureTransmitter;
    satisfy pressureProtectionReq by pumpingSubsystem.controller;
    satisfy turbopumpOverspeedReq by pumpingSubsystem.driveMotor;
    satisfy turbopumpOverspeedReq by pumpingSubsystem.variableFrequencyDrive;
    satisfy turbopumpHydraulicReq by pumpingSubsystem.turbopump;
}
