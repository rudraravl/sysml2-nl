package ArtificialHeartSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "mmHg";
    }

    attribute def FlowRate {
        :> scalarValues::Real;
        unit = "L/min";
    }

    attribute def Volume {
        :> scalarValues::Real;
        unit = "mL";
    }

    attribute def Frequency {
        :> scalarValues::Real;
        unit = "beats/min";
    }

    attribute def ElectricalPotential {
        :> scalarValues::Real;
        unit = "V";
    }

    attribute def ElectricalCurrent {
        :> scalarValues::Real;
        unit = "A";
    }

    attribute def Power {
        :> scalarValues::Real;
        unit = "W";
    }

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def OxygenSaturation {
        :> scalarValues::Real;
        unit = "%";
    }

    attribute def TimeDuration {
        :> scalarValues::Real;
        unit = "s";
    }

    item def Blood {
        attribute oxygenSaturation : OxygenSaturation;
        attribute hematocrit : scalarValues::Real;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricalPotential;
        attribute current : ElectricalCurrent;
        attribute availablePower : Power;
    }

    item def ControlCommand {
        attribute requestedPumpRate : Frequency;
        attribute requestedFlowRate : FlowRate;
        attribute leftPumpSpeedCommand : scalarValues::Real;
        attribute rightPumpSpeedCommand : scalarValues::Real;
    }

    item def PhysiologicalTelemetry {
        attribute leftAtrialPressure : Pressure;
        attribute rightAtrialPressure : Pressure;
        attribute aorticPressure : Pressure;
        attribute pulmonaryArteryPressure : Pressure;
        attribute systemicFlow : FlowRate;
        attribute pulmonaryFlow : FlowRate;
        attribute pumpRate : Frequency;
        attribute deviceTemperature : Temperature;
        attribute batteryPowerRemaining : scalarValues::Real;
    }

    item def AlarmSignal {
        attribute severity : AlarmSeverity;
        attribute messageCode : scalarValues::String;
        attribute timeActive : TimeDuration;
    }

    enum def AlarmSeverity {
        enum normal;
        enum advisory;
        enum warning;
        enum critical;
    }

    enum def PumpMode {
        enum standby;
        enum startup;
        enum normalAssist;
        enum highDemand;
        enum lowPower;
        enum faultResponse;
        enum safeShutdown;
    }

    port def BloodInletPort {
        in item incomingBlood : Blood;
    }

    port def BloodOutletPort {
        out item outgoingBlood : Blood;
    }

    port def EnergyInputPort {
        in item energyIn : ElectricalEnergy;
    }

    port def EnergyOutputPort {
        out item energyOut : ElectricalEnergy;
    }

    port def CommandInputPort {
        in item commandIn : ControlCommand;
    }

    port def TelemetryOutputPort {
        out item telemetryOut : PhysiologicalTelemetry;
    }

    port def AlarmOutputPort {
        out item alarmOut : AlarmSignal;
    }

    port def SensorDataPort {
        out item telemetry : PhysiologicalTelemetry;
    }

    port def ActuatorCommandPort {
        in item command : ControlCommand;
    }

    part def ArtificialHeart {
        attribute nominalSystemicFlow : FlowRate = 5.0;
        attribute maximumSystemicFlow : FlowRate = 9.5;
        attribute minimumSystemicFlow : FlowRate = 2.0;
        attribute nominalPumpRate : Frequency = 75.0;
        attribute maximumPumpRate : Frequency = 160.0;
        attribute nominalPowerConsumption : Power = 14.0;
        attribute maximumDeviceTemperature : Temperature = 42.0;

        port venaCavaInlet : BloodInletPort;
        port pulmonaryVeinInlet : BloodInletPort;
        port pulmonaryArteryOutlet : BloodOutletPort;
        port aortaOutlet : BloodOutletPort;
        port externalPowerInput : EnergyInputPort;
        port implantBatteryInput : EnergyInputPort;
        port clinicianCommandInput : CommandInputPort;
        port telemetryOutput : TelemetryOutputPort;
        port alarmOutput : AlarmOutputPort;

        part rightPump : VentricularPump {
            attribute chamberRole = "Right ventricular replacement";
            attribute nominalOutletPressure = 25.0;
            attribute maximumOutletPressure = 45.0;
        }

        part leftPump : VentricularPump {
            attribute chamberRole = "Left ventricular replacement";
            attribute nominalOutletPressure = 100.0;
            attribute maximumOutletPressure = 140.0;
        }

        part inflowManifold : BloodManifold {
            attribute containedVolume = 65.0;
        }

        part outflowManifold : BloodManifold {
            attribute containedVolume = 80.0;
        }

        part controller : PhysiologicalController;

        part sensorSuite : HemodynamicSensorSuite;

        part powerSubsystem : PowerSubsystem;

        part thermalManager : ThermalManager;

        part alarmManager : AlarmManager;

        connect venaCavaInlet to inflowManifold.systemicVenousInlet;
        connect pulmonaryVeinInlet to inflowManifold.pulmonaryVenousInlet;
        connect inflowManifold.rightPumpFeed to rightPump.inlet;
        connect inflowManifold.leftPumpFeed to leftPump.inlet;
        connect rightPump.outlet to outflowManifold.pulmonaryOutletFeed;
        connect leftPump.outlet to outflowManifold.systemicOutletFeed;
        connect outflowManifold.pulmonaryArteryOutlet to pulmonaryArteryOutlet;
        connect outflowManifold.aortaOutlet to aortaOutlet;

        connect externalPowerInput to powerSubsystem.externalPowerInput;
        connect implantBatteryInput to powerSubsystem.batteryPowerInput;
        connect powerSubsystem.conditionedPowerOutput to controller.powerInput;
        connect powerSubsystem.conditionedPowerOutput to rightPump.powerInput;
        connect powerSubsystem.conditionedPowerOutput to leftPump.powerInput;
        connect powerSubsystem.conditionedPowerOutput to sensorSuite.powerInput;
        connect powerSubsystem.conditionedPowerOutput to thermalManager.powerInput;

        connect clinicianCommandInput to controller.clinicianCommandInput;
        connect sensorSuite.sensorTelemetryOutput to controller.sensorTelemetryInput;
        connect controller.rightPumpCommandOutput to rightPump.commandInput;
        connect controller.leftPumpCommandOutput to leftPump.commandInput;
        connect controller.telemetryOutput to telemetryOutput;
        connect controller.alarmRequestOutput to alarmManager.alarmInput;
        connect thermalManager.thermalTelemetryOutput to controller.thermalTelemetryInput;
        connect powerSubsystem.powerTelemetryOutput to controller.powerTelemetryInput;
        connect alarmManager.alarmOutput to alarmOutput;
    }

    part def VentricularPump {
        attribute chamberRole : scalarValues::String;
        attribute strokeVolume : Volume = 70.0;
        attribute nominalOutletPressure : Pressure;
        attribute maximumOutletPressure : Pressure;
        attribute actualFlowRate : FlowRate;
        attribute actualPumpRate : Frequency;
        attribute motorTemperature : Temperature;
        attribute powerDraw : Power;

        port inlet : BloodInletPort;
        port outlet : BloodOutletPort;
        port powerInput : EnergyInputPort;
        port commandInput : ActuatorCommandPort;

        part bloodChamber : BloodCompatibleChamber {
            attribute primingVolume = 85.0;
        }

        part impellerMotor : BrushlessMotor {
            attribute nominalVoltage = 24.0;
            attribute peakPower = 28.0;
        }

        part oneWayInletValve : MechanicalValve {
            attribute crackingPressure = 2.0;
        }

        part oneWayOutletValve : MechanicalValve {
            attribute crackingPressure = 4.0;
        }

        perform action pumpBlood;
    }

    part def BloodCompatibleChamber {
        attribute primingVolume : Volume;
        attribute surfaceRoughness : scalarValues::Real;
        attribute thromboresistantCoatingPresent : scalarValues::Boolean = true;
    }

    part def BrushlessMotor {
        attribute nominalVoltage : ElectricalPotential;
        attribute peakPower : Power;
        attribute rotationalSpeed : scalarValues::Real;
        attribute windingTemperature : Temperature;
    }

    part def MechanicalValve {
        attribute crackingPressure : Pressure;
        attribute regurgitantFraction : scalarValues::Real = 0.01;
        attribute openState : scalarValues::Boolean;
    }

    part def BloodManifold {
        attribute containedVolume : Volume;

        port systemicVenousInlet : BloodInletPort;
        port pulmonaryVenousInlet : BloodInletPort;
        port rightPumpFeed : BloodOutletPort;
        port leftPumpFeed : BloodOutletPort;
        port pulmonaryOutletFeed : BloodInletPort;
        port systemicOutletFeed : BloodInletPort;
        port pulmonaryArteryOutlet : BloodOutletPort;
        port aortaOutlet : BloodOutletPort;
    }

    part def HemodynamicSensorSuite {
        attribute samplePeriod : TimeDuration = 0.02;

        port powerInput : EnergyInputPort;
        port sensorTelemetryOutput : SensorDataPort;

        part leftAtrialPressureSensor : PressureSensor {
            attribute measurementRangeLow = 0.0;
            attribute measurementRangeHigh = 40.0;
        }

        part rightAtrialPressureSensor : PressureSensor {
            attribute measurementRangeLow = 0.0;
            attribute measurementRangeHigh = 30.0;
        }

        part aorticPressureSensor : PressureSensor {
            attribute measurementRangeLow = 40.0;
            attribute measurementRangeHigh = 180.0;
        }

        part pulmonaryPressureSensor : PressureSensor {
            attribute measurementRangeLow = 5.0;
            attribute measurementRangeHigh = 60.0;
        }

        part systemicFlowSensor : FlowSensor {
            attribute measurementRangeHigh = 10.0;
        }

        part pulmonaryFlowSensor : FlowSensor {
            attribute measurementRangeHigh = 10.0;
        }
    }

    part def PressureSensor {
        attribute measurementRangeLow : Pressure;
        attribute measurementRangeHigh : Pressure;
        attribute accuracy : Pressure = 1.0;
    }

    part def FlowSensor {
        attribute measurementRangeLow : FlowRate = 0.0;
        attribute measurementRangeHigh : FlowRate;
        attribute accuracy : FlowRate = 0.2;
    }

    part def PhysiologicalController {
        attribute currentMode : PumpMode;
        attribute targetSystemicFlow : FlowRate = 5.0;
        attribute targetPulmonaryFlow : FlowRate = 5.0;
        attribute targetPumpRate : Frequency = 75.0;
        attribute minimumMeanAorticPressure : Pressure = 65.0;
        attribute maximumMeanAorticPressure : Pressure = 120.0;
        attribute controlLoopPeriod : TimeDuration = 0.02;

        port powerInput : EnergyInputPort;
        port clinicianCommandInput : CommandInputPort;
        port sensorTelemetryInput : SensorDataPort;
        port thermalTelemetryInput : SensorDataPort;
        port powerTelemetryInput : SensorDataPort;
        port rightPumpCommandOutput : ActuatorCommandPort;
        port leftPumpCommandOutput : ActuatorCommandPort;
        port telemetryOutput : TelemetryOutputPort;
        port alarmRequestOutput : AlarmOutputPort;

        perform action regulateCirculation;

        state def OperatingStateMachine {
            state standby;
            state startup;
            state normalAssist;
            state highDemand;
            state lowPower;
            state faultResponse;
            state safeShutdown;

            transition first standby;

            transition standby_to_startup
                first standby
                then startup
                accept ControlCommand
                if clinicianCommandInput.commandIn.requestedPumpRate > 0.0;

            transition startup_to_normal
                first startup
                then normalAssist
                if sensorTelemetryInput.telemetry.systemicFlow >= 2.0;

            transition normal_to_highDemand
                first normalAssist
                then highDemand
                if sensorTelemetryInput.telemetry.systemicFlow < targetSystemicFlow and sensorTelemetryInput.telemetry.aorticPressure < maximumMeanAorticPressure;

            transition highDemand_to_normal
                first highDemand
                then normalAssist
                if sensorTelemetryInput.telemetry.systemicFlow >= targetSystemicFlow;

            transition normal_to_lowPower
                first normalAssist
                then lowPower
                if powerTelemetryInput.telemetry.batteryPowerRemaining < 20.0;

            transition lowPower_to_normal
                first lowPower
                then normalAssist
                if powerTelemetryInput.telemetry.batteryPowerRemaining >= 35.0;

            transition any_to_fault
                first normalAssist
                then faultResponse
                if sensorTelemetryInput.telemetry.deviceTemperature > 42.0;

            transition fault_to_shutdown
                first faultResponse
                then safeShutdown
                if sensorTelemetryInput.telemetry.systemicFlow < 1.0;
        }
    }

    part def PowerSubsystem {
        attribute externalVoltage : ElectricalPotential = 24.0;
        attribute batteryVoltage : ElectricalPotential = 22.2;
        attribute batteryCapacityPercent : scalarValues::Real = 100.0;
        attribute maximumContinuousPower : Power = 60.0;

        port externalPowerInput : EnergyInputPort;
        port batteryPowerInput : EnergyInputPort;
        port conditionedPowerOutput : EnergyOutputPort;
        port powerTelemetryOutput : SensorDataPort;

        part powerConditioner : PowerConditioner;
        part implantBattery : RechargeableBattery;
    }

    part def PowerConditioner {
        attribute outputVoltage : ElectricalPotential = 24.0;
        attribute conversionEfficiency : scalarValues::Real = 0.92;
        attribute maximumOutputPower : Power = 60.0;
    }

    part def RechargeableBattery {
        attribute storedEnergyPercent : scalarValues::Real = 100.0;
        attribute nominalRuntime : TimeDuration = 3600.0;
        attribute rechargeCycleCount : scalarValues::Integer;
    }

    part def ThermalManager {
        attribute nominalDeviceTemperature : Temperature = 37.0;
        attribute maximumAllowedTemperature : Temperature = 42.0;

        port powerInput : EnergyInputPort;
        port thermalTelemetryOutput : SensorDataPort;

        part heatSpreader : HeatSpreader;
    }

    part def HeatSpreader {
        attribute thermalResistance : scalarValues::Real = 1.4;
        attribute heatDissipationCapacity : Power = 20.0;
    }

    part def AlarmManager {
        attribute activeSeverity : AlarmSeverity = AlarmSeverity::normal;

        port alarmInput : AlarmOutputPort;
        port alarmOutput : AlarmOutputPort;

        perform action classifyAlarm;
    }

    action def PumpBlood {
        in item venousBlood : Blood;
        in targetRate : Frequency;
        out item arterialBlood : Blood;
        out deliveredFlow : FlowRate;

        objective {
            doc /* Move blood from venous inlet to arterial outlet while maintaining commanded rate and pressure. */
        }
    }

    action def RegulateCirculation {
        in item measuredTelemetry : PhysiologicalTelemetry;
        in item clinicianCommand : ControlCommand;
        out item rightPumpCommand : ControlCommand;
        out item leftPumpCommand : ControlCommand;
        out item reportedTelemetry : PhysiologicalTelemetry;

        objective {
            doc /* Adjust left and right pump output to maintain systemic and pulmonary blood flow for organ perfusion. */
        }
    }

    action def ClassifyAlarm {
        in item telemetry : PhysiologicalTelemetry;
        out item alarm : AlarmSignal;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The artificial heart shall replace the pumping function of failed native ventricles by receiving venous blood and delivering regulated blood flow to the pulmonary artery and aorta. */
    }

    requirement def SystemicPerfusionRequirement {
        doc /* The artificial heart shall provide systemic blood flow between 2.0 L/min and 9.5 L/min with a nominal adult operating target of 5.0 L/min. */
    }

    requirement def PulmonaryPerfusionRequirement {
        doc /* The artificial heart shall provide pulmonary blood flow balanced with systemic blood flow to avoid sustained pulmonary congestion or systemic venous congestion. */
    }

    requirement def PressureControlRequirement {
        doc /* The controller shall regulate pump output to maintain mean aortic pressure from 65 mmHg to 120 mmHg during normal assist mode. */
    }

    requirement def PowerContinuityRequirement {
        doc /* The power subsystem shall provide conditioned electrical power to pumps, controller, sensors, and thermal management during external power and implant battery operation. */
    }

    requirement def ThermalSafetyRequirement {
        doc /* The device shall issue a critical alarm and enter fault response if measured device temperature exceeds 42 degC. */
    }

    requirement def TelemetryRequirement {
        doc /* The artificial heart shall report pressure, flow, pump rate, device temperature, and battery state telemetry to external clinical monitoring equipment. */
    }

    requirement def AlarmRequirement {
        doc /* The artificial heart shall generate advisory, warning, or critical alarm signals for abnormal flow, abnormal pressure, low battery, overheating, and pump fault conditions. */
    }

    requirement def BloodCompatibilityRequirement {
        doc /* Blood-contacting chambers, manifolds, and valves shall use smooth thromboresistant surfaces to reduce hemolysis and clot formation during continuous operation. */
    }

    part artificialHeartSystem : ArtificialHeart;

    satisfy PrimaryFunctionRequirement by artificialHeartSystem;
    satisfy SystemicPerfusionRequirement by artificialHeartSystem.leftPump;
    satisfy PulmonaryPerfusionRequirement by artificialHeartSystem.rightPump;
    satisfy PressureControlRequirement by artificialHeartSystem.controller;
    satisfy PowerContinuityRequirement by artificialHeartSystem.powerSubsystem;
    satisfy ThermalSafetyRequirement by artificialHeartSystem.thermalManager;
    satisfy TelemetryRequirement by artificialHeartSystem.sensorSuite;
    satisfy AlarmRequirement by artificialHeartSystem.alarmManager;
    satisfy BloodCompatibilityRequirement by artificialHeartSystem.inflowManifold;
    satisfy BloodCompatibilityRequirement by artificialHeartSystem.outflowManifold;
    satisfy BloodCompatibilityRequirement by artificialHeartSystem.leftPump.bloodChamber;
    satisfy BloodCompatibilityRequirement by artificialHeartSystem.rightPump.bloodChamber;
}