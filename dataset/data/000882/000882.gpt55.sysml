package GallonPerWattHourBasedFluidDeliverySystem {

    import ScalarValues::*;

    doc /*
     The GallonPerWattHourFluidDeliverySystem is an electrically powered fluid-transfer system
     whose primary high-level function is to convert stored electrical energy into delivered
     liquid volume while continuously measuring and controlling performance in gallons per
     watt-hour.
     */

    attribute def Gallon :> Real {
        doc /* US liquid gallon used as the delivered-volume unit. */
    }

    attribute def Watt :> Real {
        doc /* Electrical or mechanical power in watts. */
    }

    attribute def WattHour :> Real {
        doc /* Electrical energy equal to one watt used for one hour. */
    }

    attribute def Volt :> Real {
        doc /* Electrical potential in volts. */
    }

    attribute def Ampere :> Real {
        doc /* Electrical current in amperes. */
    }

    attribute def Psi :> Real {
        doc /* Fluid pressure in pounds per square inch. */
    }

    attribute def GallonPerMinute :> Real {
        doc /* Volumetric flow rate in gallons per minute. */
    }

    attribute def GallonPerWattHour :> Real {
        doc /* Fluid-delivery efficiency metric: gallons delivered per watt-hour consumed. */
    }

    attribute def Percent :> Real {
        doc /* Dimensionless percentage value. */
    }

    attribute def Second :> Real {
        doc /* Time duration in seconds. */
    }

    attribute def RevolutionsPerMinute :> Real {
        doc /* Rotational speed in revolutions per minute. */
    }

    attribute def DegreeCelsius :> Real {
        doc /* Temperature in degrees Celsius. */
    }

    enum def PumpOperatingMode {
        enum off;
        enum selfTest;
        enum priming;
        enum efficientDelivery;
        enum highPressureProtection;
        enum lowEnergyProtection;
        enum faulted;
        enum shutdown;
    }

    enum def FluidQuality {
        enum potableWater;
        enum processWater;
        enum irrigationWater;
    }

    item def Liquid {
        attribute quality : FluidQuality;
        attribute temperature : DegreeCelsius;
        attribute pressure : Psi;
    }

    item def LiquidFlow {
        attribute volumeFlowRate : GallonPerMinute;
        attribute pressure : Psi;
        attribute cumulativeVolume : Gallon;
        attribute temperature : DegreeCelsius;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute power : Watt;
    }

    item def ElectricalEnergy {
        attribute energy : WattHour;
    }

    item def MotorCommand {
        attribute requestedSpeed : RevolutionsPerMinute;
        attribute requestedDutyCycle : Percent;
        attribute enable : Boolean;
    }

    item def ValveCommand {
        attribute requestedOpenPercent : Percent;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute valid : Boolean;
        attribute sampleAge : Second;
    }

    item def EfficiencyTelemetry {
        attribute deliveredVolume : Gallon;
        attribute consumedEnergy : WattHour;
        attribute instantaneousFlow : GallonPerMinute;
        attribute instantaneousPower : Watt;
        attribute efficiency : GallonPerWattHour;
        attribute operatingMode : PumpOperatingMode;
    }

    item def MechanicalTorque {
        attribute shaftSpeed : RevolutionsPerMinute;
        attribute mechanicalPower : Watt;
    }

    port def DcPowerInPort {
        in item dcPower : ElectricalPower;
    }

    port def DcPowerOutPort {
        out item dcPower : ElectricalPower;
    }

    port def FluidInPort {
        in item liquidIn : LiquidFlow;
    }

    port def FluidOutPort {
        out item liquidOut : LiquidFlow;
    }

    port def CommandInPort {
        in item command : MotorCommand;
    }

    port def ValveCommandInPort {
        in item valveCommand : ValveCommand;
    }

    port def SensorOutPort {
        out item signal : SensorSignal;
    }

    port def TelemetryOutPort {
        out item telemetry : EfficiencyTelemetry;
    }

    port def TorqueOutPort {
        out item torque : MechanicalTorque;
    }

    port def TorqueInPort {
        in item torque : MechanicalTorque;
    }

    part def BatteryPack {
        doc /* Provides regulated DC energy to the delivery system. */

        port dcOut : DcPowerOutPort;

        attribute nominalVoltage : Volt = 48.0;
        attribute ratedCapacity : WattHour = 1200.0;
        attribute usableEnergyRemaining : WattHour = 1200.0;
        attribute minimumAllowedEnergy : WattHour = 120.0;
        attribute maximumDischargePower : Watt = 650.0;
        attribute stateOfCharge : Percent = 100.0;
        attribute packTemperature : DegreeCelsius = 25.0;
    }

    part def EnergyMeter {
        doc /* Measures electrical energy entering the motor drive for efficiency computation. */

        port dcIn : DcPowerInPort;
        port dcOut : DcPowerOutPort;
        port energySignal : SensorOutPort;

        attribute measuredVoltage : Volt;
        attribute measuredCurrent : Ampere;
        attribute instantaneousPower : Watt;
        attribute accumulatedEnergy : WattHour;
        attribute measurementAccuracy : Percent = 1.0;
    }

    part def MotorDriver {
        doc /* Converts DC input power into commanded motor power. */

        port dcIn : DcPowerInPort;
        port commandIn : CommandInPort;
        port motorPowerOut : DcPowerOutPort;

        attribute conversionEfficiency : Percent = 94.0;
        attribute commandedDutyCycle : Percent;
        attribute outputPower : Watt;
        attribute thermalLimit : DegreeCelsius = 85.0;
        attribute driverTemperature : DegreeCelsius = 30.0;
    }

    part def BrushlessMotor {
        doc /* Converts electrical power into shaft torque for the pump. */

        port electricalIn : DcPowerInPort;
        port torqueOut : TorqueOutPort;

        attribute motorEfficiency : Percent = 88.0;
        attribute speed : RevolutionsPerMinute;
        attribute ratedSpeed : RevolutionsPerMinute = 3600.0;
        attribute ratedPower : Watt = 500.0;
        attribute windingTemperature : DegreeCelsius = 35.0;
    }

    part def PositiveDisplacementPump {
        doc /* Converts motor shaft torque into pressurized liquid flow. */

        port shaftIn : TorqueInPort;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;

        attribute displacementPerRevolution : Gallon = 0.0011;
        attribute hydraulicEfficiency : Percent = 76.0;
        attribute expectedFlowAtRatedSpeed : GallonPerMinute = 3.96;
        attribute maximumOutletPressure : Psi = 75.0;
        attribute currentOutletPressure : Psi;
    }

    part def InletFilter {
        doc /* Removes debris before liquid reaches the pump. */

        port rawFluidIn : FluidInPort;
        port filteredFluidOut : FluidOutPort;

        attribute nominalPressureDrop : Psi = 1.5;
        attribute cloggingPressureDropLimit : Psi = 8.0;
        attribute measuredPressureDrop : Psi;
    }

    part def CheckValve {
        doc /* Prevents reverse flow when the pump stops. */

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;

        attribute crackingPressure : Psi = 0.8;
        attribute reverseLeakageFlow : GallonPerMinute = 0.0;
    }

    part def OutletControlValve {
        doc /* Modulates outlet restriction to keep operation near the best gallon-per-watt-hour point. */

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port commandIn : ValveCommandInPort;

        attribute openPercent : Percent = 100.0;
        attribute minimumOpenPercent : Percent = 15.0;
        attribute maximumOpenPercent : Percent = 100.0;
    }

    part def FlowMeter {
        doc /* Measures delivered fluid volume and flow rate. */

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port flowSignal : SensorOutPort;

        attribute measuredFlowRate : GallonPerMinute;
        attribute accumulatedVolume : Gallon;
        attribute measurementAccuracy : Percent = 1.5;
    }

    part def PressureSensor {
        doc /* Measures fluid pressure at a protected hydraulic location. */

        port pressureSignal : SensorOutPort;

        attribute measuredPressure : Psi;
        attribute maximumRatedPressure : Psi = 100.0;
        attribute measurementAccuracy : Percent = 1.0;
    }

    part def EfficiencyController {
        doc /*
         Computes gallons per watt-hour and commands motor speed and outlet valve position
         so the system delivers useful fluid volume with minimum electrical energy consumption.
         */

        port energyIn : SensorOutPort;
        port flowIn : SensorOutPort;
        port inletPressureIn : SensorOutPort;
        port outletPressureIn : SensorOutPort;
        port motorCommandOut : CommandInPort;
        port valveCommandOut : ValveCommandInPort;
        port telemetryOut : TelemetryOutPort;

        attribute targetEfficiency : GallonPerWattHour = 0.045;
        attribute minimumAllowedEfficiency : GallonPerWattHour = 0.035;
        attribute measuredEfficiency : GallonPerWattHour;
        attribute deliveredVolume : Gallon;
        attribute consumedEnergy : WattHour;
        attribute commandedSpeed : RevolutionsPerMinute;
        attribute commandedValveOpening : Percent;
        attribute activeMode : PumpOperatingMode;
        attribute lowEnergyThreshold : WattHour = 120.0;
        attribute maximumSafeOutletPressure : Psi = 70.0;
        attribute minimumPrimeFlow : GallonPerMinute = 0.15;
    }

    action def ComputeGallonPerWattHour {
        in deliveredVolume : Gallon;
        in consumedEnergy : WattHour;
        out efficiency : GallonPerWattHour;

        doc /* efficiency = deliveredVolume / consumedEnergy when consumedEnergy is greater than zero. */
    }

    action def SelectBestEfficiencyOperatingPoint {
        in currentEfficiency : GallonPerWattHour;
        in outletPressure : Psi;
        in availableEnergy : WattHour;
        out requestedSpeed : RevolutionsPerMinute;
        out requestedValveOpening : Percent;

        doc /*
         Selects a motor speed and outlet valve opening that preserve required pressure
         while moving operation toward the highest gallons per watt-hour region.
         */
    }

    action def DeliverFluidEfficiently {
        in requestedVolume : Gallon;
        in availableEnergy : WattHour;
        out deliveredVolume : Gallon;
        out consumedEnergy : WattHour;
        out achievedEfficiency : GallonPerWattHour;

        first startDelivery;
        then meterEnergy;
        then meterVolume;
        then computeEfficiency;
        then adjustOperatingPoint;
        then reportTelemetry;

        action startDelivery;
        action meterEnergy;
        action meterVolume;
        action computeEfficiency : ComputeGallonPerWattHour;
        action adjustOperatingPoint : SelectBestEfficiencyOperatingPoint;
        action reportTelemetry;
    }

    state def FluidDeliveryStateMachine {
        attribute mode : PumpOperatingMode;

        state off;
        state selfTest;
        state priming;
        state efficientDelivery;
        state highPressureProtection;
        state lowEnergyProtection;
        state faulted;
        state shutdown;

        transition initial then off;

        transition off_to_selfTest
            first off
            accept startCommand
            then selfTest;

        transition selfTest_to_priming
            first selfTest
            accept selfTestPassed
            then priming;

        transition selfTest_to_faulted
            first selfTest
            accept selfTestFailed
            then faulted;

        transition priming_to_efficientDelivery
            first priming
            accept primeFlowEstablished
            then efficientDelivery;

        transition priming_to_faulted
            first priming
            accept primeTimeout
            then faulted;

        transition efficientDelivery_to_highPressureProtection
            first efficientDelivery
            accept outletPressureAboveLimit
            then highPressureProtection;

        transition highPressureProtection_to_efficientDelivery
            first highPressureProtection
            accept pressureRecovered
            then efficientDelivery;

        transition efficientDelivery_to_lowEnergyProtection
            first efficientDelivery
            accept usableEnergyBelowThreshold
            then lowEnergyProtection;

        transition lowEnergyProtection_to_shutdown
            first lowEnergyProtection
            accept safeStopComplete
            then shutdown;

        transition efficientDelivery_to_shutdown
            first efficientDelivery
            accept requestedVolumeDelivered
            then shutdown;

        transition faulted_to_shutdown
            first faulted
            accept operatorAcknowledgedFault
            then shutdown;

        transition shutdown_to_off
            first shutdown
            accept powerRemoved
            then off;
    }

    part def GallonPerWattHourFluidDeliverySystem {
        doc /*
         Primary function: deliver liquid from an inlet to an outlet while optimizing and reporting
         the ratio of delivered gallons to consumed watt-hours.
         */

        port systemPowerIn : DcPowerInPort;
        port fluidInlet : FluidInPort;
        port fluidOutlet : FluidOutPort;
        port efficiencyTelemetryOut : TelemetryOutPort;

        part battery : BatteryPack;
        part energyMeter : EnergyMeter;
        part motorDriver : MotorDriver;
        part motor : BrushlessMotor;
        part pump : PositiveDisplacementPump;
        part inletFilter : InletFilter;
        part checkValve : CheckValve;
        part outletValve : OutletControlValve;
        part flowMeter : FlowMeter;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part controller : EfficiencyController;

        attribute designTargetEfficiency : GallonPerWattHour = 0.045;
        attribute minimumCertifiedEfficiency : GallonPerWattHour = 0.035;
        attribute maximumDeliveredPressure : Psi = 70.0;
        attribute nominalDeliveredFlow : GallonPerMinute = 3.5;
        attribute maximumElectricalPower : Watt = 600.0;
        attribute requestedDeliveryVolume : Gallon = 100.0;
        attribute expectedEnergyForRequestedVolume : WattHour = 2222.2;

        perform deliveryBehavior : DeliverFluidEfficiently;
        exhibit operatingStates : FluidDeliveryStateMachine;

        connect systemPowerIn to energyMeter.dcIn;
        connect battery.dcOut to energyMeter.dcIn;
        connect energyMeter.dcOut to motorDriver.dcIn;
        connect motorDriver.motorPowerOut to motor.electricalIn;
        connect motor.torqueOut to pump.shaftIn;

        connect fluidInlet to inletFilter.rawFluidIn;
        connect inletFilter.filteredFluidOut to pump.fluidIn;
        connect pump.fluidOut to checkValve.fluidIn;
        connect checkValve.fluidOut to outletValve.fluidIn;
        connect outletValve.fluidOut to flowMeter.fluidIn;
        connect flowMeter.fluidOut to fluidOutlet;

        connect energyMeter.energySignal to controller.energyIn;
        connect flowMeter.flowSignal to controller.flowIn;
        connect inletPressureSensor.pressureSignal to controller.inletPressureIn;
        connect outletPressureSensor.pressureSignal to controller.outletPressureIn;
        connect controller.motorCommandOut to motorDriver.commandIn;
        connect controller.valveCommandOut to outletValve.commandIn;
        connect controller.telemetryOut to efficiencyTelemetryOut;
    }

    requirement def PrimaryFunctionRequirement {
        doc /*
         The system shall deliver liquid from the fluid inlet to the fluid outlet using electrical
         energy and shall express primary performance as gallons delivered per watt-hour consumed.
         */

        subject deliverySystem : GallonPerWattHourFluidDeliverySystem;

        require constraint {
            deliverySystem.designTargetEfficiency >= 0.045
        }
    }

    requirement def MinimumEfficiencyRequirement {
        doc /*
         During steady efficient-delivery operation, the measured delivery efficiency shall not
         fall below 0.035 gallons per watt-hour for nominal process water at rated flow.
         */

        subject deliverySystem : GallonPerWattHourFluidDeliverySystem;

        require constraint {
            deliverySystem.minimumCertifiedEfficiency >= 0.035
        }
    }

    requirement def EnergyMeasurementRequirement {
        doc /*
         The system shall measure consumed electrical energy in watt-hours to support computation
         of gallon-per-watt-hour efficiency.
         */

        subject meter : EnergyMeter;

        require constraint {
            meter.measurementAccuracy <= 1.0
        }
    }

    requirement def VolumeMeasurementRequirement {
        doc /*
         The system shall measure delivered liquid volume in gallons with sufficient accuracy
         to compute efficiency and generate telemetry.
         */

        subject meter : FlowMeter;

        require constraint {
            meter.measurementAccuracy <= 1.5
        }
    }

    requirement def PressureProtectionRequirement {
        doc /*
         The controller shall command protective operation before outlet pressure exceeds the
         mechanical pressure limit of the pump and outlet plumbing.
         */

        subject deliverySystem : GallonPerWattHourFluidDeliverySystem;

        require constraint {
            deliverySystem.maximumDeliveredPressure <= 70.0
        }
    }

    requirement def LowEnergyProtectionRequirement {
        doc /*
         The controller shall stop delivery before the energy source is discharged below the
         reserved safe energy threshold.
         */

        subject battery : BatteryPack;

        require constraint {
            battery.minimumAllowedEnergy >= 120.0
        }
    }

    satisfy PrimaryFunctionRequirement by GallonPerWattHourFluidDeliverySystem;
    satisfy MinimumEfficiencyRequirement by GallonPerWattHourFluidDeliverySystem;
    satisfy EnergyMeasurementRequirement by EnergyMeter;
    satisfy VolumeMeasurementRequirement by FlowMeter;
    satisfy PressureProtectionRequirement by GallonPerWattHourFluidDeliverySystem;
    satisfy LowEnergyProtectionRequirement by BatteryPack;

    part deliverySystem : GallonPerWattHourFluidDeliverySystem {
        attribute designTargetEfficiency = 0.045;
        attribute minimumCertifiedEfficiency = 0.035;
        attribute maximumDeliveredPressure = 70.0;
        attribute nominalDeliveredFlow = 3.5;
        attribute maximumElectricalPower = 600.0;
        attribute requestedDeliveryVolume = 100.0;
    }
}
