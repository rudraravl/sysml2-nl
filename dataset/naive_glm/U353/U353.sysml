package RespironicsTherapyDevice {

    // ============ Value Types ============
    value type Pressure { unit 'Pa'; }
    value type PressureCMH2O { unit 'cmH2O'; }
    value type FlowRate { unit 'm^3/s'; }
    value type FlowRateLPM { unit 'L/min'; }
    value type Temperature { unit 'K'; }
    value type TemperatureCelsius { unit 'degC'; }
    value type Volume { unit 'm^3'; }
    value type VolumeMilliliter { unit 'mL'; }
    value type Duration { unit 's'; }
    value type DurationHour { unit 'h'; }
    value type Power { unit 'W'; }
    value type Energy { unit 'J'; }
    value type EnergyWattHour { unit 'Wh'; }
    value type Frequency { unit '1/s'; }
    value type Dimensionless { unit '1'; }
    value type Boolean { unit '1'; }
    value type Percent { unit '%'; }

    // ============ Items ============
    item def Air {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        attribute humidity : Percent;
    }
    item def AmbientAir :> Air;
    item def FilteredAir :> Air;
    item def PressurizedAir :> Air;
    item def ConditionedAir :> Air;

    item def BreathSignal {
        attribute flowRate : FlowRate;
        attribute timestamp : Duration;
        attribute isInspiration : Boolean;
    }

    item def TherapyEvent {
        attribute type : String;
        attribute timestamp : Duration;
        attribute severity : Dimensionless;
    }

    // ============ Port Definitions ============
    port def AirInPort {
        in air : Air;
    }
    port def AirOutPort {
        out air : Air;
    }
    port def AirPassThroughPort {
        in inAir : Air;
        out outAir : Air;
    }
    port def ControlCmdPort {
        out command : Dimensionless;
    }
    port def ControlCmdInPort {
        in command : Dimensionless;
    }
    port def SensorDataPort {
        out measurement : Dimensionless;
    }
    port def SensorDataInPort {
        in measurement : Dimensionless;
    }
    port def AlarmSignalPort {
        out alarm : Dimensionless;
    }
    port def PowerOutPort {
        out power : Power;
    }
    port def PowerInPort {
        in power : Power;
    }
    port def DataIOPort {
        in rxData : Dimensionless;
        out txData : Dimensionless;
    }
    port def DisplayDataPort {
        out displayData : Dimensionless;
    }

    // ============ Enums ============
    enum def TherapyMode { CPAP; BiPAP; AutoPAP; }
    enum def AlarmPriority { Low; Medium; High; Critical; }
    enum def MaskType { Nasal; FullFace; NasalPillow; }

    // ============ Filter ============
    part def Filter {
        attribute replaceable : Boolean = true;
        attribute efficiency : Percent = 99.5;
        attribute replacementInterval : DurationHour = 1752;
        attribute airflowResistance : Dimensionless;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute inletAir : AmbientAir;
        attribute outletAir : FilteredAir;
        action def filterAir {
            in incoming : AmbientAir;
            out outgoing : FilteredAir;
        }
        perform action filterAir;
        flow through FilterFlow : Air from airIn.air to airOut.air;
    }

    // ============ Blower ============
    part def Blower {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port controlIn : ControlCmdInPort;
        attribute maxPressure : Pressure = 2000;
        attribute minPressure : Pressure = 200;
        attribute currentRPM : Frequency;
        attribute targetPressure : Pressure;
        attribute rampRate : Pressure;
        action def pressurize {
            in incoming : FilteredAir;
            out outgoing : PressurizedAir;
        }
        perform action pressurize;
        flow through BlowerFlow : Air from airIn.air to airOut.air;
    }

    // ============ Humidifier ============
    part def Humidifier {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port controlIn : ControlCmdInPort;
        attribute waterLevel : VolumeMilliliter;
        attribute maxWaterLevel : VolumeMilliliter = 300;
        attribute minWaterLevel : VolumeMilliliter = 20;
        attribute targetTemp : Temperature = 309.15;
        attribute currentTemp : Temperature;
        attribute heaterPower : Power;
        attribute enabled : Boolean = true;

        state machine def HumidifierStates {
            state Off;
            state HeatingUp;
            state MaintainingTemperature;
            state LowWaterAlert;
            transition offToHeating from Off to HeatingUp when enabled == true;
            transition heatingToMaintaining from HeatingUp to MaintainingTemperature when currentTemp >= targetTemp;
            transition maintainingToLowWater from MaintainingTemperature to LowWaterAlert when waterLevel < minWaterLevel;
            transition lowWaterToMaintaining from LowWaterAlert to MaintainingTemperature when waterLevel >= minWaterLevel;
            transition anyToOff from HeatingUp, MaintainingTemperature, LowWaterAlert to Off when enabled == false;
        }

        state machine : HumidifierStates;
        flow through HumidifierFlow : Air from airIn.air to airOut.air;
    }

    // ============ Patient Circuit ============
    part def PatientCircuit {
        attribute length : Real;
        attribute innerDiameter : Real;
        attribute heatedTube : Boolean = true;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        flow through CircuitFlow : Air from airIn.air to airOut.air;
    }

    // ============ Mask ============
    part def Mask {
        attribute maskType : MaskType = MaskType.Nasal;
        attribute cushionSize : String;
        attribute leakRate : FlowRate;
        port airIn : AirInPort;
        flow through MaskFlow : Air from airIn.air;
    }

    // ============ Sensors ============
    part def PressureSensor {
        port airPort : AirPassThroughPort;
        port dataOut : SensorDataPort;
        attribute measuredPressure : Pressure;
        attribute accuracy : Percent = 1.0;
        attribute samplingRate : Frequency = 100;
        action def measurePressure {
            out reading : Pressure;
        }
        perform action measurePressure;
    }

    part def FlowSensor {
        port airPort : AirPassThroughPort;
        port dataOut : SensorDataPort;
        attribute measuredFlow : FlowRate;
        attribute accuracy : Percent = 2.0;
        attribute samplingRate : Frequency = 100;
        action def measureFlow {
            out reading : FlowRate;
        }
        perform action measureFlow;
    }

    part def HumiditySensor {
        port airPort : AirPassThroughPort;
        port dataOut : SensorDataPort;
        attribute measuredHumidity : Percent;
        action def measureHumidity {
            out reading : Percent;
        }
        perform action measureHumidity;
    }

    part def TemperatureSensor {
        port airPort : AirPassThroughPort;
        port dataOut : SensorDataPort;
        attribute measuredTemp : Temperature;
        action def measureTemp {
            out reading : Temperature;
        }
        perform action measureTemp;
    }

    // ============ Therapy Controller ============
    part def TherapyController {
        port pressureCmd : ControlCmdPort;
        port humidifierCmd : ControlCmdPort;
        port sensorIn : SensorDataInPort;
        port uiIn : DataIOPort;
        port loggerCmd : DataIOPort;
        port alarmCmd : DataIOPort;
        attribute currentMode : TherapyMode = TherapyMode.CPAP;
        attribute prescribedCPAP : Pressure = 800;
        attribute prescribedIPAP : Pressure;
        attribute prescribedEPAP : Pressure;
        attribute minAutoPressure : Pressure = 400;
        attribute maxAutoPressure : Pressure = 1200;
        attribute rampDuration : Duration = 1200;
        attribute rampEnabled : Boolean = true;
        attribute currentTargetPressure : Pressure;
        attribute rampStart : Duration;
        attribute leakRate : FlowRate;
        attribute apneaDetected : Boolean;

        action def detectBreath {
            in flowSignal : BreathSignal;
            out breathDetected : Boolean;
        }

        action def computeTarget {
            in mode : TherapyMode;
            in flow : FlowRate;
            in pressure : Pressure;
            out target : Pressure;
        }

        state machine def ControllerStates {
            state Standby;
            state RampUp;
            state SteadyTherapy;
            state BreathingSync;
            transition standbyToRamp from Standby to RampUp when rampEnabled == true;
            transition rampToSteady from RampUp to SteadyTherapy when rampElapsed;
            transition steadyToSync from SteadyTherapy to BreathingSync when currentMode != TherapyMode.CPAP;
            transition syncToSteady from BreathingSync to SteadyTherapy when apneaDetected == false;
        }

        state machine : ControllerStates;
    }

    // ============ Alarm Manager ============
    part def AlarmManager {
        port sensorIn : SensorDataInPort;
        port controllerIn : DataIOPort;
        port alarmOut : AlarmSignalPort;
        port uiOut : DisplayDataPort;
        attribute highPressureThreshold : Pressure = 2200;
        attribute lowPressureThreshold : Pressure = 100;
        attribute apneaTimeout : Duration = 10;
        attribute disconnectionFlowThreshold : FlowRate = 0.001;
        attribute activeAlarmPriority : AlarmPriority;

        action def evaluateConditions {
            in pressure : Pressure;
            in flow : FlowRate;
            in apneaFlag : Boolean;
            out priority : AlarmPriority;
        }

        action def raiseAlarm {
            in priority : AlarmPriority;
            out signal : Dimensionless;
        }

        state machine def AlarmStates {
            state Normal;
            state Warning;
            state CriticalAlarm;
            state DisconnectionAlert;
            transition normalToWarning from Normal to Warning when pressure > highPressureThreshold * 0.9;
            transition normalToCritical from Normal to CriticalAlarm when pressure > highPressureThreshold;
            transition normalToDisconnection from Normal to DisconnectionAlert when flow < disconnectionFlowThreshold;
            transition warningToNormal from Warning to Normal when pressure <= highPressureThreshold * 0.9;
            transition criticalToNormal from CriticalAlarm to Normal when pressure < highPressureThreshold;
            transition disconnectionToNormal from DisconnectionAlert to Normal when flow >= disconnectionFlowThreshold;
        }

        state machine : AlarmStates;
    }

    // ============ User Interface ============
    part def UserInterface {
        port controllerIO : DataIOPort;
        port alarmIn : DataIOPort;
        port displayOut : DisplayDataPort;
        attribute screenType : String = "LCD";
        attribute backlight : Boolean;
        attribute menuState : String;
        attribute currentPressureDisplay : Pressure;
        attribute currentLeakDisplay : FlowRate;
        action def renderDisplay {
            in data : Dimensionless;
        }
        perform action renderDisplay;
    }

    // ============ Data Logger ============
    part def DataLogger {
        port controllerIO : DataIOPort;
        attribute storageCapacity : EnergyWattHour;
        attribute sessionHours : DurationHour;
        attribute recordedEvents : TherapyEvent;
        attribute usageHours : DurationHour;
        attribute recordedPressures : Pressure;
        action def logSession {
            in sessionData : Dimensionless;
        }
        perform action logSession;
        action def exportData {
            out exported : Dimensionless;
        }
    }

    // ============ Power Management ============
    part def PowerManagement {
        port acIn : PowerInPort;
        port powerOut : PowerOutPort;
        attribute inputVoltage : Real;
        attribute outputVoltage : Real;
        attribute batteryConnected : Boolean = true;
        attribute onBattery : Boolean = false;
        action def switchToBattery {
        }
        action def switchToAC {
        }
        state machine def PowerStates {
            state ACMode;
            state BatteryMode;
            transition acToBattery from ACMode to BatteryMode when acPowerLost;
            transition batteryToAC from BatteryMode to ACMode when acPowerRestored;
        }
        state machine : PowerStates;
    }

    part def BackupBattery {
        port powerOut : PowerOutPort;
        attribute capacity : EnergyWattHour = 100;
        attribute minRuntime : DurationHour = 3;
        attribute chargeLevel : Percent = 100;
        attribute outputPower : Power;
        action def discharge {
            out power : Power;
        }
    }

    part def ACAdapter {
        port powerOut : PowerOutPort;
        attribute inputVoltage : Real = 120;
        attribute outputVoltage : Real = 24;
        attribute ratedPower : Power = 100;
    }

    // ============ Top-level Device ============
    part def RespironicsTherapyDevice {
        attribute deviceModel : String = "Philips Respironics";
        attribute serialNumber : String;
        attribute firmwareVersion : String;

        part filter : Filter;
        part blower : Blower;
        part humidifier : Humidifier;
        part patientCircuit : PatientCircuit;
        part mask : Mask;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part humiditySensor : HumiditySensor;
        part tempSensor : TemperatureSensor;
        part therapyController : TherapyController;
        part alarmManager : AlarmManager;
        part userInterface : UserInterface;
        part dataLogger : DataLogger;
        part powerManagement : PowerManagement;
        part backupBattery : BackupBattery;
        part acAdapter : ACAdapter;

        // Pneumatic connections
        connect filter.airOut to blower.airIn;
        connect blower.airOut to pressureSensor.airPort;
        connect pressureSensor.airPort to humidifier.airIn;
        connect humidifier.airOut to flowSensor.airPort;
        connect flowSensor.airPort to patientCircuit.airIn;
        connect patientCircuit.airOut to mask.airIn;

        // Sensor connections to controller
        connect pressureSensor.dataOut to therapyController.sensorIn;
        connect flowSensor.dataOut to therapyController.sensorIn;
        connect humiditySensor.dataOut to therapyController.sensorIn;
        connect tempSensor.dataOut to therapyController.sensorIn;

        // Control connections
        connect therapyController.pressureCmd to blower.controlIn;
        connect therapyController.humidifierCmd to humidifier.controlIn;

        // Alarm connections
        connect therapyController.alarmCmd to alarmManager.controllerIn;
        connect alarmManager.alarmOut to userInterface.alarmIn;
        connect alarmManager.uiOut to userInterface.displayOut;

        // UI and logger
        connect userInterface.controllerIO to therapyController.uiIn;
        connect therapyController.loggerCmd to dataLogger.controllerIO;

        // Power connections
        connect acAdapter.powerOut to powerManagement.acIn;
        connect backupBattery.powerOut to powerManagement.acIn;
        connect powerManagement.powerOut to blower.controlIn;
    }

    // ============ Requirements ============
    requirement def RespiratoryTherapyRequirement {
        subject device : RespironicsTherapyDevice;
        doc
        /* The device shall deliver pressurized, humidified air to a patient for treatment of sleep apnea. */
    }

    requirement def AirFiltrationRequirement {
        doc
        /* The device shall draw ambient air through a replaceable filter before pressurization. */
        subject device : RespironicsTherapyDevice;
        constraint { device.filter.replaceable == true; }
    }

    requirement def PressurizationRequirement {
        doc
        /* The blower shall pressurize air to the prescribed therapy pressure within operating range. */
        subject device : RespironicsTherapyDevice;
        constraint { device.blower.maxPressure >= 2000; }
        constraint { device.blower.minPressure <= 200; }
    }

    requirement def HumidificationRequirement {
        doc
        /* The humidifier shall heat and humidify delivered air and alert on low water. */
        subject device : RespironicsTherapyDevice;
        constraint { device.humidifier.minWaterLevel >= 20; }
    }

    requirement def TherapyModesRequirement {
        doc
        /* The controller shall support CPAP, BiPAP, and AutoPAP therapy modes. */
        subject device : RespironicsTherapyDevice;
        constraint { device.therapyController.currentMode in TherapyMode::*; }
    }

    requirement def BreathSyncRequirement {
        doc
        /* The controller shall detect patient breaths to synchronize pressure changes for BiPAP and AutoPAP. */
        subject device : RespironicsTherapyDevice;
    }

    requirement def RampRequirement {
        doc
        /* The controller shall ramp pressure gradually at therapy start to aid sleep onset. */
        subject device : RespironicsTherapyDevice;
        constraint { device.therapyController.rampDuration >= 600; }
    }

    requirement def AlarmRequirement {
        doc
        /* The alarm manager shall detect high/low pressure, disconnection, and apnea, raising prioritized alarms. */
        subject device : RespironicsTherapyDevice;
        constraint { device.alarmManager.highPressureThreshold <= 2200; }
        constraint { device.alarmManager.lowPressureThreshold >= 100; }
        constraint { device.alarmManager.apneaTimeout <= 10; }
    }

    requirement def BackupPowerRequirement {
        doc
        /* The backup battery shall sustain therapy for at least three hours during a power outage. */
        subject device : RespironicsTherapyDevice;
        constraint { device.backupBattery.minRuntime >= 3; }
    }

    requirement def DataLoggingRequirement {
        doc
        /* The data logger shall record session usage hours, pressure levels, and detected events. */
        subject device : RespironicsTherapyDevice;
    }

    requirement def UIDisplayRequirement {
        doc
        /* The user interface shall display therapy parameters and real-time pressure and leak rate. */
        subject device : RespironicsTherapyDevice;
    }

    requirement RespiratoryTherapy :> RespiratoryTherapyRequirement;
    requirement AirFiltration :> AirFiltrationRequirement;
    requirement Pressurization :> PressurizationRequirement;
    requirement Humidification :> HumidificationRequirement;
    requirement TherapyModes :> TherapyModesRequirement;
    requirement BreathSync :> BreathSyncRequirement;
    requirement RampSupport :> RampRequirement;
    requirement Alarms :> AlarmRequirement;
    requirement BackupPower :> BackupPowerRequirement;
    requirement Logging :> DataLoggingRequirement;
    requirement Display :> UIDisplayRequirement;

    satisfaction satisfyAirFiltration by RespironicsTherapyDevice::filter satisfies AirFiltration;
    satisfaction satisfyPressurization by RespironicsTherapyDevice::blower satisfies Pressurization;
    satisfaction satisfyHumidification by RespironicsTherapyDevice::humidifier satisfies Humidification;
    satisfaction satisfyTherapyModes by RespironicsTherapyDevice::therapyController satisfies TherapyModes;
    satisfaction satisfyBreathSync by RespironicsTherapyDevice::therapyController satisfies BreathSync;
    satisfaction satisfyRamp by RespironicsTherapyDevice::therapyController satisfies RampSupport;
    satisfaction satisfyAlarms by RespironicsTherapyDevice::alarmManager satisfies Alarms;
    satisfaction satisfyBackup by RespironicsTherapyDevice::backupBattery satisfies BackupPower;
    satisfaction satisfyLogging by RespironicsTherapyDevice::dataLogger satisfies Logging;
    satisfaction satisfyDisplay by RespironicsTherapyDevice::userInterface satisfies Display;
}
