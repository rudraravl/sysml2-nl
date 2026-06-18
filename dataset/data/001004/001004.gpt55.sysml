package CarbonMonoxideDetectorModel {

    import ScalarValues::*;

    unit def ppm;
    unit def s;
    unit def min;
    unit def h;
    unit def V;
    unit def mA;
    unit def mAh;
    unit def dBA;
    unit def degC;
    unit def percent;

    attribute def COConcentration :> Real {
        :>> unit = ppm;
    }

    attribute def Duration :> Real {
        :>> unit = s;
    }

    attribute def Voltage :> Real {
        :>> unit = V;
    }

    attribute def Current :> Real {
        :>> unit = mA;
    }

    attribute def BatteryCapacity :> Real {
        :>> unit = mAh;
    }

    attribute def SoundPressureLevel :> Real {
        :>> unit = dBA;
    }

    attribute def Temperature :> Real {
        :>> unit = degC;
    }

    attribute def RelativeHumidity :> Real {
        :>> unit = percent;
    }

    enum def DetectorMode {
        enum unpowered;
        enum startUp;
        enum normalMonitoring;
        enum elevatedCO;
        enum alarmActive;
        enum fault;
        enum endOfLife;
        enum testAlarm;
    }

    enum def AlarmPriority {
        enum none;
        enum advisory;
        enum urgent;
        enum lifeSafety;
    }

    enum def FaultCode {
        enum noFault;
        enum lowBattery;
        enum sensorFault;
        enum hornFault;
        enum memoryFault;
        enum endOfLifeReached;
        enum blockedAirPath;
    }

    item def AirSample {
        attribute coLevel: COConcentration;
        attribute temperature: Temperature;
        attribute relativeHumidity: RelativeHumidity;
        attribute sampleAge: Duration;
    }

    item def SensorElectricalSignal {
        attribute voltage: Voltage;
        attribute current: Current;
        attribute representedCO: COConcentration;
    }

    item def ElectricalPower {
        attribute supplyVoltage: Voltage;
        attribute availableCurrent: Current;
    }

    item def BatteryCharge {
        attribute remainingCapacity: BatteryCapacity;
        attribute terminalVoltage: Voltage;
    }

    item def AlarmCommand {
        attribute priority: AlarmPriority;
        attribute requestedSoundLevel: SoundPressureLevel;
        attribute pulsePeriod: Duration;
        attribute active: Boolean;
    }

    item def AcousticAlarm {
        attribute soundLevel: SoundPressureLevel;
        attribute patternPeriod: Duration;
        attribute active: Boolean;
    }

    item def VisualAlarm {
        attribute flashPeriod: Duration;
        attribute active: Boolean;
    }

    item def WirelessNotification {
        attribute reportedCO: COConcentration;
        attribute reportedMode: DetectorMode;
        attribute reportedFault: FaultCode;
        attribute lifeSafetyAlarm: Boolean;
    }

    item def UserCommand {
        attribute testRequested: Boolean;
        attribute silenceRequested: Boolean;
        attribute resetRequested: Boolean;
    }

    item def HealthStatus {
        attribute mode: DetectorMode;
        attribute fault: FaultCode;
        attribute batteryVoltage: Voltage;
        attribute sensorAge: Duration;
        attribute lastMeasuredCO: COConcentration;
    }

    port def AirIntakePort {
        in item air: AirSample;
    }

    port def SensorSignalPort {
        out item signal: SensorElectricalSignal;
    }

    port def SignalInputPort {
        in item signal: SensorElectricalSignal;
    }

    port def ConditionedSignalPort {
        out item signal: SensorElectricalSignal;
    }

    port def PowerInputPort {
        in item power: ElectricalPower;
    }

    port def PowerOutputPort {
        out item power: ElectricalPower;
    }

    port def BatteryPort {
        inout item charge: BatteryCharge;
    }

    port def AlarmCommandPort {
        in item command: AlarmCommand;
    }

    port def AlarmCommandOutputPort {
        out item command: AlarmCommand;
    }

    port def AudibleAlarmPort {
        out item sound: AcousticAlarm;
    }

    port def VisualAlarmPort {
        out item light: VisualAlarm;
    }

    port def UserCommandPort {
        in item command: UserCommand;
    }

    port def NotificationPort {
        out item notification: WirelessNotification;
    }

    port def HealthStatusPort {
        out item status: HealthStatus;
    }

    action def SampleAmbientAir {
        in item ambientAir: AirSample;
        out item sensorSignal: SensorElectricalSignal;
        attribute sampleInterval: Duration = 10 [s];
    }

    action def ConditionSensorSignal {
        in item rawSignal: SensorElectricalSignal;
        out item conditionedSignal: SensorElectricalSignal;
    }

    action def EstimateCOConcentration {
        in item conditionedSignal: SensorElectricalSignal;
        out item measuredCO: COConcentration;
    }

    action def EvaluateAlarmNeed {
        in item measuredCO: COConcentration;
        out item command: AlarmCommand;
        attribute advisoryThreshold: COConcentration = 30 [ppm];
        attribute urgentThreshold: COConcentration = 70 [ppm];
        attribute lifeSafetyThreshold: COConcentration = 150 [ppm];
    }

    action def DriveAudibleAlarm {
        in item command: AlarmCommand;
        out item sound: AcousticAlarm;
        attribute minimumSoundLevel: SoundPressureLevel = 85 [dBA];
    }

    action def DriveVisualAlarm {
        in item command: AlarmCommand;
        out item light: VisualAlarm;
        attribute alarmFlashPeriod: Duration = 1 [s];
    }

    action def PublishWirelessStatus {
        in item measuredCO: COConcentration;
        in item status: HealthStatus;
        out item notification: WirelessNotification;
    }

    action def PerformSelfTest {
        out item status: HealthStatus;
        attribute selfTestInterval: Duration = 86400 [s];
    }

    action def ManagePower {
        in item mainsPower: ElectricalPower;
        inout item battery: BatteryCharge;
        out item regulatedPower: ElectricalPower;
        attribute nominalVoltage: Voltage = 3.3 [V];
        attribute lowBatteryVoltage: Voltage = 2.7 [V];
    }

    action def DetectCarbonMonoxideAndAlert {
        in item ambientAir: AirSample;
        in item userCommand: UserCommand;
        in item mainsPower: ElectricalPower;
        inout item battery: BatteryCharge;
        out item audibleAlarm: AcousticAlarm;
        out item visualAlarm: VisualAlarm;
        out item wirelessNotification: WirelessNotification;
        out item healthStatus: HealthStatus;

        action managePower: ManagePower;
        action sampleAir: SampleAmbientAir;
        action conditionSignal: ConditionSensorSignal;
        action estimateCO: EstimateCOConcentration;
        action evaluateAlarm: EvaluateAlarmNeed;
        action driveHorn: DriveAudibleAlarm;
        action driveIndicator: DriveVisualAlarm;
        action selfTest: PerformSelfTest;
        action publishStatus: PublishWirelessStatus;

        succession managePower then sampleAir;
        succession sampleAir then conditionSignal;
        succession conditionSignal then estimateCO;
        succession estimateCO then evaluateAlarm;
        succession evaluateAlarm then driveHorn;
        succession evaluateAlarm then driveIndicator;
        succession selfTest then publishStatus;

        flow ambientAir to sampleAir.ambientAir;
        flow mainsPower to managePower.mainsPower;
        flow battery to managePower.battery;
        flow sampleAir.sensorSignal to conditionSignal.rawSignal;
        flow conditionSignal.conditionedSignal to estimateCO.conditionedSignal;
        flow estimateCO.measuredCO to evaluateAlarm.measuredCO;
        flow evaluateAlarm.command to driveHorn.command;
        flow evaluateAlarm.command to driveIndicator.command;
        flow driveHorn.sound to audibleAlarm;
        flow driveIndicator.light to visualAlarm;
        flow selfTest.status to healthStatus;
        flow estimateCO.measuredCO to publishStatus.measuredCO;
        flow selfTest.status to publishStatus.status;
        flow publishStatus.notification to wirelessNotification;
    }

    state def CODetectorOperationalStateMachine {
        attribute currentMode: DetectorMode;
        attribute measuredCO: COConcentration;
        attribute fault: FaultCode;
        attribute batteryVoltage: Voltage;
        attribute sensorServiceAge: Duration;

        state Unpowered;
        state StartUpSelfTest;
        state NormalMonitoring;
        state ElevatedCO;
        state AlarmActive;
        state Fault;
        state EndOfLife;
        state TestAlarm;

        transition initialPowerOff first Unpowered;

        transition powerApplied
            first Unpowered
            accept ElectricalPower
            then StartUpSelfTest;

        transition selfTestPassed
            first StartUpSelfTest
            if fault == FaultCode::noFault
            then NormalMonitoring;

        transition selfTestFailed
            first StartUpSelfTest
            if fault != FaultCode::noFault
            then Fault;

        transition advisoryCO
            first NormalMonitoring
            if measuredCO >= 30 [ppm] and measuredCO < 70 [ppm]
            then ElevatedCO;

        transition lifeSafetyCOFromNormal
            first NormalMonitoring
            if measuredCO >= 70 [ppm]
            then AlarmActive;

        transition lifeSafetyCOFromElevated
            first ElevatedCO
            if measuredCO >= 70 [ppm]
            then AlarmActive;

        transition coCleared
            first ElevatedCO
            if measuredCO < 30 [ppm]
            then NormalMonitoring;

        transition alarmCleared
            first AlarmActive
            if measuredCO < 30 [ppm]
            then NormalMonitoring;

        transition lowBatteryFault
            first NormalMonitoring
            if batteryVoltage < 2.7 [V]
            then Fault;

        transition sensorFaultDetected
            first NormalMonitoring
            if fault == FaultCode::sensorFault or fault == FaultCode::blockedAirPath
            then Fault;

        transition endOfLifeReached
            first NormalMonitoring
            if sensorServiceAge >= 315360000 [s]
            then EndOfLife;

        transition userTest
            first NormalMonitoring
            accept UserCommand
            then TestAlarm;

        transition testComplete
            first TestAlarm
            then NormalMonitoring;

        transition faultRecovered
            first Fault
            if fault == FaultCode::noFault and batteryVoltage >= 2.7 [V]
            then NormalMonitoring;
    }

    part def Housing {
        port ambientVent: AirIntakePort;
        port internalAirPath: AirIntakePort;
        attribute ingressProtectionMaintained: Boolean = true;
        attribute airPathBlocked: Boolean = false;
    }

    part def ElectrochemicalCOSensor {
        port sampleIn: AirIntakePort;
        port rawSignalOut: SensorSignalPort;
        port powerIn: PowerInputPort;
        attribute measurementRangeLow: COConcentration = 0 [ppm];
        attribute measurementRangeHigh: COConcentration = 1000 [ppm];
        attribute nominalSensitivity: Voltage = 0.040 [V];
        attribute serviceLife: Duration = 315360000 [s];
    }

    part def SignalConditioner {
        port rawIn: SignalInputPort;
        port conditionedOut: ConditionedSignalPort;
        port powerIn: PowerInputPort;
        attribute analogFilterTimeConstant: Duration = 2 [s];
        attribute offsetCompensationEnabled: Boolean = true;
    }

    part def Microcontroller {
        port conditionedIn: SignalInputPort;
        port alarmCommandOut: AlarmCommandOutputPort;
        port healthOut: HealthStatusPort;
        port notificationOut: NotificationPort;
        port userCommandIn: UserCommandPort;
        port powerIn: PowerInputPort;

        attribute samplingInterval: Duration = 10 [s];
        attribute displayedCO: COConcentration = 0 [ppm];
        attribute activeFault: FaultCode = FaultCode::noFault;
        attribute operatingMode: DetectorMode = DetectorMode::startUp;
        attribute lowAlarmThreshold: COConcentration = 70 [ppm];
        attribute highAlarmThreshold: COConcentration = 150 [ppm];
        attribute minimumAlarmPersistence: Duration = 60 [s];

        perform action detectionBehavior: DetectCarbonMonoxideAndAlert;
        exhibit state operationalStates: CODetectorOperationalStateMachine;
    }

    part def PiezoelectricHorn {
        port commandIn: AlarmCommandPort;
        port soundOut: AudibleAlarmPort;
        port powerIn: PowerInputPort;
        attribute ratedSoundLevel: SoundPressureLevel = 85 [dBA];
        attribute alarmPatternPeriod: Duration = 4 [s];
    }

    part def StatusLED {
        port commandIn: AlarmCommandPort;
        port lightOut: VisualAlarmPort;
        port powerIn: PowerInputPort;
        attribute normalFlashPeriod: Duration = 60 [s];
        attribute alarmFlashPeriod: Duration = 1 [s];
        attribute faultFlashPeriod: Duration = 10 [s];
    }

    part def UserInterface {
        port commandOut: UserCommandPort;
        attribute testButtonDebounceTime: Duration = 0.05 [s];
        attribute silenceDuration: Duration = 300 [s];
    }

    part def WirelessModule {
        port notificationIn: NotificationPort;
        port notificationOut: NotificationPort;
        port powerIn: PowerInputPort;
        attribute statusReportInterval: Duration = 3600 [s];
        attribute alarmReportLatency: Duration = 5 [s];
    }

    part def BatteryPack {
        port batteryPort: BatteryPort;
        port powerOut: PowerOutputPort;
        attribute nominalVoltage: Voltage = 3.0 [V];
        attribute capacity: BatteryCapacity = 2400 [mAh];
        attribute lowVoltageLimit: Voltage = 2.7 [V];
    }

    part def ACAdapter {
        port mainsIn: PowerInputPort;
        port dcOut: PowerOutputPort;
        attribute inputVoltage: Voltage = 120 [V];
        attribute regulatedVoltage: Voltage = 5 [V];
    }

    part def PowerManager {
        port mainsPowerIn: PowerInputPort;
        port batteryInOut: BatteryPort;
        port regulatedPowerOut: PowerOutputPort;
        attribute regulatedVoltage: Voltage = 3.3 [V];
        attribute sleepCurrent: Current = 0.020 [mA];
        attribute alarmCurrent: Current = 80 [mA];
    }

    part def CarbonMonoxideDetector {
        doc /* Primary function: continuously monitor ambient indoor air for carbon monoxide, determine whether the measured concentration presents a hazardous condition, and warn occupants using audible, visual, and optional wireless alerts while maintaining self-test and power-fail-safe operation. */

        port ambientAirIn: AirIntakePort;
        port mainsPowerIn: PowerInputPort;
        port userCommandIn: UserCommandPort;
        port audibleAlarmOut: AudibleAlarmPort;
        port visualAlarmOut: VisualAlarmPort;
        port wirelessNotificationOut: NotificationPort;
        port healthStatusOut: HealthStatusPort;

        part housing: Housing;
        part coSensor: ElectrochemicalCOSensor;
        part conditioner: SignalConditioner;
        part controller: Microcontroller;
        part horn: PiezoelectricHorn;
        part led: StatusLED;
        part ui: UserInterface;
        part radio: WirelessModule;
        part battery: BatteryPack;
        part acAdapter: ACAdapter;
        part powerManager: PowerManager;

        attribute installed: Boolean = true;
        attribute measuredCO: COConcentration = 0 [ppm];
        attribute alarmActive: Boolean = false;
        attribute currentMode: DetectorMode = DetectorMode::startUp;
        attribute maximumSensorRange: COConcentration = 1000 [ppm];
        attribute lowBatteryThreshold: Voltage = 2.7 [V];
        attribute requiredAudibleLevel: SoundPressureLevel = 85 [dBA];
        attribute designServiceLife: Duration = 315360000 [s];

        connect ambientAirIn to housing.ambientVent;
        connect housing.internalAirPath to coSensor.sampleIn;
        connect coSensor.rawSignalOut to conditioner.rawIn;
        connect conditioner.conditionedOut to controller.conditionedIn;
        connect controller.alarmCommandOut to horn.commandIn;
        connect controller.alarmCommandOut to led.commandIn;
        connect horn.soundOut to audibleAlarmOut;
        connect led.lightOut to visualAlarmOut;
        connect userCommandIn to controller.userCommandIn;
        connect ui.commandOut to controller.userCommandIn;
        connect controller.notificationOut to radio.notificationIn;
        connect radio.notificationOut to wirelessNotificationOut;
        connect controller.healthOut to healthStatusOut;
        connect mainsPowerIn to acAdapter.mainsIn;
        connect acAdapter.dcOut to powerManager.mainsPowerIn;
        connect battery.batteryPort to powerManager.batteryInOut;
        connect powerManager.regulatedPowerOut to coSensor.powerIn;
        connect powerManager.regulatedPowerOut to conditioner.powerIn;
        connect powerManager.regulatedPowerOut to controller.powerIn;
        connect powerManager.regulatedPowerOut to horn.powerIn;
        connect powerManager.regulatedPowerOut to led.powerIn;
        connect powerManager.regulatedPowerOut to radio.powerIn;

        perform action primaryFunction: DetectCarbonMonoxideAndAlert;
        exhibit state lifecycle: CODetectorOperationalStateMachine;
    }

    part def DwellingRoom {
        port roomAir: AirIntakePort;
        port occupantHearing: AudibleAlarmPort;
        port occupantSight: VisualAlarmPort;
        port homeNetwork: NotificationPort;

        part detector: CarbonMonoxideDetector;

        attribute backgroundCO: COConcentration = 0 [ppm];
        attribute hazardousCOScenario: COConcentration = 150 [ppm];
        attribute roomTemperature: Temperature = 22 [degC];
        attribute roomHumidity: RelativeHumidity = 45 [percent];

        connect roomAir to detector.ambientAirIn;
        connect detector.audibleAlarmOut to occupantHearing;
        connect detector.visualAlarmOut to occupantSight;
        connect detector.wirelessNotificationOut to homeNetwork;
    }

    requirement def PrimaryFunctionRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.installed implies
            detector.primaryFunction.ambientAir != null
        }
        doc /* The detector shall continuously sample ambient air and provide warnings when carbon monoxide concentration is hazardous to occupants. */
    }

    requirement def COHazardDetectionRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.maximumSensorRange >= 1000 [ppm]
        }
        doc /* The detector shall measure carbon monoxide concentration over at least 0 ppm to 1000 ppm. */
    }

    requirement def LifeSafetyAlarmRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.measuredCO >= 70 [ppm] implies detector.alarmActive == true
        }
        doc /* The detector shall command an alarm when the evaluated carbon monoxide exposure reaches the life-safety threshold. */
    }

    requirement def AudibleAlarmRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.requiredAudibleLevel >= 85 [dBA]
        }
        doc /* The detector shall provide an audible alarm of at least 85 dBA during a life-safety alarm. */
    }

    requirement def VisualAlarmRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.led.alarmFlashPeriod <= 1 [s]
        }
        doc /* The detector shall provide a visible alarm indication when the audible alarm is active. */
    }

    requirement def BatteryBackupRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.battery.nominalVoltage >= 3.0 [V] and detector.battery.capacity >= 2400 [mAh]
        }
        doc /* The detector shall include battery-backed operation sufficient to maintain monitoring when mains power is unavailable. */
    }

    requirement def LowBatteryFaultRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.lowBatteryThreshold == 2.7 [V]
        }
        doc /* The detector shall report a fault when battery voltage falls below the low-battery threshold. */
    }

    requirement def SelfTestRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.controller.detectionBehavior.selfTest.selfTestInterval <= 86400 [s]
        }
        doc /* The detector shall perform an automatic self-test at least once per day. */
    }

    requirement def EndOfLifeRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.designServiceLife == 315360000 [s]
        }
        doc /* The detector shall indicate end-of-life after ten years of sensor service. */
    }

    requirement def WirelessNotificationRequirement {
        subject detector: CarbonMonoxideDetector;
        require constraint {
            detector.radio.alarmReportLatency <= 5 [s]
        }
        doc /* If wireless communication is available, the detector shall publish alarm status within five seconds. */
    }

    satisfy PrimaryFunctionRequirement by CarbonMonoxideDetector::primaryFunction;
    satisfy COHazardDetectionRequirement by CarbonMonoxideDetector::coSensor;
    satisfy LifeSafetyAlarmRequirement by CarbonMonoxideDetector::controller;
    satisfy AudibleAlarmRequirement by CarbonMonoxideDetector::horn;
    satisfy VisualAlarmRequirement by CarbonMonoxideDetector::led;
    satisfy BatteryBackupRequirement by CarbonMonoxideDetector::battery;
    satisfy LowBatteryFaultRequirement by CarbonMonoxideDetector::powerManager;
    satisfy SelfTestRequirement by CarbonMonoxideDetector::controller;
    satisfy EndOfLifeRequirement by CarbonMonoxideDetector::coSensor;
    satisfy WirelessNotificationRequirement by CarbonMonoxideDetector::radio;
}
