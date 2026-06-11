package NasalCannulaSupplementalOxygenSystem {

  import ScalarValues::*;

  attribute def Length_mm :> Real;
  attribute def FlowRate_L_per_min :> Real;
  attribute def Pressure_kPa :> Real;
  attribute def OxygenFraction_percent :> Real;
  attribute def Duration_min :> Real;
  attribute def Temperature_C :> Real;
  attribute def Humidity_percent :> Real;
  attribute def Force_N :> Real;

  item def MedicalOxygen {
    attribute oxygenFraction: OxygenFraction_percent;
    attribute flowRate: FlowRate_L_per_min;
    attribute supplyPressure: Pressure_kPa;
    attribute temperature: Temperature_C;
    attribute relativeHumidity: Humidity_percent;
  }

  item def AmbientAir {
    attribute oxygenFraction: OxygenFraction_percent = 20.9;
    attribute temperature: Temperature_C;
    attribute relativeHumidity: Humidity_percent;
  }

  item def InspiredGasMixture {
    attribute oxygenFraction: OxygenFraction_percent;
    attribute totalFlowRate: FlowRate_L_per_min;
    attribute temperature: Temperature_C;
    attribute relativeHumidity: Humidity_percent;
  }

  item def ExhaledGas {
    attribute carbonDioxideFraction: OxygenFraction_percent;
    attribute flowRate: FlowRate_L_per_min;
  }

  item def PatientBreathingDemand {
    attribute inspiratoryFlow: FlowRate_L_per_min;
    attribute respiratoryCycleDuration: Duration_min;
  }

  port def OxygenSupplyPort {
    in item oxygenIn: MedicalOxygen;
  }

  port def GasDeliveryPort {
    out item inspiredGasOut: InspiredGasMixture;
    in item exhaledGasNearNares: ExhaledGas;
  }

  port def PatientInterfacePort {
    out item oxygenToNares: InspiredGasMixture;
    in item breathingDemand: PatientBreathingDemand;
  }

  port def AmbientInterfacePort {
    in item ambientAir: AmbientAir;
  }

  port def SupportLoadPort {
    in attribute retentionForce: Force_N;
  }

  action def ReceiveOxygenFlow {
    in item suppliedOxygen: MedicalOxygen;
    out item conditionedOxygen: MedicalOxygen;
  }

  action def SplitFlowBetweenProngs {
    in item conditionedOxygen: MedicalOxygen;
    out item leftProngFlow: MedicalOxygen;
    out item rightProngFlow: MedicalOxygen;
  }

  action def MixWithAmbientAirAtNares {
    in item leftProngFlow: MedicalOxygen;
    in item rightProngFlow: MedicalOxygen;
    in item ambientAir: AmbientAir;
    in item breathingDemand: PatientBreathingDemand;
    out item inspiredMixture: InspiredGasMixture;
  }

  action def DeliverSupplementalOxygen {
    in item suppliedOxygen: MedicalOxygen;
    in item ambientAir: AmbientAir;
    in item breathingDemand: PatientBreathingDemand;
    out item inspiredGas: InspiredGasMixture;

    action receive: ReceiveOxygenFlow {
      in suppliedOxygen = suppliedOxygen;
    }

    action split: SplitFlowBetweenProngs {
      in conditionedOxygen = receive.conditionedOxygen;
    }

    action mix: MixWithAmbientAirAtNares {
      in leftProngFlow = split.leftProngFlow;
      in rightProngFlow = split.rightProngFlow;
      in ambientAir = ambientAir;
      in breathingDemand = breathingDemand;
    }

    bind inspiredGas = mix.inspiredMixture;
  }

  state def CannulaOperationalStates {
    state disconnected;
    state connectedIdle;
    state deliveringOxygen;
    state obstructed;
    state removedFromPatient;

    transition initial then disconnected;

    transition connectSystem
      first disconnected
      then connectedIdle;

    transition startFlow
      first connectedIdle
      then deliveringOxygen;

    transition stopFlow
      first deliveringOxygen
      then connectedIdle;

    transition detectObstruction
      first deliveringOxygen
      then obstructed;

    transition clearObstruction
      first obstructed
      then deliveringOxygen;

    transition removeCannula
      first connectedIdle
      then removedFromPatient;

    transition removeDuringDelivery
      first deliveringOxygen
      then removedFromPatient;

    transition reconnectAfterRemoval
      first removedFromPatient
      then connectedIdle;
  }

  part def OxygenSource {
    attribute outletPressure: Pressure_kPa;
    attribute commandedFlow: FlowRate_L_per_min;
    port oxygenOutlet: OxygenSupplyPort;
  }

  part def SupplyTubing {
    attribute internalLength: Length_mm;
    attribute internalDiameter: Length_mm;
    attribute pressureDrop: Pressure_kPa;
    port sourceEnd: OxygenSupplyPort;
    port cannulaEnd: OxygenSupplyPort;
  }

  part def NasalProng {
    attribute insertionLength: Length_mm;
    attribute outerDiameter: Length_mm;
    attribute deliveredFlow: FlowRate_L_per_min;
    port outlet: GasDeliveryPort;
  }

  part def BifurcationManifold {
    attribute leftBranchFlow: FlowRate_L_per_min;
    attribute rightBranchFlow: FlowRate_L_per_min;
    port inlet: OxygenSupplyPort;
    port leftOutlet: GasDeliveryPort;
    port rightOutlet: GasDeliveryPort;
  }

  part def EarLoopSupport {
    attribute supportForce: Force_N;
    port loadPort: SupportLoadPort;
  }

  part def NasalCannula {
    attribute nominalAdultFlowRangeLow: FlowRate_L_per_min = 1.0;
    attribute nominalAdultFlowRangeHigh: FlowRate_L_per_min = 6.0;
    attribute prongSpacing: Length_mm;
    attribute tubingLength: Length_mm;
    attribute maximumComfortableSupportForce: Force_N = 2.0;

    port oxygenInlet: OxygenSupplyPort;
    port leftNasalOutlet: GasDeliveryPort;
    port rightNasalOutlet: GasDeliveryPort;
    port ambientExposure: AmbientInterfacePort;
    port patientInterface: PatientInterfacePort;
    port supportInterface: SupportLoadPort;

    part manifold: BifurcationManifold;
    part leftProng: NasalProng;
    part rightProng: NasalProng;
    part leftEarLoop: EarLoopSupport;
    part rightEarLoop: EarLoopSupport;

    connection inletToManifold connect oxygenInlet to manifold.inlet;
    connection manifoldToLeftProng connect manifold.leftOutlet to leftProng.outlet;
    connection manifoldToRightProng connect manifold.rightOutlet to rightProng.outlet;
    connection leftProngToPatient connect leftNasalOutlet to patientInterface;
    connection rightProngToPatient connect rightNasalOutlet to patientInterface;
    connection leftSupport connect leftEarLoop.loadPort to supportInterface;
    connection rightSupport connect rightEarLoop.loadPort to supportInterface;

    perform action delivery: DeliverSupplementalOxygen;
    exhibit state operatingState: CannulaOperationalStates;
  }

  part def Patient {
    attribute restingInspiratoryDemand: FlowRate_L_per_min;
    port nares: PatientInterfacePort;
  }

  part def ClinicalEnvironment {
    attribute ambientTemperature: Temperature_C;
    attribute ambientHumidity: Humidity_percent;
    port roomAir: AmbientInterfacePort;
  }

  part def NasalCannulaOxygenDeliverySystem {
    attribute prescribedFlowRate: FlowRate_L_per_min;
    attribute intendedTherapyDuration: Duration_min;

    part oxygenSource: OxygenSource;
    part supplyTubing: SupplyTubing;
    part cannula: NasalCannula;
    part patient: Patient;
    part environment: ClinicalEnvironment;

    connection sourceToTubing connect oxygenSource.oxygenOutlet to supplyTubing.sourceEnd;
    connection tubingToCannula connect supplyTubing.cannulaEnd to cannula.oxygenInlet;
    connection cannulaToPatient connect cannula.patientInterface to patient.nares;
    connection environmentToCannula connect environment.roomAir to cannula.ambientExposure;

    perform action primaryFunction: DeliverSupplementalOxygen;
  }

  requirement def ProvideSupplementalOxygen {
    subject system: NasalCannulaOxygenDeliverySystem;

    doc /* The system shall provide a low-flow stream of medical oxygen through two nasal prongs so the patient inhales an oxygen-enriched gas mixture while continuing normal breathing through the nose. */
  }

  requirement def MaintainPrescribedFlow {
    subject cannula: NasalCannula;

    require constraint {
      cannula.nominalAdultFlowRangeLow <= cannula.delivery.suppliedOxygen.flowRate and
      cannula.delivery.suppliedOxygen.flowRate <= cannula.nominalAdultFlowRangeHigh
    }
  }

  requirement def SplitFlowToBothNares {
    subject cannula: NasalCannula;

    require constraint {
      cannula.manifold.leftBranchFlow > 0.0 and
      cannula.manifold.rightBranchFlow > 0.0
    }
  }

  requirement def PreserveSpontaneousBreathing {
    subject cannula: NasalCannula;

    require constraint {
      cannula.delivery.inspiredGas.totalFlowRate >= cannula.delivery.breathingDemand.inspiratoryFlow
    }
  }

  requirement def LimitSupportForce {
    subject cannula: NasalCannula;

    require constraint {
      cannula.leftEarLoop.supportForce <= cannula.maximumComfortableSupportForce and
      cannula.rightEarLoop.supportForce <= cannula.maximumComfortableSupportForce
    }
  }

  satisfy ProvideSupplementalOxygen by NasalCannulaOxygenDeliverySystem;
  satisfy MaintainPrescribedFlow by NasalCannula;
  satisfy SplitFlowToBothNares by BifurcationManifold;
  satisfy PreserveSpontaneousBreathing by NasalCannula;
  satisfy LimitSupportForce by EarLoopSupport;
}