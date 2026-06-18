package DepthGaugeSystemModel {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def Meter :> Real {
        doc "Length value in meters.";
    }

    attribute def Millimeter :> Real {
        doc "Length value in millimeters.";
    }

    attribute def Kilopascal :> Real {
        doc "Pressure value in kilopascals.";
    }

    attribute def Pascal :> Real {
        doc "Pressure value in pascals.";
    }

    attribute def KilogramPerCubicMeter :> Real {
        doc "Density value in kilograms per cubic meter.";
    }

    attribute def MeterPerSecondSquared :> Real {
        doc "Acceleration value in meters per second squared.";
    }

    attribute def Celsius :> Real {
        doc "Temperature value in degrees Celsius.";
    }

    attribute def Volt :> Real {
        doc "Electrical potential value in volts.";
    }

    attribute def Milliampere :> Real {
        doc "Electrical current value in milliamperes.";
    }

    attribute def Percent :> Real {
        doc "Percentage value from 0 to 100.";
    }

    attribute def Second :> Real {
        doc "Time value in seconds.";
    }

    attribute def Hertz :> Real {
        doc "Frequency value in cycles per second.";
    }

    attribute def CandelaPerSquareMeter :> Real {
        doc "Display luminance value in candelas per square meter.";
    }

    enum def GaugeMode {
        enum surface;
        enum measuring;
        enum hold;
        enum calibrating;
        enum alarm;
        enum fault;
    }

    enum def AlarmLevel {
        enum none;
        enum advisory;
        enum warning;
        enum critical;
    }

    enum def SensorHealth {
        enum unknown;
        enum healthy;
        enum degraded;
        enum failed;
    }

    item def AmbientWater {
        attribute staticPressure : Kilopascal;
        attribute temperature : Celsius;
        attribute density : KilogramPerCubicMeter;
    }

    item def PressureSample {
        attribute absolutePressure : Kilopascal;
        attribute temperature : Celsius;
        attribute sampleTime : Second;
        attribute sensorHealth : SensorHealth;
    }

    item def ConditionedPressure {
        attribute compensatedPressure : Kilopascal;
        attribute atmosphericReferencePressure : Kilopascal;
        attribute fluidDensity : KilogramPerCubicMeter;
        attribute gravity : MeterPerSecondSquared;
        attribute compensationTemperature : Celsius;
        attribute sampleTime : Second;
        attribute valid : Boolean;
    }

    item def DepthEstimate {
        attribute depth : Meter;
        attribute resolution : Millimeter;
        attribute accuracy : Millimeter;
        attribute updateTime : Second;
        attribute valid : Boolean;
    }

    item def DisplayMessage {
        attribute indicatedDepth : Meter;
        attribute mode : GaugeMode;
        attribute alarmLevel : AlarmLevel;
        attribute valid : Boolean;
        attribute text : String;
    }

    item def UserCommand {
        attribute powerButtonPressed : Boolean;
        attribute zeroButtonPressed : Boolean;
        attribute holdButtonPressed : Boolean;
        attribute calibrationButtonPressed : Boolean;
    }

    item def PowerEnergy {
        attribute supplyVoltage : Volt;
        attribute loadCurrent : Milliampere;
        attribute batteryStateOfCharge : Percent;
    }

    item def DiagnosticReport {
        attribute pressureSensorHealth : SensorHealth;
        attribute batteryStateOfCharge : Percent;
        attribute displayOperational : Boolean;
        attribute processorOperational : Boolean;
        attribute activeAlarm : AlarmLevel;
        attribute message : String;
    }

    port def WaterPressurePort {
        in item water : AmbientWater;
    }

    port def PressureSignalPort {
        out item pressureSample : PressureSample;
    }

    port def ConditionedPressurePort {
        in item rawPressure : PressureSample;
        out item conditionedPressure : ConditionedPressure;
    }

    port def ComputedDepthPort {
        in item conditionedPressure : ConditionedPressure;
        out item depthEstimate : DepthEstimate;
    }

    port def DisplayDataPort {
        in item displayMessage : DisplayMessage;
    }

    port def UserInterfacePort {
        in item command : UserCommand;
        out item displayMessage : DisplayMessage;
    }

    port def PowerPort {
        inout item power : PowerEnergy;
    }

    port def DiagnosticPort {
        out item diagnostic : DiagnosticReport;
    }

    constraint def HydrostaticDepthConversion {
        in absolutePressure : Kilopascal;
        in atmosphericReferencePressure : Kilopascal;
        in fluidDensity : KilogramPerCubicMeter;
        in gravity : MeterPerSecondSquared;
        out depth : Meter;

        constraint equation {
            depth == ((absolutePressure - atmosphericReferencePressure) * 1000.0) / (fluidDensity * gravity);
        }
    }

    constraint def DepthRangeLimit {
        in depth : Meter;

        constraint range {
            depth >= 0.0 and depth <= 120.0;
        }
    }

    constraint def AccuracyLimit {
        in error : Millimeter;

        constraint accuracy {
            error >= -50.0 and error <= 50.0;
        }
    }

    constraint def UpdateRateLimit {
        in updateRate : Hertz;

        constraint rate {
            updateRate >= 2.0;
        }
    }

    action def SenseAmbientPressure {
        in item water : AmbientWater;
        out item pressureSample : PressureSample;

        attribute conversionGain : Real = 1.0;
        attribute offsetPressure : Kilopascal = 0.0;
        attribute sensorStatus : SensorHealth = SensorHealth::healthy;
    }

    action def ConditionPressureSignal {
        in item rawPressure : PressureSample;
        out item conditionedPressure : ConditionedPressure;

        attribute filterTimeConstant : Second = 0.25;
        attribute defaultAtmosphericReferencePressure : Kilopascal = 101.325;
        attribute defaultWaterDensity : KilogramPerCubicMeter = 997.0;
        attribute standardGravity : MeterPerSecondSquared = 9.80665;
    }

    action def ComputeDepthFromPressure {
        in item conditionedPressure : ConditionedPressure;
        out item depthEstimate : DepthEstimate;

        attribute depthResolution : Millimeter = 1.0;
        attribute maximumDepth : Meter = 120.0;
        attribute nominalAccuracy : Millimeter = 25.0;

        constraint conversion : HydrostaticDepthConversion {
            absolutePressure = conditionedPressure.compensatedPressure;
            atmosphericReferencePressure = conditionedPressure.atmosphericReferencePressure;
            fluidDensity = conditionedPressure.fluidDensity;
            gravity = conditionedPressure.gravity;
            depth = depthEstimate.depth;
        }

        constraint range : DepthRangeLimit {
            depth = depthEstimate.depth;
        }
    }

    action def EvaluateAlarms {
        in item depthEstimate : DepthEstimate;
        out attribute alarmLevel : AlarmLevel;

        attribute advisoryDepthThreshold : Meter = 40.0;
        attribute warningDepthThreshold : Meter = 80.0;
        attribute criticalDepthThreshold : Meter = 110.0;
    }

    action def FormatDepthDisplay {
        in item depthEstimate : DepthEstimate;
        in attribute alarmLevel : AlarmLevel;
        in attribute activeMode : GaugeMode;
        out item displayMessage : DisplayMessage;

        attribute displayPrecision : Millimeter = 1.0;
    }

    action def RunSelfDiagnostics {
        in item power : PowerEnergy;
        out item diagnostic : DiagnosticReport;

        attribute minimumOperatingVoltage : Volt = 3.0;
        attribute lowBatteryThreshold : Percent = 15.0;
    }

    action def PrimaryDepthGaugeFunction {
        doc "Primary high-level function: accept surrounding water pressure, compensate it for reference pressure and fluid properties, convert it into a depth estimate, and present the resulting depth to the user with validity and alarm status.";

        in item ambientWater : AmbientWater;
        in item userCommand : UserCommand;
        inout item power : PowerEnergy;
        out item indicatedDepth : DepthEstimate;
        out item displayedDepth : DisplayMessage;
        out item diagnostic : DiagnosticReport;

        action sense : SenseAmbientPressure {
            in item water = ambientWater;
        }

        action condition : ConditionPressureSignal {
            in item rawPressure = sense.pressureSample;
        }

        action compute : ComputeDepthFromPressure {
            in item conditionedPressure = condition.conditionedPressure;
            out item depthEstimate = indicatedDepth;
        }

        action alarmCheck : EvaluateAlarms {
            in item depthEstimate = compute.depthEstimate;
        }

        action format : FormatDepthDisplay {
            in item depthEstimate = compute.depthEstimate;
            in attribute alarmLevel = alarmCheck.alarmLevel;
            in attribute activeMode = GaugeMode::measuring;
            out item displayMessage = displayedDepth;
        }

        action diagnostics : RunSelfDiagnostics {
            in item power = power;
            out item diagnostic = diagnostic;
        }

        succession sense then condition;
        succession condition then compute;
        succession compute then alarmCheck;
        succession alarmCheck then format;
        succession format then diagnostics;
    }

    state def DepthGaugeOperatingStateMachine {
        attribute mode : GaugeMode;

        state off;
        state startup;
        state surfaceZero;
        state measuring;
        state hold;
        state calibrating;
        state alarm;
        state fault;

        entry; then off;

        transition powerOn
            first off
            then startup
            accept UserCommand
            if powerButtonPressed;

        transition startupComplete
            first startup
            then surfaceZero;

        transition zeroAccepted
            first surfaceZero
            then measuring
            accept UserCommand
            if zeroButtonPressed;

        transition beginMeasureWithoutZero
            first surfaceZero
            then measuring;

        transition enterHold
            first measuring
            then hold
            accept UserCommand
            if holdButtonPressed;

        transition leaveHold
            first hold
            then measuring
            accept UserCommand
            if holdButtonPressed;

        transition enterCalibration
            first measuring
            then calibrating
            accept UserCommand
            if calibrationButtonPressed;

        transition calibrationComplete
            first calibrating
            then measuring;

        transition alarmRaised
            first measuring
            then alarm;

        transition alarmCleared
            first alarm
            then measuring;

        transition detectedFaultFromStartup
            first startup
            then fault;

        transition detectedFaultFromMeasuring
            first measuring
            then fault;

        transition detectedFaultFromAlarm
            first alarm
            then fault;

        transition powerOffFromMeasuring
            first measuring
            then off
            accept UserCommand
            if powerButtonPressed;

        transition powerOffFromHold
            first hold
            then off
            accept UserCommand
            if powerButtonPressed;

        transition powerOffFromFault
            first fault
            then off
            accept UserCommand
            if powerButtonPressed;
    }

    part def PressureSensor {
        doc "Wetted pressure sensing element that converts ambient hydrostatic pressure into a digital pressure sample.";

        port waterInput : WaterPressurePort;
        port sampleOutput : PressureSignalPort;
        port powerInput : PowerPort;
        port diagnosticOutput : DiagnosticPort;

        attribute pressureRangeMinimum : Kilopascal = 0.0;
        attribute pressureRangeMaximum : Kilopascal = 1300.0;
        attribute pressureAccuracy : Kilopascal = 0.5;
        attribute pressureResolution : Kilopascal = 0.01;
        attribute temperatureRangeMinimum : Celsius = -5.0;
        attribute temperatureRangeMaximum : Celsius = 50.0;
        attribute sampleRate : Hertz = 10.0;
        attribute health : SensorHealth = SensorHealth::healthy;

        perform action sensing : SenseAmbientPressure;
    }

    part def SignalConditioner {
        doc "Filters pressure samples, rejects invalid samples, and applies temperature and zero-reference compensation.";

        port rawInput : ConditionedPressurePort;
        port powerInput : PowerPort;
        port diagnosticOutput : DiagnosticPort;

        attribute filterTimeConstant : Second = 0.25;
        attribute atmosphericReferencePressure : Kilopascal = 101.325;
        attribute assumedFreshWaterDensity : KilogramPerCubicMeter = 997.0;
        attribute standardGravity : MeterPerSecondSquared = 9.80665;

        perform action conditioning : ConditionPressureSignal;
    }

    part def DepthComputer {
        doc "Computes depth from compensated pressure using the hydrostatic relation.";

        port conditionedInput : ComputedDepthPort;
        port powerInput : PowerPort;
        port diagnosticOutput : DiagnosticPort;

        attribute updateRate : Hertz = 5.0;
        attribute depthMinimum : Meter = 0.0;
        attribute depthMaximum : Meter = 120.0;
        attribute depthResolution : Millimeter = 1.0;
        attribute nominalAccuracy : Millimeter = 25.0;

        constraint updateRateRequirement : UpdateRateLimit {
            updateRate = updateRate;
        }

        perform action computeDepth : ComputeDepthFromPressure;
    }

    part def AlarmManager {
        doc "Compares computed depth with configured thresholds and assigns an alarm level.";

        port depthInput : ComputedDepthPort;
        port diagnosticOutput : DiagnosticPort;

        attribute advisoryThreshold : Meter = 40.0;
        attribute warningThreshold : Meter = 80.0;
        attribute criticalThreshold : Meter = 110.0;
        attribute activeAlarm : AlarmLevel = AlarmLevel::none;

        perform action alarmEvaluation : EvaluateAlarms;
    }

    part def DisplayUnit {
        doc "Human-readable depth display with numeric depth, validity flag, operating mode, and alarm indication.";

        port displayInput : DisplayDataPort;
        port userInterface : UserInterfacePort;
        port powerInput : PowerPort;
        port diagnosticOutput : DiagnosticPort;

        attribute digitHeight : Millimeter = 12.0;
        attribute luminance : CandelaPerSquareMeter = 400.0;
        attribute refreshRate : Hertz = 5.0;
        attribute visibleDepthResolution : Millimeter = 1.0;
        attribute operational : Boolean = true;

        perform action displayFormatting : FormatDepthDisplay;
    }

    part def UserControls {
        doc "Buttons used by the operator to power the gauge, zero the surface reference, hold a reading, and enter calibration.";

        port userInterface : UserInterfacePort;
        port powerInput : PowerPort;

        attribute buttonDebounceTime : Second = 0.05;
        attribute waterSealed : Boolean = true;
    }

    part def BatteryPowerSupply {
        doc "Self-contained battery supply for the depth gauge electronics.";

        port powerOutput : PowerPort;
        port diagnosticOutput : DiagnosticPort;

        attribute nominalVoltage : Volt = 3.7;
        attribute minimumVoltage : Volt = 3.0;
        attribute maximumCurrent : Milliampere = 250.0;
        attribute stateOfCharge : Percent = 100.0;
        attribute expectedOperatingTime : Second = 28800.0;
    }

    part def WaterproofHousing {
        doc "Mechanical housing that exposes the pressure port to water while protecting electronics and the display.";

        port waterExposure : WaterPressurePort;

        attribute ratedDepth : Meter = 150.0;
        attribute sealCompression : Millimeter = 0.6;
        attribute lensThickness : Millimeter = 3.0;
        attribute leakTight : Boolean = true;
    }

    part def DepthGauge {
        doc "Portable electronic depth gauge. Its primary function is to determine depth below the water surface from ambient hydrostatic pressure and display the depth to the user.";

        port waterPressurePort : WaterPressurePort;
        port userInterfacePort : UserInterfacePort;
        port diagnosticPort : DiagnosticPort;

        part housing : WaterproofHousing;
        part pressureSensor : PressureSensor;
        part signalConditioner : SignalConditioner;
        part depthComputer : DepthComputer;
        part alarmManager : AlarmManager;
        part display : DisplayUnit;
        part controls : UserControls;
        part battery : BatteryPowerSupply;

        attribute operatingMode : GaugeMode = GaugeMode::surface;
        attribute statedDepthRangeMinimum : Meter = 0.0;
        attribute statedDepthRangeMaximum : Meter = 120.0;
        attribute statedAccuracy : Millimeter = 50.0;
        attribute statedResolution : Millimeter = 1.0;
        attribute nominalUpdateRate : Hertz = 5.0;
        attribute referenceAtmosphericPressure : Kilopascal = 101.325;
        attribute referenceFluidDensity : KilogramPerCubicMeter = 997.0;
        attribute referenceGravity : MeterPerSecondSquared = 9.80665;

        connect waterToHousing
            connect waterPressurePort to housing.waterExposure;

        connect housingToSensor
            connect housing.waterExposure to pressureSensor.waterInput;

        connect sensorToConditioner
            connect pressureSensor.sampleOutput to signalConditioner.rawInput;

        connect conditionerToComputer
            connect signalConditioner.rawInput to depthComputer.conditionedInput;

        connect computerToAlarm
            connect depthComputer.conditionedInput to alarmManager.depthInput;

        connect computerToDisplay
            connect depthComputer.conditionedInput to display.displayInput;

        connect displayToExternalInterface
            connect display.userInterface to userInterfacePort;

        connect controlsToExternalInterface
            connect controls.userInterface to userInterfacePort;

        connect batteryToSensor
            connect battery.powerOutput to pressureSensor.powerInput;

        connect batteryToConditioner
            connect battery.powerOutput to signalConditioner.powerInput;

        connect batteryToComputer
            connect battery.powerOutput to depthComputer.powerInput;

        connect batteryToDisplay
            connect battery.powerOutput to display.powerInput;

        connect batteryToControls
            connect battery.powerOutput to controls.powerInput;

        connect sensorDiagnostics
            connect pressureSensor.diagnosticOutput to diagnosticPort;

        connect conditionerDiagnostics
            connect signalConditioner.diagnosticOutput to diagnosticPort;

        connect computerDiagnostics
            connect depthComputer.diagnosticOutput to diagnosticPort;

        connect alarmDiagnostics
            connect alarmManager.diagnosticOutput to diagnosticPort;

        connect displayDiagnostics
            connect display.diagnosticOutput to diagnosticPort;

        connect batteryDiagnostics
            connect battery.diagnosticOutput to diagnosticPort;

        exhibit state behavior : DepthGaugeOperatingStateMachine;

        perform action primaryFunction : PrimaryDepthGaugeFunction;
    }

    requirement def PrimaryFunctionRequirement {
        doc "The depth gauge shall provide the primary high-level function of measuring ambient water pressure, converting it to depth below the surface, and displaying the resulting depth to the user.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.statedDepthRangeMinimum == 0.0 and
            gauge.statedDepthRangeMaximum >= 120.0 and
            gauge.nominalUpdateRate >= 2.0;
        }
    }

    requirement def DepthAccuracyRequirement {
        doc "For depths from 0 m through 120 m, the indicated depth error shall not exceed plus or minus 50 mm under reference water density and gravity conditions.";

        subject gauge : DepthGauge;
        attribute allowableError : Millimeter = 50.0;

        require constraint {
            gauge.statedAccuracy <= allowableError;
        }
    }

    requirement def DepthResolutionRequirement {
        doc "The depth gauge shall display depth with a resolution of 1 mm or finer.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.statedResolution <= 1.0;
        }
    }

    requirement def DepthRangeRequirement {
        doc "The depth gauge shall measure and display valid depth from the surface to at least 120 m.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.statedDepthRangeMinimum <= 0.0 and
            gauge.statedDepthRangeMaximum >= 120.0;
        }
    }

    requirement def UpdateRateRequirement {
        doc "The displayed depth shall update at least twice per second while the gauge is in measuring mode.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.nominalUpdateRate >= 2.0;
        }
    }

    requirement def WaterproofRequirement {
        doc "The housing shall remain leak-tight at a depth greater than the maximum indicated measurement depth.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.housing.ratedDepth >= 150.0 and
            gauge.housing.leakTight == true;
        }
    }

    requirement def AlarmRequirement {
        doc "The gauge shall provide advisory, warning, and critical alarm levels based on computed depth thresholds.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.alarmManager.advisoryThreshold < gauge.alarmManager.warningThreshold and
            gauge.alarmManager.warningThreshold < gauge.alarmManager.criticalThreshold and
            gauge.alarmManager.criticalThreshold <= gauge.statedDepthRangeMaximum;
        }
    }

    requirement def BatteryRequirement {
        doc "The power supply shall support continuous operation for at least eight hours at nominal load.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.battery.expectedOperatingTime >= 28800.0 and
            gauge.battery.nominalVoltage >= gauge.battery.minimumVoltage;
        }
    }

    requirement def DiagnosticsRequirement {
        doc "The depth gauge shall provide diagnostic reports for pressure sensor health, battery state of charge, display status, processor status, and active alarm level.";

        subject gauge : DepthGauge;

        require constraint {
            gauge.pressureSensor.health != SensorHealth::unknown and
            gauge.display.operational == true;
        }
    }

    part def DepthGaugeOperationalContext {
        doc "Operational context for a user carrying the depth gauge underwater.";

        part gauge : DepthGauge;
        part surroundingWater {
            attribute pressureAtGauge : Kilopascal = 298.0;
            attribute temperature : Celsius = 12.0;
            attribute density : KilogramPerCubicMeter = 997.0;
        }
        part user {
            attribute requiresDisplayedDepth : Boolean = true;
            attribute readsDisplayDirectly : Boolean = true;
        }

        port waterEnvironment : WaterPressurePort;
        port userCommands : UserInterfacePort;
        port diagnostics : DiagnosticPort;

        connect environmentToGauge
            connect waterEnvironment to gauge.waterPressurePort;

        connect userToGauge
            connect userCommands to gauge.userInterfacePort;

        connect gaugeDiagnostics
            connect gauge.diagnosticPort to diagnostics;
    }

    satisfy PrimaryFunctionSatisfaction by DepthGauge;
    satisfy DepthAccuracySatisfaction by DepthGauge;
    satisfy DepthResolutionSatisfaction by DepthGauge;
    satisfy DepthRangeSatisfaction by DepthGauge;
    satisfy UpdateRateSatisfaction by DepthGauge;
    satisfy WaterproofSatisfaction by DepthGauge;
    satisfy AlarmSatisfaction by DepthGauge;
    satisfy BatterySatisfaction by DepthGauge;
    satisfy DiagnosticsSatisfaction by DepthGauge;
}
