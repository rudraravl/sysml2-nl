package CarbonNanotubeHighLevelModel {

  enum def LengthUnit { nm; um; }
  enum def TemperatureUnit { K; degC; }
  enum def VoltageUnit { V; mV; }
  enum def CurrentUnit { A; uA; nA; }
  enum def PowerUnit { W; uW; }
  enum def ConductanceUnit { S; uS; }
  enum def ForceUnit { N; uN; }
  enum def StressUnit { GPa; }
  enum def ThermalConductivityUnit { W_per_mK; }
  enum def ChiralityClass { armchair; zigzag; chiral; }
  enum def WallStructure { singleWall; doubleWall; multiWall; }
  enum def ElectronicBehavior { metallic; semiconducting; }
  enum def OperatingMode { idle; characterize; conductCharge; conductHeat; supportLoad; faultIsolate; }

  attribute def LengthValue {
    attribute value : Real;
    attribute unit : LengthUnit;
  }

  attribute def TemperatureValue {
    attribute value : Real;
    attribute unit : TemperatureUnit;
  }

  attribute def VoltageValue {
    attribute value : Real;
    attribute unit : VoltageUnit;
  }

  attribute def CurrentValue {
    attribute value : Real;
    attribute unit : CurrentUnit;
  }

  attribute def PowerValue {
    attribute value : Real;
    attribute unit : PowerUnit;
  }

  attribute def ConductanceValue {
    attribute value : Real;
    attribute unit : ConductanceUnit;
  }

  attribute def ForceValue {
    attribute value : Real;
    attribute unit : ForceUnit;
  }

  attribute def StressValue {
    attribute value : Real;
    attribute unit : StressUnit;
  }

  attribute def ThermalConductivityValue {
    attribute value : Real;
    attribute unit : ThermalConductivityUnit;
  }

  item def ElectronCurrent {
    attribute magnitude : CurrentValue;
    attribute carrierMobility : Real;
    attribute meanFreePath : LengthValue;
  }

  item def PhononHeatFlow {
    attribute thermalPower : PowerValue;
    attribute temperatureGradient : TemperatureValue;
    attribute effectiveThermalConductivity : ThermalConductivityValue;
  }

  item def MechanicalLoad {
    attribute axialForce : ForceValue;
    attribute tensileStress : StressValue;
  }

  item def MeasurementSignal {
    attribute measuredVoltage : VoltageValue;
    attribute measuredCurrent : CurrentValue;
    attribute measuredTemperature : TemperatureValue;
  }

  port def ElectricalPort {
    in item incomingCharge : ElectronCurrent;
    out item outgoingCharge : ElectronCurrent;
    attribute potential : VoltageValue;
  }

  port def ThermalPort {
    in item incomingHeat : PhononHeatFlow;
    out item outgoingHeat : PhononHeatFlow;
    attribute interfaceTemperature : TemperatureValue;
  }

  port def MechanicalPort {
    in item appliedLoad : MechanicalLoad;
    out item reactedLoad : MechanicalLoad;
  }

  port def DiagnosticPort {
    out item telemetry : MeasurementSignal;
  }

  part def CarbonNanotube {
    attribute length : LengthValue;
    attribute outerDiameter : LengthValue;
    attribute innerDiameter : LengthValue;
    attribute wallStructure : WallStructure;
    attribute chiralityClass : ChiralityClass;
    attribute chiralIndexN : Integer;
    attribute chiralIndexM : Integer;
    attribute electronicBehavior : ElectronicBehavior;
    attribute axialConductance : ConductanceValue;
    attribute thermalConductivity : ThermalConductivityValue;
    attribute ultimateTensileStress : StressValue;
    attribute operatingTemperature : TemperatureValue;

    port leftElectrical : ElectricalPort;
    port rightElectrical : ElectricalPort;
    port leftThermal : ThermalPort;
    port rightThermal : ThermalPort;
    port axialMechanical : MechanicalPort;
  }

  part def ContactElectrode {
    attribute contactResistance : Real;
    attribute workFunction_eV : Real;
    port externalTerminal : ElectricalPort;
    port nanotubeTerminal : ElectricalPort;
  }

  part def ThermalInterface {
    attribute interfaceResistance : Real;
    port environmentSide : ThermalPort;
    port nanotubeSide : ThermalPort;
  }

  part def SupportMatrix {
    attribute elasticModulus : StressValue;
    attribute allowableStress : StressValue;
    port loadInput : MechanicalPort;
    port nanotubeAnchor : MechanicalPort;
  }

  part def SensorController {
    attribute samplePeriod_ms : Real;
    attribute overTemperatureLimit : TemperatureValue;
    attribute overCurrentLimit : CurrentValue;
    port senseInput : DiagnosticPort;
  }

  action def TransportCharge {
    in item inputCurrent : ElectronCurrent;
    in attribute biasVoltage : VoltageValue;
    out item outputCurrent : ElectronCurrent;
  }

  action def ConductHeat {
    in item inputHeat : PhononHeatFlow;
    out item rejectedHeat : PhononHeatFlow;
  }

  action def CarryAxialLoad {
    in item externalLoad : MechanicalLoad;
    out item reactedLoad : MechanicalLoad;
  }

  action def CharacterizeNanotube {
    in item measurement : MeasurementSignal;
    out attribute inferredBehavior : ElectronicBehavior;
    out attribute inferredConductance : ConductanceValue;
  }

  state def NanotubeOperationalStateMachine {
    state idle;
    state characterizing;
    state chargeTransport;
    state heatTransport;
    state loadBearing;
    state isolatedFault;

    transition first idle;
    transition idle then characterizing accept characterizeCommand;
    transition characterizing then idle accept characterizationComplete;
    transition idle then chargeTransport accept electricalBiasApplied;
    transition chargeTransport then idle accept electricalBiasRemoved;
    transition idle then heatTransport accept thermalGradientApplied;
    transition heatTransport then idle accept thermalGradientRemoved;
    transition idle then loadBearing accept axialLoadApplied;
    transition loadBearing then idle accept axialLoadRemoved;
    transition chargeTransport then isolatedFault accept overCurrentDetected;
    transition heatTransport then isolatedFault accept overTemperatureDetected;
    transition loadBearing then isolatedFault accept overloadDetected;
    transition isolatedFault then idle accept resetAfterInspection;
  }

  part def CarbonNanotubeFunctionalSystem {
    attribute primaryFunction : String = "Provide a nanoscale, high-aspect-ratio pathway that transports electrical charge and thermal energy while contributing axial mechanical strength.";
    attribute selectedMode : OperatingMode;

    part nanotube : CarbonNanotube {
      attribute length = (value = 1000.0, unit = nm);
      attribute outerDiameter = (value = 1.4, unit = nm);
      attribute innerDiameter = (value = 0.0, unit = nm);
      attribute wallStructure = WallStructure::singleWall;
      attribute chiralityClass = ChiralityClass::armchair;
      attribute chiralIndexN = 10;
      attribute chiralIndexM = 10;
      attribute electronicBehavior = ElectronicBehavior::metallic;
      attribute axialConductance = (value = 77.5, unit = uS);
      attribute thermalConductivity = (value = 3000.0, unit = W_per_mK);
      attribute ultimateTensileStress = (value = 80.0, unit = GPa);
      attribute operatingTemperature = (value = 300.0, unit = K);
    }

    part sourceElectrode : ContactElectrode;
    part drainElectrode : ContactElectrode;
    part heatSourceInterface : ThermalInterface;
    part heatSinkInterface : ThermalInterface;
    part structuralMatrix : SupportMatrix;
    part controller : SensorController;

    port systemElectricalInput : ElectricalPort;
    port systemElectricalOutput : ElectricalPort;
    port systemThermalInput : ThermalPort;
    port systemThermalOutput : ThermalPort;
    port systemMechanicalInput : MechanicalPort;
    port systemDiagnosticOutput : DiagnosticPort;

    connection inputElectricalPath connect systemElectricalInput to sourceElectrode.externalTerminal;
    connection sourceToNanotube connect sourceElectrode.nanotubeTerminal to nanotube.leftElectrical;
    connection nanotubeToDrain connect nanotube.rightElectrical to drainElectrode.nanotubeTerminal;
    connection outputElectricalPath connect drainElectrode.externalTerminal to systemElectricalOutput;

    connection inputThermalPath connect systemThermalInput to heatSourceInterface.environmentSide;
    connection heatIntoNanotube connect heatSourceInterface.nanotubeSide to nanotube.leftThermal;
    connection heatOutOfNanotube connect nanotube.rightThermal to heatSinkInterface.nanotubeSide;
    connection outputThermalPath connect heatSinkInterface.environmentSide to systemThermalOutput;

    connection mechanicalLoadPath connect systemMechanicalInput to structuralMatrix.loadInput;
    connection matrixToNanotubeAnchor connect structuralMatrix.nanotubeAnchor to nanotube.axialMechanical;

    perform action chargeTransport : TransportCharge;
    perform action heatTransport : ConductHeat;
    perform action axialLoadTransfer : CarryAxialLoad;
    perform action nanotubeCharacterization : CharacterizeNanotube;

    exhibit state behavior : NanotubeOperationalStateMachine;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : CarbonNanotubeFunctionalSystem;
    require constraint {
      system.primaryFunction == "Provide a nanoscale, high-aspect-ratio pathway that transports electrical charge and thermal energy while contributing axial mechanical strength."
    }
  }

  requirement def ElectricalTransportRequirement {
    subject tube : CarbonNanotube;
    require constraint {
      tube.axialConductance.value >= 50.0 and tube.axialConductance.unit == ConductanceUnit::uS
    }
  }

  requirement def ThermalTransportRequirement {
    subject tube : CarbonNanotube;
    require constraint {
      tube.thermalConductivity.value >= 1000.0 and tube.thermalConductivity.unit == ThermalConductivityUnit::W_per_mK
    }
  }

  requirement def MechanicalStrengthRequirement {
    subject tube : CarbonNanotube;
    require constraint {
      tube.ultimateTensileStress.value >= 50.0 and tube.ultimateTensileStress.unit == StressUnit::GPa
    }
  }

  requirement def NanoscaleGeometryRequirement {
    subject tube : CarbonNanotube;
    require constraint {
      tube.outerDiameter.value <= 5.0 and tube.outerDiameter.unit == LengthUnit::nm and tube.length.value >= 100.0
    }
  }

  requirement def SafeOperationRequirement {
    subject system : CarbonNanotubeFunctionalSystem;
    require constraint {
      system.controller.overTemperatureLimit.value <= 500.0 and system.controller.overTemperatureLimit.unit == TemperatureUnit::K
    }
  }

}