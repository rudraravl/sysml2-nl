package TimePressureGaugeModel {

  import SI::*;
  import ISQ::*;

  attribute def Pressure {
    :>> quantityKind = pressure;
    :>> unit = kPa;
  }

  attribute def Time {
    :>> quantityKind = time;
    :>> unit = s;
  }

  attribute def Temperature {
    :>> quantityKind = thermodynamicTemperature;
    :>> unit = degC;
  }

  attribute def Voltage {
    :>> quantityKind = electricPotential;
    :>> unit = V;
  }

  attribute def Percent {
    :>> unit = one;
  }

  attribute def SampleRate {
    :>> unit = Hz;
  }

  item def PressurizedMedium {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
  }

  item def PressureSample {
    attribute measuredPressure : Pressure;
    attribute sampleTime : Time;
    attribute sensorTemperature : Temperature;
    attribute validity : Boolean;
  }

  item def DisplayFrame {
    attribute indicatedPressure : Pressure;
    attribute elapsedTime : Time;
    attribute batteryLevel : Percent;
    attribute alarmActive : Boolean;
  }

  item def ElectricalEnergy {
    attribute supplyVoltage : Voltage;
    attribute chargeRemaining : Percent;
  }

  port def PressurePort {
    in item medium : PressurizedMedium;
  }

  port def SamplePort {
    out item sample : PressureSample;
  }

  port def DisplayPort {
    in item frame : DisplayFrame;
  }

  port def PowerPort {
    in item energy : ElectricalEnergy;
  }

  port def UserInputPort {
    in item powerCommand : Boolean;
    in item zeroCommand : Boolean;
    in item holdCommand : Boolean;
  }

  part def PressureTransducer {
    attribute rangeMin : Pressure = 0 [kPa];
    attribute rangeMax : Pressure = 1000 [kPa];
    attribute accuracy : Pressure = 2 [kPa];
    attribute responseTime : Time = 0.05 [s];

    port pressureInput : PressurePort;
    port sampleOutput : SamplePort;

    action sensePressure {
      in item medium : PressurizedMedium;
      out item rawSample : PressureSample;
    }
  }

  part def SignalConditioner {
    attribute filterCutoff : SampleRate = 20 [Hz];
    attribute offsetCorrection : Pressure = 0 [kPa];

    port rawInput : SamplePort;
    port conditionedOutput : SamplePort;

    action conditionSignal {
      in item rawSample : PressureSample;
      out item conditionedSample : PressureSample;
    }
  }

  part def TimeBase {
    attribute tickPeriod : Time = 0.01 [s];
    attribute elapsedTime : Time;

    action resetTimer;
    action updateElapsedTime {
      out elapsed : Time;
    }
  }

  part def GaugeController {
    attribute samplePeriod : Time = 0.1 [s];
    attribute lowBatteryThreshold : Percent = 15;
    attribute overPressureThreshold : Pressure = 900 [kPa];
    attribute currentPressure : Pressure;
    attribute heldPressure : Pressure;
    attribute elapsedMeasurementTime : Time;
    attribute holdMode : Boolean = false;
    attribute alarmActive : Boolean = false;

    port sampleInput : SamplePort;
    port userInput : UserInputPort;
    port displayOutput : DisplayPort;

    action acquireSample {
      in item pressureSample : PressureSample;
    }

    action evaluatePressure {
      in pressure : Pressure;
      out overLimit : Boolean;
    }

    action updateDisplayFrame {
      out item frame : DisplayFrame;
    }

    action zeroGauge {
      out zeroOffset : Pressure;
    }

    state def ControllerStateMachine {
      state Off;
      state Starting;
      state Ready;
      state Measuring;
      state Holding;
      state Alarm;
      state Fault;

      transition initial then Off;

      transition powerOn
        first Off
        then Starting
        accept powerCommand;

      transition startupComplete
        first Starting
        then Ready;

      transition beginMeasurement
        first Ready
        then Measuring
        accept pressureSample;

      transition holdReading
        first Measuring
        then Holding
        accept holdCommand;

      transition resumeMeasurement
        first Holding
        then Measuring
        accept holdCommand;

      transition overPressureDetected
        first Measuring
        then Alarm
        if alarmActive == true;

      transition pressureNormal
        first Alarm
        then Measuring
        if alarmActive == false;

      transition invalidSample
        first Measuring
        then Fault
        if pressureSample.validity == false;

      transition resetFromFault
        first Fault
        then Ready
        accept zeroCommand;

      transition powerOff
        first Ready
        then Off
        accept powerCommand;
    }
  }

  part def DigitalDisplay {
    attribute refreshPeriod : Time = 0.2 [s];
    attribute pressureDigits : Integer = 4;
    attribute timeDigits : Integer = 4;

    port frameInput : DisplayPort;

    action renderFrame {
      in item frame : DisplayFrame;
    }
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage = 3.7 [V];
    attribute remainingCharge : Percent = 100;

    port powerOutput : PowerPort;
  }

  part def Enclosure {
    attribute ingressProtected : Boolean = true;
    attribute impactResistant : Boolean = true;
  }

  part def TimePressureGauge {
    attribute primaryFunction : String =
      "Measure pressure at the gauge inlet, associate each measurement with elapsed time, and present the current pressure-time reading to the user.";

    port pressureIn : PressurePort;
    port userControls : UserInputPort;

    part transducer : PressureTransducer;
    part conditioner : SignalConditioner;
    part timeBase : TimeBase;
    part controller : GaugeController;
    part display : DigitalDisplay;
    part battery : BatteryPack;
    part enclosure : Enclosure;

    connect pressureIn to transducer.pressureInput;
    connect transducer.sampleOutput to conditioner.rawInput;
    connect conditioner.conditionedOutput to controller.sampleInput;
    connect controller.displayOutput to display.frameInput;
    connect userControls to controller.userInput;
    connect battery.powerOutput to controller.sampleInput;

    action performPrimaryFunction {
      in item medium : PressurizedMedium;
      out item frame : DisplayFrame;

      first start;
      then sense by transducer.sensePressure;
      then condition by conditioner.conditionSignal;
      then timeStamp by timeBase.updateElapsedTime;
      then evaluate by controller.evaluatePressure;
      then publish by controller.updateDisplayFrame;
    }

    state def GaugeOperatingState {
      state Unpowered;
      state SelfTest;
      state Zeroing;
      state ActiveMeasurement;
      state ReadingHeld;
      state OverPressureWarning;
      state Shutdown;

      transition initial then Unpowered;
      transition turnOn first Unpowered then SelfTest accept userControls.powerCommand;
      transition selfTestPassed first SelfTest then Zeroing;
      transition zeroComplete first Zeroing then ActiveMeasurement;
      transition hold first ActiveMeasurement then ReadingHeld accept userControls.holdCommand;
      transition releaseHold first ReadingHeld then ActiveMeasurement accept userControls.holdCommand;
      transition pressureExceeded first ActiveMeasurement then OverPressureWarning;
      transition pressureRecovered first OverPressureWarning then ActiveMeasurement;
      transition turnOff first ActiveMeasurement then Shutdown accept userControls.powerCommand;
      transition shutdownComplete first Shutdown then Unpowered;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject gauge : TimePressureGauge;

    doc
      "The time pressure gauge shall measure inlet pressure, associate the measurement with elapsed time, and display the pressure-time reading to the user.";

    require constraint {
      gauge.controller.currentPressure >= gauge.transducer.rangeMin and
      gauge.controller.currentPressure <= gauge.transducer.rangeMax
    }
  }

  requirement def MeasurementAccuracyRequirement {
    subject gauge : TimePressureGauge;

    doc
      "The indicated pressure shall remain within the specified measurement accuracy across the supported pressure range.";

    require constraint {
      gauge.transducer.accuracy <= 2 [kPa]
    }
  }

  requirement def MeasurementUpdateRequirement {
    subject gauge : TimePressureGauge;

    doc
      "The displayed pressure-time reading shall update at least five times per second during active measurement.";

    require constraint {
      gauge.display.refreshPeriod <= 0.2 [s]
    }
  }

  requirement def OverPressureAlarmRequirement {
    subject gauge : TimePressureGauge;

    doc
      "The gauge shall activate an alarm indication when measured pressure exceeds the configured over-pressure threshold.";

    require constraint {
      gauge.controller.overPressureThreshold == 900 [kPa]
    }
  }

  requirement def PortablePowerRequirement {
    subject gauge : TimePressureGauge;

    doc
      "The gauge shall operate from an internal battery supply and report low battery state before shutdown.";

    require constraint {
      gauge.controller.lowBatteryThreshold >= 10
    }
  }

  part timePressureGaugeSystem : TimePressureGauge;

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject gauge = timePressureGaugeSystem;
  }

  requirement measurementAccuracy : MeasurementAccuracyRequirement {
    subject gauge = timePressureGaugeSystem;
  }

  requirement measurementUpdate : MeasurementUpdateRequirement {
    subject gauge = timePressureGaugeSystem;
  }

  requirement overPressureAlarm : OverPressureAlarmRequirement {
    subject gauge = timePressureGaugeSystem;
  }

  requirement portablePower : PortablePowerRequirement {
    subject gauge = timePressureGaugeSystem;
  }

  satisfy primaryFunction by timePressureGaugeSystem;
  satisfy measurementAccuracy by timePressureGaugeSystem.transducer;
  satisfy measurementUpdate by timePressureGaugeSystem.display;
  satisfy overPressureAlarm by timePressureGaugeSystem.controller;
  satisfy portablePower by timePressureGaugeSystem.battery;
}