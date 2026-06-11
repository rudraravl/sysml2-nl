package OdonDeviceHighLevelModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Pressure_kPa :> Real {
    unit = "kPa";
  }

  attribute def Force_N :> Real {
    unit = "N";
  }

  attribute def Volume_mL :> Real {
    unit = "mL";
  }

  attribute def Length_mm :> Real {
    unit = "mm";
  }

  attribute def Time_s :> Real {
    unit = "s";
  }

  attribute def Temperature_C :> Real {
    unit = "degC";
  }

  item def MedicalAir {
    attribute supplyPressure : Pressure_kPa;
    attribute volumeDelivered : Volume_mL;
  }

  item def LubricantFilm {
    attribute thickness : Length_mm;
    attribute sterile : Boolean;
  }

  item def FetalHeadContactLoad {
    attribute radialPressure : Pressure_kPa;
    attribute tractionForce : Force_N;
  }

  item def TractionCommand {
    attribute requestedForce : Force_N;
    attribute rampTime : Time_s;
  }

  item def PressureSignal {
    attribute measuredPressure : Pressure_kPa;
    attribute sampleAge : Time_s;
  }

  item def DeviceStatus {
    attribute sterileBarrierIntact : Boolean;
    attribute sleevePositioned : Boolean;
    attribute sleeveInflated : Boolean;
    attribute readyForTraction : Boolean;
  }

  port def InflationPort {
    in item airIn : MedicalAir;
    out item pressureOut : PressureSignal;
  }

  port def TractionPort {
    in item command : TractionCommand;
    out item appliedLoad : FetalHeadContactLoad;
  }

  port def ContactPort {
    out item contactLoad : FetalHeadContactLoad;
    in item lubricant : LubricantFilm;
  }

  port def StatusPort {
    out item status : DeviceStatus;
  }

  part def OdonDevice {
    attribute maximumSleevePressure : Pressure_kPa = 25.0;
    attribute nominalSleevePressure : Pressure_kPa = 18.0;
    attribute maximumTractionForce : Force_N = 80.0;
    attribute insertionDepth : Length_mm = 180.0;
    attribute deploymentTimeLimit : Time_s = 90.0;

    port inflationPort : InflationPort;
    port tractionPort : TractionPort;
    port fetalHeadInterface : ContactPort;
    port statusPort : StatusPort;

    part insertionGuide : InsertionGuide;
    part inflatableSleeve : InflatableSleeve;
    part applicatorHandle : ApplicatorHandle;
    part tractionHandle : TractionHandle;
    part pressureLimiter : PressureLimiter;
    part sterileBarrier : SterileBarrier;

    connection airPath connect inflationPort to pressureLimiter.inflationIn;
    connection limitedAirPath connect pressureLimiter.limitedInflationOut to inflatableSleeve.inflationIn;
    connection mechanicalSupport connect applicatorHandle.guideMount to insertionGuide.handleMount;
    connection sleeveOnGuide connect inflatableSleeve.sleeveMount to insertionGuide.sleeveCarrier;
    connection tractionLoadPath connect tractionHandle.tractionOut to inflatableSleeve.tractionIn;
    connection fetalContact connect inflatableSleeve.contactSurface to fetalHeadInterface;
    connection statusAggregation connect inflatableSleeve.statusOut to statusPort;
  }

  part def InsertionGuide {
    attribute distalCupDiameter : Length_mm = 58.0;
    attribute guideLength : Length_mm = 220.0;
    attribute surfaceTemperature : Temperature_C;

    port handleMount : StatusPort;
    port sleeveCarrier : StatusPort;
  }

  part def InflatableSleeve {
    attribute uninflatedDiameter : Length_mm = 60.0;
    attribute inflatedDiameter : Length_mm = 95.0;
    attribute workingPressure : Pressure_kPa = 18.0;
    attribute burstPressure : Pressure_kPa = 45.0;
    attribute contactLength : Length_mm = 95.0;

    port inflationIn : InflationPort;
    port tractionIn : TractionPort;
    port contactSurface : ContactPort;
    port statusOut : StatusPort;

    state sleeveState : SleeveDeploymentState;
  }

  part def ApplicatorHandle {
    attribute gripLength : Length_mm = 130.0;
    attribute insertionForceLimit : Force_N = 35.0;

    port guideMount : StatusPort;
  }

  part def TractionHandle {
    attribute forceLimit : Force_N = 80.0;
    attribute nominalPullForce : Force_N = 50.0;

    port tractionOut : TractionPort;
  }

  part def PressureLimiter {
    attribute reliefOpeningPressure : Pressure_kPa = 28.0;
    attribute regulatedPressure : Pressure_kPa = 18.0;

    port inflationIn : InflationPort;
    port limitedInflationOut : InflationPort;
  }

  part def SterileBarrier {
    attribute sterile : Boolean = true;
    attribute packageIntegrity : Boolean = true;
  }

  part def BirthCanalEnvironment {
    attribute availableWorkingLength : Length_mm;
    attribute ambientTemperature : Temperature_C = 37.0;

    part fetalHead : FetalHead;
    part maternalSoftTissue : MaternalSoftTissue;
    part clinician : Clinician;

    port fetalInterface : ContactPort;
    port clinicianTractionInput : TractionPort;
  }

  part def FetalHead {
    attribute approximateDiameter : Length_mm;
    attribute allowableRadialPressure : Pressure_kPa = 25.0;

    port contactInterface : ContactPort;
  }

  part def MaternalSoftTissue {
    attribute allowableInsertionForce : Force_N = 35.0;
    attribute allowableContactPressure : Pressure_kPa = 25.0;
  }

  part def Clinician {
    attribute maximumManualTractionForce : Force_N = 80.0;

    port tractionCommandOut : TractionPort;
  }

  part def OdonAssistedDeliverySystem {
    attribute primaryFunction : String =
      "Assist vaginal delivery by placing an inflatable sleeve around the fetal head and enabling controlled axial traction while limiting pressure and force.";

    part device : OdonDevice;
    part clinicalEnvironment : BirthCanalEnvironment;

    connection clinicianCommand connect clinicalEnvironment.clinician.tractionCommandOut to device.tractionPort;
    connection deviceToFetalHead connect device.fetalHeadInterface to clinicalEnvironment.fetalHead.contactInterface;
    connection environmentContact connect clinicalEnvironment.fetalInterface to device.fetalHeadInterface;

    perform action prepareDevice : PrepareOdonDevice;
    perform action deploySleeve : DeployInflatableSleeve;
    perform action applyControlledTraction : ApplyControlledTraction;
    exhibit state operatingState : OdonSystemOperatingState;
  }

  action def PrepareOdonDevice {
    in item sterileStatus : DeviceStatus;
    out item readyStatus : DeviceStatus;

    first start;
    then verifyPackage;
    then lubricateSleeve;
    then armPressureLimiter;
    then complete;

    action verifyPackage;
    action lubricateSleeve;
    action armPressureLimiter;
    action complete;
  }

  action def DeployInflatableSleeve {
    in item medicalAir : MedicalAir;
    in item lubricant : LubricantFilm;
    out item status : DeviceStatus;
    out item pressure : PressureSignal;

    first start;
    then insertGuide;
    then advanceSleeve;
    then inflateSleeve;
    then verifyPosition;
    then complete;

    action insertGuide;
    action advanceSleeve;
    action inflateSleeve;
    action verifyPosition;
    action complete;
  }

  action def ApplyControlledTraction {
    in item command : TractionCommand;
    in item measuredPressure : PressureSignal;
    out item appliedLoad : FetalHeadContactLoad;
    out item status : DeviceStatus;

    first start;
    then checkPressureLimit;
    then rampTraction;
    then maintainAlignment;
    then releaseAfterDelivery;

    action checkPressureLimit;
    action rampTraction;
    action maintainAlignment;
    action releaseAfterDelivery;
  }

  state def SleeveDeploymentState {
    entry action resetSleeve;

    state Folded;
    state AdvancedAroundHead;
    state Inflating;
    state InflatedAndSeated;
    state Released;

    transition first Folded;
    transition Folded then AdvancedAroundHead;
    transition AdvancedAroundHead then Inflating;
    transition Inflating then InflatedAndSeated;
    transition InflatedAndSeated then Released;
  }

  state def OdonSystemOperatingState {
    state Packaged;
    state Prepared;
    state Inserted;
    state SleeveDeployed;
    state TractionReady;
    state AssistingDelivery;
    state Removed;
    state Faulted;

    transition first Packaged;
    transition Packaged then Prepared;
    transition Prepared then Inserted;
    transition Inserted then SleeveDeployed;
    transition SleeveDeployed then TractionReady;
    transition TractionReady then AssistingDelivery;
    transition AssistingDelivery then Removed;

    transition Prepared then Faulted;
    transition Inserted then Faulted;
    transition SleeveDeployed then Faulted;
    transition TractionReady then Faulted;
    transition AssistingDelivery then Faulted;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : OdonAssistedDeliverySystem;

    doc
      "The system shall assist vaginal delivery by positioning an inflatable sleeve around the fetal head and enabling controlled traction through the sleeve.";

    require constraint {
      system.device.maximumTractionForce <= 80.0
    }
  }

  requirement def SleevePressureLimitRequirement {
    subject device : OdonDevice;

    doc
      "The device shall limit sleeve inflation pressure to reduce excessive radial loading on fetal and maternal tissue.";

    require constraint {
      device.maximumSleevePressure <= 25.0
    }
  }

  requirement def ControlledTractionRequirement {
    subject device : OdonDevice;

    doc
      "The device shall transmit clinician-applied traction through the inflated sleeve while limiting peak axial force.";

    require constraint {
      device.maximumTractionForce <= 80.0
    }
  }

  requirement def SterilityRequirement {
    subject device : OdonDevice;

    doc
      "The device shall maintain a sterile patient-contact path before clinical use.";

    require constraint {
      device.sterileBarrier.sterile == true
    }
  }

  requirement def DeploymentTimeRequirement {
    subject device : OdonDevice;

    doc
      "The device shall support sleeve deployment within a clinically practical time after insertion.";

    require constraint {
      device.deploymentTimeLimit <= 90.0
    }
  }

  requirement def PressureReliefRequirement {
    subject limiter : PressureLimiter;

    doc
      "The pressure limiter shall open before sleeve pressure exceeds the maximum allowable sleeve pressure.";

    require constraint {
      limiter.reliefOpeningPressure <= 28.0
    }
  }

  satisfy PrimaryFunctionRequirement by OdonAssistedDeliverySystem;
  satisfy SleevePressureLimitRequirement by OdonDevice;
  satisfy ControlledTractionRequirement by TractionHandle;
  satisfy SterilityRequirement by SterileBarrier;
  satisfy DeploymentTimeRequirement by InflatableSleeve;
  satisfy PressureReliefRequirement by PressureLimiter;
}