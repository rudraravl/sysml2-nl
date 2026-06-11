package PulsoconSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Percent :> Real {
    doc /* ratio expressed from 0 to 100 */
  }

  attribute def BeatsPerMinute :> Real {
    doc /* heart beats per minute */
  }

  attribute def Milliseconds :> Real {
    doc /* elapsed time in milliseconds */
  }

  attribute def Milliwatt :> Real {
    doc /* optical or electrical power in milliwatts */
  }

  attribute def Volt :> Real {
    doc /* electrical potential */
  }

  attribute def Milliampere :> Real {
    doc /* electrical current */
  }

  item def FingerTissue {
    attribute perfusionIndex : Percent;
    attribute arterialOxygenSaturation : Percent;
    attribute pulseRate : BeatsPerMinute;
  }

  item def OpticalPulse {
    attribute wavelength_nm : Real;
    attribute radiantPower : Milliwatt;
    attribute modulationPeriod : Milliseconds;
  }

  item def PhotoplethysmogramSignal {
    attribute redAC : Real;
    attribute redDC : Real;
    attribute infraredAC : Real;
    attribute infraredDC : Real;
    attribute sampleRate_Hz : Real;
  }

  item def VitalSignsEstimate {
    attribute spo2 : Percent;
    attribute pulseRate : BeatsPerMinute;
    attribute confidence : Percent;
    attribute measurementAge : Milliseconds;
  }

  item def DisplayFrame {
    attribute spo2Text : String;
    attribute pulseRateText : String;
    attribute statusText : String;
    attribute alarmVisible : Boolean;
  }

  item def AlarmEvent {
    attribute severity : String;
    attribute message : String;
    attribute timestamp_ms : Milliseconds;
  }

  item def ElectricalPower {
    attribute voltage : Volt;
    attribute current : Milliampere;
  }

  port def TissueOpticalPort {
    out opticalEmission : OpticalPulse;
    in returnedLight : OpticalPulse;
  }

  port def AnalogSignalPort {
    out ppgSignal : PhotoplethysmogramSignal;
  }

  port def VitalSignsPort {
    out estimate : VitalSignsEstimate;
  }

  port def UserDisplayPort {
    out frame : DisplayFrame;
  }

  port def AlarmPort {
    out alarm : AlarmEvent;
  }

  port def PowerPort {
    in power : ElectricalPower;
  }

  part def Pulsocon {
    doc /*
      Primary high-level function:
      The Pulsocon noninvasively estimates patient oxygen saturation and pulse rate by emitting red and infrared light into perfused finger tissue, sensing the returned pulsatile light, processing the photoplethysmogram, and presenting validated vital signs and alarms to the user.
    */

    port tissueInterface : TissueOpticalPort;
    port vitalSignsOut : VitalSignsPort;
    port displayOut : UserDisplayPort;
    port alarmOut : AlarmPort;
    port powerIn : PowerPort;

    attribute minimumSpO2AlarmLimit : Percent = 90.0;
    attribute maximumSignalAge : Milliseconds = 2000.0;
    attribute nominalSampleRate_Hz : Real = 100.0;

    part opticalEmitter : OpticalEmitter;
    part photodetector : Photodetector;
    part analogFrontEnd : AnalogFrontEnd;
    part signalProcessor : SignalProcessor;
    part displayController : DisplayController;
    part alarmManager : AlarmManager;
    part powerManager : PowerManager;

    connect powerIn to powerManager.externalPower;
    connect powerManager.regulatedPower to opticalEmitter.power;
    connect powerManager.regulatedPower to photodetector.power;
    connect powerManager.regulatedPower to analogFrontEnd.power;
    connect powerManager.regulatedPower to signalProcessor.power;
    connect powerManager.regulatedPower to displayController.power;
    connect powerManager.regulatedPower to alarmManager.power;

    connect opticalEmitter.opticalOut to tissueInterface;
    connect tissueInterface to photodetector.opticalIn;
    connect photodetector.photoCurrentOut to analogFrontEnd.photoCurrentIn;
    connect analogFrontEnd.conditionedSignalOut to signalProcessor.ppgIn;
    connect signalProcessor.vitalSignsOut to vitalSignsOut;
    connect signalProcessor.vitalSignsOut to displayController.vitalSignsIn;
    connect signalProcessor.vitalSignsOut to alarmManager.vitalSignsIn;
    connect displayController.displayOut to displayOut;
    connect alarmManager.alarmOut to alarmOut;

    state def OperatingState {
      entry action initializeSystem;
      state Off;
      state SelfTest;
      state SensorPlacementCheck;
      state Measuring;
      state Displaying;
      state AlarmActive;
      state Fault;

      transition first Off;
      transition powerApplied from Off to SelfTest;
      transition selfTestPassed from SelfTest to SensorPlacementCheck;
      transition selfTestFailed from SelfTest to Fault;
      transition tissueDetected from SensorPlacementCheck to Measuring;
      transition tissueLost from Measuring to SensorPlacementCheck;
      transition estimateValid from Measuring to Displaying;
      transition estimateUpdated from Displaying to Measuring;
      transition lowOxygenDetected from Displaying to AlarmActive;
      transition alarmAcknowledged from AlarmActive to Measuring;
      transition unrecoverableError from Measuring to Fault;
      transition powerRemoved from SelfTest to Off;
      transition powerRemoved from SensorPlacementCheck to Off;
      transition powerRemoved from Measuring to Off;
      transition powerRemoved from Displaying to Off;
      transition powerRemoved from AlarmActive to Off;
      transition powerRemoved from Fault to Off;
    }

    action def initializeSystem {
      out ready : Boolean;
    }

    action def acquirePhotoplethysmogram {
      in tissue : FingerTissue;
      out signal : PhotoplethysmogramSignal;
    }

    action def estimateVitalSigns {
      in signal : PhotoplethysmogramSignal;
      out estimate : VitalSignsEstimate;
    }

    action def evaluateAlarm {
      in estimate : VitalSignsEstimate;
      out alarmRequired : Boolean;
      out event : AlarmEvent;
    }

    action def updateDisplay {
      in estimate : VitalSignsEstimate;
      out frame : DisplayFrame;
    }
  }

  part def OpticalEmitter {
    port power : PowerPort;
    port opticalOut : TissueOpticalPort;

    attribute redWavelength_nm : Real = 660.0;
    attribute infraredWavelength_nm : Real = 940.0;
    attribute redRadiantPower : Milliwatt = 1.8;
    attribute infraredRadiantPower : Milliwatt = 2.2;
    attribute pulsePeriod : Milliseconds = 10.0;

    action def emitAlternatingLight {
      out redPulse : OpticalPulse;
      out infraredPulse : OpticalPulse;
    }
  }

  part def Photodetector {
    port power : PowerPort;
    port opticalIn : TissueOpticalPort;
    port photoCurrentOut : AnalogSignalPort;

    attribute responsivity_A_per_W : Real = 0.55;
    attribute darkCurrent_nA : Real = 2.0;

    action def convertReturnedLight {
      in returnedLight : OpticalPulse;
      out rawSignal : PhotoplethysmogramSignal;
    }
  }

  part def AnalogFrontEnd {
    port power : PowerPort;
    port photoCurrentIn : AnalogSignalPort;
    port conditionedSignalOut : AnalogSignalPort;

    attribute gain : Real = 128.0;
    attribute lowPassCutoff_Hz : Real = 12.0;
    attribute highPassCutoff_Hz : Real = 0.4;
    attribute adcResolution_bits : Integer = 16;

    action def filterAndDigitize {
      in rawSignal : PhotoplethysmogramSignal;
      out conditionedSignal : PhotoplethysmogramSignal;
    }
  }

  part def SignalProcessor {
    port power : PowerPort;
    port ppgIn : AnalogSignalPort;
    port vitalSignsOut : VitalSignsPort;

    attribute minimumConfidence : Percent = 80.0;
    attribute validSpO2LowerBound : Percent = 70.0;
    attribute validSpO2UpperBound : Percent = 100.0;
    attribute validPulseLowerBound : BeatsPerMinute = 30.0;
    attribute validPulseUpperBound : BeatsPerMinute = 240.0;

    action def computeRatioOfRatios {
      in signal : PhotoplethysmogramSignal;
      out ratio : Real;
    }

    action def calculateSpO2 {
      in ratio : Real;
      out spo2 : Percent;
    }

    action def detectPulseRate {
      in signal : PhotoplethysmogramSignal;
      out pulseRate : BeatsPerMinute;
    }

    action def publishEstimate {
      in spo2 : Percent;
      in pulseRate : BeatsPerMinute;
      out estimate : VitalSignsEstimate;
    }
  }

  part def DisplayController {
    port power : PowerPort;
    port vitalSignsIn : VitalSignsPort;
    port displayOut : UserDisplayPort;

    attribute refreshPeriod : Milliseconds = 500.0;
    attribute normalBrightness : Percent = 70.0;
    attribute alarmBrightness : Percent = 100.0;

    action def formatDisplayFrame {
      in estimate : VitalSignsEstimate;
      out frame : DisplayFrame;
    }
  }

  part def AlarmManager {
    port power : PowerPort;
    port vitalSignsIn : VitalSignsPort;
    port alarmOut : AlarmPort;

    attribute lowSpO2Limit : Percent = 90.0;
    attribute staleSignalLimit : Milliseconds = 2000.0;
    attribute alarmDelay : Milliseconds = 1000.0;

    action def checkVitalSignLimits {
      in estimate : VitalSignsEstimate;
      out alarm : AlarmEvent;
    }
  }

  part def PowerManager {
    port externalPower : PowerPort;
    port regulatedPower : PowerPort;

    attribute inputVoltage : Volt = 5.0;
    attribute regulatedVoltage : Volt = 3.3;
    attribute maximumSystemCurrent : Milliampere = 250.0;

    action def regulatePower {
      in external : ElectricalPower;
      out regulated : ElectricalPower;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /*
      The Pulsocon shall noninvasively estimate and report blood oxygen saturation and pulse rate from optical measurements of perfused tissue.
    */
    subject pulsocon : Pulsocon;
    require constraint {
      pulsocon.nominalSampleRate_Hz >= 50.0
    }
  }

  requirement def OxygenSaturationAccuracyRequirement {
    doc /*
      For valid perfusion and motion conditions, the Pulsocon shall provide an SpO2 estimate within the clinical display range of 70 percent to 100 percent.
    */
    subject processor : SignalProcessor;
    require constraint {
      processor.validSpO2LowerBound == 70.0 and
      processor.validSpO2UpperBound == 100.0
    }
  }

  requirement def PulseRateRangeRequirement {
    doc /*
      The Pulsocon shall report pulse rate across the expected adult and pediatric monitoring range.
    */
    subject processor : SignalProcessor;
    require constraint {
      processor.validPulseLowerBound <= 30.0 and
      processor.validPulseUpperBound >= 240.0
    }
  }

  requirement def LowOxygenAlarmRequirement {
    doc /*
      The Pulsocon shall generate a visible and audible alarm when a valid SpO2 estimate is below the configured low oxygen limit.
    */
    subject alarmManager : AlarmManager;
    require constraint {
      alarmManager.lowSpO2Limit == 90.0
    }
  }

  requirement def SignalFreshnessRequirement {
    doc /*
      The Pulsocon shall not display a vital-sign estimate as current when its source measurement is older than two seconds.
    */
    subject pulsocon : Pulsocon;
    require constraint {
      pulsocon.maximumSignalAge <= 2000.0
    }
  }

  part pulsoconSystem : Pulsocon {
    attribute minimumSpO2AlarmLimit = 90.0;
    attribute maximumSignalAge = 2000.0;
    attribute nominalSampleRate_Hz = 100.0;
  }

}