package DrumPumpPumpingSubsystemModel {
    private import ScalarValues::*;

    attribute def Volume :> Real {
        attribute unitSymbol : String = "L";
    }

    attribute def VolumetricFlowRate :> Real {
        attribute unitSymbol : String = "L/min";
    }

    attribute def Pressure :> Real {
        attribute unitSymbol : String = "kPa";
    }

    attribute def Temperature :> Real {
        attribute unitSymbol : String = "degC";
    }

    attribute def Density :> Real {
        attribute unitSymbol : String = "kg/m^3";
    }

    attribute def DynamicViscosity :> Real {
        attribute unitSymbol : String = "mPa*s";
    }

    attribute def Voltage :> Real {
        attribute unitSymbol : String = "V";
    }

    attribute def Current :> Real {
        attribute unitSymbol : String = "A";
    }

    attribute def ElectricalPower :> Real {
        attribute unitSymbol : String = "W";
    }

    attribute def RotationalSpeed :> Real {
        attribute unitSymbol : String = "rpm";
    }

    attribute def Torque :> Real {
        attribute unitSymbol : String = "N*m";
    }

    attribute def Length :> Real {
        attribute unitSymbol : String = "m";
    }

    attribute def TimeDuration :> Real {
        attribute unitSymbol : String = "s";
    }

    attribute def Percent :> Real {
        attribute unitSymbol : String = "%";
    }

    item def Fluid {
        attribute density : Density = 998.0;
        attribute temperature : Temperature = 20.0;
        attribute dynamicViscosity : DynamicViscosity = 1.0;
        attribute vaporPressure : Pressure = 2.3;
        attribute compatibleWithPolypropylene : Boolean = true;
        attribute compatibleWithViton : Boolean = true;
    }

    item def ElectricEnergy {
        attribute voltage : Voltage = 120.0;
        attribute current : Current = 8.0;
        attribute power : ElectricalPower = 600.0;
    }

    item def MechanicalRotation {
        attribute shaftSpeed : RotationalSpeed = 3600.0;
        attribute shaftTorque : Torque = 1.2;
    }

    item def PumpCommand {
        attribute startRequested : Boolean = false;
        attribute stopRequested : Boolean = false;
        attribute flushRequested : Boolean = false;
        attribute resetRequested : Boolean = false;
        attribute targetFlowRate : VolumetricFlowRate = 25.0;
    }

    item def PumpStatus {
        attribute energized : Boolean = false;
        attribute primed : Boolean = false;
        attribute pumping : Boolean = false;
        attribute faulted : Boolean = false;
        attribute dryRunDetected : Boolean = false;
        attribute leakDetected : Boolean = false;
        attribute measuredFlowRate : VolumetricFlowRate = 0.0;
        attribute measuredDischargePressure : Pressure = 0.0;
    }

    item def LevelSignal {
        attribute levelPercent : Percent = 100.0;
        attribute lowLevelAlarm : Boolean = false;
    }

    item def FlowSignal {
        attribute measuredFlowRate : VolumetricFlowRate = 0.0;
    }

    item def PressureSignal {
        attribute measuredPressure : Pressure = 0.0;
        attribute highPressureAlarm : Boolean = false;
    }

    item def LeakSignal {
        attribute leakPresent : Boolean = false;
    }

    port def FluidOutletPort {
        out item fluid : Fluid;
        attribute portPressure : Pressure = 0.0;
        attribute availableFlowRate : VolumetricFlowRate = 0.0;
    }

    port def FluidInletPort {
        in item fluid : Fluid;
        attribute portPressure : Pressure = 0.0;
        attribute acceptedFlowRate : VolumetricFlowRate = 0.0;
    }

    port def ElectricalPowerOutPort {
        out item energy : ElectricEnergy;
    }

    port def ElectricalPowerInPort {
        in item energy : ElectricEnergy;
    }

    port def RotaryOutPort {
        out item rotation : MechanicalRotation;
    }

    port def RotaryInPort {
        in item rotation : MechanicalRotation;
    }

    port def CommandOutPort {
        out item command : PumpCommand;
    }

    port def CommandInPort {
        in item command : PumpCommand;
    }

    port def StatusOutPort {
        out item status : PumpStatus;
    }

    port def StatusInPort {
        in item status : PumpStatus;
    }

    port def LevelSignalOutPort {
        out item signal : LevelSignal;
    }

    port def LevelSignalInPort {
        in item signal : LevelSignal;
    }

    port def FlowSignalOutPort {
        out item signal : FlowSignal;
    }

    port def FlowSignalInPort {
        in item signal : FlowSignal;
    }

    port def PressureSignalOutPort {
        out item signal : PressureSignal;
    }

    port def PressureSignalInPort {
        in item signal : PressureSignal;
    }

    port def LeakSignalOutPort {
        out item signal : LeakSignal;
    }

    port def LeakSignalInPort {
        in item signal : LeakSignal;
    }

    interface def FluidTransferInterface {
        end supplier : FluidOutletPort;
        end receiver : FluidInletPort;
        flow supplier.fluid to receiver.fluid;
    }

    interface def ElectricalSupplyInterface {
        end source : ElectricalPowerOutPort;
        end load : ElectricalPowerInPort;
        flow source.energy to load.energy;
    }

    interface def RotaryDriveInterface {
        end driver : RotaryOutPort;
        end driven : RotaryInPort;
        flow driver.rotation to driven.rotation;
    }

    interface def CommandInterface {
        end source : CommandOutPort;
        end receiver : CommandInPort;
        flow source.command to receiver.command;
    }

    interface def StatusInterface {
        end source : StatusOutPort;
        end receiver : StatusInPort;
        flow source.status to receiver.status;
    }

    interface def LevelSignalInterface {
        end source : LevelSignalOutPort;
        end receiver : LevelSignalInPort;
        flow source.signal to receiver.signal;
    }

    interface def FlowSignalInterface {
        end source : FlowSignalOutPort;
        end receiver : FlowSignalInPort;
        flow source.signal to receiver.signal;
    }

    interface def PressureSignalInterface {
        end source : PressureSignalOutPort;
        end receiver : PressureSignalInPort;
        flow source.signal to receiver.signal;
    }

    interface def LeakSignalInterface {
        end source : LeakSignalOutPort;
        end receiver : LeakSignalInPort;
        flow source.signal to receiver.signal;
    }

    part def DrumContainer {
        attribute totalVolume : Volume = 208.0;
        attribute usableVolume : Volume = 200.0;
        attribute minimumResidualVolume : Volume = 5.0;
        attribute ventOpen : Boolean = true;
        attribute bungOpeningDiameter : Length = 0.051;
        port fluidOut : FluidOutletPort;
        port levelSignalOut : LevelSignalOutPort;
        part levelSensor : DrumLevelSensor;
    }

    part def DrumLevelSensor {
        attribute measurementRange : Percent = 100.0;
        attribute lowLevelTripPoint : Percent = 5.0;
        port signalOut : LevelSignalOutPort;
    }

    part def ElectricPowerSupply {
        attribute outputVoltage : Voltage = 120.0;
        attribute maximumCurrent : Current = 10.0;
        attribute maximumPower : ElectricalPower = 1200.0;
        port powerOut : ElectricalPowerOutPort;
    }

    part def ControlPanel {
        attribute commandedFlowRate : VolumetricFlowRate = 25.0;
        attribute emergencyStopActive : Boolean = false;
        attribute automaticShutoffEnabled : Boolean = true;
        port commandOut : CommandOutPort;
        port statusIn : StatusInPort;
    }

    part def ElectricMotor {
        attribute ratedVoltage : Voltage = 120.0;
        attribute ratedCurrent : Current = 6.5;
        attribute ratedPower : ElectricalPower = 500.0;
        attribute ratedSpeed : RotationalSpeed = 3600.0;
        attribute thermalTripEnabled : Boolean = true;
        port powerIn : ElectricalPowerInPort;
        port commandIn : CommandInPort;
        port shaftOut : RotaryOutPort;
        port statusOut : StatusOutPort;
    }

    part def PumpTube {
        attribute insertionLength : Length = 0.95;
        attribute tubeDiameter : Length = 0.038;
        attribute wettedMaterialCompatible : Boolean = true;
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def IntakeStrainer {
        attribute meshOpening : Length = 0.001;
        attribute cloggingPercent : Percent = 0.0;
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def Impeller {
        attribute bladeDiameter : Length = 0.032;
        attribute designSpeed : RotationalSpeed = 3600.0;
        port rotaryIn : RotaryInPort;
    }

    part def ShaftSeal {
        attribute compatibleWithFluid : Boolean = true;
        attribute leakageRate : VolumetricFlowRate = 0.0;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure = 5.0;
        attribute backflowPrevented : Boolean = true;
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def PumpController {
        attribute dryRunShutdownEnabled : Boolean = true;
        attribute highPressureShutdownEnabled : Boolean = true;
        attribute maximumContinuousRunTime : TimeDuration = 1800.0;
        port commandIn : CommandInPort;
        port motorCommandOut : CommandOutPort;
        port statusIn : StatusInPort;
        port levelSignalIn : LevelSignalInPort;
        port flowSignalIn : FlowSignalInPort;
        port pressureSignalIn : PressureSignalInPort;
        port leakSignalIn : LeakSignalInPort;
        port statusOut : StatusOutPort;
    }

    part def FlowMeter {
        attribute measurementRange : VolumetricFlowRate = 60.0;
        attribute accuracy : Percent = 2.0;
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port signalOut : FlowSignalOutPort;
    }

    part def PressureSensor {
        attribute measurementRange : Pressure = 400.0;
        attribute highPressureTripPoint : Pressure = 250.0;
        port fluidIn : FluidInletPort;
        port signalOut : PressureSignalOutPort;
    }

    part def FlexibleDischargeHose {
        attribute internalDiameter : Length = 0.025;
        attribute length : Length = 3.0;
        attribute ratedPressure : Pressure = 400.0;
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def DispenseNozzle {
        attribute manualValveOpen : Boolean = true;
        attribute maximumFlowRate : VolumetricFlowRate = 45.0;
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def ReceivingVessel {
        attribute capacity : Volume = 100.0;
        attribute receivedVolume : Volume = 0.0;
        port inlet : FluidInletPort;
    }

    part def LeakContainmentTray {
        attribute containmentVolume : Volume = 20.0;
        attribute collectedLeakVolume : Volume = 0.0;
        port leakSignalOut : LeakSignalOutPort;
    }

    action def PrimePump {
        in item sourceFluid : Fluid;
        out item primedFluid : Fluid;
        attribute maximumPrimeTime : TimeDuration = 10.0;
        attribute achievedPrime : Boolean = true;
    }

    action def TransferFluid {
        in item inletFluid : Fluid;
        out item outletFluid : Fluid;
        attribute targetFlowRate : VolumetricFlowRate = 25.0;
        attribute achievedFlowRate : VolumetricFlowRate = 25.0;
        attribute dischargePressure : Pressure = 120.0;
        constraint { achievedFlowRate >= 18.0 }
        constraint { dischargePressure <= 250.0 }
    }

    action def StopTransfer {
        attribute commandedStop : Boolean = true;
        attribute motorDeenergized : Boolean = true;
        attribute backflowPrevented : Boolean = true;
    }

    action def FlushPump {
        in item flushFluid : Fluid;
        out item flushedFluid : Fluid;
        attribute flushTime : TimeDuration = 30.0;
    }

    state def DrumPumpOperatingStates {
        state off;
        state priming;
        state pumping;
        state flushing;
        state faulted;

        transition startPump first off then priming;
        transition primeComplete first priming then pumping;
        transition stopPump first pumping then off;
        transition flushRequested first pumping then flushing;
        transition flushComplete first flushing then off;
        transition dryRunFault first priming then faulted;
        transition overPressureFault first pumping then faulted;
        transition leakFault first pumping then faulted;
        transition resetFault first faulted then off;
    }

    part def DrumPump {
        attribute nominalFlowRate : VolumetricFlowRate = 25.0;
        attribute maximumFlowRate : VolumetricFlowRate = 45.0;
        attribute minimumStableFlowRate : VolumetricFlowRate = 5.0;
        attribute maximumDischargePressure : Pressure = 250.0;
        attribute maximumFluidTemperature : Temperature = 50.0;
        attribute maximumViscosity : DynamicViscosity = 100.0;
        attribute dryRunAllowed : Boolean = false;
        attribute selfPriming : Boolean = true;
        attribute wettedMaterialCompatible : Boolean = true;

        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port powerIn : ElectricalPowerInPort;
        port commandIn : CommandInPort;
        port levelSignalIn : LevelSignalInPort;
        port flowSignalIn : FlowSignalInPort;
        port pressureSignalIn : PressureSignalInPort;
        port leakSignalIn : LeakSignalInPort;
        port statusOut : StatusOutPort;

        part motor : ElectricMotor;
        part controller : PumpController;
        part tube : PumpTube;
        part strainer : IntakeStrainer;
        part impeller : Impeller;
        part seal : ShaftSeal;
        part dischargeCheckValve : CheckValve;

        state operatingState : DrumPumpOperatingStates;

        action primingAction : PrimePump;
        action transferAction : TransferFluid {
            :>> targetFlowRate = nominalFlowRate;
            :>> achievedFlowRate = nominalFlowRate;
            :>> dischargePressure = 120.0;
        }
        action stopAction : StopTransfer;
        action flushAction : FlushPump;

        interface inletToStrainer : FluidTransferInterface connect inlet to strainer.inlet;
        interface strainerToTube : FluidTransferInterface connect strainer.outlet to tube.inlet;
        interface tubeToCheckValve : FluidTransferInterface connect tube.outlet to dischargeCheckValve.inlet;
        interface checkValveToOutlet : FluidTransferInterface connect dischargeCheckValve.outlet to outlet;
        interface electricalFeed : ElectricalSupplyInterface connect powerIn to motor.powerIn;
        interface rotaryDrive : RotaryDriveInterface connect motor.shaftOut to impeller.rotaryIn;
        interface commandToController : CommandInterface connect commandIn to controller.commandIn;
        interface controllerToMotor : CommandInterface connect controller.motorCommandOut to motor.commandIn;
        interface motorStatusToController : StatusInterface connect motor.statusOut to controller.statusIn;
        interface levelToController : LevelSignalInterface connect levelSignalIn to controller.levelSignalIn;
        interface flowToController : FlowSignalInterface connect flowSignalIn to controller.flowSignalIn;
        interface pressureToController : PressureSignalInterface connect pressureSignalIn to controller.pressureSignalIn;
        interface leakToController : LeakSignalInterface connect leakSignalIn to controller.leakSignalIn;
        interface controllerStatusOut : StatusInterface connect controller.statusOut to statusOut;
    }

    part def PumpingSubsystem {
        attribute requiredFlowRate : VolumetricFlowRate = 18.0;
        attribute actualFlowRate : VolumetricFlowRate = 25.0;
        attribute dischargePressure : Pressure = 120.0;
        attribute transferredVolume : Volume = 0.0;
        attribute continuousRunTime : TimeDuration = 0.0;
        attribute fluidContained : Boolean = true;
        attribute safeToOperate : Boolean = true;

        port externalCommandIn : CommandInPort;
        port externalStatusOut : StatusOutPort;
        port finalDischargeOut : FluidOutletPort;

        part drum : DrumContainer {
            :>> totalVolume = 208.0;
            :>> usableVolume = 200.0;
        }

        part pump : DrumPump {
            :>> nominalFlowRate = 25.0;
            :>> maximumDischargePressure = 250.0;
        }

        part powerSupply : ElectricPowerSupply {
            :>> outputVoltage = 120.0;
            :>> maximumCurrent = 10.0;
        }

        part controlPanel : ControlPanel {
            :>> commandedFlowRate = 25.0;
        }

        part flowMeter : FlowMeter;
        part pressureSensor : PressureSensor;
        part dischargeHose : FlexibleDischargeHose;
        part nozzle : DispenseNozzle;
        part receivingVessel : ReceivingVessel;
        part containmentTray : LeakContainmentTray;

        interface drumToPump : FluidTransferInterface connect drum.fluidOut to pump.inlet;
        interface pumpToFlowMeter : FluidTransferInterface connect pump.outlet to flowMeter.inlet;
        interface flowMeterToHose : FluidTransferInterface connect flowMeter.outlet to dischargeHose.inlet;
        interface hoseToNozzle : FluidTransferInterface connect dischargeHose.outlet to nozzle.inlet;
        interface nozzleToReceiver : FluidTransferInterface connect nozzle.outlet to receivingVessel.inlet;
        interface nozzleToExternalDischarge : FluidTransferInterface connect nozzle.outlet to finalDischargeOut;

        interface electricalSupplyToPump : ElectricalSupplyInterface connect powerSupply.powerOut to pump.powerIn;
        interface operatorCommandToPanel : CommandInterface connect externalCommandIn to controlPanel.commandOut;
        interface panelCommandToPump : CommandInterface connect controlPanel.commandOut to pump.commandIn;
        interface pumpStatusToPanel : StatusInterface connect pump.statusOut to controlPanel.statusIn;
        interface pumpStatusToExternal : StatusInterface connect pump.statusOut to externalStatusOut;
        interface drumLevelToPump : LevelSignalInterface connect drum.levelSignalOut to pump.levelSignalIn;
        interface meterSignalToPump : FlowSignalInterface connect flowMeter.signalOut to pump.flowSignalIn;
        interface pressureSignalToPump : PressureSignalInterface connect pressureSensor.signalOut to pump.pressureSignalIn;
        interface leakSignalToPump : LeakSignalInterface connect containmentTray.leakSignalOut to pump.leakSignalIn;

        constraint { actualFlowRate >= requiredFlowRate }
        constraint { dischargePressure <= pump.maximumDischargePressure }
        constraint { fluidContained == true }
        constraint { safeToOperate == true }
    }

    requirement def MoveFluidUsingDrumPumpRequirement {
        subject subsystem : PumpingSubsystem;
        attribute minimumDeliveredFlowRate : VolumetricFlowRate = 18.0;
        require constraint { subsystem.actualFlowRate >= minimumDeliveredFlowRate }
        require constraint { subsystem.pump.selfPriming == true }
        require constraint { subsystem.pump.dryRunAllowed == false }
    }

    requirement def PressureSafetyRequirement {
        subject subsystem : PumpingSubsystem;
        attribute maximumAllowedPressure : Pressure = 250.0;
        require constraint { subsystem.dischargePressure <= maximumAllowedPressure }
        require constraint { subsystem.pump.maximumDischargePressure <= maximumAllowedPressure }
    }

    requirement def FluidContainmentRequirement {
        subject subsystem : PumpingSubsystem;
        attribute minimumContainmentVolume : Volume = 20.0;
        require constraint { subsystem.fluidContained == true }
        require constraint { subsystem.containmentTray.containmentVolume >= minimumContainmentVolume }
    }

    requirement def CompatibilityRequirement {
        subject subsystem : PumpingSubsystem;
        require constraint { subsystem.pump.wettedMaterialCompatible == true }
        require constraint { subsystem.drum.ventOpen == true }
    }

    part installedDrumPumpSubsystem : PumpingSubsystem;

    requirement moveFluidUsingDrumPump : MoveFluidUsingDrumPumpRequirement {
        subject subsystem = installedDrumPumpSubsystem;
    }

    requirement pressureSafety : PressureSafetyRequirement {
        subject subsystem = installedDrumPumpSubsystem;
    }

    requirement fluidContainment : FluidContainmentRequirement {
        subject subsystem = installedDrumPumpSubsystem;
    }

    requirement materialCompatibility : CompatibilityRequirement {
        subject subsystem = installedDrumPumpSubsystem;
    }

    satisfy moveFluidUsingDrumPump by installedDrumPumpSubsystem;
    satisfy pressureSafety by installedDrumPumpSubsystem;
    satisfy fluidContainment by installedDrumPumpSubsystem;
    satisfy materialCompatibility by installedDrumPumpSubsystem;
}
