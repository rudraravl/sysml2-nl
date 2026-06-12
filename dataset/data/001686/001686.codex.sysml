package TimerSystemModel {

  import ScalarValues::*;
  import SI::*;

  value type TimeSecond specializes Real {
    unit = "s";
  }

  value type TimeMillisecond specializes Real {
    unit = "ms";
  }

  value type FrequencyHz specializes Real {
    unit = "Hz";
  }

  value type VoltageVolt specializes Real {
    unit = "V";
  }

  value type CurrentAmpere specializes Real {
    unit = "A";
  }

  value type PowerWatt specializes Real {
    unit = "W";
  }

  value type TemperatureCelsius specializes Real {
    unit = "degC";
  }

  value type Percentage specializes Real {
    unit = "%";
  }

  enum def TimerMode {
    enum oneShot;
    enum periodic;
    enum countUp;
    enum paused;
  }

  enum def TimerStatus {
    enum idle;
    enum configured;
    enum running;
    enum elapsed;
    enum paused;
    enum faulted;
  }

  enum def ButtonCommand {
    enum start;
    enum stop;
    enum pause;
    enum resume;
    enum reset;
    enum setDuration;
  }

  item def TimeSetting {
    attribute duration : TimeSecond;
    attribute mode : TimerMode;
    attribute repeatCount : Integer;
  }

  item def TimeReading {
    attribute remainingTime : TimeSecond;
    attribute elapsedTime : TimeSecond;
    attribute progress : Percentage;
    attribute status : TimerStatus;
  }

  item def UserCommand {
    attribute command : ButtonCommand;
    attribute requestedDuration : TimeSecond;
    attribute requestedMode : TimerMode;
  }

  item def TickSignal {
    attribute period : TimeMillisecond;
    attribute sequenceNumber : Integer;
  }

  item def AlarmSignal {
    attribute active : Boolean;
    attribute alarmDuration : TimeSecond;
    attribute alarmPatternId : Integer;
  }

  item def DisplayFrame {
    attribute shownRemainingTime : TimeSecond;
    attribute shownElapsedTime : TimeSecond;
    attribute statusTextCode : Integer;
    attribute progress : Percentage;
  }

  port def PowerInputPort {
    in item supplyVoltage : VoltageVolt;
    in item supplyCurrent : CurrentAmpere;
  }

  port def ClockInputPort {
    in item tick : TickSignal;
  }

  port def CommandInputPort {
    in item userCommand : UserCommand;
  }

  port def DisplayOutputPort {
    out item frame : DisplayFrame;
  }

  port def AlarmOutputPort {
    out item alarm : AlarmSignal;
  }

  port def ReadingOutputPort {
    out item reading : TimeReading;
  }

  port def InternalTickPort {
    out item tick : TickSignal;
  }

  action def ValidateSetting {
    in item requestedSetting : TimeSetting;
    out item acceptedSetting : TimeSetting;
    out item valid : Boolean;

    first start;
    then checkDuration;
    then checkMode;
    then publishResult;
    then done;

    action checkDuration {
      constraint durationRange {
        requestedSetting.duration >= 1.0 and requestedSetting.duration <= 86400.0
      }
    }

    action checkMode {
      constraint repeatRange {
        requestedSetting.repeatCount >= 0 and requestedSetting.repeatCount <= 9999
      }
    }

    action publishResult {
      valid = true;
      acceptedSetting = requestedSetting;
    }
  }

  action def CountDown {
    in item currentReading : TimeReading;
    in item tick : TickSignal;
    out item updatedReading : TimeReading;

    first receiveTick;
    then subtractTickPeriod;
    then clampRemainingTime;
    then updateProgress;
    then done;

    action subtractTickPeriod {
      updatedReading.remainingTime =
        currentReading.remainingTime - (tick.period / 1000.0);
      updatedReading.elapsedTime =
        currentReading.elapsedTime + (tick.period / 1000.0);
    }

    action clampRemainingTime {
      constraint nonNegativeRemaining {
        updatedReading.remainingTime >= 0.0
      }
    }

    action updateProgress {
      updatedReading.progress =
        100.0 * updatedReading.elapsedTime /
        (updatedReading.elapsedTime + updatedReading.remainingTime);
    }
  }

  action def GenerateAlarm {
    in item reading : TimeReading;
    out item alarm : AlarmSignal;

    first evaluateElapsed;
    then issueAlarm;
    then done;

    action evaluateElapsed {
      constraint elapsedCondition {
        reading.remainingTime <= 0.0
      }
    }

    action issueAlarm {
      alarm.active = true;
      alarm.alarmDuration = 5.0;
      alarm.alarmPatternId = 1;
    }
  }

  action def RenderTimerDisplay {
    in item reading : TimeReading;
    out item frame : DisplayFrame;

    first mapReading;
    then mapStatus;
    then done;

    action mapReading {
      frame.shownRemainingTime = reading.remainingTime;
      frame.shownElapsedTime = reading.elapsedTime;
      frame.progress = reading.progress;
    }

    action mapStatus {
      frame.statusTextCode =
        if reading.status == TimerStatus::running then 1
        else if reading.status == TimerStatus::paused then 2
        else if reading.status == TimerStatus::elapsed then 3
        else if reading.status == TimerStatus::configured then 4
        else 0;
    }
  }

  part def PowerRegulator {
    port powerIn : PowerInputPort;
    attribute nominalInputVoltage : VoltageVolt = 5.0;
    attribute regulatedVoltage : VoltageVolt = 3.3;
    attribute maximumCurrent : CurrentAmpere = 0.5;
    attribute conversionEfficiency : Percentage = 88.0;
    attribute dissipatedPower : PowerWatt;
  }

  part def Oscillator {
    port powerIn : PowerInputPort;
    port tickOut : InternalTickPort;
    attribute nominalFrequency : FrequencyHz = 1000.0;
    attribute tickPeriod : TimeMillisecond = 1.0;
    attribute frequencyTolerance : Percentage = 0.01;
    attribute operatingTemperature : TemperatureCelsius;
  }

  part def UserInterface {
    port commandOut : CommandInputPort;
    attribute defaultDuration : TimeSecond = 60.0;
    attribute minimumDuration : TimeSecond = 1.0;
    attribute maximumDuration : TimeSecond = 86400.0;
    attribute selectedMode : TimerMode = TimerMode::oneShot;
  }

  part def TimerController {
    port commandIn : CommandInputPort;
    port clockIn : ClockInputPort;
    port readingOut : ReadingOutputPort;
    port alarmOut : AlarmOutputPort;

    attribute configuredDuration : TimeSecond = 60.0;
    attribute remainingTime : TimeSecond = 60.0;
    attribute elapsedTime : TimeSecond = 0.0;
    attribute mode : TimerMode = TimerMode::oneShot;
    attribute repeatCount : Integer = 0;
    attribute completedCycles : Integer = 0;
    attribute status : TimerStatus = TimerStatus::idle;
    attribute tickResolution : TimeMillisecond = 1.0;
    attribute timingAccuracy : Percentage = 0.05;

    perform action validateSetting : ValidateSetting;
    perform action countDown : CountDown;
    perform action generateAlarm : GenerateAlarm;

    state def TimerLifecycle {
      entry;
      state Idle;
      state Configured;
      state Running;
      state Paused;
      state Elapsed;
      state Faulted;
      exit;

      transition entry then Idle;

      transition Idle_to_Configured
        first Idle
        accept UserCommand
        if userCommand.command == ButtonCommand::setDuration
        then Configured;

      transition Configured_to_Running
        first Configured
        accept UserCommand
        if userCommand.command == ButtonCommand::start
        then Running;

      transition Running_to_Paused
        first Running
        accept UserCommand
        if userCommand.command == ButtonCommand::pause
        then Paused;

      transition Paused_to_Running
        first Paused
        accept UserCommand
        if userCommand.command == ButtonCommand::resume
        then Running;

      transition Running_to_Elapsed
        first Running
        accept TickSignal
        if remainingTime <= 0.0
        then Elapsed;

      transition Elapsed_to_Running_Periodic
        first Elapsed
        if mode == TimerMode::periodic and
           (repeatCount == 0 or completedCycles < repeatCount)
        then Running;

      transition Elapsed_to_Idle
        first Elapsed
        accept UserCommand
        if userCommand.command == ButtonCommand::reset
        then Idle;

      transition Running_to_Idle
        first Running
        accept UserCommand
        if userCommand.command == ButtonCommand::stop
        then Idle;

      transition Paused_to_Idle
        first Paused
        accept UserCommand
        if userCommand.command == ButtonCommand::reset
        then Idle;

      transition Any_to_Faulted
        first Idle
        if configuredDuration < 1.0 or configuredDuration > 86400.0
        then Faulted;

      transition Faulted_to_Idle
        first Faulted
        accept UserCommand
        if userCommand.command == ButtonCommand::reset
        then Idle;
    }

    exhibit state lifecycle : TimerLifecycle;
  }

  part def Display {
    port readingIn : ReadingOutputPort;
    port displayOut : DisplayOutputPort;
    attribute refreshPeriod : TimeMillisecond = 100.0;
    attribute visibleDigits : Integer = 6;
    attribute brightness : Percentage = 80.0;
    perform action renderDisplay : RenderTimerDisplay;
  }

  part def AlarmActuator {
    port alarmIn : AlarmOutputPort;
    attribute soundPressureLevelCode : Integer = 2;
    attribute alarmTimeout : TimeSecond = 5.0;
    attribute enabled : Boolean = true;
  }

  part def TimerSystem {
    port externalPower : PowerInputPort;
    port userCommands : CommandInputPort;
    port displayFrames : DisplayOutputPort;
    port alarmOutput : AlarmOutputPort;

    part regulator : PowerRegulator;
    part oscillator : Oscillator;
    part userInterface : UserInterface;
    part controller : TimerController;
    part display : Display;
    part alarmActuator : AlarmActuator;

    attribute primaryFunction : String =
      "Measure a user-configured time interval, present the remaining or elapsed time, and issue an alarm when the interval expires.";
    attribute maximumConfiguredDuration : TimeSecond = 86400.0;
    attribute minimumConfiguredDuration : TimeSecond = 1.0;
    attribute nominalTickResolution : TimeMillisecond = 1.0;
    attribute maximumDisplayLatency : TimeMillisecond = 150.0;
    attribute maximumAlarmLatency : TimeMillisecond = 50.0;
    attribute standbyPower : PowerWatt = 0.05;
    attribute runningPower : PowerWatt = 0.35;

    connect externalPower to regulator.powerIn;
    connect regulator.powerIn to oscillator.powerIn;
    connect oscillator.tickOut to controller.clockIn;
    connect userCommands to controller.commandIn;
    connect userInterface.commandOut to controller.commandIn;
    connect controller.readingOut to display.readingIn;
    connect display.displayOut to displayFrames;
    connect controller.alarmOut to alarmActuator.alarmIn;
    connect controller.alarmOut to alarmOutput;
  }

  requirement def PrimaryTimerFunctionRequirement {
    doc
      /* The TimerSystem shall measure a configured duration and notify the user when the duration has elapsed. */

    subject timerSystem : TimerSystem;

    require constraint {
      timerSystem.minimumConfiguredDuration <= 1.0 and
      timerSystem.maximumConfiguredDuration >= 86400.0
    }
  }

  requirement def TimingAccuracyRequirement {
    doc
      /* While running, the TimerSystem shall maintain elapsed-time error within 0.05 percent of the configured interval under nominal operating conditions. */

    subject controller : TimerController;

    require constraint {
      controller.timingAccuracy <= 0.05
    }
  }

  requirement def DisplayUpdateRequirement {
    doc
      /* The TimerSystem shall update the displayed time at least every 150 milliseconds while configured, running, paused, or elapsed. */

    subject timerSystem : TimerSystem;

    require constraint {
      timerSystem.maximumDisplayLatency <= 150.0
    }
  }

  requirement def AlarmLatencyRequirement {
    doc
      /* The TimerSystem shall activate its alarm output within 50 milliseconds after the configured interval reaches zero. */

    subject timerSystem : TimerSystem;

    require constraint {
      timerSystem.maximumAlarmLatency <= 50.0
    }
  }

  requirement def ValidDurationRequirement {
    doc
      /* The TimerSystem shall accept configured durations from 1 second through 86400 seconds inclusive and reject values outside that range. */

    subject controller : TimerController;

    require constraint {
      controller.configuredDuration >= 1.0 and
      controller.configuredDuration <= 86400.0
    }
  }

  requirement def ResetRequirement {
    doc
      /* When reset is commanded, the TimerSystem shall return to idle status, clear elapsed time, and restore remaining time to the configured duration. */

    subject controller : TimerController;

    require constraint {
      controller.elapsedTime == 0.0 and
      controller.remainingTime == controller.configuredDuration
    }
  }

  satisfy PrimaryTimerFunctionRequirement by TimerSystem;
  satisfy TimingAccuracyRequirement by TimerController;
  satisfy DisplayUpdateRequirement by TimerSystem;
  satisfy AlarmLatencyRequirement by TimerSystem;
  satisfy ValidDurationRequirement by TimerController;
  satisfy ResetRequirement by TimerController;

}