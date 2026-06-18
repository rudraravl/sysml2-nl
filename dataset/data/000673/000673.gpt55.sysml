package MammotomeBasedVacuumAssistedBiopsySystem {

  import ScalarValues::*;
  import SI::*;

  value type Pressure_kPa specializes Real {
    doc "Pressure measured in kilopascals; negative values indicate vacuum relative to atmospheric pressure."
  }

  value type FlowRate_mL_per_min specializes Real {
    doc "Volumetric flow rate measured in milliliters per minute."
  }

  value type Volume_mL specializes Real {
    doc "Volume measured in milliliters."
  }

  value type Length_mm specializes Real {
    doc "Length measured in millimeters."
  }

  value type Diameter_mm specializes Real {
    doc "Diameter measured in millimeters."
  }

  value type Mass_g specializes Real {
    doc "Mass measured in grams."
  }

  value type Force_N specializes Real {
    doc "Force measured in newtons."
  }

  value type Torque_mNm specializes Real {
    doc "Torque measured in millinewton-meters."
  }

  value type RotationalSpeed_rpm specializes Real {
    doc "Rotational speed measured in revolutions per minute."
  }

  value type Time_s specializes Real {
    doc "Time measured in seconds."
  }

  value type ElectricPotential_V specializes Real {
    doc "Voltage measured in volts."
  }

  value type ElectricCurrent_A specializes Real {
    doc "Electrical current measured in amperes."
  }

  value type ElectricPower_W specializes Real {
    doc "Electrical power measured in watts."
  }

  value type Temperature_C specializes Real {
    doc "Temperature measured in degrees Celsius."
  }

  value type SoundLevel_dBA specializes Real {
    doc "A-weighted sound level measured in decibels."
  }

  enum def SamplingMode {
    enum singleCore;
    enum sequentialCores;
    enum continuousCores;
    enum lavageOnly;
    enum primeOnly;
  }

  enum def NeedleGauge {
    enum gauge8;
    enum gauge10;
    enum gauge11;
    enum gauge12;
    enum gauge14;
  }

  enum def AlarmSeverity {
    enum advisory;
    enum caution;
    enum critical;
  }

  enum def SterilityState {
    enum sterilePackaged;
    enum sterileConnected;
    enum inUse;
    enum contaminated;
    enum discarded;
  }

  enum def ConsoleMode {
    enum poweredOff;
    enum selfTest;
    enum ready;
    enum armed;
    enum sampling;
    enum lavage;
    enum paused;
    enum faulted;
    enum shutdown;
  }

  item def ElectricalPower {
    attribute voltage : ElectricPotential_V;
    attribute current : ElectricCurrent_A;
    attribute power : ElectricPower_W;
    attribute frequency_Hz : Real;
  }

  item def ControlCommand {
    attribute commandId : String;
    attribute requestedMode : SamplingMode;
    attribute requestedVacuum : Pressure_kPa;
    attribute requestedCutterSpeed : RotationalSpeed_rpm;
    attribute requestedSampleCount : Integer;
    attribute enableCutter : Boolean;
    attribute enableVacuum : Boolean;
    attribute enableIrrigation : Boolean;
  }

  item def DeviceStatus {
    attribute mode : ConsoleMode;
    attribute vacuumPressure : Pressure_kPa;
    attribute cutterSpeed : RotationalSpeed_rpm;
    attribute sampleCount : Integer;
    attribute remainingCanisterVolume : Volume_mL;
    attribute disposableSterility : SterilityState;
    attribute faultPresent : Boolean;
    attribute message : String;
  }

  item def Vacuum {
    attribute pressure : Pressure_kPa;
    attribute flowRate : FlowRate_mL_per_min;
    attribute filtered : Boolean;
  }

  item def Saline {
    attribute volume : Volume_mL;
    attribute flowRate : FlowRate_mL_per_min;
    attribute sterile : Boolean;
    attribute temperature : Temperature_C;
  }

  item def Air {
    attribute pressure : Pressure_kPa;
    attribute flowRate : FlowRate_mL_per_min;
    attribute filtered : Boolean;
  }

  item def TissueTarget {
    attribute anatomicalRegion : String;
    attribute lesionDiameter : Diameter_mm;
    attribute lesionDepth : Length_mm;
    attribute plannedNeedlePathLength : Length_mm;
    attribute targetCoordinates_mm : String;
  }

  item def TissueSample {
    attribute sampleId : String;
    attribute length : Length_mm;
    attribute diameter : Diameter_mm;
    attribute mass : Mass_g;
    attribute acquisitionTime : Time_s;
    attribute vacuumAssisted : Boolean;
    attribute intactCore : Boolean;
    attribute radiopaqueMarkerPresent : Boolean;
  }

  item def WasteFluid {
    attribute volume : Volume_mL;
    attribute containsBlood : Boolean;
    attribute containsSaline : Boolean;
    attribute containedByClosedPath : Boolean;
  }

  item def AcousticAlarm {
    attribute severity : AlarmSeverity;
    attribute soundLevel : SoundLevel_dBA;
    attribute message : String;
  }

  item def VisualMessage {
    attribute severity : AlarmSeverity;
    attribute text : String;
    attribute flashing : Boolean;
  }

  item def ImagingRegistrationData {
    attribute modality : String;
    attribute targetCoordinates_mm : String;
    attribute needleTipCoordinates_mm : String;
    attribute registrationValid : Boolean;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def PoweredOutputPort {
    out item power : ElectricalPower;
  }

  port def ControlInputPort {
    in item command : ControlCommand;
  }

  port def ControlOutputPort {
    out item command : ControlCommand;
  }

  port def StatusInputPort {
    in item status : DeviceStatus;
  }

  port def StatusOutputPort {
    out item status : DeviceStatus;
  }

  port def VacuumSupplyPort {
    out item vacuum : Vacuum;
  }

  port def VacuumReceivePort {
    in item vacuum : Vacuum;
  }

  port def SalineSupplyPort {
    out item saline : Saline;
  }

  port def SalineReceivePort {
    in item saline : Saline;
  }

  port def TissueInputPort {
    in item tissue : TissueSample;
  }

  port def TissueOutputPort {
    out item tissue : TissueSample;
  }

  port def WasteInputPort {
    in item waste : WasteFluid;
  }

  port def WasteOutputPort {
    out item waste : WasteFluid;
  }

  port def AlarmOutputPort {
    out item alarm : AcousticAlarm;
    out item message : VisualMessage;
  }

  port def ImagingDataPort {
    in item registration : ImagingRegistrationData;
  }

  port def FootSwitchPort {
    out item command : ControlCommand;
  }

  interface def ConsoleToHandpiecePowerInterface {
    end source : PoweredOutputPort;
    end load : PowerPort;
  }

  interface def ConsoleToHandpieceControlInterface {
    end controller : ControlOutputPort;
    end actuator : ControlInputPort;
  }

  interface def ConsoleToProbeVacuumInterface {
    end source : VacuumSupplyPort;
    end sink : VacuumReceivePort;
  }

  interface def ConsoleToProbeSalineInterface {
    end source : SalineSupplyPort;
    end sink : SalineReceivePort;
  }

  interface def ProbeToCanisterWasteInterface {
    end source : WasteOutputPort;
    end sink : WasteInputPort;
  }

  interface def ProbeToSampleTrayInterface {
    end source : TissueOutputPort;
    end sink : TissueInputPort;
  }

  constraint def VacuumOperatingRange {
    in pressure : Pressure_kPa;
    constraint validVacuum {
      pressure >= -85.0 and pressure <= -45.0
    }
  }

  constraint def CutterSpeedRange {
    in speed : RotationalSpeed_rpm;
    constraint validSpeed {
      speed >= 900.0 and speed <= 3600.0
    }
  }

  constraint def CanisterCapacityLimit {
    in usedVolume : Volume_mL;
    in capacity : Volume_mL;
    constraint notOverfilled {
      usedVolume <= capacity * 0.90
    }
  }

  constraint def TissueSampleAdequacy {
    in length : Length_mm;
    in intactCore : Boolean;
    constraint adequate {
      length >= 8.0 and intactCore == true
    }
  }

  action def RunSelfTest {
    out status : DeviceStatus;
    attribute maximumDuration : Time_s = 20.0;
    doc "Checks processor, display, sensors, pump, cutter drive, foot switch, canister presence, and disposable recognition."
  }

  action def PrimeFluidPath {
    in sterileSaline : Saline;
    out primedStatus : DeviceStatus;
    attribute primeVolume : Volume_mL = 8.0;
    attribute maximumPrimeTime : Time_s = 15.0;
  }

  action def GenerateVacuum {
    in setPoint : Pressure_kPa;
    out deliveredVacuum : Vacuum;
    attribute nominalSetPoint : Pressure_kPa = -65.0;
    attribute settlingTime : Time_s = 2.0;
  }

  action def RegulateVacuum {
    in measuredVacuum : Vacuum;
    in commandedVacuum : Pressure_kPa;
    out regulatedVacuum : Vacuum;
    assert constraint regulatedRange : VacuumOperatingRange {
      pressure = commandedVacuum;
    }
  }

  action def RotateCutter {
    in commandedSpeed : RotationalSpeed_rpm;
    out actualSpeed : RotationalSpeed_rpm;
    attribute nominalSpeed : RotationalSpeed_rpm = 2400.0;
    assert constraint speedRange : CutterSpeedRange {
      speed = commandedSpeed;
    }
  }

  action def AdvanceCutterAcrossAperture {
    in cutterSpeed : RotationalSpeed_rpm;
    out cutComplete : Boolean;
    attribute cutterStrokeLength : Length_mm = 22.0;
    attribute maximumStrokeTime : Time_s = 4.0;
  }

  action def CaptureTissueByVacuum {
    in target : TissueTarget;
    in vacuum : Vacuum;
    out capturedCore : TissueSample;
    attribute sideApertureLength : Length_mm = 20.0;
    attribute captureTime : Time_s = 2.5;
  }

  action def TransportSampleToChamber {
    in cutCore : TissueSample;
    in transportVacuum : Vacuum;
    out collectedSample : TissueSample;
    attribute transportTime : Time_s = 3.0;
  }

  action def IrrigateAndClearAperture {
    in saline : Saline;
    in vacuum : Vacuum;
    out waste : WasteFluid;
    attribute lavageVolume : Volume_mL = 5.0;
    attribute clearTime : Time_s = 5.0;
  }

  action def StoreSample {
    in sample : TissueSample;
    out storedSample : TissueSample;
    attribute labelApplied : Boolean = true;
  }

  action def DetectFaults {
    in status : DeviceStatus;
    out alarm : AcousticAlarm;
    out visual : VisualMessage;
    attribute vacuumLossThreshold : Pressure_kPa = -35.0;
    attribute overfillMargin : Volume_mL = 50.0;
  }

  action def VacuumAssistedBiopsyProcedure {
    in target : TissueTarget;
    in mode : SamplingMode;
    out samples : TissueSample[1..24];
    out waste : WasteFluid;

    action selfTest : RunSelfTest;
    action prime : PrimeFluidPath;
    action generateVacuum : GenerateVacuum;
    action capture : CaptureTissueByVacuum;
    action rotate : RotateCutter;
    action cut : AdvanceCutterAcrossAperture;
    action transport : TransportSampleToChamber;
    action irrigate : IrrigateAndClearAperture;
    action store : StoreSample;
    action monitor : DetectFaults;

    succession s1 first selfTest then prime;
    succession s2 first prime then generateVacuum;
    succession s3 first generateVacuum then capture;
    succession s4 first capture then rotate;
    succession s5 first rotate then cut;
    succession s6 first cut then transport;
    succession s7 first transport then store;
    succession s8 first store then irrigate;
    succession s9 first irrigate then monitor;

    doc "High-level primary function: use controlled vacuum to draw targeted breast tissue into a side aperture, cut the captured tissue with a rotating cutter, transport the tissue core to a sample chamber, and repeat sampling through a single needle placement under operator and imaging guidance."
  }

  state def MammotomeOperationalStates {
    state off;
    state selfTesting;
    state ready;
    state priming;
    state armed;
    state sampling;
    state lavage;
    state paused;
    state faulted;
    state shutdown;

    transition powerOn first off then selfTesting;
    transition selfTestPassed first selfTesting then ready;
    transition selfTestFailed first selfTesting then faulted;
    transition primeRequested first ready then priming;
    transition primeComplete first priming then ready;
    transition armRequested first ready then armed;
    transition footSwitchPressed first armed then sampling;
    transition sampleCycleComplete first sampling then armed;
    transition lavageRequested first armed then lavage;
    transition lavageComplete first lavage then armed;
    transition pauseRequested first sampling then paused;
    transition resumeRequested first paused then sampling;
    transition faultDetectedFromReady first ready then faulted;
    transition faultDetectedFromArmed first armed then faulted;
    transition faultDetectedFromSampling first sampling then faulted;
    transition clearFault first faulted then ready;
    transition shutdownRequestedFromReady first ready then shutdown;
    transition shutdownRequestedFromFault first faulted then shutdown;
    transition shutdownComplete first shutdown then off;
  }

  part def VacuumPump {
    port powerIn : PowerPort;
    port vacuumOut : VacuumSupplyPort;
    port statusOut : StatusOutputPort;

    attribute maximumVacuum : Pressure_kPa = -85.0;
    attribute nominalVacuum : Pressure_kPa = -65.0;
    attribute maximumFlowRate : FlowRate_mL_per_min = 900.0;
    attribute acousticNoise : SoundLevel_dBA = 58.0;

    perform action generate : GenerateVacuum;
    perform action regulate : RegulateVacuum;
  }

  part def CutterMotorDrive {
    port powerIn : PowerPort;
    port commandIn : ControlInputPort;
    port statusOut : StatusOutputPort;

    attribute maximumSpeed : RotationalSpeed_rpm = 3600.0;
    attribute nominalSpeed : RotationalSpeed_rpm = 2400.0;
    attribute stallTorqueLimit : Torque_mNm = 75.0;
    attribute currentLimit : ElectricCurrent_A = 2.5;

    perform action rotate : RotateCutter;
  }

  part def IrrigationPump {
    port powerIn : PowerPort;
    port salineOut : SalineSupplyPort;
    port commandIn : ControlInputPort;

    attribute nominalFlowRate : FlowRate_mL_per_min = 60.0;
    attribute primeVolume : Volume_mL = 8.0;
    attribute lavageVolumePerCycle : Volume_mL = 5.0;

    perform action prime : PrimeFluidPath;
  }

  part def VacuumCanister {
    port wasteIn : WasteInputPort;
    port statusOut : StatusOutputPort;

    attribute totalCapacity : Volume_mL = 500.0;
    attribute overfillStopVolume : Volume_mL = 450.0;
    attribute currentVolume : Volume_mL = 0.0;
    attribute biohazardClosedPath : Boolean = true;

    assert constraint capacityProtected : CanisterCapacityLimit {
      usedVolume = currentVolume;
      capacity = totalCapacity;
    }
  }

  part def UserDisplay {
    port powerIn : PowerPort;
    port statusIn : StatusInputPort;
    port commandOut : ControlOutputPort;
    port alarmOut : AlarmOutputPort;

    attribute diagonalSize : Length_mm = 177.8;
    attribute touchEnabled : Boolean = true;
    attribute minimumBrightness_cd_per_m2 : Real = 350.0;
  }

  part def AlarmModule {
    port powerIn : PowerPort;
    port alarmOut : AlarmOutputPort;

    attribute maximumSoundLevel : SoundLevel_dBA = 75.0;
    attribute criticalAlarmSoundLevel : SoundLevel_dBA = 65.0;
  }

  part def EmbeddedController {
    port powerIn : PowerPort;
    port operatorCommandIn : ControlInputPort;
    port footSwitchCommandIn : ControlInputPort;
    port imagingIn : ImagingDataPort;
    port pumpCommandOut : ControlOutputPort;
    port motorCommandOut : ControlOutputPort;
    port irrigationCommandOut : ControlOutputPort;
    port statusOut : StatusOutputPort;
    port alarmOut : AlarmOutputPort;

    attribute watchdogTimeout : Time_s = 0.5;
    attribute sampleCycleTimeout : Time_s = 30.0;
    attribute maximumSamplesPerInsertion : Integer = 24;
    attribute softwareSafetyClass : String = "medical device active control with protective monitoring";

    perform action monitorFaults : DetectFaults;
  }

  part def ControlConsole {
    port powerIn : PowerPort;
    port handpiecePowerOut : PoweredOutputPort;
    port handpieceCommandOut : ControlOutputPort;
    port handpieceStatusIn : StatusInputPort;
    port vacuumOut : VacuumSupplyPort;
    port salineOut : SalineSupplyPort;
    port wasteIn : WasteInputPort;
    port footSwitchIn : ControlInputPort;
    port imagingIn : ImagingDataPort;
    port operatorCommandIn : ControlInputPort;
    port statusOut : StatusOutputPort;
    port alarmOut : AlarmOutputPort;

    part controller : EmbeddedController;
    part vacuumPump : VacuumPump;
    part cutterDrive : CutterMotorDrive;
    part irrigationPump : IrrigationPump;
    part canister : VacuumCanister;
    part display : UserDisplay;
    part alarmModule : AlarmModule;

    attribute inputVoltage : ElectricPotential_V = 120.0;
    attribute maximumInputPower : ElectricPower_W = 250.0;
    attribute nominalVacuumSetPoint : Pressure_kPa = -65.0;
    attribute nominalCutterSpeed : RotationalSpeed_rpm = 2400.0;
    attribute enclosureIngressProtection : String = "drip-resistant clinical equipment enclosure";

    connect powerIn to controller.powerIn;
    connect powerIn to vacuumPump.powerIn;
    connect powerIn to cutterDrive.powerIn;
    connect powerIn to irrigationPump.powerIn;
    connect powerIn to display.powerIn;
    connect powerIn to alarmModule.powerIn;

    connect controller.pumpCommandOut to cutterDrive.commandIn;
    connect controller.motorCommandOut to cutterDrive.commandIn;
    connect controller.irrigationCommandOut to irrigationPump.commandIn;
    connect controller.statusOut to display.statusIn;
    connect controller.alarmOut to alarmModule.alarmOut;
    connect footSwitchIn to controller.footSwitchCommandIn;
    connect operatorCommandIn to controller.operatorCommandIn;
    connect imagingIn to controller.imagingIn;

    connect vacuumPump.vacuumOut to vacuumOut;
    connect irrigationPump.salineOut to salineOut;
    connect wasteIn to canister.wasteIn;
    connect cutterDrive.statusOut to handpieceStatusIn;
    connect statusOut to controller.statusOut;
    connect alarmOut to alarmModule.alarmOut;

    assert constraint consoleVacuumRange : VacuumOperatingRange {
      pressure = nominalVacuumSetPoint;
    }

    exhibit state operationalState : MammotomeOperationalStates;
  }

  part def RotatingCutter {
    port powerIn : PowerPort;
    port commandIn : ControlInputPort;
    port tissueOut : TissueOutputPort;

    attribute cutterOuterDiameter : Diameter_mm = 3.0;
    attribute cuttingWindowLength : Length_mm = 20.0;
    attribute maximumStrokeForce : Force_N = 18.0;
    attribute nominalSpeed : RotationalSpeed_rpm = 2400.0;

    perform action rotate : RotateCutter;
    perform action advance : AdvanceCutterAcrossAperture;
  }

  part def ProbeCannula {
    port vacuumIn : VacuumReceivePort;
    port salineIn : SalineReceivePort;
    port tissueOut : TissueOutputPort;
    port wasteOut : WasteOutputPort;

    attribute gauge : NeedleGauge = NeedleGauge::gauge11;
    attribute outerDiameter : Diameter_mm = 3.05;
    attribute apertureLength : Length_mm = 20.0;
    attribute insertionLength : Length_mm = 120.0;
    attribute echogenicTip : Boolean = true;
    attribute radiopaqueMarkerCompatible : Boolean = true;

    perform action capture : CaptureTissueByVacuum;
    perform action irrigate : IrrigateAndClearAperture;
  }

  part def SampleChamber {
    port tissueIn : TissueInputPort;
    port tissueOut : TissueOutputPort;
    port statusOut : StatusOutputPort;

    attribute chamberCapacity : Integer = 24;
    attribute sampleSlotCount : Integer = 12;
    attribute sealedFromOperatorContact : Boolean = true;
    attribute removableCassette : Boolean = true;

    perform action store : StoreSample;
  }

  part def VacuumAssistedProbe {
    port vacuumIn : VacuumReceivePort;
    port salineIn : SalineReceivePort;
    port cutterPowerIn : PowerPort;
    port cutterCommandIn : ControlInputPort;
    port tissueOut : TissueOutputPort;
    port wasteOut : WasteOutputPort;
    port statusOut : StatusOutputPort;

    part cannula : ProbeCannula;
    part cutter : RotatingCutter;
    part chamber : SampleChamber;

    attribute sterility : SterilityState = SterilityState::sterilePackaged;
    attribute singleUse : Boolean = true;
    attribute maximumSamplesPerInsertion : Integer = 24;
    attribute targetCompatibleLesionDiameter : Diameter_mm = 25.0;

    connect vacuumIn to cannula.vacuumIn;
    connect salineIn to cannula.salineIn;
    connect cutterPowerIn to cutter.powerIn;
    connect cutterCommandIn to cutter.commandIn;
    connect cannula.tissueOut to chamber.tissueIn;
    connect cutter.tissueOut to chamber.tissueIn;
    connect chamber.tissueOut to tissueOut;
    connect cannula.wasteOut to wasteOut;
    connect chamber.statusOut to statusOut;
  }

  part def BiopsyHandpiece {
    port powerIn : PowerPort;
    port commandIn : ControlInputPort;
    port statusOut : StatusOutputPort;
    port probePowerOut : PoweredOutputPort;
    port probeCommandOut : ControlOutputPort;

    attribute gripDiameter : Diameter_mm = 36.0;
    attribute mass : Mass_g = 420.0;
    attribute maximumSurfaceTemperature : Temperature_C = 41.0;
    attribute sterileDrapeCompatible : Boolean = true;

    part motorDriveCoupling : CutterMotorDrive;

    connect powerIn to motorDriveCoupling.powerIn;
    connect commandIn to motorDriveCoupling.commandIn;
    connect motorDriveCoupling.statusOut to statusOut;
    connect probePowerOut to powerIn;
    connect probeCommandOut to commandIn;
  }

  part def FootPedal {
    port commandOut : FootSwitchPort;

    attribute cableLength : Length_mm = 3000.0;
    attribute sealedForCleaning : Boolean = true;
    attribute twoStageSwitch : Boolean = true;
    attribute firstStageArmsVacuum : Boolean = true;
    attribute secondStageInitiatesCut : Boolean = true;
  }

  part def SampleManagementTray {
    port tissueIn : TissueInputPort;

    attribute labeledSlots : Integer = 24;
    attribute formalinCompatible : Boolean = true;
    attribute minimumSampleLengthAccepted : Length_mm = 8.0;
  }

  part def ImagingGuidanceInterface {
    port registrationIn : ImagingDataPort;

    attribute supportedModalities : String = "stereotactic mammography, ultrasound, MRI-guided targeting";
    attribute registrationUpdatePeriod : Time_s = 1.0;
    attribute displaysNeedlePath : Boolean = true;
  }

  part def PatientInterface {
    port tissueAccess : TissueOutputPort;

    attribute target : TissueTarget;
    attribute localAnesthesiaRequired : Boolean = true;
    attribute compressionCompatible : Boolean = true;
  }

  part def ClinicalOperator {
    port commandOut : ControlOutputPort;
    port alarmIn : AlarmOutputPort;

    attribute trainedForVacuumAssistedBreastBiopsy : Boolean = true;
    attribute verifiesSpecimenRadiography : Boolean = true;
  }

  part def MammotomeBiopsySystem {
    doc "A Mammotome-based vacuum-assisted biopsy system whose primary high-level function is to acquire diagnostically useful breast tissue cores by drawing tissue into a side aperture with controlled vacuum, cutting it with a rotating cutter, and transporting samples to a collection chamber through a single probe placement."

    port acPowerIn : PowerPort;
    port operatorCommandIn : ControlInputPort;
    port imagingDataIn : ImagingDataPort;
    port alarmOut : AlarmOutputPort;
    port collectedTissueOut : TissueOutputPort;
    port wasteOut : WasteOutputPort;

    part console : ControlConsole;
    part handpiece : BiopsyHandpiece;
    part disposableProbe : VacuumAssistedProbe;
    part footPedal : FootPedal;
    part sampleTray : SampleManagementTray;
    part imagingInterface : ImagingGuidanceInterface;

    attribute primaryFunction : String = "Controlled vacuum-assisted acquisition, cutting, transport, and preservation of intact breast tissue biopsy cores.";
    attribute maximumSamplesPerInsertion : Integer = 24;
    attribute nominalVacuumSetPoint : Pressure_kPa = -65.0;
    attribute nominalCutterSpeed : RotationalSpeed_rpm = 2400.0;
    attribute maximumSampleCycleTime : Time_s = 30.0;
    attribute systemMass : Mass_g = 18500.0;

    connect acPowerIn to console.powerIn;
    connect operatorCommandIn to console.operatorCommandIn;
    connect imagingDataIn to console.imagingIn;
    connect footPedal.commandOut to console.footSwitchIn;

    connect console.handpiecePowerOut to handpiece.powerIn;
    connect console.handpieceCommandOut to handpiece.commandIn;
    connect handpiece.statusOut to console.handpieceStatusIn;

    connect handpiece.probePowerOut to disposableProbe.cutterPowerIn;
    connect handpiece.probeCommandOut to disposableProbe.cutterCommandIn;

    connect console.vacuumOut to disposableProbe.vacuumIn;
    connect console.salineOut to disposableProbe.salineIn;
    connect disposableProbe.wasteOut to console.wasteIn;
    connect disposableProbe.tissueOut to sampleTray.tissueIn;
    connect disposableProbe.tissueOut to collectedTissueOut;
    connect disposableProbe.wasteOut to wasteOut;
    connect console.alarmOut to alarmOut;
    connect imagingDataIn to imagingInterface.registrationIn;

    flow suppliedVacuum : Vacuum from console.vacuumOut to disposableProbe.vacuumIn;
    flow suppliedSaline : Saline from console.salineOut to disposableProbe.salineIn;
    flow acquiredTissue : TissueSample from disposableProbe.tissueOut to sampleTray.tissueIn;
    flow collectedWaste : WasteFluid from disposableProbe.wasteOut to console.wasteIn;

    perform action primaryBiopsyFunction : VacuumAssistedBiopsyProcedure;

    assert constraint systemVacuumRange : VacuumOperatingRange {
      pressure = nominalVacuumSetPoint;
    }

    assert constraint systemCutterSpeedRange : CutterSpeedRange {
      speed = nominalCutterSpeed;
    }

    exhibit state operationalState : MammotomeOperationalStates;
  }

  requirement <'MB-001'> PrimaryFunction {
    subject system : MammotomeBiopsySystem;
    doc "The system shall acquire intact tissue cores from a targeted breast lesion using vacuum assistance and a rotating cutter, transporting each sample to a collection chamber without requiring full probe removal between samples."
    require constraint {
      system.maximumSamplesPerInsertion >= 12
    }
  }

  requirement <'MB-002'> ControlledVacuum {
    subject system : MammotomeBiopsySystem;
    doc "The system shall provide controlled vacuum at the probe aperture sufficient to draw tissue into the sampling window."
    require constraint {
      system.nominalVacuumSetPoint >= -85.0 and system.nominalVacuumSetPoint <= -45.0
    }
  }

  requirement <'MB-003'> CutterPerformance {
    subject system : MammotomeBiopsySystem;
    doc "The system shall rotate and advance a cutter across the side aperture to separate captured tissue from surrounding tissue."
    require constraint {
      system.nominalCutterSpeed >= 900.0 and system.nominalCutterSpeed <= 3600.0
    }
  }

  requirement <'MB-004'> SampleCycleTime {
    subject system : MammotomeBiopsySystem;
    doc "The system shall complete one vacuum capture, cutting, transport, and chamber storage cycle within the specified time."
    require constraint {
      system.maximumSampleCycleTime <= 30.0
    }
  }

  requirement <'MB-005'> ClosedWastePath {
    subject system : MammotomeBiopsySystem;
    doc "The system shall route aspirated fluid and biological waste to a closed canister to reduce operator exposure."
    require constraint {
      system.console.canister.biohazardClosedPath == true
    }
  }

  requirement <'MB-006'> CanisterOverfillProtection {
    subject system : MammotomeBiopsySystem;
    doc "The system shall stop vacuum-assisted sampling before the waste canister exceeds ninety percent of rated capacity."
    require constraint {
      system.console.canister.overfillStopVolume <= system.console.canister.totalCapacity * 0.90
    }
  }

  requirement <'MB-007'> SingleUseSterileProbe {
    subject system : MammotomeBiopsySystem;
    doc "The tissue-contacting probe shall be sterile before use and intended for single-patient use."
    require constraint {
      system.disposableProbe.singleUse == true
    }
  }

  requirement <'MB-008'> OperatorFeedback {
    subject system : MammotomeBiopsySystem;
    doc "The system shall provide audible and visual alarms for vacuum loss, cutter stall, canister overfill, disposable mismatch, and controller fault."
    require constraint {
      system.console.alarmModule.criticalAlarmSoundLevel >= 60.0
    }
  }

  requirement <'MB-009'> ImagingCompatibility {
    subject system : MammotomeBiopsySystem;
    doc "The system shall accept target registration information from common breast-biopsy imaging guidance workflows."
    require constraint {
      system.imagingInterface.displaysNeedlePath == true
    }
  }

  requirement <'MB-010'> TissueAdequacy {
    subject sample : TissueSample;
    doc "A collected diagnostic sample shall be an intact tissue core with minimum length of eight millimeters."
    require constraint {
      sample.length >= 8.0 and sample.intactCore == true
    }
  }

  part clinicalUseConfiguration {
    part operator : ClinicalOperator;
    part patient : PatientInterface;
    part mammotomeSystem : MammotomeBiopsySystem;

    connect operator.commandOut to mammotomeSystem.operatorCommandIn;
    connect mammotomeSystem.alarmOut to operator.alarmIn;
    connect mammotomeSystem.imagingDataIn to mammotomeSystem.imagingInterface.registrationIn;
  }

  satisfy PrimaryFunction by MammotomeBiopsySystem::primaryBiopsyFunction;
  satisfy ControlledVacuum by MammotomeBiopsySystem::console::vacuumPump;
  satisfy CutterPerformance by MammotomeBiopsySystem::disposableProbe::cutter;
  satisfy SampleCycleTime by MammotomeBiopsySystem::primaryBiopsyFunction;
  satisfy ClosedWastePath by MammotomeBiopsySystem::console::canister;
  satisfy CanisterOverfillProtection by MammotomeBiopsySystem::console::canister;
  satisfy SingleUseSterileProbe by MammotomeBiopsySystem::disposableProbe;
  satisfy OperatorFeedback by MammotomeBiopsySystem::console::alarmModule;
  satisfy ImagingCompatibility by MammotomeBiopsySystem::imagingInterface;

}
