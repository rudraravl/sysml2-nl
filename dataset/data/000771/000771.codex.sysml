package SphygmomanometerSpecification {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Pressure_mmHg :> Real;
  attribute def Volume_mL :> Real;
  attribute def Flow_mL_per_s :> Real;
  attribute def Time_s :> Real;
  attribute def Frequency_Hz :> Real;
  attribute def Voltage_V :> Real;
  attribute def Current_mA :> Real;
  attribute def Percent :> Real;

  enum def MeasurementMode {
    enum automatic;
    enum manualOverride;
    enum serviceCalibration;
  }

  enum def CuffSize {
    enum pediatric;
    enum adult;
    enum largeAdult;
  }

  enum def MeasurementStatus {
    enum notStarted;
    enum cuffApplied;
    enum inflating;
    enum occluding;
    enum controlledDeflation;
    enum detectingOscillations;
    enum computingPressure;
    enum complete;
    enum fault;
  }

  item def CompressedAir {
    attribute pressure : Pressure_mmHg;
    attribute flowRate : Flow_mL_per_s;
  }

  item def ArmPressureSignal {
    attribute cuffPressure : Pressure_mmHg;
    attribute oscillationAmplitude : Pressure_mmHg;
    attribute sampleRate : Frequency_Hz;
  }

  item def BloodPressureReading {
    attribute systolicPressure : Pressure_mmHg;
    attribute diastolicPressure : Pressure_mmHg;
    attribute meanArterialPressure : Pressure_mmHg;
    attribute pulseRate : Frequency_Hz;
    attribute confidence : Percent;
    attribute measurementTime : Time_s;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute current : Current_mA;
  }

  port def AirPort {
    out item air : CompressedAir;
  }

  port def PressureSensePort {
    in item signal : ArmPressureSignal;
  }

  port def ReadingPort {
    out item reading : BloodPressureReading;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def HumanInterfacePort {
    in item startCommand;
    in item stopCommand;
    out item displayedReading : BloodPressureReading;
    out item status : MeasurementStatus;
  }

  part def InflatableCuff {
    attribute size : CuffSize;
    attribute bladderVolume : Volume_mL;
    attribute appliedCircumferenceMin : Real;
    attribute appliedCircumferenceMax : Real;
    attribute currentPressure : Pressure_mmHg;

    port airIn : AirPort;
    port pressureOut : PressureSensePort;

    action def ApplyToUpperArm {
      out item status : MeasurementStatus;
    }

    action def OccludeBrachialArtery {
      in attribute targetPressure : Pressure_mmHg;
      out attribute occlusionAchieved : Boolean;
    }
  }

  part def Pump {
    attribute maximumPressure : Pressure_mmHg;
    attribute nominalFlowRate : Flow_mL_per_s;

    port powerIn : PowerPort;
    port airOut : AirPort;

    action def Inflate {
      in attribute targetPressure : Pressure_mmHg;
      in attribute timeout : Time_s;
      out attribute achievedPressure : Pressure_mmHg;
    }
  }

  part def DeflationValve {
    attribute minimumDeflationRate : Flow_mL_per_s;
    attribute maximumDeflationRate : Flow_mL_per_s;
    attribute commandedOpening : Percent;

    port airExhaust : AirPort;

    action def ControlledDeflate {
      in attribute targetRate : Flow_mL_per_s;
      out attribute actualRate : Flow_mL_per_s;
    }

    action def EmergencyVent {
      out attribute ventedPressure : Pressure_mmHg;
    }
  }

  part def PressureSensor {
    attribute rangeMin : Pressure_mmHg;
    attribute rangeMax : Pressure_mmHg;
    attribute accuracy : Pressure_mmHg;
    attribute sampleRate : Frequency_Hz;

    port pressureIn : PressureSensePort;

    action def SamplePressure {
      out item pressureSignal : ArmPressureSignal;
    }
  }

  part def SignalProcessor {
    attribute systolicThresholdRatio : Percent;
    attribute diastolicThresholdRatio : Percent;
    attribute minimumConfidence : Percent;

    port sensorIn : PressureSensePort;
    port readingOut : ReadingPort;

    action def DetectOscillations {
      in item pressureSignal : ArmPressureSignal;
      out attribute oscillationEnvelopeDetected : Boolean;
    }

    action def ComputeBloodPressure {
      in item pressureSignal : ArmPressureSignal;
      out item reading : BloodPressureReading;
    }
  }

  part def DisplayAndControls {
    attribute lastDisplayedStatus : MeasurementStatus;

    port userInterface : HumanInterfacePort;
    port readingIn : ReadingPort;

    action def ShowStatus {
      in attribute status : MeasurementStatus;
    }

    action def ShowReading {
      in item reading : BloodPressureReading;
    }
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage_V;
    attribute remainingCharge : Percent;

    port powerOut : PowerPort;
  }

  action def AutomaticBloodPressureMeasurement {
    in item startCommand;
    out item reading : BloodPressureReading;
    out attribute finalStatus : MeasurementStatus;

    first action applyCuff;
    then action inflateCuff;
    then action detectOcclusion;
    then action controlledDeflation;
    then action analyzeOscillations;
    then action computeReading;
    then action displayResult;
  }

  state def MeasurementLifecycle {
    state idle;
    state ready;
    state inflating;
    state holdingOcclusion;
    state deflating;
    state processing;
    state resultAvailable;
    state faultDetected;

    transition idle_to_ready
      first idle
      then ready;

    transition ready_to_inflating
      first ready
      then inflating;

    transition inflating_to_holdingOcclusion
      first inflating
      then holdingOcclusion;

    transition holdingOcclusion_to_deflating
      first holdingOcclusion
      then deflating;

    transition deflating_to_processing
      first deflating
      then processing;

    transition processing_to_resultAvailable
      first processing
      then resultAvailable;

    transition any_to_faultDetected
      first idle
      then faultDetected;
  }

  part def Sphygmomanometer {
    attribute mode : MeasurementMode;
    attribute status : MeasurementStatus;
    attribute targetInflationPressure : Pressure_mmHg;
    attribute maximumSafeCuffPressure : Pressure_mmHg;
    attribute nominalDeflationRate : Flow_mL_per_s;
    attribute measuredSystolicPressure : Pressure_mmHg;
    attribute measuredDiastolicPressure : Pressure_mmHg;
    attribute measuredMeanArterialPressure : Pressure_mmHg;

    port powerInput : PowerPort;
    port userInterface : HumanInterfacePort;
    port readingOutput : ReadingPort;

    part cuff : InflatableCuff {
      attribute size = CuffSize::adult;
      attribute bladderVolume = 160.0;
    }

    part pump : Pump {
      attribute maximumPressure = 300.0;
      attribute nominalFlowRate = 35.0;
    }

    part valve : DeflationValve {
      attribute minimumDeflationRate = 2.0;
      attribute maximumDeflationRate = 6.0;
    }

    part pressureSensor : PressureSensor {
      attribute rangeMin = 0.0;
      attribute rangeMax = 300.0;
      attribute accuracy = 3.0;
      attribute sampleRate = 100.0;
    }

    part processor : SignalProcessor {
      attribute systolicThresholdRatio = 55.0;
      attribute diastolicThresholdRatio = 85.0;
      attribute minimumConfidence = 90.0;
    }

    part display : DisplayAndControls;
    part battery : BatteryPack {
      attribute nominalVoltage = 6.0;
      attribute remainingCharge = 100.0;
    }

    connect battery.powerOut to powerInput;
    connect powerInput to pump.powerIn;
    connect pump.airOut to cuff.airIn;
    connect cuff.pressureOut to pressureSensor.pressureIn;
    connect pressureSensor.pressureIn to processor.sensorIn;
    connect processor.readingOut to display.readingIn;
    connect processor.readingOut to readingOutput;
    connect display.userInterface to userInterface;
    connect valve.airExhaust to cuff.airIn;

    perform action measurement : AutomaticBloodPressureMeasurement;

    exhibit state measurementLifecycle : MeasurementLifecycle;
  }

  requirement def PrimaryFunctionRequirement {
    subject device : Sphygmomanometer;

    doc /* The sphygmomanometer shall noninvasively measure arterial blood pressure by applying an inflatable cuff to the upper arm, inflating the cuff to temporarily occlude arterial flow, gradually releasing pressure, detecting cuff pressure oscillations, and reporting systolic pressure, diastolic pressure, mean arterial pressure, and pulse rate. */

    require constraint {
      device.maximumSafeCuffPressure <= 300.0
    }
  }

  requirement def PressureAccuracyRequirement {
    subject sensor : PressureSensor;

    doc /* The pressure sensing function shall measure cuff pressure with accuracy sufficient for clinical blood pressure estimation. */

    require constraint {
      sensor.accuracy <= 3.0
    }
  }

  requirement def ControlledDeflationRequirement {
    subject device : Sphygmomanometer;

    doc /* During measurement, the device shall deflate the cuff at a controlled rate that supports oscillometric waveform detection. */

    require constraint {
      device.nominalDeflationRate >= 2.0 and device.nominalDeflationRate <= 6.0
    }
  }

  requirement def MeasurementOutputRequirement {
    subject reading : BloodPressureReading;

    doc /* Each completed measurement shall provide systolic pressure, diastolic pressure, mean arterial pressure, pulse rate, confidence, and measurement time. */

    require constraint {
      reading.systolicPressure > reading.diastolicPressure and
      reading.confidence >= 90.0
    }
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject device = Sphygmomanometer;
  }

  requirement pressureAccuracy : PressureAccuracyRequirement {
    subject sensor = Sphygmomanometer::pressureSensor;
  }

  requirement controlledDeflation : ControlledDeflationRequirement {
    subject device = Sphygmomanometer;
  }
}