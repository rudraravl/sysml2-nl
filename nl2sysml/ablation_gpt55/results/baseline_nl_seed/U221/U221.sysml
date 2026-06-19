package ExtracorporealMembraneOxygenationModel {
    private import ScalarValues::*;

    attribute def Percent :> Real {
        attribute unitSymbol : String = "%";
    }

    attribute def VolumeFlowRate_L_per_min :> Real {
        attribute unitSymbol : String = "L/min";
    }

    attribute def GasFlowRate_L_per_min :> Real {
        attribute unitSymbol : String = "L/min";
    }

    attribute def Pressure_mmHg :> Real {
        attribute unitSymbol : String = "mmHg";
    }

    attribute def Temperature_degC :> Real {
        attribute unitSymbol : String = "degC";
    }

    attribute def PartialPressure_mmHg :> Real {
        attribute unitSymbol : String = "mmHg";
    }

    attribute def RotationalSpeed_rpm :> Real {
        attribute unitSymbol : String = "rpm";
    }

    attribute def ElectricalPower_W :> Real {
        attribute unitSymbol : String = "W";
    }

    attribute def ElectricalVoltage_V :> Real {
        attribute unitSymbol : String = "V";
    }

    attribute def Time_min :> Real {
        attribute unitSymbol : String = "min";
    }

    attribute def Area_m2 :> Real {
        attribute unitSymbol : String = "m^2";
    }

    attribute def Volume_mL :> Real {
        attribute unitSymbol : String = "mL";
    }

    attribute def Concentration_g_per_dL :> Real {
        attribute unitSymbol : "g/dL";
    }

    item def Blood {
        attribute oxygenSaturation : Percent;
        attribute carbonDioxidePartialPressure : PartialPressure_mmHg;
        attribute oxygenPartialPressure : PartialPressure_mmHg;
        attribute temperature : Temperature_degC;
        attribute hemoglobinConcentration : Concentration_g_per_dL;
        attribute flowRate : VolumeFlowRate_L_per_min;
        attribute pressure : Pressure_mmHg;
    }

    item def SweepGas {
        attribute oxygenFraction : Percent;
        attribute carbonDioxideFraction : Percent;
        attribute flowRate : GasFlowRate_L_per_min;
        attribute pressure : Pressure_mmHg;
        attribute temperature : Temperature_degC;
    }

    item def ExhaustGas {
        attribute oxygenFraction : Percent;
        attribute carbonDioxideFraction : Percent;
        attribute flowRate : GasFlowRate_L_per_min;
    }

    item def ElectricalPower {
        attribute voltage : ElectricalVoltage_V;
        attribute power : ElectricalPower_W;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute valid : Boolean;
        attribute alarmLimitExceeded : Boolean;
    }

    item def ControlCommand {
        attribute setPoint : Real;
        attribute enabled : Boolean;
        attribute emergencyStop : Boolean;
    }

    item def HeatTransfer {
        attribute targetTemperature : Temperature_degC;
        attribute deliveredPower : ElectricalPower_W;
    }

    port def BloodInputPort {
        in item blood : Blood;
    }

    port def BloodOutputPort {
        out item blood : Blood;
    }

    port def SweepGasInputPort {
        in item gas : SweepGas;
    }

    port def SweepGasOutputPort {
        out item gas : SweepGas;
    }

    port def ExhaustGasOutputPort {
        out item gas : ExhaustGas;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    port def SensorOutputPort {
        out item signal : SensorSignal;
    }

    port def SensorInputPort {
        in item signal : SensorSignal;
    }

    port def CommandInputPort {
        in item command : ControlCommand;
    }

    port def CommandOutputPort {
        out item command : ControlCommand;
    }

    port def HeatCommandOutputPort {
        out item heat : HeatTransfer;
    }

    port def HeatCommandInputPort {
        in item heat : HeatTransfer;
    }

    constraint def SafeBloodFlowConstraint {
        in flow : VolumeFlowRate_L_per_min;
        in minimumFlow : VolumeFlowRate_L_per_min;
        in maximumFlow : VolumeFlowRate_L_per_min;
        constraint { flow >= minimumFlow and flow <= maximumFlow }
    }

    constraint def AdequateOxygenationConstraint {
        in saturation : Percent;
        in minimumSaturation : Percent;
        constraint { saturation >= minimumSaturation }
    }

    constraint def SafePressureConstraint {
        in pressure : Pressure_mmHg;
        in maximumPressure : Pressure_mmHg;
        constraint { pressure <= maximumPressure }
    }

    constraint def NormothermiaConstraint {
        in temperature : Temperature_degC;
        in minimumTemperature : Temperature_degC;
        in maximumTemperature : Temperature_degC;
        constraint { temperature >= minimumTemperature and temperature <= maximumTemperature }
    }

    action def DrainVenousBlood {
        in item patientVenousBlood : Blood;
        out item drainedBlood : Blood;
        attribute targetDrainageFlow : VolumeFlowRate_L_per_min = 4.0;
        attribute allowableVenousPressure : Pressure_mmHg = -80.0;
    }

    action def PumpBlood {
        in item inletBlood : Blood;
        out item pressurizedBlood : Blood;
        in item pumpCommand : ControlCommand;
        attribute commandedSpeed : RotationalSpeed_rpm = 3200.0;
        attribute targetFlow : VolumeFlowRate_L_per_min = 4.0;
    }

    action def ExchangeGasAcrossMembrane {
        in item venousBlood : Blood;
        in item sweepGas : SweepGas;
        out item arterializedBlood : Blood;
        out item exhaustGas : ExhaustGas;
        attribute targetOxygenSaturation : Percent = 95.0;
        attribute targetCarbonDioxidePartialPressure : PartialPressure_mmHg = 40.0;
    }

    action def RegulateBloodTemperature {
        in item bloodBeforeHeatExchange : Blood;
        in item thermalCommand : HeatTransfer;
        out item conditionedBlood : Blood;
        attribute targetTemperature : Temperature_degC = 37.0;
    }

    action def ReturnArterializedBloodToPatient {
        in item conditionedBlood : Blood;
        out item returnedBlood : Blood;
        attribute maximumReturnPressure : Pressure_mmHg = 300.0;
    }

    action def MonitorAndControlECMO {
        in item flowSignal : SensorSignal;
        in item pressureSignal : SensorSignal;
        in item oxygenSignal : SensorSignal;
        in item temperatureSignal : SensorSignal;
        out item pumpCommand : ControlCommand;
        out item gasCommand : ControlCommand;
        out item heatCommand : HeatTransfer;
        attribute controlCycleTime : Time_min = 0.017;
    }

    action def ProvideExtracorporealLifeSupport {
        in item venousBloodFromPatient : Blood;
        in item sweepGasSupply : SweepGas;
        in item electricalSupply : ElectricalPower;
        out item oxygenatedBloodToPatient : Blood;
        out item gasExhaust : ExhaustGas;

        action drain : DrainVenousBlood;
        action pump : PumpBlood;
        action exchange : ExchangeGasAcrossMembrane;
        action regulateTemperature : RegulateBloodTemperature;
        action returnToPatient : ReturnArterializedBloodToPatient;

        succession s1 first drain then pump;
        succession s2 first pump then exchange;
        succession s3 first exchange then regulateTemperature;
        succession s4 first regulateTemperature then returnToPatient;
    }

    state def ECMOOperatingMode {
        entry; then off;

        state off;
        state priming;
        state ready;
        state support;
        state alarm;
        state emergencyStop;

        transition offToPriming first off then priming;
        transition primingToReady first priming then ready;
        transition readyToSupport first ready then support;
        transition supportToAlarm first support then alarm;
        transition alarmToSupport first alarm then support;
        transition alarmToEmergencyStop first alarm then emergencyStop;
        transition supportToEmergencyStop first support then emergencyStop;
        transition emergencyStopToOff first emergencyStop then off;
    }

    part def Patient {
        port venousAccess : BloodOutputPort;
        port arterialAccess : BloodInputPort;

        attribute venousPressure : Pressure_mmHg = 5.0;
        attribute arterialPressure : Pressure_mmHg = 90.0;
        attribute venousOxygenSaturation : Percent = 65.0;
        attribute systemicOxygenSaturation : Percent = 88.0;
        attribute bloodTemperature : Temperature_degC = 37.0;
    }

    part def VenousDrainageCannula {
        port patientSide : BloodInputPort;
        port circuitSide : BloodOutputPort;

        attribute internalVolume : Volume_mL = 35.0;
        attribute maximumDrainageFlow : VolumeFlowRate_L_per_min = 7.0;
        attribute minimumSafeDrainagePressure : Pressure_mmHg = -100.0;
    }

    part def ArterialReturnCannula {
        port circuitSide : BloodInputPort;
        port patientSide : BloodOutputPort;

        attribute internalVolume : Volume_mL = 25.0;
        attribute maximumReturnFlow : VolumeFlowRate_L_per_min = 7.0;
        attribute maximumReturnPressure : Pressure_mmHg = 300.0;
    }

    part def CentrifugalPump {
        port inlet : BloodInputPort;
        port outlet : BloodOutputPort;
        port powerIn : PowerInputPort;
        port commandIn : CommandInputPort;
        port speedSignalOut : SensorOutputPort;

        attribute speed : RotationalSpeed_rpm = 3200.0;
        attribute commandedFlow : VolumeFlowRate_L_per_min = 4.0;
        attribute maximumFlow : VolumeFlowRate_L_per_min = 7.0;
        attribute maximumOutletPressure : Pressure_mmHg = 450.0;
        attribute nominalPower : ElectricalPower_W = 85.0;
    }

    part def FlowSensor {
        port bloodIn : BloodInputPort;
        port bloodOut : BloodOutputPort;
        port signalOut : SensorOutputPort;

        attribute measuredFlow : VolumeFlowRate_L_per_min = 4.0;
        attribute lowFlowAlarmLimit : VolumeFlowRate_L_per_min = 2.0;
        attribute highFlowAlarmLimit : VolumeFlowRate_L_per_min = 6.5;
    }

    part def PressureSensor {
        port signalOut : SensorOutputPort;

        attribute measuredPressure : Pressure_mmHg = 180.0;
        attribute highPressureAlarmLimit : Pressure_mmHg = 350.0;
        attribute lowPressureAlarmLimit : Pressure_mmHg = -90.0;
    }

    part def OxygenSaturationSensor {
        port signalOut : SensorOutputPort;

        attribute measuredSaturation : Percent = 95.0;
        attribute lowSaturationAlarmLimit : Percent = 90.0;
    }

    part def TemperatureSensor {
        port signalOut : SensorOutputPort;

        attribute measuredTemperature : Temperature_degC = 37.0;
        attribute lowTemperatureAlarmLimit : Temperature_degC = 35.0;
        attribute highTemperatureAlarmLimit : Temperature_degC = 38.5;
    }

    part def MembraneOxygenator {
        port bloodIn : BloodInputPort;
        port bloodOut : BloodOutputPort;
        port gasIn : SweepGasInputPort;
        port gasOut : ExhaustGasOutputPort;

        attribute membraneSurfaceArea : Area_m2 = 1.8;
        attribute ratedBloodFlow : VolumeFlowRate_L_per_min = 7.0;
        attribute ratedSweepGasFlow : GasFlowRate_L_per_min = 10.0;
        attribute maximumPressureDrop : Pressure_mmHg = 80.0;
        attribute oxygenTransferEfficiency : Percent = 92.0;
        attribute carbonDioxideRemovalEfficiency : Percent = 90.0;
    }

    part def HeatExchanger {
        port bloodIn : BloodInputPort;
        port bloodOut : BloodOutputPort;
        port powerIn : PowerInputPort;
        port commandIn : HeatCommandInputPort;
        port temperatureSignalOut : SensorOutputPort;

        attribute targetTemperature : Temperature_degC = 37.0;
        attribute maximumHeatingPower : ElectricalPower_W = 250.0;
        attribute maximumCoolingPower : ElectricalPower_W = 150.0;
    }

    part def OxygenSource {
        port gasOut : SweepGasOutputPort;

        attribute oxygenFraction : Percent = 100.0;
        attribute regulatedPressure : Pressure_mmHg = 1500.0;
    }

    part def AirSource {
        port gasOut : SweepGasOutputPort;

        attribute oxygenFraction : Percent = 21.0;
        attribute regulatedPressure : Pressure_mmHg = 1500.0;
    }

    part def GasBlender {
        port oxygenIn : SweepGasInputPort;
        port airIn : SweepGasInputPort;
        port blendedGasOut : SweepGasOutputPort;
        port commandIn : CommandInputPort;

        attribute setOxygenFraction : Percent = 80.0;
        attribute minimumOxygenFraction : Percent = 21.0;
        attribute maximumOxygenFraction : Percent = 100.0;
    }

    part def SweepGasFlowController {
        port gasIn : SweepGasInputPort;
        port gasOut : SweepGasOutputPort;
        port commandIn : CommandInputPort;

        attribute setSweepFlow : GasFlowRate_L_per_min = 4.0;
        attribute maximumSweepFlow : GasFlowRate_L_per_min = 12.0;
    }

    part def SweepGasSubsystem {
        port gasOut : SweepGasOutputPort;
        port commandIn : CommandInputPort;

        part oxygenSource : OxygenSource;
        part airSource : AirSource;
        part blender : GasBlender;
        part flowController : SweepGasFlowController;

        connect oxygenSupplyToBlender : oxygenSource.gasOut to blender.oxygenIn;
        connect airSupplyToBlender : airSource.gasOut to blender.airIn;
        connect blendedGasToFlowController : blender.blendedGasOut to flowController.gasIn;
        connect controlledSweepGasOut : flowController.gasOut to gasOut;
        connect gasCommandToBlender : commandIn to blender.commandIn;
        connect gasCommandToFlowController : commandIn to flowController.commandIn;
    }

    part def PowerSupply {
        port externalIn : PowerInputPort;
        port pumpPowerOut : PowerOutputPort;
        port heaterPowerOut : PowerOutputPort;
        port controllerPowerOut : PowerOutputPort;

        attribute externalVoltage : ElectricalVoltage_V = 240.0;
        attribute batteryVoltage : ElectricalVoltage_V = 24.0;
        attribute availableBatteryAutonomy : Time_min = 60.0;
        attribute nominalOutputPower : ElectricalPower_W = 500.0;
    }

    part def ECMOController {
        port flowSignalIn : SensorInputPort;
        port pressureSignalIn : SensorInputPort;
        port oxygenSignalIn : SensorInputPort;
        port temperatureSignalIn : SensorInputPort;
        port speedSignalIn : SensorInputPort;
        port powerIn : PowerInputPort;
        port pumpCommandOut : CommandOutputPort;
        port gasCommandOut : CommandOutputPort;
        port heatCommandOut : HeatCommandOutputPort;

        attribute targetBloodFlow : VolumeFlowRate_L_per_min = 4.0;
        attribute targetReturnOxygenSaturation : Percent = 95.0;
        attribute targetReturnTemperature : Temperature_degC = 37.0;
        attribute highPressureAlarmLimit : Pressure_mmHg = 350.0;
        attribute lowFlowAlarmLimit : VolumeFlowRate_L_per_min = 2.0;
        attribute alarmActive : Boolean = false;

        perform action monitorAndControl : MonitorAndControlECMO;
        exhibit state operatingMode : ECMOOperatingMode;
    }

    part def ECMOSystem {
        port venousBloodIn : BloodInputPort;
        port arterialBloodOut : BloodOutputPort;
        port externalPowerIn : PowerInputPort;
        port exhaustGasOut : ExhaustGasOutputPort;

        attribute nominalBloodFlow : VolumeFlowRate_L_per_min = 4.0;
        attribute minimumTherapeuticBloodFlow : VolumeFlowRate_L_per_min = 2.0;
        attribute maximumTherapeuticBloodFlow : VolumeFlowRate_L_per_min = 6.5;
        attribute nominalReturnOxygenSaturation : Percent = 95.0;
        attribute minimumReturnOxygenSaturation : Percent = 92.0;
        attribute nominalReturnCarbonDioxidePartialPressure : PartialPressure_mmHg = 40.0;
        attribute nominalReturnTemperature : Temperature_degC = 37.0;
        attribute maximumCircuitPressure : Pressure_mmHg = 350.0;
        attribute batteryAutonomy : Time_min = 60.0;

        part drainageCannula : VenousDrainageCannula;
        part pump : CentrifugalPump;
        part flowSensor : FlowSensor;
        part oxygenator : MembraneOxygenator;
        part heatExchanger : HeatExchanger;
        part returnCannula : ArterialReturnCannula;
        part sweepGas : SweepGasSubsystem;
        part powerSupply : PowerSupply;
        part controller : ECMOController;
        part venousPressureSensor : PressureSensor;
        part returnPressureSensor : PressureSensor;
        part oxygenSaturationSensor : OxygenSaturationSensor;
        part returnTemperatureSensor : TemperatureSensor;

        perform action provideSupport : ProvideExtracorporealLifeSupport;
        exhibit state systemMode : ECMOOperatingMode;

        constraint safeFlow : SafeBloodFlowConstraint {
            in flow = nominalBloodFlow;
            in minimumFlow = minimumTherapeuticBloodFlow;
            in maximumFlow = maximumTherapeuticBloodFlow;
        }

        constraint adequateOxygenation : AdequateOxygenationConstraint {
            in saturation = nominalReturnOxygenSaturation;
            in minimumSaturation = minimumReturnOxygenSaturation;
        }

        constraint safePressure : SafePressureConstraint {
            in pressure = maximumCircuitPressure;
            in maximumPressure = 350.0;
        }

        constraint temperatureControl : NormothermiaConstraint {
            in temperature = nominalReturnTemperature;
            in minimumTemperature = 36.0;
            in maximumTemperature = 38.0;
        }

        connect venousAccessToDrainageCannula : venousBloodIn to drainageCannula.patientSide;
        connect drainageCannulaToPump : drainageCannula.circuitSide to pump.inlet;
        connect pumpToFlowSensor : pump.outlet to flowSensor.bloodIn;
        connect flowSensorToOxygenator : flowSensor.bloodOut to oxygenator.bloodIn;
        connect oxygenatorToHeatExchanger : oxygenator.bloodOut to heatExchanger.bloodIn;
        connect heatExchangerToReturnCannula : heatExchanger.bloodOut to returnCannula.circuitSide;
        connect returnCannulaToArterialAccess : returnCannula.patientSide to arterialBloodOut;

        connect sweepGasToOxygenator : sweepGas.gasOut to oxygenator.gasIn;
        connect oxygenatorExhaust : oxygenator.gasOut to exhaustGasOut;

        connect externalPowerToSupply : externalPowerIn to powerSupply.externalIn;
        connect supplyToPump : powerSupply.pumpPowerOut to pump.powerIn;
        connect supplyToHeater : powerSupply.heaterPowerOut to heatExchanger.powerIn;
        connect supplyToController : powerSupply.controllerPowerOut to controller.powerIn;

        connect flowSignalToController : flowSensor.signalOut to controller.flowSignalIn;
        connect venousPressureSignalToController : venousPressureSensor.signalOut to controller.pressureSignalIn;
        connect returnPressureSignalToController : returnPressureSensor.signalOut to controller.pressureSignalIn;
        connect oxygenSignalToController : oxygenSaturationSensor.signalOut to controller.oxygenSignalIn;
        connect heatExchangerTemperatureSignalToController : heatExchanger.temperatureSignalOut to controller.temperatureSignalIn;
        connect returnTemperatureSignalToController : returnTemperatureSensor.signalOut to controller.temperatureSignalIn;
        connect pumpSpeedSignalToController : pump.speedSignalOut to controller.speedSignalIn;

        connect pumpCommand : controller.pumpCommandOut to pump.commandIn;
        connect gasCommand : controller.gasCommandOut to sweepGas.commandIn;
        connect heatCommand : controller.heatCommandOut to heatExchanger.commandIn;
    }

    part def ECMOTherapyConfiguration {
        part patient : Patient;
        part ecmo : ECMOSystem;

        connect patientVenousBloodToECMO : patient.venousAccess to ecmo.venousBloodIn;
        connect ecmoArterialBloodToPatient : ecmo.arterialBloodOut to patient.arterialAccess;
    }

    requirement def PrimaryECMOFunctionRequirement {
        subject system : ECMOSystem;
        doc /* The primary high-level function is to withdraw venous blood from a patient, pump it through an extracorporeal membrane oxygenator, add oxygen, remove carbon dioxide, regulate temperature, and return conditioned blood to the patient at safe therapeutic flow and pressure. */
        require constraint {
            system.nominalBloodFlow >= system.minimumTherapeuticBloodFlow and
            system.nominalBloodFlow <= system.maximumTherapeuticBloodFlow and
            system.nominalReturnOxygenSaturation >= system.minimumReturnOxygenSaturation and
            system.nominalReturnCarbonDioxidePartialPressure <= 45.0 and
            system.nominalReturnTemperature >= 36.0 and
            system.nominalReturnTemperature <= 38.0
        }
    }

    requirement def CircuitPressureSafetyRequirement {
        subject system : ECMOSystem;
        require constraint {
            system.maximumCircuitPressure <= 350.0
        }
    }

    requirement def BackupPowerRequirement {
        subject system : ECMOSystem;
        require constraint {
            system.batteryAutonomy >= 30.0
        }
    }

    requirement def ControllerAlarmRequirement {
        subject controller : ECMOController;
        require constraint {
            controller.highPressureAlarmLimit <= 350.0 and
            controller.lowFlowAlarmLimit >= 1.5
        }
    }

    requirement primaryFunction : PrimaryECMOFunctionRequirement {
        subject system : ECMOSystem;
    }

    requirement pressureSafety : CircuitPressureSafetyRequirement {
        subject system : ECMOSystem;
    }

    requirement backupPower : BackupPowerRequirement {
        subject system : ECMOSystem;
    }

    requirement alarmControl : ControllerAlarmRequirement {
        subject controller : ECMOController;
    }

    part ecmoTherapy : ECMOTherapyConfiguration;
}
