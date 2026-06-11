package HeatedHumidifiedHighFlowTherapySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    /* Value Types and Units */

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = L / min;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = degC;
    }

    attribute def RelativeHumidity {
        attribute value : Real;
        constraint { value >= 0.0 and value <= 100.0 }
        unit = "%";
    }

    attribute def Pressure :> ISQ::pressure {
        unit = kPa;
    }

    attribute def OxygenFraction {
        attribute value : Real;
        constraint { value >= 21.0 and value <= 100.0 }
        unit = "%";
    }

    attribute def ElectricalPower :> ISQ::power {
        unit = W;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = s;
    }

    attribute def WaterVolume :> ISQ::volume {
        unit = mL;
    }

    attribute def TherapyStatus {
        enum values {
            Off;
            Standby;
            Starting;
            DeliveringTherapy;
            Warming;
            Fault;
            Shutdown;
        }
    }

    attribute def AlarmSeverity {
        enum values {
            Advisory;
            Caution;
            Critical;
        }
    }

    /* Item Definitions */

    item def AmbientAir {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute relativeHumidity : RelativeHumidity;
    }

    item def MedicalOxygen {
        attribute pressure : Pressure;
        attribute oxygenFraction : OxygenFraction = 100.0 [%];
    }

    item def BlendedGas {
        attribute totalFlow : FlowRate;
        attribute oxygenFraction : OxygenFraction;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute relativeHumidity : RelativeHumidity;
    }

    item def SterileWater {
        attribute availableVolume : WaterVolume;
    }

    item def HumidifiedHeatedGas :> BlendedGas {
        attribute airwayTemperature : Temperature;
        attribute absoluteHumidityTargetMet : Boolean;
    }

    item def PatientBreathingInterface {
        attribute cannulaSize : String;
        attribute maxComfortFlow : FlowRate;
    }

    item def ControlCommand {
        attribute requestedFlow : FlowRate;
        attribute requestedOxygenFraction : OxygenFraction;
        attribute requestedTemperature : Temperature;
        attribute therapyEnabled : Boolean;
    }

    item def SensorReading {
        attribute measuredFlow : FlowRate;
        attribute measuredOxygenFraction : OxygenFraction;
        attribute measuredTemperature : Temperature;
        attribute measuredPressure : Pressure;
        attribute measuredHumidity : RelativeHumidity;
        attribute waterLevel : WaterVolume;
    }

    item def AlarmSignal {
        attribute severity : AlarmSeverity;
        attribute message : String;
        attribute active : Boolean;
    }

    /* Port Definitions */

    port def GasInletPort {
        in item air : AmbientAir;
    }

    port def OxygenInletPort {
        in item oxygen : MedicalOxygen;
    }

    port def WaterInletPort {
        in item water : SterileWater;
    }

    port def TherapyGasPort {
        out item therapyGas : HumidifiedHeatedGas;
    }

    port def PatientInterfacePort {
        in item interface : PatientBreathingInterface;
        inout item deliveredGas : HumidifiedHeatedGas;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def SensorPort {
        out item reading : SensorReading;
    }

    port def AlarmPort {
        out item alarm : AlarmSignal;
    }

    port def PowerPort {
        in attribute voltage : Real;
        in attribute frequency : Real;
        out attribute consumedPower : ElectricalPower;
    }

    /* Part Definitions */

    part def AirIntakeSubsystem {
        port ambientAirIn : GasInletPort;
        port filteredAirOut : TherapyGasPort;

        attribute filterInstalled : Boolean;
        attribute filterOcclusionPressureDrop : Pressure;

        action filterAmbientAir {
            in item air : AmbientAir;
            out item filteredGas : BlendedGas;
        }
    }

    part def OxygenSupplySubsystem {
        port oxygenIn : OxygenInletPort;
        port oxygenOut : TherapyGasPort;

        attribute inletPressureMinimum : Pressure = 280.0 [kPa];
        attribute inletPressureMaximum : Pressure = 600.0 [kPa];

        action regulateOxygenPressure {
            in item oxygen : MedicalOxygen;
            out item regulatedOxygen : MedicalOxygen;
        }
    }

    part def GasBlender {
        port airIn : TherapyGasPort;
        port oxygenIn : TherapyGasPort;
        port blendedGasOut : TherapyGasPort;
        port commandIn : CommandPort;

        attribute setFlow : FlowRate;
        attribute setOxygenFraction : OxygenFraction;
        attribute blendAccuracy : OxygenFraction = 3.0 [%];

        action blendAirAndOxygen {
            in item airStream : BlendedGas;
            in item oxygenStream : MedicalOxygen;
            in item command : ControlCommand;
            out item blendedGas : BlendedGas;

            constraint {
                blendedGas.totalFlow == command.requestedFlow
            }

            constraint {
                blendedGas.oxygenFraction >= command.requestedOxygenFraction - blendAccuracy and
                blendedGas.oxygenFraction <= command.requestedOxygenFraction + blendAccuracy
            }
        }
    }

    part def FlowGenerator {
        port blendedGasIn : TherapyGasPort;
        port pressurizedGasOut : TherapyGasPort;
        port commandIn : CommandPort;

        attribute minimumFlow : FlowRate = 2.0 [L/min];
        attribute maximumFlow : FlowRate = 80.0 [L/min];
        attribute pressureLimit : Pressure = 6.0 [kPa];

        action generateHighFlow {
            in item blendedGas : BlendedGas;
            in item command : ControlCommand;
            out item pressurizedGas : BlendedGas;

            constraint {
                pressurizedGas.totalFlow >= minimumFlow and
                pressurizedGas.totalFlow <= maximumFlow
            }

            constraint {
                pressurizedGas.pressure <= pressureLimit
            }
        }
    }

    part def WaterReservoir {
        port sterileWaterIn : WaterInletPort;
        port waterStatusOut : SensorPort;

        attribute capacity : WaterVolume = 500.0 [mL];
        attribute lowWaterThreshold : WaterVolume = 50.0 [mL];
        attribute currentVolume : WaterVolume;

        action monitorWaterLevel {
            out item reading : SensorReading;
        }
    }

    part def HeatedHumidifierChamber {
        port gasIn : TherapyGasPort;
        port waterIn : WaterInletPort;
        port humidifiedGasOut : TherapyGasPort;
        port commandIn : CommandPort;
        port sensorOut : SensorPort;

        attribute heaterPlatePower : ElectricalPower = 160.0 [W];
        attribute targetRelativeHumidity : RelativeHumidity = 100.0 [%];
        attribute targetChamberTemperature : Temperature = 37.0 [degC];

        action heatAndHumidifyGas {
            in item dryGas : BlendedGas;
            in item water : SterileWater;
            in item command : ControlCommand;
            out item humidifiedGas : HumidifiedHeatedGas;

            constraint {
                humidifiedGas.relativeHumidity >= 95.0 [%]
            }

            constraint {
                humidifiedGas.airwayTemperature >= command.requestedTemperature - 2.0 [degC] and
                humidifiedGas.airwayTemperature <= command.requestedTemperature + 2.0 [degC]
            }
        }
    }

    part def HeatedBreathingCircuit {
        port humidifiedGasIn : TherapyGasPort;
        port patientGasOut : PatientInterfacePort;
        port commandIn : CommandPort;
        port sensorOut : SensorPort;

        attribute circuitHeaterPower : ElectricalPower = 60.0 [W];
        attribute condensationDetected : Boolean;
        attribute deliveredTemperatureTarget : Temperature = 37.0 [degC];

        action maintainCircuitTemperature {
            in item humidifiedGas : HumidifiedHeatedGas;
            out item deliveredGas : HumidifiedHeatedGas;

            constraint {
                deliveredGas.airwayTemperature >= 34.0 [degC] and
                deliveredGas.airwayTemperature <= 40.0 [degC]
            }
        }
    }

    part def NasalCannulaInterface {
        port gasIn : PatientInterfacePort;

        attribute size : String;
        attribute patientLeakExpected : Boolean = true;
        attribute maximumAppliedPressure : Pressure = 6.0 [kPa];

        action deliverGasToPatient {
            in item deliveredGas : HumidifiedHeatedGas;
        }
    }

    part def SensorSuite {
        port gasMeasurementIn : TherapyGasPort;
        port readingOut : SensorPort;

        attribute flowSensorAccuracy : FlowRate = 1.0 [L/min];
        attribute oxygenSensorAccuracy : OxygenFraction = 2.0 [%];
        attribute temperatureSensorAccuracy : Temperature = 0.5 [degC];
        attribute pressureSensorAccuracy : Pressure = 0.2 [kPa];

        action measureTherapyGas {
            in item gas : HumidifiedHeatedGas;
            out item reading : SensorReading;
        }
    }

    part def TherapyController {
        port commandIn : CommandPort;
        port sensorIn : SensorPort;
        port blenderCommandOut : CommandPort;
        port flowCommandOut : CommandPort;
        port humidifierCommandOut : CommandPort;
        port circuitCommandOut : CommandPort;
        port alarmOut : AlarmPort;

        attribute status : TherapyStatus;
        attribute requestedFlow : FlowRate;
        attribute requestedOxygenFraction : OxygenFraction;
        attribute requestedTemperature : Temperature;
        attribute startupWarmupTime : TimeDuration = 180.0 [s];

        action computeClosedLoopControls {
            in item command : ControlCommand;
            in item reading : SensorReading;
            out item blenderCommand : ControlCommand;
            out item flowCommand : ControlCommand;
            out item humidifierCommand : ControlCommand;
            out item circuitCommand : ControlCommand;
        }

        action detectFaults {
            in item reading : SensorReading;
            out item alarm : AlarmSignal;
        }

        state def TherapyControlStateMachine {
            state off;
            state standby;
            state starting;
            state warming;
            state delivering;
            state fault;
            state shutdown;

            initial then off;

            transition off_to_standby
                first off
                accept ControlCommand
                if command.therapyEnabled == false
                then standby;

            transition standby_to_starting
                first standby
                accept ControlCommand
                if command.therapyEnabled == true
                then starting;

            transition starting_to_warming
                first starting
                then warming;

            transition warming_to_delivering
                first warming
                accept SensorReading
                if reading.measuredTemperature >= 34.0 [degC] and reading.measuredHumidity >= 90.0 [%]
                then delivering;

            transition delivering_to_fault
                first delivering
                accept SensorReading
                if reading.measuredPressure > 6.0 [kPa] or reading.waterLevel < 50.0 [mL]
                then fault;

            transition warming_to_fault
                first warming
                accept SensorReading
                if reading.measuredPressure > 6.0 [kPa] or reading.waterLevel < 50.0 [mL]
                then fault;

            transition fault_to_standby
                first fault
                accept ControlCommand
                if command.therapyEnabled == false
                then standby;

            transition delivering_to_shutdown
                first delivering
                accept ControlCommand
                if command.therapyEnabled == false
                then shutdown;

            transition shutdown_to_off
                first shutdown
                then off;
        }
    }

    part def UserInterface {
        port commandOut : CommandPort;
        port alarmIn : AlarmPort;

        attribute displayedFlow : FlowRate;
        attribute displayedOxygenFraction : OxygenFraction;
        attribute displayedTemperature : Temperature;
        attribute alarmSilenced : Boolean;

        action acceptClinicianSettings {
            out item command : ControlCommand;

            constraint {
                command.requestedFlow >= 2.0 [L/min] and
                command.requestedFlow <= 80.0 [L/min]
            }

            constraint {
                command.requestedOxygenFraction >= 21.0 [%] and
                command.requestedOxygenFraction <= 100.0 [%]
            }

            constraint {
                command.requestedTemperature >= 31.0 [degC] and
                command.requestedTemperature <= 37.0 [degC]
            }
        }

        action displayAlarm {
            in item alarm : AlarmSignal;
        }
    }

    part def AlarmSubsystem {
        port alarmIn : AlarmPort;
        port alarmOut : AlarmPort;

        attribute audibleAlarmEnabled : Boolean = true;
        attribute visualAlarmEnabled : Boolean = true;
        attribute alarmVolume : Real;

        action annunciateAlarm {
            in item alarm : AlarmSignal;
            out item annunciatedAlarm : AlarmSignal;
        }
    }

    part def PowerSupply {
        port mainsPower : PowerPort;

        attribute inputVoltageMinimum : Real = 100.0;
        attribute inputVoltageMaximum : Real = 240.0;
        attribute outputPowerCapacity : ElectricalPower = 300.0 [W];

        action convertMainsPower {
            in attribute voltage : Real;
            out attribute availablePower : ElectricalPower;
        }
    }

    /* System Definition */

    part def HeatedHumidifiedHighFlowTherapyDevice {
        port ambientAirInput : GasInletPort;
        port oxygenInput : OxygenInletPort;
        port sterileWaterInput : WaterInletPort;
        port patientOutput : PatientInterfacePort;
        port clinicianCommandInput : CommandPort;
        port alarmOutput : AlarmPort;
        port electricalInput : PowerPort;

        part airIntake : AirIntakeSubsystem;
        part oxygenSupply : OxygenSupplySubsystem;
        part blender : GasBlender;
        part flowGenerator : FlowGenerator;
        part reservoir : WaterReservoir;
        part humidifier : HeatedHumidifierChamber;
        part breathingCircuit : HeatedBreathingCircuit;
        part cannula : NasalCannulaInterface;
        part sensors : SensorSuite;
        part controller : TherapyController;
        part userInterface : UserInterface;
        part alarms : AlarmSubsystem;
        part powerSupply : PowerSupply;

        attribute primaryFunction : String =
            "Deliver a clinician-set high flow of warmed, humidified respiratory gas with controlled oxygen concentration to a spontaneously breathing patient through a nasal cannula interface.";

        attribute nominalFlowRangeLow : FlowRate = 2.0 [L/min];
        attribute nominalFlowRangeHigh : FlowRate = 80.0 [L/min];
        attribute nominalTemperature : Temperature = 37.0 [degC];
        attribute oxygenControlRangeLow : OxygenFraction = 21.0 [%];
        attribute oxygenControlRangeHigh : OxygenFraction = 100.0 [%];

        connect ambientAirInput to airIntake.ambientAirIn;
        connect oxygenInput to oxygenSupply.oxygenIn;
        connect sterileWaterInput to reservoir.sterileWaterIn;
        connect sterileWaterInput to humidifier.waterIn;
        connect electricalInput to powerSupply.mainsPower;

        connect airIntake.filteredAirOut to blender.airIn;
        connect oxygenSupply.oxygenOut to blender.oxygenIn;
        connect blender.blendedGasOut to flowGenerator.blendedGasIn;
        connect flowGenerator.pressurizedGasOut to humidifier.gasIn;
        connect humidifier.humidifiedGasOut to breathingCircuit.humidifiedGasIn;
        connect breathingCircuit.patientGasOut to cannula.gasIn;
        connect cannula.gasIn to patientOutput;

        connect clinicianCommandInput to userInterface.commandOut;
        connect userInterface.commandOut to controller.commandIn;
        connect controller.blenderCommandOut to blender.commandIn;
        connect controller.flowCommandOut to flowGenerator.commandIn;
        connect controller.humidifierCommandOut to humidifier.commandIn;
        connect controller.circuitCommandOut to breathingCircuit.commandIn;

        connect humidifier.sensorOut to controller.sensorIn;
        connect breathingCircuit.sensorOut to controller.sensorIn;
        connect reservoir.waterStatusOut to controller.sensorIn;
        connect sensors.readingOut to controller.sensorIn;

        connect controller.alarmOut to alarms.alarmIn;
        connect alarms.alarmOut to userInterface.alarmIn;
        connect alarms.alarmOut to alarmOutput;

        perform action provideHeatedHumidifiedHighFlowTherapy {
            in item ambientAir : AmbientAir;
            in item oxygen : MedicalOxygen;
            in item sterileWater : SterileWater;
            in item command : ControlCommand;
            out item deliveredGas : HumidifiedHeatedGas;
            out item alarm : AlarmSignal;

            first airIntake.filterAmbientAir;
            then oxygenSupply.regulateOxygenPressure;
            then blender.blendAirAndOxygen;
            then flowGenerator.generateHighFlow;
            then humidifier.heatAndHumidifyGas;
            then breathingCircuit.maintainCircuitTemperature;
            then cannula.deliverGasToPatient;
            then sensors.measureTherapyGas;
            then controller.detectFaults;
        }
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall provide heated, humidified, high-flow respiratory therapy by delivering a prescribed flow of blended air and oxygen through a patient interface. */

        subject device : HeatedHumidifiedHighFlowTherapyDevice;

        require constraint {
            device.nominalFlowRangeLow == 2.0 [L/min] and
            device.nominalFlowRangeHigh == 80.0 [L/min]
        }
    }

    requirement def FlowDeliveryRequirement {
        subject gas : HumidifiedHeatedGas;
        attribute commandedFlow : FlowRate;

        require constraint {
            gas.totalFlow >= commandedFlow - 1.0 [L/min] and
            gas.totalFlow <= commandedFlow + 1.0 [L/min]
        }
    }

    requirement def OxygenConcentrationRequirement {
        subject gas : HumidifiedHeatedGas;
        attribute commandedOxygenFraction : OxygenFraction;

        require constraint {
            gas.oxygenFraction >= commandedOxygenFraction - 3.0 [%] and
            gas.oxygenFraction <= commandedOxygenFraction + 3.0 [%]
        }
    }

    requirement def HumidificationRequirement {
        subject gas : HumidifiedHeatedGas;

        require constraint {
            gas.relativeHumidity >= 95.0 [%]
        }
    }

    requirement def TemperatureRequirement {
        subject gas : HumidifiedHeatedGas;
        attribute targetTemperature : Temperature = 37.0 [degC];

        require constraint {
            gas.airwayTemperature >= 34.0 [degC] and
            gas.airwayTemperature <= 40.0 [degC]
        }
    }

    requirement def PressureSafetyRequirement {
        subject gas : HumidifiedHeatedGas;

        require constraint {
            gas.pressure <= 6.0 [kPa]
        }
    }

    requirement def LowWaterAlarmRequirement {
        subject reservoir : WaterReservoir;
        subject alarm : AlarmSignal;

        require constraint {
            reservoir.currentVolume < reservoir.lowWaterThreshold implies
            alarm.active == true
        }
    }

    requirement def OverPressureAlarmRequirement {
        subject reading : SensorReading;
        subject alarm : AlarmSignal;

        require constraint {
            reading.measuredPressure > 6.0 [kPa] implies
            alarm.active == true and alarm.severity == AlarmSeverity::Critical
        }
    }

    requirement def WarmupRequirement {
        subject device : HeatedHumidifiedHighFlowTherapyDevice;
        attribute maximumWarmupTime : TimeDuration = 180.0 [s];

        require constraint {
            device.controller.startupWarmupTime <= maximumWarmupTime
        }
    }

    requirement def ElectricalPowerRequirement {
        subject supply : PowerSupply;

        require constraint {
            supply.outputPowerCapacity >= 280.0 [W]
        }
    }

    /* System Instance */

    part hhHftSystem : HeatedHumidifiedHighFlowTherapyDevice {
        attribute primaryFunction =
            "Provide noninvasive respiratory support by conditioning and delivering high-flow blended gas that improves oxygen delivery, washes out anatomical dead space, and maintains airway comfort through heating and humidification.";

        part cannula {
            attribute size = "Adult medium nasal cannula";
            attribute maximumAppliedPressure = 6.0 [kPa];
        }

        part controller {
            attribute status = TherapyStatus::Standby;
            attribute requestedFlow = 40.0 [L/min];
            attribute requestedOxygenFraction = 35.0 [%];
            attribute requestedTemperature = 37.0 [degC];
        }

        part reservoir {
            attribute currentVolume = 500.0 [mL];
        }
    }

    satisfy PrimaryFunctionRequirement by hhHftSystem;
    satisfy WarmupRequirement by hhHftSystem;
    satisfy ElectricalPowerRequirement by hhHftSystem.powerSupply;
}