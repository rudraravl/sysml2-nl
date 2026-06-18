package DurableMedicalEquipment_OxygenConcentratorModel {

  import ScalarValues::*;

  quantity kind def Mass;
  quantity kind def VolumeFlowRate;
  quantity kind def Pressure;
  quantity kind def ElectricPotential;
  quantity kind def ElectricCurrent;
  quantity kind def Energy;
  quantity kind def Time;
  quantity kind def Temperature;
  quantity kind def Fraction;
  quantity kind def SoundPressureLevel;

  unit def kilogram {
    :>> quantityKind = Mass;
  }

  unit def literPerMinute {
    :>> quantityKind = VolumeFlowRate;
  }

  unit def kilopascal {
    :>> quantityKind = Pressure;
  }

  unit def volt {
    :>> quantityKind = ElectricPotential;
  }

  unit def ampere {
    :>> quantityKind = ElectricCurrent;
  }

  unit def wattHour {
    :>> quantityKind = Energy;
  }

  unit def hour {
    :>> quantityKind = Time;
  }

  unit def degreeCelsius {
    :>> quantityKind = Temperature;
  }

  unit def percent {
    :>> quantityKind = Fraction;
  }

  unit def decibelA {
    :>> quantityKind = SoundPressureLevel;
  }

  attribute def Mass_kg :> Real {
    :>> unit = kilogram;
  }

  attribute def Flow_L_per_min :> Real {
    :>> unit = literPerMinute;
  }

  attribute def Pressure_kPa :> Real {
    :>> unit = kilopascal;
  }

  attribute def Voltage_V :> Real {
    :>> unit = volt;
  }

  attribute def Current_A :> Real {
    :>> unit = ampere;
  }

  attribute def Energy_Wh :> Real {
    :>> unit = wattHour;
  }

  attribute def Duration_h :> Real {
    :>> unit = hour;
  }

  attribute def Temperature_degC :> Real {
    :>> unit = degreeCelsius;
  }

  attribute def PercentValue :> Real {
    :>> unit = percent;
  }

  attribute def Sound_dBA :> Real {
    :>> unit = decibelA;
  }

  enum def TherapyMode {
    enum continuousFlow;
    enum pulseDose;
    enum sleepOptimized;
    enum standby;
    enum service;
  }

  enum def AlarmSeverity {
    enum advisory;
    enum caution;
    enum critical;
  }

  enum def AlarmKind {
    enum lowOxygenPurity;
    enum lowBattery;
    enum blockedCannula;
    enum highTemperature;
    enum compressorFault;
    enum noBreathDetected;
    enum powerDisconnected;
    enum filterMaintenanceDue;
  }

  enum def PowerSourceKind {
    enum acMains;
    enum dcVehicle;
    enum internalBattery;
  }

  enum def PatientBreathPhase {
    enum inhalation;
    enum exhalation;
    enum apnea;
    enum unknown;
  }

  item def AmbientAir {
    attribute oxygenFraction : PercentValue = 20.95;
    attribute nitrogenFraction : PercentValue = 78.08;
    attribute argonAndTraceGasFraction : PercentValue = 0.97;
    attribute humidity : PercentValue;
    attribute temperature : Temperature_degC;
    attribute particulateLoad_mg_per_m3 : Real;
  }

  item def FilteredAir {
    attribute oxygenFraction : PercentValue;
    attribute humidity : PercentValue;
    attribute particleRemovalEfficiency : PercentValue;
    attribute flow : Flow_L_per_min;
    attribute pressure : Pressure_kPa;
  }

  item def CompressedAir {
    attribute oxygenFraction : PercentValue;
    attribute pressure : Pressure_kPa;
    attribute temperature : Temperature_degC;
    attribute flow : Flow_L_per_min;
  }

  item def NitrogenRichExhaust {
    attribute nitrogenFraction : PercentValue;
    attribute pressure : Pressure_kPa;
    attribute flow : Flow_L_per_min;
  }

  item def OxygenEnrichedGas {
    attribute oxygenFraction : PercentValue;
    attribute pressure : Pressure_kPa;
    attribute flow : Flow_L_per_min;
    attribute temperature : Temperature_degC;
  }

  item def DeliveredOxygenDose {
    attribute oxygenFraction : PercentValue;
    attribute deliveredFlow : Flow_L_per_min;
    attribute deliveryPressure : Pressure_kPa;
    attribute pulseVolume_mL : Real;
    attribute therapyMode : TherapyMode;
  }

  item def BreathSignal {
    attribute phase : PatientBreathPhase;
    attribute nasalPressure : Pressure_kPa;
    attribute breathRate_per_min : Real;
    attribute signalConfidence : PercentValue;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute current : Current_A;
    attribute sourceKind : PowerSourceKind;
  }

  item def BatteryEnergy {
    attribute remainingEnergy : Energy_Wh;
    attribute stateOfCharge : PercentValue;
    attribute estimatedRuntime : Duration_h;
  }

  item def UserPrescription {
    attribute prescribedMode : TherapyMode;
    attribute prescribedContinuousFlow : Flow_L_per_min;
    attribute prescribedPulseVolume_mL : Real;
    attribute minimumOxygenPurity : PercentValue;
    attribute maximumSoundLevel : Sound_dBA;
  }

  item def AlarmMessage {
    attribute kind : AlarmKind;
    attribute severity : AlarmSeverity;
    attribute active : Boolean;
    attribute messageText : String;
  }

  item def DisplayStatus {
    attribute currentMode : TherapyMode;
    attribute measuredOxygenPurity : PercentValue;
    attribute deliveredFlow : Flow_L_per_min;
    attribute batteryStateOfCharge : PercentValue;
    attribute activeAlarmCount : Integer;
  }

  port def AirIntakePort {
    in item ambientAir : AmbientAir;
  }

  port def FilteredAirPort {
    in item filteredAirIn : FilteredAir;
    out item filteredAirOut : FilteredAir;
  }

  port def CompressedAirPort {
    in item compressedAirIn : CompressedAir;
    out item compressedAirOut : CompressedAir;
  }

  port def OxygenProductPort {
    in item oxygenIn : OxygenEnrichedGas;
    out item oxygenOut : OxygenEnrichedGas;
  }

  port def ExhaustPort {
    out item exhaust : NitrogenRichExhaust;
  }

  port def PatientGasPort {
    out item therapyGas : DeliveredOxygenDose;
    in item breath : BreathSignal;
  }

  port def PowerInputPort {
    in item inputPower : ElectricalPower;
  }

  port def BatteryPort {
    in item chargePower : ElectricalPower;
    out item storedEnergy : BatteryEnergy;
    out item dischargePower : ElectricalPower;
  }

  port def UserInterfacePort {
    in item prescription : UserPrescription;
    out item status : DisplayStatus;
    out item alarm : AlarmMessage;
  }

  port def ControlSignalPort {
    in item command : DisplayStatus;
    out item measurement : DisplayStatus;
  }

  abstract part def DurableMedicalEquipment {
    attribute equipmentName : String;
    attribute intendedUse : String;
    attribute serviceLife_year : Real;
    attribute reusable : Boolean = true;
    attribute mass : Mass_kg;
  }

  part def IntakeFilter {
    attribute particleRemovalEfficiency : PercentValue = 99.97;
    attribute replacementInterval_h : Duration_h = 400.0;
    attribute accumulatedUse_h : Duration_h;
    attribute pressureDrop : Pressure_kPa;

    port inlet : AirIntakePort;
    port outlet : FilteredAirPort;

    action filterAmbientAir {
      in item rawAir : AmbientAir;
      out item cleanAir : FilteredAir;
    }
  }

  part def AcousticMuffler {
    attribute insertionLoss : Sound_dBA = 8.0;
    attribute pressureDrop : Pressure_kPa = 1.2;

    port inlet : OxygenProductPort;
    port outlet : OxygenProductPort;
  }

  part def CompressorAssembly {
    attribute nominalMotorVoltage : Voltage_V = 24.0;
    attribute maximumCurrent : Current_A = 7.0;
    attribute outputPressure : Pressure_kPa = 210.0;
    attribute nominalFlow : Flow_L_per_min = 28.0;
    attribute soundLevel : Sound_dBA = 42.0;
    attribute operatingTemperature : Temperature_degC;

    port airIn : FilteredAirPort;
    port compressedAirOut : CompressedAirPort;
    port electricalInput : PowerInputPort;

    action compressAir {
      in item inletAir : FilteredAir;
      in item motorPower : ElectricalPower;
      out item pressurizedAir : CompressedAir;
    }
  }

  part def MolecularSieveBed {
    attribute zeoliteMass : Mass_kg = 1.4;
    attribute adsorptionPressure : Pressure_kPa = 205.0;
    attribute purgePressure : Pressure_kPa = 115.0;
    attribute nominalOxygenPurity : PercentValue = 93.0;
    attribute minimumEffectivePurity : PercentValue = 87.0;

    port compressedAirIn : CompressedAirPort;
    port oxygenProductOut : OxygenProductPort;
    port nitrogenExhaustOut : ExhaustPort;

    action adsorbNitrogen {
      in item pressurizedAir : CompressedAir;
      out item productGas : OxygenEnrichedGas;
      out item exhaustGas : NitrogenRichExhaust;
    }
  }

  part def ProductReservoir {
    attribute internalVolume_L : Real = 1.1;
    attribute nominalPressure : Pressure_kPa = 150.0;
    attribute minimumDeliveryPressure : Pressure_kPa = 35.0;

    port productIn : OxygenProductPort;
    port productOut : OxygenProductPort;

    action smoothProductFlow {
      in item pulsatingOxygen : OxygenEnrichedGas;
      out item bufferedOxygen : OxygenEnrichedGas;
    }
  }

  part def FlowControlValve {
    attribute minimumContinuousFlow : Flow_L_per_min = 0.5;
    attribute maximumContinuousFlow : Flow_L_per_min = 5.0;
    attribute pulseDoseMinimum_mL : Real = 16.0;
    attribute pulseDoseMaximum_mL : Real = 96.0;
    attribute responseTime_ms : Real = 80.0;

    port oxygenIn : OxygenProductPort;
    port patientOut : PatientGasPort;
    port controllerInterface : ControlSignalPort;

    action meterOxygen {
      in item reservoirGas : OxygenEnrichedGas;
      in item prescription : UserPrescription;
      in item breathSignal : BreathSignal;
      out item deliveredDose : DeliveredOxygenDose;
    }
  }

  part def OxygenPuritySensor {
    attribute measuredPurity : PercentValue;
    attribute accuracy : PercentValue = 2.0;
    attribute warmupTime_h : Duration_h = 0.02;

    port sampleIn : OxygenProductPort;
    port measurementOut : ControlSignalPort;

    action measurePurity {
      in item sampleGas : OxygenEnrichedGas;
      out attribute purity : PercentValue;
    }
  }

  part def FlowPressureSensor {
    attribute measuredFlow : Flow_L_per_min;
    attribute measuredPressure : Pressure_kPa;
    attribute flowAccuracy : PercentValue = 5.0;
    attribute pressureAccuracy : PercentValue = 3.0;

    port gasSampleIn : OxygenProductPort;
    port measurementOut : ControlSignalPort;

    action measureFlowAndPressure {
      in item sampleGas : OxygenEnrichedGas;
      out attribute flow : Flow_L_per_min;
      out attribute pressure : Pressure_kPa;
    }
  }

  part def BreathDetectionSensor {
    attribute breathRate_per_min : Real;
    attribute apneaTimeout_s : Real = 30.0;
    attribute nasalPressureSensitivity : Pressure_kPa = 0.02;

    port patientInterface : PatientGasPort;
    port measurementOut : ControlSignalPort;

    action detectBreath {
      in item patientBreath : BreathSignal;
      out item interpretedBreath : BreathSignal;
    }
  }

  part def BatteryPack {
    attribute nominalVoltage : Voltage_V = 24.0;
    attribute capacity : Energy_Wh = 360.0;
    attribute stateOfCharge : PercentValue;
    attribute minimumRuntimeAt2LPM : Duration_h = 4.0;
    attribute maximumChargeCurrent : Current_A = 6.0;

    port batteryInterface : BatteryPort;

    action supplyPower {
      out item dischargePower : ElectricalPower;
      out item energyStatus : BatteryEnergy;
    }

    action recharge {
      in item chargePower : ElectricalPower;
      out item energyStatus : BatteryEnergy;
    }
  }

  part def PowerManagementUnit {
    attribute acInputVoltage : Voltage_V = 120.0;
    attribute dcBusVoltage : Voltage_V = 24.0;
    attribute maximumOutputCurrent : Current_A = 10.0;
    attribute powerConversionEfficiency : PercentValue = 91.0;

    port externalPowerIn : PowerInputPort;
    port batteryConnection : BatteryPort;
    port compressorPowerOut : PowerInputPort;
    port controllerPowerOut : PowerInputPort;

    action selectPowerSource {
      in item externalPower : ElectricalPower;
      in item batteryEnergy : BatteryEnergy;
      out item regulatedPower : ElectricalPower;
    }
  }

  part def UserInterfaceModule {
    attribute displayBrightness_percent : PercentValue = 70.0;
    attribute audibleAlarmLevel : Sound_dBA = 65.0;
    attribute buttonDebounce_ms : Real = 40.0;

    port userPort : UserInterfacePort;
    port controllerPort : ControlSignalPort;

    action presentStatusAndAlarms {
      in item status : DisplayStatus;
      in item alarm : AlarmMessage;
      out item prescription : UserPrescription;
    }
  }

  part def EmbeddedController {
    attribute controlLoopPeriod_ms : Real = 100.0;
    attribute firmwareVersion : String = "POC-DME-3.2.0";
    attribute oxygenPurityFaultThreshold : PercentValue = 82.0;
    attribute batteryLowThreshold : PercentValue = 15.0;
    attribute highTemperatureThreshold : Temperature_degC = 50.0;

    port sensorInput : ControlSignalPort;
    port valveCommand : ControlSignalPort;
    port userInterface : ControlSignalPort;
    port controllerPower : PowerInputPort;

    action regulateTherapy {
      in item prescription : UserPrescription;
      in item measuredStatus : DisplayStatus;
      in item breathSignal : BreathSignal;
      out item valveCommandStatus : DisplayStatus;
      out item alarm : AlarmMessage;
    }

    action evaluateSafety {
      in item measuredStatus : DisplayStatus;
      out item alarm : AlarmMessage;
    }
  }

  action def DeliverOxygenTherapy {
    in item ambientAir : AmbientAir;
    in item electricalPower : ElectricalPower;
    in item prescription : UserPrescription;
    in item patientBreath : BreathSignal;
    out item deliveredOxygen : DeliveredOxygenDose;
    out item exhaustGas : NitrogenRichExhaust;
    out item status : DisplayStatus;
    out item alarm : AlarmMessage;

    first start;

    action filterAir {
      in item ambientAir;
      out item filteredAir : FilteredAir;
    }

    then filterAir;

    action compressFilteredAir {
      in item filteredAir;
      in item electricalPower;
      out item compressedAir : CompressedAir;
    }

    then compressFilteredAir;

    action separateOxygen {
      in item compressedAir;
      out item oxygenProduct : OxygenEnrichedGas;
      out item nitrogenExhaust : NitrogenRichExhaust;
    }

    then separateOxygen;

    action bufferProduct {
      in item oxygenProduct;
      out item reservoirGas : OxygenEnrichedGas;
    }

    then bufferProduct;

    action senseGasAndBreath {
      in item reservoirGas;
      in item patientBreath;
      out item status : DisplayStatus;
    }

    then senseGasAndBreath;

    action meterDose {
      in item reservoirGas;
      in item prescription;
      in item patientBreath;
      out item deliveredOxygen : DeliveredOxygenDose;
    }

    then meterDose;

    action reportStatus {
      in item status;
      out item alarm : AlarmMessage;
    }

    then reportStatus;
  }

  state def OxygenConcentratorOperatingStates {
    attribute activeMode : TherapyMode;
    attribute activeAlarm : AlarmKind;

    entry action initializeSelfTest {
      out attribute activeMode = TherapyMode::standby;
    }

    state off;
    state powerUpSelfTest;
    state standby;
    state continuousTherapy;
    state pulseDoseTherapy;
    state alarmedTherapy;
    state serviceLockout;
    state controlledShutdown;

    transition initial then off;

    transition powerButtonPressed
      first off
      then powerUpSelfTest;

    transition selfTestPassed
      first powerUpSelfTest
      then standby;

    transition continuousPrescriptionAccepted
      first standby
      then continuousTherapy;

    transition pulsePrescriptionAccepted
      first standby
      then pulseDoseTherapy;

    transition lowPurityDuringContinuous
      first continuousTherapy
      then alarmedTherapy;

    transition blockedCannulaDuringPulse
      first pulseDoseTherapy
      then alarmedTherapy;

    transition alarmClearedReturnContinuous
      first alarmedTherapy
      then continuousTherapy;

    transition alarmClearedReturnPulse
      first alarmedTherapy
      then pulseDoseTherapy;

    transition unrecoverableCompressorFault
      first alarmedTherapy
      then serviceLockout;

    transition userShutdownFromStandby
      first standby
      then controlledShutdown;

    transition userShutdownFromContinuous
      first continuousTherapy
      then controlledShutdown;

    transition userShutdownFromPulse
      first pulseDoseTherapy
      then controlledShutdown;

    transition shutdownComplete
      first controlledShutdown
      then off;
  }

  part def PortableOxygenConcentrator :> DurableMedicalEquipment {
    :>> equipmentName = "Portable Oxygen Concentrator";
    :>> intendedUse = "Durable medical equipment that draws ambient air, removes nitrogen through pressure swing adsorption, and delivers oxygen-enriched gas to a patient at a prescribed flow or pulse dose.";
    :>> serviceLife_year = 5.0;
    :>> mass = 9.5;

    attribute modelNumber : String = "DME-POC-5000";
    attribute maximumContinuousFlow : Flow_L_per_min = 5.0;
    attribute minimumContinuousFlow : Flow_L_per_min = 0.5;
    attribute maximumPulseDose_mL : Real = 96.0;
    attribute nominalOxygenPurity : PercentValue = 93.0;
    attribute minimumTherapeuticPurity : PercentValue = 87.0;
    attribute maximumSoundLevel : Sound_dBA = 45.0;
    attribute operatingTemperatureMinimum : Temperature_degC = 5.0;
    attribute operatingTemperatureMaximum : Temperature_degC = 40.0;
    attribute minimumBatteryRuntimeAt2LPM : Duration_h = 4.0;

    port ambientAirIn : AirIntakePort;
    port patientConnection : PatientGasPort;
    port exhaustOutlet : ExhaustPort;
    port externalPower : PowerInputPort;
    port userInterface : UserInterfacePort;

    part intakeFilter : IntakeFilter;
    part compressor : CompressorAssembly;
    part sieveBedA : MolecularSieveBed;
    part sieveBedB : MolecularSieveBed;
    part productReservoir : ProductReservoir;
    part muffler : AcousticMuffler;
    part flowValve : FlowControlValve;
    part oxygenSensor : OxygenPuritySensor;
    part flowPressureSensor : FlowPressureSensor;
    part breathSensor : BreathDetectionSensor;
    part battery : BatteryPack;
    part powerManager : PowerManagementUnit;
    part controller : EmbeddedController;
    part ui : UserInterfaceModule;

    connect ambientAirIn to intakeFilter.inlet;
    connect intakeFilter.outlet to compressor.airIn;
    connect compressor.compressedAirOut to sieveBedA.compressedAirIn;
    connect compressor.compressedAirOut to sieveBedB.compressedAirIn;
    connect sieveBedA.oxygenProductOut to productReservoir.productIn;
    connect sieveBedB.oxygenProductOut to productReservoir.productIn;
    connect sieveBedA.nitrogenExhaustOut to exhaustOutlet;
    connect sieveBedB.nitrogenExhaustOut to exhaustOutlet;
    connect productReservoir.productOut to muffler.inlet;
    connect muffler.outlet to flowValve.oxygenIn;
    connect flowValve.patientOut to patientConnection;
    connect productReservoir.productOut to oxygenSensor.sampleIn;
    connect productReservoir.productOut to flowPressureSensor.gasSampleIn;
    connect patientConnection to breathSensor.patientInterface;
    connect externalPower to powerManager.externalPowerIn;
    connect battery.batteryInterface to powerManager.batteryConnection;
    connect powerManager.compressorPowerOut to compressor.electricalInput;
    connect powerManager.controllerPowerOut to controller.controllerPower;
    connect oxygenSensor.measurementOut to controller.sensorInput;
    connect flowPressureSensor.measurementOut to controller.sensorInput;
    connect breathSensor.measurementOut to controller.sensorInput;
    connect controller.valveCommand to flowValve.controllerInterface;
    connect userInterface to ui.userPort;
    connect ui.controllerPort to controller.userInterface;

    perform action primaryTherapy : DeliverOxygenTherapy;
    exhibit state operatingState : OxygenConcentratorOperatingStates;
  }

  requirement def PrimaryFunctionRequirement {
    subject concentrator : PortableOxygenConcentrator;

    doc /* The durable medical equipment shall provide the primary high-level function of producing oxygen-enriched respiratory gas from ambient air and delivering it to a patient through a nasal cannula according to a clinical prescription. */

    require constraint {
      concentrator.maximumContinuousFlow >= 5.0 and
      concentrator.minimumContinuousFlow <= 0.5 and
      concentrator.nominalOxygenPurity >= 90.0 and
      concentrator.minimumTherapeuticPurity >= 87.0
    }
  }

  requirement def OxygenPurityRequirement {
    subject concentrator : PortableOxygenConcentrator;

    require constraint {
      concentrator.minimumTherapeuticPurity >= 87.0
    }
  }

  requirement def ContinuousFlowRequirement {
    subject concentrator : PortableOxygenConcentrator;

    require constraint {
      concentrator.minimumContinuousFlow <= 0.5 and
      concentrator.maximumContinuousFlow >= 5.0
    }
  }

  requirement def BatteryRuntimeRequirement {
    subject concentrator : PortableOxygenConcentrator;

    require constraint {
      concentrator.minimumBatteryRuntimeAt2LPM >= 4.0
    }
  }

  requirement def AcousticRequirement {
    subject concentrator : PortableOxygenConcentrator;

    require constraint {
      concentrator.maximumSoundLevel <= 45.0
    }
  }

  requirement def SafetyAlarmRequirement {
    subject concentrator : PortableOxygenConcentrator;

    doc /* The equipment shall detect and annunciate low oxygen purity, low battery, blocked cannula, high internal temperature, compressor fault, and no-breath-detected conditions. */
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject concentrator = PortableOxygenConcentrator;
  }

  requirement oxygenPurity : OxygenPurityRequirement {
    subject concentrator = PortableOxygenConcentrator;
  }

  requirement continuousFlowCapability : ContinuousFlowRequirement {
    subject concentrator = PortableOxygenConcentrator;
  }

  requirement batteryRuntime : BatteryRuntimeRequirement {
    subject concentrator = PortableOxygenConcentrator;
  }

  requirement acousticLimit : AcousticRequirement {
    subject concentrator = PortableOxygenConcentrator;
  }

  requirement safetyAlarms : SafetyAlarmRequirement {
    subject concentrator = PortableOxygenConcentrator;
  }

  satisfy primaryFunction by PortableOxygenConcentrator;
  satisfy oxygenPurity by MolecularSieveBed;
  satisfy continuousFlowCapability by FlowControlValve;
  satisfy batteryRuntime by BatteryPack;
  satisfy acousticLimit by AcousticMuffler;
  satisfy safetyAlarms by EmbeddedController;

  part portableOxygenConcentratorSystem : PortableOxygenConcentrator {
    attribute deployedName : String = "Home-and-ambulatory oxygen therapy concentrator";
  }

}
