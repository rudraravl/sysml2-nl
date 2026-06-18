package ElectromechanicalFilmModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Voltage {
    :>> baseType = Real;
    attribute unit = "V";
    attribute minValue : Real = 0.0;
  }

  attribute def ElectricCurrent {
    :>> baseType = Real;
    attribute unit = "A";
  }

  attribute def ElectricCharge {
    :>> baseType = Real;
    attribute unit = "C";
  }

  attribute def Capacitance {
    :>> baseType = Real;
    attribute unit = "F";
  }

  attribute def ElectricFieldStrength {
    :>> baseType = Real;
    attribute unit = "V/m";
  }

  attribute def Force {
    :>> baseType = Real;
    attribute unit = "N";
  }

  attribute def Displacement {
    :>> baseType = Real;
    attribute unit = "m";
  }

  attribute def Strain {
    :>> baseType = Real;
    attribute unit = "1";
  }

  attribute def Stress {
    :>> baseType = Real;
    attribute unit = "Pa";
  }

  attribute def Thickness {
    :>> baseType = Real;
    attribute unit = "m";
  }

  attribute def Area {
    :>> baseType = Real;
    attribute unit = "m^2";
  }

  attribute def Frequency {
    :>> baseType = Real;
    attribute unit = "Hz";
  }

  attribute def Temperature {
    :>> baseType = Real;
    attribute unit = "degC";
  }

  attribute def Power {
    :>> baseType = Real;
    attribute unit = "W";
  }

  attribute def Energy {
    :>> baseType = Real;
    attribute unit = "J";
  }

  attribute def Time {
    :>> baseType = Real;
    attribute unit = "s";
  }

  attribute def Ratio {
    :>> baseType = Real;
    attribute unit = "1";
  }

  attribute def BooleanStatus {
    :>> baseType = Boolean;
  }

  enum def FilmModeKind {
    enum idle;
    enum charged;
    enum actuating;
    enum sensing;
    enum faulted;
    enum discharged;
  }

  enum def FaultKind {
    enum none;
    enum overVoltage;
    enum overCurrent;
    enum overTemperature;
    enum dielectricBreakdownRisk;
    enum displacementLimitExceeded;
    enum electrodeContinuityLoss;
  }

  item def VoltageCommand {
    attribute requestedVoltage : Voltage;
    attribute rampTime : Time;
    attribute waveformFrequency : Frequency;
  }

  item def VoltageFeedback {
    attribute measuredVoltage : Voltage;
    attribute measuredCurrent : ElectricCurrent;
    attribute storedCharge : ElectricCharge;
  }

  item def MechanicalCommand {
    attribute requestedDisplacement : Displacement;
    attribute requestedForce : Force;
    attribute requestedFrequency : Frequency;
  }

  item def MechanicalOutput {
    attribute deliveredDisplacement : Displacement;
    attribute deliveredForce : Force;
    attribute filmStrain : Strain;
    attribute outputFrequency : Frequency;
  }

  item def ThermalStatus {
    attribute filmTemperature : Temperature;
    attribute driverTemperature : Temperature;
    attribute coolingPower : Power;
  }

  item def HealthStatus {
    attribute mode : FilmModeKind;
    attribute fault : FaultKind;
    attribute ready : BooleanStatus;
    attribute safeToTouch : BooleanStatus;
  }

  item def ElectricalEnergyFlow {
    attribute voltage : Voltage;
    attribute current : ElectricCurrent;
    attribute power : Power;
    attribute charge : ElectricCharge;
  }

  item def MechanicalEnergyFlow {
    attribute force : Force;
    attribute displacementRate : Real;
    attribute mechanicalPower : Power;
  }

  port def CommandInputPort {
    in item mechanicalCommand : MechanicalCommand;
  }

  port def ControlSignalPort {
    out item voltageCommand : VoltageCommand;
  }

  port def ElectricalDrivePort {
    out item driveEnergy : ElectricalEnergyFlow;
    in item voltageFeedback : VoltageFeedback;
  }

  port def FilmElectricalPort {
    in item appliedEnergy : ElectricalEnergyFlow;
    out item electricalResponse : VoltageFeedback;
  }

  port def MechanicalOutputPort {
    out item mechanicalOutput : MechanicalOutput;
  }

  port def MechanicalLoadPort {
    in item mechanicalOutput : MechanicalOutput;
  }

  port def SensorPort {
    out item voltageFeedback : VoltageFeedback;
    out item thermalStatus : ThermalStatus;
    out item mechanicalOutput : MechanicalOutput;
  }

  port def StatusPort {
    out item healthStatus : HealthStatus;
  }

  port def CoolingPort {
    in item thermalStatus : ThermalStatus;
  }

  constraint def ElectricFieldLimit {
    in voltage : Voltage;
    in thickness : Thickness;
    in maximumField : ElectricFieldStrength;
    constraint { voltage / thickness <= maximumField }
  }

  constraint def CapacitiveEnergy {
    in capacitance : Capacitance;
    in voltage : Voltage;
    out storedEnergy : Energy;
    constraint { storedEnergy == 0.5 * capacitance * voltage * voltage }
  }

  constraint def FilmActuationApproximation {
    in electricField : ElectricFieldStrength;
    in electrostrictiveCoefficient : Real;
    out inducedStrain : Strain;
    constraint { inducedStrain == electrostrictiveCoefficient * electricField * electricField }
  }

  constraint def MechanicalOutputLimit {
    in displacement : Displacement;
    in maximumDisplacement : Displacement;
    in force : Force;
    in maximumForce : Force;
    constraint {
      displacement <= maximumDisplacement and
      force <= maximumForce
    }
  }

  action def ComputeVoltageForRequestedDisplacement {
    in requestedDisplacement : Displacement;
    in activeLength : Displacement;
    in filmThickness : Thickness;
    in electrostrictiveCoefficient : Real;
    in maximumVoltage : Voltage;
    out commandedVoltage : Voltage;

    action computeRequiredStrain;
    action computeRequiredField;
    action limitVoltage;

    first computeRequiredStrain then computeRequiredField then limitVoltage;

    constraint {
      commandedVoltage <= maximumVoltage
    }
  }

  action def RampHighVoltage {
    in targetVoltage : Voltage;
    in rampTime : Time;
    out appliedVoltage : Voltage;
    out rampComplete : BooleanStatus;

    action initializeRamp;
    action increaseVoltage;
    action verifyCurrent;
    action holdTarget;

    first initializeRamp then increaseVoltage then verifyCurrent then holdTarget;
  }

  action def ConvertElectricalFieldToMechanicalMotion {
    in appliedVoltage : Voltage;
    in filmThickness : Thickness;
    in activeLength : Displacement;
    in electrostrictiveCoefficient : Real;
    out generatedDisplacement : Displacement;
    out generatedStrain : Strain;

    action computeElectricField;
    action computeStrain;
    action computeDisplacement;

    first computeElectricField then computeStrain then computeDisplacement;
  }

  action def SenseFilmResponse {
    in measuredCharge : ElectricCharge;
    in measuredVoltage : Voltage;
    in filmCapacitance : Capacitance;
    out estimatedDisplacement : Displacement;
    out feedback : VoltageFeedback;

    action sampleElectricalState;
    action estimateMechanicalState;
    action publishFeedback;

    first sampleElectricalState then estimateMechanicalState then publishFeedback;
  }

  action def DischargeFilmSafely {
    in storedEnergy : Energy;
    in dischargeResistance : Real;
    out terminalVoltage : Voltage;
    out safeToTouch : BooleanStatus;

    action connectBleedResistor;
    action monitorVoltageDecay;
    action isolateElectrodes;

    first connectBleedResistor then monitorVoltageDecay then isolateElectrodes;
  }

  state def FilmOperationalStateMachine {
    in powerAvailable : BooleanStatus;
    in commandPresent : BooleanStatus;
    in measuredVoltage : Voltage;
    in measuredTemperature : Temperature;
    in faultDetected : BooleanStatus;
    out mode : FilmModeKind;
    out safeToTouch : BooleanStatus;

    state off {
      entry action setOffStatus;
    }

    state idle {
      entry action setIdleStatus;
    }

    state charging {
      entry action enableHighVoltageDriver;
      do action RampHighVoltage;
    }

    state actuating {
      entry action closeControlLoop;
      do action ConvertElectricalFieldToMechanicalMotion;
    }

    state sensing {
      do action SenseFilmResponse;
    }

    state discharging {
      entry action disableHighVoltageCommand;
      do action DischargeFilmSafely;
    }

    state faulted {
      entry action latchFault;
      do action DischargeFilmSafely;
    }

    transition initial_to_off first start then off;
    transition off_to_idle first off if powerAvailable then idle;
    transition idle_to_charging first idle if commandPresent then charging;
    transition charging_to_actuating first charging if measuredVoltage > 0.0 then actuating;
    transition actuating_to_sensing first actuating then sensing;
    transition sensing_to_actuating first sensing if commandPresent then actuating;
    transition actuating_to_discharging first actuating if not commandPresent then discharging;
    transition discharging_to_idle first discharging if safeToTouch then idle;
    transition any_to_faulted first off if faultDetected then faulted;
    transition idle_to_faulted first idle if faultDetected then faulted;
    transition charging_to_faulted first charging if faultDetected then faulted;
    transition actuating_to_faulted first actuating if faultDetected then faulted;
    transition sensing_to_faulted first sensing if faultDetected then faulted;
    transition faulted_to_idle first faulted if not faultDetected and safeToTouch then idle;
  }

  part def CompliantSubstrate {
    attribute materialName : String = "polyimide carrier";
    attribute thickness : Thickness = 0.000025;
    attribute activeArea : Area = 0.0025;
    attribute maximumTemperature : Temperature = 85.0;
    attribute elasticModulus : Stress = 2500000000.0;
  }

  part def ConductiveElectrode {
    attribute materialName : String = "carbon-silver compliant electrode";
    attribute sheetResistance : Real = 50.0;
    attribute thickness : Thickness = 0.000005;
    attribute activeArea : Area = 0.0025;
    port electrical : FilmElectricalPort;
  }

  part def ElectromechanicalPolymerLayer {
    attribute materialName : String = "dielectric elastomer electromechanical film";
    attribute thickness : Thickness = 0.000050;
    attribute activeArea : Area = 0.0025;
    attribute capacitance : Capacitance = 0.000000003;
    attribute relativePermittivity : Real = 4.7;
    attribute maximumElectricField : ElectricFieldStrength = 90000000.0;
    attribute electrostrictiveCoefficient : Real = 0.00000000000000018;
    attribute maximumStrain : Strain = 0.08;
    attribute maximumTemperature : Temperature = 70.0;
    port electrical : FilmElectricalPort;
    port mechanical : MechanicalOutputPort;
  }

  part def PreloadFrame {
    attribute materialName : String = "glass-filled polymer frame";
    attribute preloadForce : Force = 12.0;
    attribute maximumTravel : Displacement = 0.006;
    attribute stiffness : Real = 1800.0;
    port loadInterface : MechanicalLoadPort;
  }

  part def DisplacementSensor {
    attribute resolution : Displacement = 0.000001;
    attribute samplingFrequency : Frequency = 1000.0;
    port sensing : SensorPort;
  }

  part def TemperatureSensor {
    attribute accuracy : Temperature = 1.0;
    attribute samplingFrequency : Frequency = 10.0;
    port sensing : SensorPort;
  }

  part def HighVoltageDriver {
    attribute maximumOutputVoltage : Voltage = 2500.0;
    attribute maximumOutputCurrent : ElectricCurrent = 0.002;
    attribute maximumOutputPower : Power = 5.0;
    attribute switchingFrequency : Frequency = 50000.0;
    attribute outputVoltageRipple : Voltage = 5.0;
    port commandIn : ControlSignalPort;
    port driveOut : ElectricalDrivePort;
    port statusOut : StatusPort;

    perform action voltageRamp : RampHighVoltage;
  }

  part def ChargeMonitor {
    attribute measurementRange : ElectricCharge = 0.000001;
    attribute currentResolution : ElectricCurrent = 0.00000001;
    port filmSense : FilmElectricalPort;
    port sensorOut : SensorPort;

    perform action responseSensing : SenseFilmResponse;
  }

  part def SafetyDischargeCircuit {
    attribute bleedResistance : Real = 10000000.0;
    attribute safeVoltageThreshold : Voltage = 30.0;
    attribute maximumDischargeTime : Time = 2.0;
    port filmConnection : FilmElectricalPort;
    port statusOut : StatusPort;

    perform action safeDischarge : DischargeFilmSafely;
  }

  part def MotionController {
    attribute controlLoopFrequency : Frequency = 1000.0;
    attribute maximumCommandedVoltage : Voltage = 2300.0;
    attribute displacementGain : Real = 1.0;
    attribute forceGain : Real = 0.4;
    port commandIn : CommandInputPort;
    port voltageCommandOut : ControlSignalPort;
    port feedbackIn : SensorPort;
    port statusOut : StatusPort;

    perform action commandComputation : ComputeVoltageForRequestedDisplacement;
  }

  part def ElectromechanicalFilmStack {
    attribute nominalThickness : Thickness = 0.000080;
    attribute activeArea : Area = 0.0025;
    attribute nominalCapacitance : Capacitance = 0.000000003;
    attribute nominalStroke : Displacement = 0.002;
    attribute nominalBlockingForce : Force = 5.0;
    attribute maximumVoltage : Voltage = 2300.0;
    attribute maximumElectricField : ElectricFieldStrength = 90000000.0;
    attribute maximumTemperature : Temperature = 70.0;

    part lowerSubstrate : CompliantSubstrate;
    part lowerElectrode : ConductiveElectrode;
    part activeFilm : ElectromechanicalPolymerLayer;
    part upperElectrode : ConductiveElectrode;
    part upperSubstrate : CompliantSubstrate;
    part preloadFrame : PreloadFrame;

    port electricalIn : FilmElectricalPort;
    port mechanicalOut : MechanicalOutputPort;
    port sensorOut : SensorPort;

    bind lowerElectrode.electrical = electricalIn;
    bind upperElectrode.electrical = electricalIn;
    bind activeFilm.electrical = electricalIn;
    bind activeFilm.mechanical = mechanicalOut;
    connect mechanicalOut to preloadFrame.loadInterface;

    assert constraint fieldSafety : ElectricFieldLimit {
      voltage = maximumVoltage;
      thickness = activeFilm.thickness;
      maximumField = maximumElectricField;
    }

    assert constraint strokeLimit : MechanicalOutputLimit {
      displacement = nominalStroke;
      maximumDisplacement = preloadFrame.maximumTravel;
      force = nominalBlockingForce;
      maximumForce = 8.0;
    }

    perform action conversion : ConvertElectricalFieldToMechanicalMotion;
  }

  part def MechanicalLoad {
    attribute loadName : String = "high-level adaptive surface or haptic interface";
    attribute requiredStroke : Displacement = 0.0015;
    attribute maximumAcceptedForce : Force = 6.0;
    attribute operatingFrequency : Frequency = 50.0;
    port inputMotion : MechanicalLoadPort;
  }

  part def ThermalManagement {
    attribute passiveThermalResistance : Real = 18.0;
    attribute maximumFilmTemperature : Temperature = 70.0;
    attribute maximumDriverTemperature : Temperature = 90.0;
    port thermalIn : CoolingPort;
    port statusOut : StatusPort;
  }

  part def ElectromechanicalFilmActuationSystem {
    attribute systemName : String = "Electromechanical Film Actuator System";
    attribute primaryFunction : String = "Convert controlled electrical energy applied across a thin electromechanical film into repeatable mechanical displacement and force for a connected load.";
    attribute nominalSupplyVoltage : Voltage = 24.0;
    attribute nominalHighVoltage : Voltage = 2000.0;
    attribute nominalStroke : Displacement = 0.0015;
    attribute nominalForce : Force = 4.0;
    attribute nominalActuationFrequency : Frequency = 50.0;
    attribute standbyPower : Power = 0.5;
    attribute peakPower : Power = 5.0;

    part controller : MotionController;
    part driver : HighVoltageDriver;
    part filmStack : ElectromechanicalFilmStack;
    part chargeMonitor : ChargeMonitor;
    part displacementSensor : DisplacementSensor;
    part temperatureSensor : TemperatureSensor;
    part dischargeCircuit : SafetyDischargeCircuit;
    part thermalManagement : ThermalManagement;
    part load : MechanicalLoad;

    port externalCommand : CommandInputPort;
    port mechanicalInterface : MechanicalOutputPort;
    port systemStatus : StatusPort;

    connect externalCommand to controller.commandIn;
    connect controller.voltageCommandOut to driver.commandIn;
    connect driver.driveOut to filmStack.electricalIn;
    connect filmStack.electricalIn to chargeMonitor.filmSense;
    connect filmStack.electricalIn to dischargeCircuit.filmConnection;
    connect filmStack.mechanicalOut to displacementSensor.sensing;
    connect filmStack.sensorOut to controller.feedbackIn;
    connect chargeMonitor.sensorOut to controller.feedbackIn;
    connect displacementSensor.sensing to controller.feedbackIn;
    connect temperatureSensor.sensing to controller.feedbackIn;
    connect temperatureSensor.sensing to thermalManagement.thermalIn;
    connect filmStack.mechanicalOut to load.inputMotion;
    bind filmStack.mechanicalOut = mechanicalInterface;
    connect controller.statusOut to systemStatus;
    connect driver.statusOut to systemStatus;
    connect dischargeCircuit.statusOut to systemStatus;
    connect thermalManagement.statusOut to systemStatus;

    perform state operationalBehavior : FilmOperationalStateMachine;

    assert constraint storedEnergyModel : CapacitiveEnergy {
      capacitance = filmStack.nominalCapacitance;
      voltage = nominalHighVoltage;
    }

    assert constraint highVoltageFieldLimit : ElectricFieldLimit {
      voltage = filmStack.maximumVoltage;
      thickness = filmStack.activeFilm.thickness;
      maximumField = filmStack.maximumElectricField;
    }

    assert constraint mechanicalCompatibility : MechanicalOutputLimit {
      displacement = nominalStroke;
      maximumDisplacement = load.requiredStroke * 1.5;
      force = nominalForce;
      maximumForce = load.maximumAcceptedForce;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ElectromechanicalFilmActuationSystem;

    doc /* The system shall perform the high-level primary function of converting a controlled electrical drive signal into mechanical displacement and force using an electromechanical film stack. */

    require constraint {
      system.nominalHighVoltage > 0.0 and
      system.nominalStroke >= 0.0015 and
      system.nominalForce >= 4.0
    }
  }

  requirement def SafeElectricFieldRequirement {
    subject film : ElectromechanicalFilmStack;

    doc /* The electric field across the active electromechanical polymer layer shall remain below the dielectric safety limit during commanded operation. */

    require constraint {
      film.maximumVoltage / film.activeFilm.thickness <= film.maximumElectricField
    }
  }

  requirement def StrokeRequirement {
    subject system : ElectromechanicalFilmActuationSystem;

    doc /* The electromechanical film system shall provide at least 1.5 mm commanded displacement to the mechanical interface under nominal load conditions. */

    require constraint {
      system.nominalStroke >= 0.0015
    }
  }

  requirement def ForceRequirement {
    subject system : ElectromechanicalFilmActuationSystem;

    doc /* The electromechanical film system shall provide at least 4 N nominal output force while remaining within the connected load force limit. */

    require constraint {
      system.nominalForce >= 4.0 and
      system.nominalForce <= system.load.maximumAcceptedForce
    }
  }

  requirement def ThermalProtectionRequirement {
    subject system : ElectromechanicalFilmActuationSystem;

    doc /* The system shall monitor film and driver temperature and shall enter a safe faulted or discharged condition before the electromechanical film exceeds its maximum operating temperature. */

    require constraint {
      system.filmStack.maximumTemperature <= 70.0 and
      system.thermalManagement.maximumFilmTemperature <= system.filmStack.maximumTemperature
    }
  }

  requirement def SafeDischargeRequirement {
    subject system : ElectromechanicalFilmActuationSystem;

    doc /* The safety discharge circuit shall reduce the film terminal voltage to a safe-to-touch threshold within the maximum discharge time after shutdown or fault detection. */

    require constraint {
      system.dischargeCircuit.safeVoltageThreshold <= 30.0 and
      system.dischargeCircuit.maximumDischargeTime <= 2.0
    }
  }

  requirement def ClosedLoopControlRequirement {
    subject system : ElectromechanicalFilmActuationSystem;

    doc /* The controller shall use electrical, displacement, and thermal feedback to regulate film voltage and achieve repeatable mechanical output. */

    require constraint {
      system.controller.controlLoopFrequency >= 1000.0 and
      system.displacementSensor.resolution <= 0.000001
    }
  }

  requirement def LoadInterfaceRequirement {
    subject system : ElectromechanicalFilmActuationSystem;

    doc /* The mechanical output port shall deliver motion to a load through a compliant preload frame without exceeding the load force rating. */

    require constraint {
      system.load.maximumAcceptedForce >= system.nominalForce and
      system.filmStack.preloadFrame.maximumTravel >= system.nominalStroke
    }
  }

  part electromechanicalFilmSystem : ElectromechanicalFilmActuationSystem;

  satisfy PrimaryFunctionRequirement by electromechanicalFilmSystem;
  satisfy SafeElectricFieldRequirement by electromechanicalFilmSystem.filmStack;
  satisfy StrokeRequirement by electromechanicalFilmSystem;
  satisfy ForceRequirement by electromechanicalFilmSystem;
  satisfy ThermalProtectionRequirement by electromechanicalFilmSystem;
  satisfy SafeDischargeRequirement by electromechanicalFilmSystem;
  satisfy ClosedLoopControlRequirement by electromechanicalFilmSystem;
  satisfy LoadInterfaceRequirement by electromechanicalFilmSystem;
}
