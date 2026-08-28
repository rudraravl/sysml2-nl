package QuartzAnalogClock {

  import ScalarValues::*;

  value def Frequency :> Real {
    unit 'Hz';
  }
  value def Voltage :> Real {
    unit 'V';
  }
  value def Current :> Real {
    unit 'mA';
  }
  value def Duration :> Real {
    unit 's';
  }
  value def Angle :> Real {
    unit 'deg';
  }
  value def Power :> Real {
    unit 'mW';
  }
  value def BatteryLife :> Real {
    unit 'day';
  }
  value def TimeDrift :> Real {
    unit 's/month';
  }
  value def Count :> Integer;

  item def ElectricalSignal {
    attribute frequency : Frequency;
    attribute voltage : Voltage;
  }

  item def PulseSignal {
    attribute period : Duration = 1 [s];
    attribute voltage : Voltage = 1.5 [V];
  }

  item def Torque {
    attribute magnitude : Real;
  }

  attribute def TimeOfDay {
    attribute hours : Integer = 0;
    attribute minutes : Integer = 0;
    attribute seconds : Integer = 0;
  }

  port def ElectricalPort {
    out signal : ElectricalSignal;
  }

  port def PulsePort {
    out pulse : PulseSignal;
  }

  port def MechanicalPort {
    out torque : Torque;
  }

  requirement def TimekeepingAccuracy {
    doc { The clock shall maintain time with a maximum drift of 15 seconds per month under normal operating conditions. }
    attribute maxDrift : TimeDrift = 15 [s/month];
    subject clock : QuartzAnalogClock;
  }

  requirement def BatteryLifeRequirement {
    doc { The clock shall operate for at least one year on a single battery. }
    attribute minLife : BatteryLife = 365 [day];
    subject clock : QuartzAnalogClock;
  }

  requirement def OscillationFrequencyRequirement {
    doc { The quartz oscillator shall vibrate at 32768 Hz when powered. }
    attribute nominalFrequency : Frequency = 32768 [Hz];
    subject oscillator : QuartzOscillator;
  }

  requirement def PulseGenerationRequirement {
    doc { The frequency divider shall produce one electrical pulse per second. }
    attribute pulsePeriod : Duration = 1 [s];
    subject divider : FrequencyDividerIC;
  }

  requirement def StepperMotorRequirement {
    doc { The stepper motor shall rotate exactly one step per second pulse. }
    attribute stepAngle : Angle = 6 [deg];
    subject motor : StepperMotor;
  }

  requirement def GearRatioRequirement {
    doc { The gear train shall translate motor steps into correct second, minute, and hour hand motion. }
    subject gearTrain : GearTrain;
  }

  requirement accuracy : TimekeepingAccuracy;
  requirement batteryLife : BatteryLifeRequirement;
  requirement oscillationFreq : OscillationFrequencyRequirement;
  requirement pulseGen : PulseGenerationRequirement;
  requirement stepperReq : StepperMotorRequirement;
  requirement gearReq : GearRatioRequirement;

  part def Battery {
    attribute nominalVoltage : Voltage = 1.5 [V];
    attribute capacity : Real = 1200;
    attribute remainingCapacity : Real = 1200;
    port out power : ElectricalPort;

    action supplyPower {
      out signal : ElectricalSignal;
    }

    state batteryStates {
      entry;
      state Active;
      state Depleted;
      transition Active to Depleted when remainingCapacity <= 0;
    }
  }

  part def QuartzOscillator {
    attribute crystalFrequency : Frequency = 32768 [Hz];
    port in powerIn : ElectricalPort;
    port out signalOut : ElectricalPort;

    action generateSignal {
      in power : ElectricalSignal;
      out signal : ElectricalSignal;
    }

    state oscillatorStates {
      state Idle;
      state Running;
      transition Idle to Running when powerIn.signal.voltage > 0 [V];
      transition Running to Idle when powerIn.signal.voltage == 0 [V];
    }
  }

  part def FrequencyDividerIC {
    attribute divisor : Count = 32768;
    attribute counter : Count = 0;
    port in signalIn : ElectricalPort;
    port out pulseOut : PulsePort;

    action divideFrequency {
      in incoming : ElectricalSignal;
      out pulse : PulseSignal;
    }

    state dividerStates {
      state Counting;
      transition Counting to Counting
        when signalIn.signal.frequency == 32768 [Hz]
        do {
          counter = counter + 1;
          if counter >= divisor {
            counter = 0;
            pulseOut.pulse = PulseSignal { period = 1 [s]; voltage = 1.5 [V]; };
          }
        }
    }
  }

  part def StepperMotor {
    attribute stepAngle : Angle = 6 [deg];
    port in pulseIn : PulsePort;
    port out mechanicalOut : MechanicalPort;

    action step {
      in pulse : PulseSignal;
      out torque : Torque;
    }

    state motorStates {
      state Idle;
      state Stepping;
      transition Idle to Stepping when pulseIn.pulse.period == 1 [s];
      transition Stepping to Idle after 0.05 [s];
    }
  }

  part def GearTrain {
    attribute secondHandRatio : Real = 1.0;
    attribute minuteHandRatio : Real = 1.0 / 60.0;
    attribute hourHandRatio : Real = 1.0 / 720.0;
    port in mechanicalIn : MechanicalPort;
    port out secondHandDrive : MechanicalPort;
    port out minuteHandDrive : MechanicalPort;
    port out hourHandDrive : MechanicalPort;

    action translateMotion {
      in input : Torque;
      out second : Torque;
      out minute : Torque;
      out hour : Torque;
    }
  }

  part def AnalogDisplay {
    attribute secondHandAngle : Angle = 0 [deg];
    attribute minuteHandAngle : Angle = 0 [deg];
    attribute hourHandAngle : Angle = 0 [deg];
    port in secondDrive : MechanicalPort;
    port in minuteDrive : MechanicalPort;
    port in hourDrive : MechanicalPort;

    action updateDisplay {
      in secondAngle : Angle;
      in minuteAngle : Angle;
      in hourAngle : Angle;
    }

    state displayStates {
      state ShowingTime;
      transition ShowingTime to ShowingTime
        when secondDrive.torque != null
        do {
          secondHandAngle = mod(secondHandAngle + 6, 360);
          if secondHandAngle == 0 {
            minuteHandAngle = mod(minuteHandAngle + 6, 360);
            if minuteHandAngle == 0 {
              hourHandAngle = mod(hourHandAngle + 30, 360);
            }
          }
        }
    }
  }

  part def TimeCounter {
    attribute currentTime : TimeOfDay = TimeOfDay { hours = 0; minutes = 0; seconds = 0; };
    port in pulseIn : PulsePort;

    action incrementTime {
      in pulse : PulseSignal;
      out time : TimeOfDay;
    }

    state counterStates {
      state Counting;
      transition Counting to Counting
        when pulseIn.pulse.period == 1 [s]
        do {
          currentTime.seconds = currentTime.seconds + 1;
          if currentTime.seconds >= 60 {
            currentTime.seconds = 0;
            currentTime.minutes = currentTime.minutes + 1;
            if currentTime.minutes >= 60 {
              currentTime.minutes = 0;
              currentTime.hours = mod(currentTime.hours + 1, 24);
            }
          }
        }
    }
  }

  part def QuartzAnalogClock {
    part battery : Battery;
    part oscillator : QuartzOscillator;
    part divider : FrequencyDividerIC;
    part motor : StepperMotor;
    part gearTrain : GearTrain;
    part display : AnalogDisplay;
    part timeCounter : TimeCounter;

    satisfy accuracy;
    satisfy batteryLife;
    satisfy oscillationFreq by oscillator;
    satisfy pulseGen by divider;
    satisfy stepperReq by motor;
    satisfy gearReq by gearTrain;

    connection powerToOscillator connect battery.power to oscillator.powerIn;
    connection signalToDivider connect oscillator.signalOut to divider.signalIn;
    connection pulseToMotor connect divider.pulseOut to motor.pulseIn;
    connection motorToGears connect motor.mechanicalOut to gearTrain.mechanicalIn;
    connection gearsToSecond connect gearTrain.secondHandDrive to display.secondDrive;
    connection gearsToMinute connect gearTrain.minuteHandDrive to display.minuteDrive;
    connection gearsToHour connect gearTrain.hourHandDrive to display.hourDrive;
    connection pulseToCounter connect divider.pulseOut to timeCounter.pulseIn;
  }

}
