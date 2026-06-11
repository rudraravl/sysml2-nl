package DoubleLumenEndobronchialTubeSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Pressure;
  attribute def FlowRate;
  attribute def Volume;
  attribute def Length;
  attribute def Diameter;
  attribute def Time;
  attribute def Fraction;

  item def GasMixture {
    attribute oxygenFraction : Fraction;
    attribute carbonDioxideFraction : Fraction;
    attribute nitrogenFraction : Fraction;
    attribute absolutePressure : Pressure;
    attribute temperature : TemperatureValue;
    attribute humidity : Fraction;
  }

  item def ExhaledGas :> GasMixture {
    attribute carbonDioxidePartialPressure : Pressure;
  }

  item def AirwaySecretion {
    attribute volume : Volume;
    attribute viscosity : Real;
  }

  item def PatientAirwayTissue {
    attribute contactPressure : Pressure;
  }

  port def GasPort {
    in item suppliedGas : GasMixture;
    out item returnedGas : ExhaledGas;
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
  }

  port def SuctionPort {
    out item removedSecretion : AirwaySecretion;
    attribute suctionPressure : Pressure;
  }

  port def MechanicalInterfacePort {
    inout item contactedTissue : PatientAirwayTissue;
    attribute insertionForce : ForceValue;
  }

  port def InflationPort {
    in item inflationGas : GasMixture;
    attribute cuffPressure : Pressure;
    attribute cuffVolume : Volume;
  }

  part def Ventilator {
    attribute inspiratoryPressure : Pressure = 20 [kPa];
    attribute expiratoryPressure : Pressure = 0 [kPa];
    attribute oxygenFractionCommand : Fraction = 0.6;
    attribute respiratoryRate : FrequencyValue = 12 ['1/min'];
    attribute tidalVolumeCommand : Volume = 500 [mL];

    port trachealCircuit : GasPort;
    port bronchialCircuit : GasPort;
  }

  part def AnesthesiaBreathingSystem {
    attribute freshGasFlow : FlowRate = 3 [L/min];
    attribute pressureLimit : Pressure = 35 [cmH2O];

    part ventilator : Ventilator;
    port commonGasSupply : GasPort;
  }

  part def TrachealLumen {
    attribute innerDiameter : Diameter = 6.0 [mm];
    attribute effectiveLength : Length = 310 [mm];
    attribute deadSpaceVolume : Volume = 8 [mL];
    attribute airwayResistance : Real = 2.2;

    port proximalConnector : GasPort;
    port distalOpening : GasPort;
    port suctionAccess : SuctionPort;
  }

  part def BronchialLumen {
    attribute innerDiameter : Diameter = 5.2 [mm];
    attribute effectiveLength : Length = 345 [mm];
    attribute deadSpaceVolume : Volume = 6 [mL];
    attribute airwayResistance : Real = 2.8;

    port proximalConnector : GasPort;
    port distalOpening : GasPort;
    port suctionAccess : SuctionPort;
  }

  part def TrachealCuff {
    attribute inflatedVolume : Volume = 8 [mL];
    attribute targetPressure : Pressure = 25 [cmH2O];
    attribute maximumSafePressure : Pressure = 30 [cmH2O];
    attribute sealLeakRate : FlowRate = 0.05 [L/min];

    port inflationValve : InflationPort;
    port tissueContact : MechanicalInterfacePort;
  }

  part def BronchialCuff {
    attribute inflatedVolume : Volume = 3 [mL];
    attribute targetPressure : Pressure = 25 [cmH2O];
    attribute maximumSafePressure : Pressure = 30 [cmH2O];
    attribute sealLeakRate : FlowRate = 0.03 [L/min];

    port inflationValve : InflationPort;
    port tissueContact : MechanicalInterfacePort;
  }

  part def YConnector {
    attribute connectorStandardDiameter : Diameter = 15 [mm];

    port ventilatorSide : GasPort;
    port trachealSide : GasPort;
    port bronchialSide : GasPort;
  }

  part def ClampValve {
    attribute isClosed : Boolean = false;
    attribute closureLeakRate : FlowRate = 0.01 [L/min];

    port inlet : GasPort;
    port outlet : GasPort;
  }

  part def PatientThorax {
    part trachea {
      attribute diameter : Diameter = 18 [mm];
      port airwayInterface : GasPort;
      port wallContact : MechanicalInterfacePort;
    }

    part leftMainBronchus {
      attribute diameter : Diameter = 12 [mm];
      port airwayInterface : GasPort;
      port wallContact : MechanicalInterfacePort;
    }

    part rightLung {
      attribute functionalResidualCapacity : Volume = 1200 [mL];
      attribute compliance : Real = 0.05;
      port ventilationPort : GasPort;
    }

    part leftLung {
      attribute functionalResidualCapacity : Volume = 1100 [mL];
      attribute compliance : Real = 0.045;
      port ventilationPort : GasPort;
    }
  }

  part def DoubleLumenEndobronchialTube {
    attribute nominalFrenchSize : Integer = 39;
    attribute totalLength : Length = 420 [mm];
    attribute outerDiameter : Diameter = 13 [mm];
    attribute placementSideIsLeft : Boolean = true;
    attribute maximumRecommendedCuffPressure : Pressure = 30 [cmH2O];

    part trachealLumen : TrachealLumen;
    part bronchialLumen : BronchialLumen;
    part trachealCuff : TrachealCuff;
    part bronchialCuff : BronchialCuff;
    part proximalYConnector : YConnector;
    part trachealClamp : ClampValve;
    part bronchialClamp : ClampValve;

    port ventilatorInterface : GasPort;
    port trachealAirwayPort : GasPort;
    port bronchialAirwayPort : GasPort;
    port trachealCuffPilotPort : InflationPort;
    port bronchialCuffPilotPort : InflationPort;

    connect ventilatorInterface to proximalYConnector.ventilatorSide;
    connect proximalYConnector.trachealSide to trachealClamp.inlet;
    connect trachealClamp.outlet to trachealLumen.proximalConnector;
    connect proximalYConnector.bronchialSide to bronchialClamp.inlet;
    connect bronchialClamp.outlet to bronchialLumen.proximalConnector;
    connect trachealLumen.distalOpening to trachealAirwayPort;
    connect bronchialLumen.distalOpening to bronchialAirwayPort;
    connect trachealCuffPilotPort to trachealCuff.inflationValve;
    connect bronchialCuffPilotPort to bronchialCuff.inflationValve;
  }

  action def InsertAndPositionTube {
    in tube : DoubleLumenEndobronchialTube;
    in patient : PatientThorax;
    out positioned : Boolean;

    first start;
    then advanceTube;
    then rotateToBronchialSide;
    then confirmBronchialTip;
    then inflateBronchialCuff;
    then inflateTrachealCuff;
    then verifyBilateralVentilation;
    then done;

    action advanceTube;
    action rotateToBronchialSide;
    action confirmBronchialTip;
    action inflateBronchialCuff;
    action inflateTrachealCuff;
    action verifyBilateralVentilation;
  }

  action def ProvideSelectiveVentilation {
    in tube : DoubleLumenEndobronchialTube;
    in ventilator : Ventilator;
    in isolateLeftLung : Boolean;
    out gasDeliveredToDependentLung : GasMixture;
    out gasReturnedFromDependentLung : ExhaledGas;

    first evaluateSurgicalRequest;
    then selectClampConfiguration;
    then deliverInspiratoryGas;
    then ventExhaledGas;
    then monitorPressureAndFlow;
    then repeatCycle;

    action evaluateSurgicalRequest;
    action selectClampConfiguration;
    action deliverInspiratoryGas;
    action ventExhaledGas;
    action monitorPressureAndFlow;
    action repeatCycle;
  }

  state def TubeOperationalState {
    entry action initialize;

    state Uninserted;
    state InsertedUnsealed;
    state Positioned;
    state TrachealAndBronchialSealed;
    state BilateralVentilation;
    state LeftLungIsolated;
    state RightLungIsolated;
    state Suctioning;
    state Removed;

    transition first Uninserted;
    transition Uninserted then InsertedUnsealed accept inserted;
    transition InsertedUnsealed then Positioned accept bronchialTipConfirmed;
    transition Positioned then TrachealAndBronchialSealed accept cuffsInflated;
    transition TrachealAndBronchialSealed then BilateralVentilation accept bothLumensOpen;
    transition BilateralVentilation then LeftLungIsolated accept leftLumenClamped;
    transition BilateralVentilation then RightLungIsolated accept rightLumenClamped;
    transition LeftLungIsolated then BilateralVentilation accept isolationReleased;
    transition RightLungIsolated then BilateralVentilation accept isolationReleased;
    transition BilateralVentilation then Suctioning accept suctionCatheterInserted;
    transition Suctioning then BilateralVentilation accept suctionComplete;
    transition TrachealAndBronchialSealed then Removed accept cuffsDeflatedAndTubeWithdrawn;
  }

  requirement def PrimaryFunctionRequirement {
    subject tube : DoubleLumenEndobronchialTube;

    doc /* The double-lumen endobronchial tube shall establish two separated airway conduits so that each lung can be ventilated, isolated, collapsed, or suctioned independently while maintaining a sealed airway for anesthetic gas exchange. */

    require constraint {
      tube.trachealCuff.targetPressure <= tube.maximumRecommendedCuffPressure and
      tube.bronchialCuff.targetPressure <= tube.maximumRecommendedCuffPressure
    }
  }

  requirement def IndependentLumenRequirement {
    subject tube : DoubleLumenEndobronchialTube;

    require constraint {
      tube.trachealLumen.deadSpaceVolume > 0 [mL] and
      tube.bronchialLumen.deadSpaceVolume > 0 [mL] and
      tube.trachealLumen.innerDiameter != tube.bronchialLumen.innerDiameter
    }
  }

  requirement def SelectiveVentilationRequirement {
    subject tube : DoubleLumenEndobronchialTube;

    doc /* When one lumen is clamped, the tube shall maintain gas delivery through the other lumen with clamp leakage not exceeding 0.01 L/min. */

    require constraint {
      tube.trachealClamp.closureLeakRate <= 0.01 [L/min] and
      tube.bronchialClamp.closureLeakRate <= 0.01 [L/min]
    }
  }

  requirement def CuffSafetyRequirement {
    subject tube : DoubleLumenEndobronchialTube;

    require constraint {
      tube.trachealCuff.targetPressure <= 30 [cmH2O] and
      tube.bronchialCuff.targetPressure <= 30 [cmH2O]
    }
  }

  part def DoubleLumenTubeClinicalSystem {
    part breathingSystem : AnesthesiaBreathingSystem;
    part tube : DoubleLumenEndobronchialTube;
    part patient : PatientThorax;

    perform insertion : InsertAndPositionTube {
      in tube = tube;
      in patient = patient;
    }

    perform ventilation : ProvideSelectiveVentilation {
      in tube = tube;
      in ventilator = breathingSystem.ventilator;
      in isolateLeftLung = true;
    }

    exhibit state operationalState : TubeOperationalState;

    connect breathingSystem.ventilator.trachealCircuit to tube.ventilatorInterface;
    connect tube.trachealAirwayPort to patient.trachea.airwayInterface;
    connect tube.bronchialAirwayPort to patient.leftMainBronchus.airwayInterface;
    connect patient.trachea.airwayInterface to patient.rightLung.ventilationPort;
    connect patient.leftMainBronchus.airwayInterface to patient.leftLung.ventilationPort;

    satisfy PrimaryFunctionRequirement by tube;
    satisfy IndependentLumenRequirement by tube;
    satisfy SelectiveVentilationRequirement by tube;
    satisfy CuffSafetyRequirement by tube;
  }

}