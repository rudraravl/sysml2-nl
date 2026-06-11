package BiophoneSystemModel {

  attribute def Voltage_V :> Real;
  attribute def Current_mA :> Real;
  attribute def Power_W :> Real;
  attribute def Frequency_MHz :> Real;
  attribute def Time_s :> Real;
  attribute def HeartRate_bpm :> Real;
  attribute def BloodPressure_mmHg :> Real;
  attribute def OxygenSaturation_percent :> Real;
  attribute def BodyTemperature_C :> Real;
  attribute def SignalStrength_dBm :> Real;
  attribute def BatteryCharge_percent :> Real;

  item def PhysiologicalSignal {
    attribute sampleTime : Time_s;
    attribute signalQuality_percent : Real;
  }

  item def ECGSignal :> PhysiologicalSignal {
    attribute leadI_mV : Real;
    attribute leadII_mV : Real;
    attribute leadIII_mV : Real;
  }

  item def VitalSigns {
    attribute heartRate : HeartRate_bpm;
    attribute systolicPressure : BloodPressure_mmHg;
    attribute diastolicPressure : BloodPressure_mmHg;
    attribute oxygenSaturation : OxygenSaturation_percent;
    attribute bodyTemperature : BodyTemperature_C;
  }

  item def VoiceAudio {
    attribute duration : Time_s;
    attribute sampleRate_Hz : Real;
    attribute encodedBitRate_kbps : Real;
  }

  item def BiophoneTelemetryPacket {
    attribute packetIdentifier : Integer;
    attribute timestamp : Time_s;
    item vitalSigns : VitalSigns;
    item audioSegment : VoiceAudio;
    attribute batteryCharge : BatteryCharge_percent;
    attribute receivedSignalStrength : SignalStrength_dBm;
  }

  item def ControlCommand {
    attribute commandCode : Integer;
    attribute commandTime : Time_s;
  }

  port def ElectrodePort {
    in item ecg : ECGSignal;
  }

  port def CuffSensorPort {
    in attribute cuffPressure : BloodPressure_mmHg;
  }

  port def OximeterPort {
    in attribute oxygenSaturation : OxygenSaturation_percent;
  }

  port def AudioPort {
    in item spokenAudio : VoiceAudio;
    out item receivedAudio : VoiceAudio;
  }

  port def RadioPort {
    out item telemetry : BiophoneTelemetryPacket;
    in item command : ControlCommand;
  }

  port def PowerPort {
    in attribute supplyVoltage : Voltage_V;
    out attribute loadCurrent : Current_mA;
  }

  part def ECGSensor {
    port electrodes : ElectrodePort;
    attribute sampleRate_Hz : Real = 500.0;
    attribute measurementRange_mV : Real = 5.0;
  }

  part def BloodPressureSensor {
    port cuff : CuffSensorPort;
    attribute maximumCuffPressure : BloodPressure_mmHg = 280.0;
  }

  part def PulseOximeter {
    port opticalProbe : OximeterPort;
    attribute minimumDetectableSpO2 : OxygenSaturation_percent = 70.0;
  }

  part def MicrophoneSpeaker {
    port audio : AudioPort;
    attribute microphoneSensitivity_dBV : Real = -42.0;
    attribute speakerPower_W : Power_W = 0.5;
  }

  part def SignalProcessor {
    in item rawECG : ECGSignal;
    in attribute rawPressure : BloodPressure_mmHg;
    in attribute rawSpO2 : OxygenSaturation_percent;
    in item rawAudio : VoiceAudio;
    out item vitalSigns : VitalSigns;
    out item encodedAudio : VoiceAudio;

    action deriveVitalSigns {
      in item ecgInput : ECGSignal;
      in attribute pressureInput : BloodPressure_mmHg;
      in attribute spo2Input : OxygenSaturation_percent;
      out item calculatedSigns : VitalSigns;
    }
  }

  part def TelemetryEncoder {
    in item vitalSigns : VitalSigns;
    in item audio : VoiceAudio;
    in attribute batteryCharge : BatteryCharge_percent;
    out item packet : BiophoneTelemetryPacket;

    action encodePacket {
      in item signs : VitalSigns;
      in item voice : VoiceAudio;
      out item telemetryPacket : BiophoneTelemetryPacket;
    }
  }

  part def RadioTransceiver {
    port antenna : RadioPort;
    attribute carrierFrequency : Frequency_MHz = 155.340;
    attribute transmitPower : Power_W = 5.0;
    attribute receiverSensitivity : SignalStrength_dBm = -115.0;
  }

  part def BatteryPack {
    port dcOutput : PowerPort;
    attribute nominalVoltage : Voltage_V = 12.0;
    attribute remainingCharge : BatteryCharge_percent;
    attribute maximumContinuousCurrent : Current_mA = 2000.0;
  }

  part def Biophone {
    port patientElectrodes : ElectrodePort;
    port bloodPressureCuff : CuffSensorPort;
    port pulseOximeterProbe : OximeterPort;
    port operatorAudio : AudioPort;
    port emergencyRadio : RadioPort;
    port externalPower : PowerPort;

    part ecgSensor : ECGSensor;
    part pressureSensor : BloodPressureSensor;
    part oximeter : PulseOximeter;
    part audioInterface : MicrophoneSpeaker;
    part processor : SignalProcessor;
    part encoder : TelemetryEncoder;
    part transceiver : RadioTransceiver;
    part battery : BatteryPack;

    connect patientElectrodes to ecgSensor.electrodes;
    connect bloodPressureCuff to pressureSensor.cuff;
    connect pulseOximeterProbe to oximeter.opticalProbe;
    connect operatorAudio to audioInterface.audio;
    connect emergencyRadio to transceiver.antenna;
    connect externalPower to battery.dcOutput;

    flow ecgSensor.electrodes.ecg to processor.rawECG;
    flow pressureSensor.cuff.cuffPressure to processor.rawPressure;
    flow oximeter.opticalProbe.oxygenSaturation to processor.rawSpO2;
    flow audioInterface.audio.spokenAudio to processor.rawAudio;
    flow processor.vitalSigns to encoder.vitalSigns;
    flow processor.encodedAudio to encoder.audio;
    flow battery.remainingCharge to encoder.batteryCharge;
    flow encoder.packet to transceiver.antenna.telemetry;

    action monitorPatientAndTransmitTelemetry {
      in item patientSignals : PhysiologicalSignal;
      out item emergencyTelemetry : BiophoneTelemetryPacket;

      first start;
      then acquireSignals;
      then validateSignals;
      then calculateVitals;
      then encodeTelemetry;
      then transmitTelemetry;
      then start;
    }

    state def OperationalState {
      state Off;
      state Standby;
      state AcquiringSignals;
      state ProcessingVitals;
      state Transmitting;
      state ReceivingCommand;
      state LowBattery;
      state Fault;

      transition initial then Off;
      transition powerOn from Off to Standby;
      transition beginMonitoring from Standby to AcquiringSignals;
      transition samplesReady from AcquiringSignals to ProcessingVitals;
      transition packetReady from ProcessingVitals to Transmitting;
      transition transmissionComplete from Transmitting to AcquiringSignals;
      transition commandReceived from Transmitting to ReceivingCommand;
      transition commandHandled from ReceivingCommand to AcquiringSignals;
      transition batteryBelow15Percent from Standby to LowBattery;
      transition batteryBelow15Percent from AcquiringSignals to LowBattery;
      transition sensorFailureDetected from AcquiringSignals to Fault;
      transition processorFailureDetected from ProcessingVitals to Fault;
      transition powerOff from Standby to Off;
      transition reset from Fault to Standby;
    }
  }

  part def EmergencyMedicalBaseStation {
    port radio : RadioPort;
    port clinicianAudio : AudioPort;

    action receiveAndDisplayPatientStatus {
      in item telemetry : BiophoneTelemetryPacket;
      out item clinicianVoiceResponse : VoiceAudio;
    }
  }

  part def Patient {
    port electrodes : ElectrodePort;
    port cuffInterface : CuffSensorPort;
    port oximeterInterface : OximeterPort;
    attribute actualHeartRate : HeartRate_bpm;
    attribute actualSystolicPressure : BloodPressure_mmHg;
    attribute actualDiastolicPressure : BloodPressure_mmHg;
    attribute actualSpO2 : OxygenSaturation_percent;
    attribute actualTemperature : BodyTemperature_C;
  }

  part def BiophoneEmergencyCareSystem {
    part patient : Patient;
    part biophone : Biophone;
    part baseStation : EmergencyMedicalBaseStation;

    connect patient.electrodes to biophone.patientElectrodes;
    connect patient.cuffInterface to biophone.bloodPressureCuff;
    connect patient.oximeterInterface to biophone.pulseOximeterProbe;
    connect biophone.emergencyRadio to baseStation.radio;
    connect biophone.operatorAudio to baseStation.clinicianAudio;
  }

  requirement def PrimaryFunctionRequirement {
    subject biophone : Biophone;
    doc "The Biophone shall acquire patient physiological signals and voice audio, derive vital signs, encode them into telemetry, and transmit them to an emergency medical base station for remote assessment."
  }

  requirement def VitalSignsAcquisitionRequirement {
    subject biophone : Biophone;
    doc "The Biophone shall acquire ECG, blood pressure, oxygen saturation, and voice audio during emergency medical monitoring."
  }

  requirement def TelemetryTransmissionRequirement {
    subject biophone : Biophone;
    doc "The Biophone shall transmit encoded patient telemetry over an emergency radio channel with sufficient signal strength for base station reception."
  }

  requirement def LowBatteryRequirement {
    subject biophone : Biophone;
    doc "The Biophone shall enter a low-battery state when remaining battery charge is below 15 percent and shall continue to preserve patient telemetry transmission as the priority function."
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject biophone : Biophone;
  }

  requirement vitalSignsAcquisition : VitalSignsAcquisitionRequirement {
    subject biophone : Biophone;
  }

  requirement telemetryTransmission : TelemetryTransmissionRequirement {
    subject biophone : Biophone;
  }

  requirement lowBatteryProtection : LowBatteryRequirement {
    subject biophone : Biophone;
  }

}