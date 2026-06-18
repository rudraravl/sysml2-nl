package BrineBasedSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Volume_L :> Real {
        doc /* Volume measured in liters. */
        attribute unitSymbol : String = "L";
    }

    attribute def FlowRate_L_per_min :> Real {
        doc /* Volumetric flow rate measured in liters per minute. */
        attribute unitSymbol : String = "L/min";
    }

    attribute def Pressure_kPa :> Real {
        doc /* Gauge pressure measured in kilopascals. */
        attribute unitSymbol : String = "kPa";
    }

    attribute def Temperature_C :> Real {
        doc /* Temperature measured in degrees Celsius. */
        attribute unitSymbol : String = "degC";
    }

    attribute def Salinity_g_per_kg :> Real {
        doc /* Salt concentration measured as grams of dissolved salts per kilogram of brine. */
        attribute unitSymbol : String = "g/kg";
    }

    attribute def Conductivity_mS_per_cm :> Real {
        doc /* Electrical conductivity measured in millisiemens per centimeter. */
        attribute unitSymbol : String = "mS/cm";
    }

    attribute def Mass_kg :> Real {
        doc /* Mass measured in kilograms. */
        attribute unitSymbol : String = "kg";
    }

    attribute def Power_kW :> Real {
        doc /* Power measured in kilowatts. */
        attribute unitSymbol : String = "kW";
    }

    attribute def Energy_kWh :> Real {
        doc /* Energy measured in kilowatt-hours. */
        attribute unitSymbol : String = "kWh";
    }

    attribute def Time_min :> Real {
        doc /* Time measured in minutes. */
        attribute unitSymbol : String = "min";
    }

    attribute def Percent :> Real {
        doc /* Dimensionless percentage. */
        attribute unitSymbol : "%";
    }

    enum def SystemMode {
        enum idle;
        enum intake;
        enum filtering;
        enum mixing;
        enum heating;
        enum verification;
        enum ready;
        enum delivery;
        enum cleaning;
        enum faulted;
        enum shutdown;
    }

    enum def ValvePosition {
        enum closed;
        enum open;
        enum modulating;
    }

    enum def PumpStatus {
        enum stopped;
        enum running;
        enum failed;
    }

    enum def QualityDisposition {
        enum acceptable;
        enum tooDilute;
        enum tooConcentrated;
        enum tooCold;
        enum tooHot;
        enum contaminated;
    }

    item def Water {
        attribute temperature : Temperature_C;
        attribute volume : Volume_L;
        attribute conductivity : Conductivity_mS_per_cm;
    }

    item def Salt {
        attribute mass : Mass_kg;
        attribute purity : Percent;
        attribute grainSize_mm : Real;
    }

    item def Brine {
        doc /* A water-based salt solution used as the central working item of the system. */
        attribute volume : Volume_L;
        attribute salinity : Salinity_g_per_kg;
        attribute temperature : Temperature_C;
        attribute pressure : Pressure_kPa;
        attribute conductivity : Conductivity_mS_per_cm;
        attribute suspendedSolids : Percent;
    }

    item def WasteBrine {
        attribute volume : Volume_L;
        attribute salinity : Salinity_g_per_kg;
        attribute temperature : Temperature_C;
        attribute suspendedSolids : Percent;
    }

    item def ControlSignal {
        attribute commandedMode : SystemMode;
        attribute commandedFlow : FlowRate_L_per_min;
        attribute commandedTemperature : Temperature_C;
        attribute commandedSalinity : Salinity_g_per_kg;
    }

    item def SensorSignal {
        attribute measuredSalinity : Salinity_g_per_kg;
        attribute measuredTemperature : Temperature_C;
        attribute measuredPressure : Pressure_kPa;
        attribute measuredFlow : FlowRate_L_per_min;
        attribute quality : QualityDisposition;
    }

    item def ElectricalPower {
        attribute voltage_V : Real;
        attribute current_A : Real;
        attribute power : Power_kW;
    }

    port def BrinePort {
        inout item brine : Brine;
    }

    port def WaterPort {
        inout item water : Water;
    }

    port def SaltPort {
        in item salt : Salt;
    }

    port def WastePort {
        out item waste : WasteBrine;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def CommandPort {
        in item command : ControlSignal;
    }

    port def TelemetryPort {
        out item telemetry : SensorSignal;
    }

    port def InternalSignalPort {
        inout item signal : SensorSignal;
    }

    part def RawBrineTank {
        doc /* Stores incoming brine before conditioning. */
        attribute capacity : Volume_L = 2500.0;
        attribute nominalInventory : Volume_L = 1800.0;
        attribute maximumSalinity : Salinity_g_per_kg = 260.0;
        attribute minimumUsableVolume : Volume_L = 200.0;

        port inlet : BrinePort;
        port outlet : BrinePort;
        port levelTelemetry : TelemetryPort;
    }

    part def WaterSupplyInterface {
        doc /* Receives make-up water for dilution and cleaning. */
        attribute maximumFlow : FlowRate_L_per_min = 120.0;
        attribute nominalPressure : Pressure_kPa = 350.0;

        port waterOutlet : WaterPort;
        port commandIn : CommandPort;
    }

    part def SaltHopper {
        doc /* Holds dry salt and meters salt into the dissolver. */
        attribute capacity : Mass_kg = 1200.0;
        attribute minimumReserve : Mass_kg = 100.0;
        attribute saltPurity : Percent = 99.2;
        attribute maximumFeedRate : Mass_kg = 25.0;

        port saltOutlet : SaltPort;
        port commandIn : CommandPort;
        port statusOut : TelemetryPort;
    }

    part def IntakeValve {
        attribute position : ValvePosition = ValvePosition::closed;
        attribute maximumFlow : FlowRate_L_per_min = 180.0;
        attribute pressureDropAtMaxFlow : Pressure_kPa = 20.0;

        port upstream : BrinePort;
        port downstream : BrinePort;
        port commandIn : CommandPort;
    }

    part def TransferPump {
        doc /* Moves brine through the conditioning train. */
        attribute status : PumpStatus = PumpStatus::stopped;
        attribute ratedFlow : FlowRate_L_per_min = 150.0;
        attribute ratedHead : Pressure_kPa = 420.0;
        attribute ratedPower : Power_kW = 5.5;
        attribute minimumSafeFlow : FlowRate_L_per_min = 25.0;

        port suction : BrinePort;
        port discharge : BrinePort;
        port electricalIn : PowerPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
    }

    part def CoarseFilter {
        doc /* Removes suspended solids before precision conditioning. */
        attribute nominalPoreSize_um : Real = 100.0;
        attribute maximumDifferentialPressure : Pressure_kPa = 90.0;
        attribute removalEfficiency : Percent = 85.0;

        port inlet : BrinePort;
        port outlet : BrinePort;
        port wasteOutlet : WastePort;
        port telemetryOut : TelemetryPort;
    }

    part def FineFilter {
        doc /* Provides final particulate removal to protect downstream users. */
        attribute nominalPoreSize_um : Real = 10.0;
        attribute maximumDifferentialPressure : Pressure_kPa = 120.0;
        attribute removalEfficiency : Percent = 97.0;

        port inlet : BrinePort;
        port outlet : BrinePort;
        port wasteOutlet : WastePort;
        port telemetryOut : TelemetryPort;
    }

    part def DissolverMixer {
        doc /* Mixes brine, water, and dry salt until a homogeneous target salinity is achieved. */
        attribute workingVolume : Volume_L = 750.0;
        attribute agitatorPower : Power_kW = 3.0;
        attribute nominalResidenceTime : Time_min = 8.0;
        attribute salinityUniformityTolerance : Salinity_g_per_kg = 1.5;

        port brineInlet : BrinePort;
        port waterInlet : WaterPort;
        port saltInlet : SaltPort;
        port brineOutlet : BrinePort;
        port electricalIn : PowerPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
    }

    part def HeatExchanger {
        doc /* Adjusts brine temperature to the required process band. */
        attribute heatingCapacity : Power_kW = 18.0;
        attribute coolingCapacity : Power_kW = 12.0;
        attribute maximumOutletTemperature : Temperature_C = 45.0;
        attribute minimumOutletTemperature : Temperature_C = -5.0;
        attribute thermalEfficiency : Percent = 88.0;

        port inlet : BrinePort;
        port outlet : BrinePort;
        port electricalIn : PowerPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
    }

    part def SalinitySensor {
        doc /* Estimates salinity from conductivity and temperature compensation. */
        attribute measurementRangeLow : Salinity_g_per_kg = 0.0;
        attribute measurementRangeHigh : Salinity_g_per_kg = 300.0;
        attribute accuracy : Salinity_g_per_kg = 0.8;
        attribute responseTime : Time_min = 0.10;

        port sampleIn : BrinePort;
        port telemetryOut : TelemetryPort;
        port electricalIn : PowerPort;
    }

    part def TemperatureSensor {
        attribute measurementRangeLow : Temperature_C = -20.0;
        attribute measurementRangeHigh : Temperature_C = 80.0;
        attribute accuracy : Temperature_C = 0.2;
        attribute responseTime : Time_min = 0.05;

        port sampleIn : BrinePort;
        port telemetryOut : TelemetryPort;
        port electricalIn : PowerPort;
    }

    part def ProductBrineTank {
        doc /* Stores conditioned brine ready for delivery. */
        attribute capacity : Volume_L = 3000.0;
        attribute nominalInventory : Volume_L = 2000.0;
        attribute maximumAllowablePressure : Pressure_kPa = 250.0;

        port inlet : BrinePort;
        port outlet : BrinePort;
        port telemetryOut : TelemetryPort;
    }

    part def DeliveryPump {
        doc /* Supplies accepted brine to the external consumer at controlled pressure and flow. */
        attribute status : PumpStatus = PumpStatus::stopped;
        attribute ratedFlow : FlowRate_L_per_min = 120.0;
        attribute ratedHead : Pressure_kPa = 500.0;
        attribute ratedPower : Power_kW = 4.5;

        port suction : BrinePort;
        port discharge : BrinePort;
        port electricalIn : PowerPort;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
    }

    part def WasteTank {
        doc /* Collects filter purge, rejected brine, and cleaning solution. */
        attribute capacity : Volume_L = 1000.0;
        attribute highLevelAlarmThreshold : Volume_L = 850.0;

        port wasteInlet : WastePort;
        port telemetryOut : TelemetryPort;
    }

    part def PowerDistributionUnit {
        attribute incomingVoltage_V : Real = 480.0;
        attribute maximumPower : Power_kW = 45.0;
        attribute protectedCircuits : Integer = 8;

        port supplyIn : PowerPort;
        port pumpPowerOut : PowerPort;
        port mixerPowerOut : PowerPort;
        port heaterPowerOut : PowerPort;
        port sensorPowerOut : PowerPort;
        port deliveryPowerOut : PowerPort;
    }

    part def BrineController {
        doc /* Supervises brine conditioning by comparing measurements to setpoints and commanding actuators. */
        attribute targetSalinity : Salinity_g_per_kg = 230.0;
        attribute salinityTolerance : Salinity_g_per_kg = 2.0;
        attribute targetTemperature : Temperature_C = 18.0;
        attribute temperatureTolerance : Temperature_C = 1.0;
        attribute targetDeliveryFlow : FlowRate_L_per_min = 100.0;
        attribute currentMode : SystemMode = SystemMode::idle;

        port operatorCommandIn : CommandPort;
        port intakeValveCommandOut : CommandPort;
        port pumpCommandOut : CommandPort;
        port mixerCommandOut : CommandPort;
        port heaterCommandOut : CommandPort;
        port saltCommandOut : CommandPort;
        port waterCommandOut : CommandPort;
        port deliveryPumpCommandOut : CommandPort;
        port sensorTelemetryIn : InternalSignalPort;
        port systemTelemetryOut : TelemetryPort;
    }

    part def DownstreamProcessInterface {
        doc /* External process connection receiving conditioned brine. */
        attribute requiredFlow : FlowRate_L_per_min = 100.0;
        attribute minimumPressure : Pressure_kPa = 250.0;
        attribute acceptedSalinityLow : Salinity_g_per_kg = 228.0;
        attribute acceptedSalinityHigh : Salinity_g_per_kg = 232.0;

        port brineIn : BrinePort;
        port commandOut : CommandPort;
        port telemetryIn : InternalSignalPort;
    }

    action def IntakeRawBrine {
        in item rawBrine : Brine;
        out item intakeBrine : Brine;

        attribute requestedVolume : Volume_L;
        attribute intakeFlow : FlowRate_L_per_min;
    }

    action def FilterBrine {
        in item unfilteredBrine : Brine;
        out item filteredBrine : Brine;
        out item removedWaste : WasteBrine;

        attribute targetSuspendedSolids : Percent = 0.05;
    }

    action def AdjustSalinity {
        in item incomingBrine : Brine;
        in item makeUpWater : Water;
        in item drySalt : Salt;
        out item salinityAdjustedBrine : Brine;

        attribute targetSalinity : Salinity_g_per_kg = 230.0;
        attribute tolerance : Salinity_g_per_kg = 2.0;
        attribute mixingDuration : Time_min = 8.0;
    }

    action def AdjustTemperature {
        in item brineIn : Brine;
        out item brineOut : Brine;

        attribute targetTemperature : Temperature_C = 18.0;
        attribute tolerance : Temperature_C = 1.0;
        attribute maximumEnergyPerBatch : Energy_kWh = 15.0;
    }

    action def VerifyBrineQuality {
        in item candidateBrine : Brine;
        out item acceptedBrine : Brine;
        out item rejectedBrine : WasteBrine;

        attribute acceptableSalinityLow : Salinity_g_per_kg = 228.0;
        attribute acceptableSalinityHigh : Salinity_g_per_kg = 232.0;
        attribute acceptableTemperatureLow : Temperature_C = 17.0;
        attribute acceptableTemperatureHigh : Temperature_C = 19.0;
        attribute maximumSuspendedSolids : Percent = 0.05;
    }

    action def DeliverConditionedBrine {
        in item storedBrine : Brine;
        out item deliveredBrine : Brine;

        attribute deliveryFlow : FlowRate_L_per_min = 100.0;
        attribute deliveryPressure : Pressure_kPa = 300.0;
    }

    action def ProduceConditionedBrine {
        doc /* High-level behavior: transform available brine, water, and salt into filtered, temperature-controlled, target-salinity brine for delivery. */

        in item rawBrine : Brine;
        in item dilutionWater : Water;
        in item replenishmentSalt : Salt;
        out item conditionedBrine : Brine;
        out item waste : WasteBrine;

        action intake : IntakeRawBrine;
        action coarseFiltering : FilterBrine;
        action salinityControl : AdjustSalinity;
        action thermalControl : AdjustTemperature;
        action fineFiltering : FilterBrine;
        action qualityCheck : VerifyBrineQuality;
        action delivery : DeliverConditionedBrine;

        flow rawBrine to intake.rawBrine;
        flow intake.intakeBrine to coarseFiltering.unfilteredBrine;
        flow coarseFiltering.filteredBrine to salinityControl.incomingBrine;
        flow dilutionWater to salinityControl.makeUpWater;
        flow replenishmentSalt to salinityControl.drySalt;
        flow salinityControl.salinityAdjustedBrine to thermalControl.brineIn;
        flow thermalControl.brineOut to fineFiltering.unfilteredBrine;
        flow fineFiltering.filteredBrine to qualityCheck.candidateBrine;
        flow qualityCheck.acceptedBrine to delivery.storedBrine;
        flow delivery.deliveredBrine to conditionedBrine;
        flow coarseFiltering.removedWaste to waste;
        flow fineFiltering.removedWaste to waste;
        flow qualityCheck.rejectedBrine to waste;

        first start;
        then intake;
        then coarseFiltering;
        then salinityControl;
        then thermalControl;
        then fineFiltering;
        then qualityCheck;
        then delivery;
        then done;
    }

    state def BrineSystemOperationalStates {
        doc /* Operational state machine for the brine-based conditioning and supply system. */

        state idle;
        state intake;
        state filtering;
        state mixing;
        state heating;
        state verification;
        state ready;
        state delivery;
        state cleaning;
        state faulted;
        state shutdown;

        transition initialTransition first start then idle;

        transition beginIntake
            first idle
            accept ControlSignal
            then intake;

        transition intakeComplete
            first intake
            then filtering;

        transition filtersPrimed
            first filtering
            then mixing;

        transition salinityAdjusted
            first mixing
            then heating;

        transition temperatureAdjusted
            first heating
            then verification;

        transition qualityAccepted
            first verification
            then ready;

        transition deliveryRequested
            first ready
            accept ControlSignal
            then delivery;

        transition deliveryComplete
            first delivery
            then ready;

        transition cleanRequested
            first ready
            accept ControlSignal
            then cleaning;

        transition cleaningComplete
            first cleaning
            then idle;

        transition qualityRejected
            first verification
            then mixing;

        transition faultDetectedFromAnyMode
            first idle
            then faulted;

        transition faultReset
            first faulted
            accept ControlSignal
            then idle;

        transition operatorShutdown
            first idle
            accept ControlSignal
            then shutdown;
    }

    constraint def SalinityWithinTarget {
        in measured : Salinity_g_per_kg;
        in target : Salinity_g_per_kg;
        in tolerance : Salinity_g_per_kg;

        measured >= target - tolerance and measured <= target + tolerance
    }

    constraint def TemperatureWithinTarget {
        in measured : Temperature_C;
        in target : Temperature_C;
        in tolerance : Temperature_C;

        measured >= target - tolerance and measured <= target + tolerance
    }

    constraint def TankNotOverfilled {
        in inventory : Volume_L;
        in capacity : Volume_L;

        inventory <= capacity
    }

    constraint def DeliveryPressureAdequate {
        in pressure : Pressure_kPa;
        in minimumPressure : Pressure_kPa;

        pressure >= minimumPressure
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Brine Conditioning and Supply System shall receive raw brine, water, and salt; condition the brine by filtering, salinity adjustment, and temperature control; verify product quality; and deliver accepted brine to a downstream process at controlled flow and pressure. */

        subject system : BrineConditioningAndSupplySystem;
    }

    requirement def ProductSalinityRequirement {
        doc /* Product brine salinity shall remain within plus or minus 2 g/kg of the 230 g/kg target when released to the product tank or downstream process. */

        subject system : BrineConditioningAndSupplySystem;

        require constraint {
            system.productBrineNominalSalinity >= 228.0 and
            system.productBrineNominalSalinity <= 232.0
        }
    }

    requirement def ProductTemperatureRequirement {
        doc /* Product brine temperature shall remain between 17 degC and 19 degC during normal delivery. */

        subject system : BrineConditioningAndSupplySystem;

        require constraint {
            system.productBrineNominalTemperature >= 17.0 and
            system.productBrineNominalTemperature <= 19.0
        }
    }

    requirement def DeliveryFlowRequirement {
        doc /* The system shall deliver conditioned brine at a nominal flow rate of 100 L/min with capability of at least 120 L/min. */

        subject system : BrineConditioningAndSupplySystem;

        require constraint {
            system.nominalDeliveryFlow == 100.0 and
            system.maximumDeliveryFlow >= 120.0
        }
    }

    requirement def FiltrationRequirement {
        doc /* Conditioned brine released to the product tank shall contain no more than 0.05 percent suspended solids. */

        subject system : BrineConditioningAndSupplySystem;

        require constraint {
            system.maximumProductSuspendedSolids <= 0.05
        }
    }

    requirement def WasteContainmentRequirement {
        doc /* Waste brine generated by filtering, quality rejection, and cleaning shall be routed to a contained waste tank with at least 1000 L capacity. */

        subject system : BrineConditioningAndSupplySystem;

        require constraint {
            system.wasteTank.capacity >= 1000.0
        }
    }

    requirement def PowerLimitRequirement {
        doc /* Total connected electrical load for the brine system shall not exceed 45 kW. */

        subject system : BrineConditioningAndSupplySystem;

        require constraint {
            system.connectedElectricalLoad <= 45.0
        }
    }

    part def BrineConditioningAndSupplySystem {
        doc /* A brine-based process system whose primary function is to produce and deliver clean, temperature-controlled, target-salinity brine for an external process. */

        attribute productBrineNominalSalinity : Salinity_g_per_kg = 230.0;
        attribute productBrineNominalTemperature : Temperature_C = 18.0;
        attribute nominalDeliveryFlow : FlowRate_L_per_min = 100.0;
        attribute maximumDeliveryFlow : FlowRate_L_per_min = 120.0;
        attribute maximumProductSuspendedSolids : Percent = 0.05;
        attribute connectedElectricalLoad : Power_kW = 43.0;
        attribute primaryFunction : String = "Condition raw brine into clean, temperature-controlled, target-salinity brine and deliver it to a downstream process.";

        port rawBrineSupply : BrinePort;
        port potableWaterSupply : WaterPort;
        port externalPowerSupply : PowerPort;
        port operatorCommand : CommandPort;
        port productBrineDelivery : BrinePort;
        port systemTelemetry : TelemetryPort;

        part rawBrineTank : RawBrineTank;
        part waterSupply : WaterSupplyInterface;
        part saltHopper : SaltHopper;
        part intakeValve : IntakeValve;
        part transferPump : TransferPump;
        part coarseFilter : CoarseFilter;
        part mixer : DissolverMixer;
        part heatExchanger : HeatExchanger;
        part fineFilter : FineFilter;
        part salinitySensor : SalinitySensor;
        part temperatureSensor : TemperatureSensor;
        part productTank : ProductBrineTank;
        part deliveryPump : DeliveryPump;
        part wasteTank : WasteTank;
        part controller : BrineController;
        part powerDistribution : PowerDistributionUnit;
        part downstreamProcess : DownstreamProcessInterface;

        perform action productionCycle : ProduceConditionedBrine;
        exhibit state operationalStates : BrineSystemOperationalStates;

        connect rawBrineSupply to rawBrineTank.inlet;
        connect rawBrineTank.outlet to intakeValve.upstream;
        connect intakeValve.downstream to transferPump.suction;
        connect transferPump.discharge to coarseFilter.inlet;
        connect coarseFilter.outlet to mixer.brineInlet;
        connect potableWaterSupply to waterSupply.waterOutlet;
        connect waterSupply.waterOutlet to mixer.waterInlet;
        connect saltHopper.saltOutlet to mixer.saltInlet;
        connect mixer.brineOutlet to heatExchanger.inlet;
        connect heatExchanger.outlet to fineFilter.inlet;
        connect fineFilter.outlet to salinitySensor.sampleIn;
        connect salinitySensor.sampleIn to temperatureSensor.sampleIn;
        connect temperatureSensor.sampleIn to productTank.inlet;
        connect productTank.outlet to deliveryPump.suction;
        connect deliveryPump.discharge to productBrineDelivery;
        connect productBrineDelivery to downstreamProcess.brineIn;

        connect coarseFilter.wasteOutlet to wasteTank.wasteInlet;
        connect fineFilter.wasteOutlet to wasteTank.wasteInlet;

        connect externalPowerSupply to powerDistribution.supplyIn;
        connect powerDistribution.pumpPowerOut to transferPump.electricalIn;
        connect powerDistribution.mixerPowerOut to mixer.electricalIn;
        connect powerDistribution.heaterPowerOut to heatExchanger.electricalIn;
        connect powerDistribution.sensorPowerOut to salinitySensor.electricalIn;
        connect powerDistribution.sensorPowerOut to temperatureSensor.electricalIn;
        connect powerDistribution.deliveryPowerOut to deliveryPump.electricalIn;

        connect operatorCommand to controller.operatorCommandIn;
        connect controller.intakeValveCommandOut to intakeValve.commandIn;
        connect controller.pumpCommandOut to transferPump.commandIn;
        connect controller.mixerCommandOut to mixer.commandIn;
        connect controller.heaterCommandOut to heatExchanger.commandIn;
        connect controller.saltCommandOut to saltHopper.commandIn;
        connect controller.waterCommandOut to waterSupply.commandIn;
        connect controller.deliveryPumpCommandOut to deliveryPump.commandIn;

        connect salinitySensor.telemetryOut to controller.sensorTelemetryIn;
        connect temperatureSensor.telemetryOut to controller.sensorTelemetryIn;
        connect transferPump.telemetryOut to controller.sensorTelemetryIn;
        connect mixer.telemetryOut to controller.sensorTelemetryIn;
        connect heatExchanger.telemetryOut to controller.sensorTelemetryIn;
        connect productTank.telemetryOut to controller.sensorTelemetryIn;
        connect wasteTank.telemetryOut to controller.sensorTelemetryIn;
        connect controller.systemTelemetryOut to systemTelemetry;
        connect systemTelemetry to downstreamProcess.telemetryIn;

        assert constraint salinityControlSatisfied : SalinityWithinTarget {
            in measured = productBrineNominalSalinity;
            in target = controller.targetSalinity;
            in tolerance = controller.salinityTolerance;
        }

        assert constraint temperatureControlSatisfied : TemperatureWithinTarget {
            in measured = productBrineNominalTemperature;
            in target = controller.targetTemperature;
            in tolerance = controller.temperatureTolerance;
        }

        assert constraint productTankCapacitySatisfied : TankNotOverfilled {
            in inventory = productTank.nominalInventory;
            in capacity = productTank.capacity;
        }

        assert constraint rawTankCapacitySatisfied : TankNotOverfilled {
            in inventory = rawBrineTank.nominalInventory;
            in capacity = rawBrineTank.capacity;
        }
    }

    part brineSystem : BrineConditioningAndSupplySystem;

    satisfy PrimaryFunctionRequirement by brineSystem;
    satisfy ProductSalinityRequirement by brineSystem;
    satisfy ProductTemperatureRequirement by brineSystem;
    satisfy DeliveryFlowRequirement by brineSystem;
    satisfy FiltrationRequirement by brineSystem;
    satisfy WasteContainmentRequirement by brineSystem;
    satisfy PowerLimitRequirement by brineSystem;
}
