package DigitalThermometerSystem {

  import ScalarValues::*;
  import Quantities::*;
  import Units::*;
  import MeasurementReferences::*;

  // ===== Value Types with Units =====
  value type Temperature :> Real {
    unit '°C';
  }
  value type Voltage :> Real {
    unit 'V';
  }
  value type Current :> Real {
    unit 'A';
  }
  value type Frequency :> Real {
    unit 'Hz';
  }
  value type TimeValue :> Real {
    unit 's';
  }
  value type Dimensionless :> Real {
  }

  // ===== Item Definitions =====
  item def RawSignal {
    attribute magnitude : Voltage;
    attribute timestamp : TimeValue;
    attribute sensorId : String;
  }

  item def ProcessedTemperature {
    attribute value : Temperature;
    attribute timestamp : TimeValue;
    attribute calibrated : Boolean;
    attribute errorEstimate : Temperature;
  }

  item def CalibrationData {
    attribute offset : Temperature;
    attribute scale : Dimensionless;
    attribute lastUpdated : TimeValue;
  }

  item def DisplayMessage {
    attribute temperature : Temperature;
    attribute timestamp : TimeValue;
    attribute unitSymbol : String = "°C";
    attribute status : String;
  }

  item def Power {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute stable : Boolean;
  }

  // ===== Port Definitions =====
  port def PowerPort {
    out power : Power;
  }

  port def RawSignalPort {
    out signal : RawSignal;
  }

  port def ProcessedTempPort {
    out temp : ProcessedTemperature;
  }

  port def DisplayPort {
    out message : DisplayMessage;
  }

  port def CalibrationPort {
    inout data : CalibrationData;
  }

  // ===== Temperature Sensor =====
  part def TemperatureSensor {
    attribute minRange : Temperature = -40 ['°C'];
    attribute maxRange : Temperature = 100 ['°C'];
    attribute responseTime : TimeValue = 0.5 ['s'];
    attribute active : Boolean = false;
    attribute ambientTemp : Temperature;
    attribute calibration : CalibrationData;

    port powerIn : ~PowerPort;
    port signalOut : RawSignalPort;
    port calib : CalibrationPort;

    action def SenseAction {
      in ambient : Temperature;
      in calib : CalibrationData;
      out raw : RawSignal;
      doc /* Converts ambient temperature into a raw electronic signal using calibration offset and scale. */;
    }

    perform sense : SenseAction;

    state sensorState {
      state Off {
        entry assign active = false;
      }
      state Sensing {
        do sense;
        entry assign active = true;
      }
      transition off_to_sensing
        from Off to Sensing
        when powerIn.power.voltage > 0 ['V'] and powerIn.power.stable;
      transition sensing_to_off
        from Sensing to Off
        when powerIn.power.voltage == 0 ['V'];
    }
  }

  // ===== Signal Processor =====
  part def SignalProcessor {
    attribute defaultOffset : Temperature = 0 ['°C'];
    attribute defaultScale : Dimensionless = 1.0;
    attribute calibration : CalibrationData;
    attribute active : Boolean = false;
    attribute calibrating : Boolean = false;
    attribute processingLatency : TimeValue = 0.1 ['s'];

    port powerIn : ~PowerPort;
    port signalIn : ~RawSignalPort;
    port tempOut : ProcessedTempPort;
    port calib : CalibrationPort;

    action def ProcessAction {
      in raw : RawSignal;
      in calib : CalibrationData;
      out temp : ProcessedTemperature;
      doc /* Applies stored calibration offset and scale to convert a raw signal into a precise temperature value. */;
    }

    action def UpdateCalibrationAction {
      inout data : CalibrationData;
      doc /* Updates stored offset and scale calibration data. */;
    }

    perform process : ProcessAction;
    perform updateCalibration : UpdateCalibrationAction;

    state processorState {
      state Idle;
      state Processing {
        do process;
      }
      state Calibrating {
        do updateCalibration;
      }
      transition idle_to_processing
        from Idle to Processing
        when active and not calibrating;
      transition processing_to_idle
        from Processing to Idle
        when not active;
      transition idle_to_calibrating
        from Idle to Calibrating
        when calibrating;
      transition processing_to_calibrating
        from Processing to Calibrating
        when calibrating;
      transition calibrating_to_idle
        from Calibrating to Idle
        when not calibrating;
    }
  }

  // ===== Display =====
  part def Display {
    attribute updateRate : Frequency = 1 ['Hz'];
    attribute minUpdatePeriod : TimeValue = 1 ['s'];
    attribute active : Boolean = false;
    attribute currentMessage : DisplayMessage;

    port powerIn : ~PowerPort;
    port messageIn : ~ProcessedTempPort;

    action def RenderAction {
      in temp : ProcessedTemperature;
      out message : DisplayMessage;
      doc /* Renders the corrected temperature reading into a user-visible display message. */;
    }

    perform render : RenderAction;

    state displayState {
      state Off {
        entry assign active = false;
      }
      state Showing {
        do render;
        entry assign active = true;
      }
      transition off_to_showing
        from Off to Showing
        when powerIn.power.voltage > 0 ['V'];
      transition showing_to_off
        from Showing to Off
        when powerIn.power.voltage == 0 ['V'];
    }
  }

  // ===== Power Supply =====
  part def PowerSupply {
    attribute outputVoltage : Voltage = 3.3 ['V'];
    attribute maxCurrent : Current = 0.5 ['A'];
    attribute switchedOn : Boolean = false;
    attribute supplyStable : Boolean = false;

    port powerOut : PowerPort;

    action def StabilizeAction {
      out power : Power;
      doc /* Produces a stable low-voltage power output for all system components. */;
    }

    perform stabilize : StabilizeAction;

    state powerState {
      state Off {
        entry assign switchedOn = false;
        entry assign supplyStable = false;
      }
      state Starting {
        do stabilize;
      }
      state On {
        entry assign supplyStable = true;
      }
      transition off_to_starting
        from Off to Starting
        when switchedOn;
      transition starting_to_on
        from Starting to On
        when supplyStable;
      transition on_to_off
        from On to Off
        when not switchedOn;
      transition starting_to_off
        from Starting to Off
        when not switchedOn;
    }
  }

  // ===== Digital Thermometer System =====
  part def DigitalThermometer {
    attribute powered : Boolean = false;
    attribute calibrationMode : Boolean = false;
    attribute measurementError : Temperature;
    attribute measuredResponseTime : TimeValue;

    part powerSupply : PowerSupply;
    part sensor : TemperatureSensor;
    part processor : SignalProcessor;
    part display : Display;

    connection powerToSensor connect powerSupply.powerOut to sensor.powerIn;
    connection powerToProcessor connect powerSupply.powerOut to processor.powerIn;
    connection powerToDisplay connect powerSupply.powerOut to display.powerIn;
    connection signalFlow connect sensor.signalOut to processor.signalIn;
    connection tempFlow connect processor.tempOut to display.messageIn;
    connection calibBus connect sensor.calib to processor.calib;

    state systemState {
      state Off {
        entry assign powered = false;
        entry assign powerSupply.switchedOn = false;
      }
      state Measuring {
        entry assign powered = true;
        entry assign powerSupply.switchedOn = true;
        entry assign calibrationMode = false;
        entry assign sensor.active = true;
        entry assign processor.active = true;
        entry assign processor.calibrating = false;
      }
      state Calibrating {
        entry assign calibrationMode = true;
        entry assign processor.calibrating = true;
        entry assign sensor.active = true;
      }
      transition off_to_measuring
        from Off to Measuring
        when powered;
      transition measuring_to_off
        from Measuring to Off
        when not powered;
      transition measuring_to_calibrating
        from Measuring to Calibrating
        when calibrationMode;
      transition calibrating_to_measuring
        from Calibrating to Measuring
        when not calibrationMode;
    }
  }

  // ===== System Instance =====
  part thermometerSystem : DigitalThermometer;

  // ===== Requirements =====
  requirement def AccuracyRequirement {
    doc /* The thermometer shall measure ambient temperature with an accuracy of ±0.5 °C across its operating range. */;
    attribute maxError : Temperature = 0.5 ['°C'];
  }

  requirement def ResponseTimeRequirement {
    doc /* The thermometer shall present an updated temperature reading within 1 second of an ambient temperature change. */;
    attribute maxResponseTime : TimeValue = 1 ['s'];
  }

  requirement def OperatingRangeRequirement {
    doc /* The temperature sensor shall operate continuously across an ambient range of -40 °C to +100 °C. */;
    attribute minRange : Temperature = -40 ['°C'];
    attribute maxRange : Temperature = 100 ['°C'];
  }

  requirement def DisplayUpdateRequirement {
    doc /* The display shall refresh its readout at least once per second. */;
    attribute minUpdateRate : Frequency = 1 ['Hz'];
  }

  requirement def LowVoltagePowerRequirement {
    doc /* The system shall be powered by a low-voltage supply not exceeding 5 V. */;
    attribute maxVoltage : Voltage = 5 ['V'];
  }

  requirement def CalibrationRequirement {
    doc /* The signal processor shall apply stored offset and scale calibration data to correct raw sensor readings. */;
    attribute offsetRange : Temperature = 5 ['°C'];
    attribute scaleRange : Dimensionless = 0.5;
  }

  requirement accuracyReq : AccuracyRequirement {
    subject thermometer : DigitalThermometer;
  }

  requirement responseTimeReq : ResponseTimeRequirement {
    subject thermometer : DigitalThermometer;
  }

  requirement operatingRangeReq : OperatingRangeRequirement {
    subject sensor : TemperatureSensor;
  }

  requirement displayUpdateReq : DisplayUpdateRequirement {
    subject display : Display;
  }

  requirement powerReq : LowVoltagePowerRequirement {
    subject powerSupply : PowerSupply;
  }

  requirement calibrationReq : CalibrationRequirement {
    subject processor : SignalProcessor;
  }

  // ===== Satisfactions =====
  satisfaction by thermometerSystem satisfies accuracyReq;
  satisfaction by thermometerSystem satisfies responseTimeReq;
  satisfaction by thermometerSystem.sensor satisfies operatingRangeReq;
  satisfaction by thermometerSystem.display satisfies displayUpdateReq;
  satisfaction by thermometerSystem.powerSupply satisfies powerReq;
  satisfaction by thermometerSystem.processor satisfies calibrationReq;

}
