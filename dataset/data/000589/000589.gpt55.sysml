package DoubleLumenEndobronchialTubeSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Length_mm :> Real {
    doc /* Length expressed in millimeters. */
  }

  attribute def Diameter_mm :> Real {
    doc /* Diameter expressed in millimeters. */
  }

  attribute def Volume_mL :> Real {
    doc /* Volume expressed in milliliters. */
  }

  attribute def Pressure_cmH2O :> Real {
    doc /* Pressure expressed in centimeters of water. */
  }

  attribute def FlowRate_L_per_min :> Real {
    doc /* Gas flow rate expressed in liters per minute. */
  }

  attribute def Fraction_percent :> Real {
    doc /* Percentage fraction from 0 to 100. */
  }

  attribute def Time_s :> Real {
    doc /* Time expressed in seconds. */
  }

  enum def LungSide {
    enum left;
    enum right;
    enum both;
    enum none;
  }

  enum def TubePositionStatus {
    enum outsidePatient;
    enum trachealPlacement;
    enum bronchialPlacement;
    enum confirmedByBronchoscopy;
    enum malpositioned;
  }

  enum def VentilationMode {
    enum bothLungVentilation;
    enum leftLungVentilation;
    enum rightLungVentilation;
    enum lungIsolation;
    enum suctionOnly;
    enum emergencyDeflation;
  }

  enum def CuffInflationState {
    enum deflated;
    enum partiallyInflated;
    enum inflated;
    enum overInflated;
    enum leaking;
  }

  enum def GasDirection {
    enum inspiratory;
    enum expiratory;
    enum bidirectional;
    enum blocked;
  }

  item def RespiratoryGas {
    attribute oxygenFraction: Fraction_percent;
    attribute nitrogenFraction: Fraction_percent;
    attribute carbonDioxideFraction: Fraction_percent;
    attribute humidityFraction: Fraction_percent;
    attribute temperature_C: Real;
    attribute pressure: Pressure_cmH2O;
  }

  item def InspiredGas :> RespiratoryGas {
    attribute oxygenFraction: Fraction_percent = 50.0;
    attribute carbonDioxideFraction: Fraction_percent = 0.04;
    attribute pressure: Pressure_cmH2O;
  }

  item def ExpiredGas :> RespiratoryGas {
    attribute oxygenFraction: Fraction_percent;
    attribute carbonDioxideFraction: Fraction_percent;
    attribute pressure: Pressure_cmH2O;
  }

  item def AirwaySecretions {
    attribute volume: Volume_mL;
    attribute viscosityIndex: Real;
  }

  item def BronchoscopeImage {
    attribute viewAdequate: Boolean;
    attribute observedTubePosition: TubePositionStatus;
    attribute observedBronchialSide: LungSide;
  }

  item def CuffInflationGas {
    attribute volume: Volume_mL;
    attribute pressure: Pressure_cmH2O;
  }

  item def PilotBalloonSignal {
    attribute indicatedInflationState: CuffInflationState;
    attribute indicatedPressure: Pressure_cmH2O;
  }

  item def PatientAirwayPressure {
    attribute airwayPressure: Pressure_cmH2O;
    attribute peakPressure: Pressure_cmH2O;
    attribute plateauPressure: Pressure_cmH2O;
  }

  item def TidalVolumeMeasurement {
    attribute inspiredTidalVolume: Volume_mL;
    attribute expiredTidalVolume: Volume_mL;
    attribute leakVolume: Volume_mL;
  }

  port def GasPort {
    in item gasIn: InspiredGas;
    out item gasOut: ExpiredGas;
    attribute permittedDirection: GasDirection;
    attribute maximumFlow: FlowRate_L_per_min;
  }

  port def PatientAirwayPort {
    in item deliveredGas: InspiredGas;
    out item returnedGas: ExpiredGas;
    out item airwayPressure: PatientAirwayPressure;
    attribute connectedSide: LungSide;
  }

  port def CuffInflationPort {
    in item inflationGas: CuffInflationGas;
    out item pilotSignal: PilotBalloonSignal;
    attribute inflationState: CuffInflationState;
  }

  port def SuctionPort {
    in item suctionFlow: RespiratoryGas;
    out item secretions: AirwaySecretions;
    attribute maximumSuctionFlow: FlowRate_L_per_min;
  }

  port def VisualizationPort {
    out item image: BronchoscopeImage;
  }

  part def UniversalVentilatorConnector {
    attribute connectorDiameter: Diameter_mm = 15.0;
    port ventilatorInterface: GasPort {
      attribute permittedDirection = GasDirection::bidirectional;
      attribute maximumFlow = 120.0;
    }
    port trachealLumenInterface: GasPort {
      attribute permittedDirection = GasDirection::bidirectional;
      attribute maximumFlow = 80.0;
    }
    port bronchialLumenInterface: GasPort {
      attribute permittedDirection = GasDirection::bidirectional;
      attribute maximumFlow = 80.0;
    }
  }

  part def Lumen {
    attribute lumenLength: Length_mm;
    attribute innerDiameter: Diameter_mm;
    attribute outerDiameterContribution: Diameter_mm;
    attribute deadSpace: Volume_mL;
    attribute resistanceIndex: Real;
    port proximalGasPort: GasPort;
    port distalAirwayPort: PatientAirwayPort;
  }

  part def TrachealLumen :> Lumen {
    attribute lumenLength: Length_mm = 290.0;
    attribute innerDiameter: Diameter_mm = 4.6;
    attribute deadSpace: Volume_mL = 11.5;
    attribute distalOpeningAboveCarinaDistance: Length_mm = 25.0;
    port suctionAccess: SuctionPort;
  }

  part def BronchialLumen :> Lumen {
    attribute lumenLength: Length_mm = 330.0;
    attribute innerDiameter: Diameter_mm = 4.2;
    attribute deadSpace: Volume_mL = 10.8;
    attribute bronchialTipLength: Length_mm = 35.0;
    attribute intendedBronchus: LungSide = LungSide::left;
    port bronchoscopeAccess: VisualizationPort;
  }

  part def InflatableCuff {
    attribute nominalVolume: Volume_mL;
    attribute maximumRecommendedPressure: Pressure_cmH2O;
    attribute inflationState: CuffInflationState = CuffInflationState::deflated;
    attribute sealPressure: Pressure_cmH2O;
    port inflationPort: CuffInflationPort;
  }

  part def TrachealCuff :> InflatableCuff {
    attribute nominalVolume: Volume_mL = 8.0;
    attribute maximumRecommendedPressure: Pressure_cmH2O = 30.0;
    attribute sealPressure: Pressure_cmH2O = 25.0;
  }

  part def BronchialCuff :> InflatableCuff {
    attribute nominalVolume: Volume_mL = 3.0;
    attribute maximumRecommendedPressure: Pressure_cmH2O = 25.0;
    attribute sealPressure: Pressure_cmH2O = 20.0;
  }

  part def PilotBalloon {
    attribute observedPressure: Pressure_cmH2O;
    attribute observedState: CuffInflationState;
    port cuffLine: CuffInflationPort;
  }

  part def RadiopaqueMarker {
    attribute markerLength: Length_mm = 10.0;
    attribute distanceFromTip: Length_mm;
  }

  part def TubeShaft {
    attribute totalLength: Length_mm = 360.0;
    attribute outerDiameter: Diameter_mm = 12.3;
    attribute frenchSize: Real = 37.0;
    attribute curvatureRadius: Length_mm = 95.0;
    part trachealLumen: TrachealLumen;
    part bronchialLumen: BronchialLumen;
    part distalTipMarker: RadiopaqueMarker {
      attribute distanceFromTip: Length_mm = 5.0;
    }
    part bronchialCuffMarker: RadiopaqueMarker {
      attribute distanceFromTip: Length_mm = 30.0;
    }
  }

  part def PatientRespiratorySystem {
    attribute trachealDiameter: Diameter_mm = 18.0;
    attribute leftMainBronchusDiameter: Diameter_mm = 12.0;
    attribute rightMainBronchusDiameter: Diameter_mm = 14.0;
    attribute currentPositionStatus: TubePositionStatus = TubePositionStatus::outsidePatient;
    port tracheaPort: PatientAirwayPort {
      attribute connectedSide = LungSide::both;
    }
    port leftBronchusPort: PatientAirwayPort {
      attribute connectedSide = LungSide::left;
    }
    port rightBronchusPort: PatientAirwayPort {
      attribute connectedSide = LungSide::right;
    }
  }

  part def AnesthesiaVentilator {
    attribute setRespiratoryRate_per_min: Real = 12.0;
    attribute setTidalVolume: Volume_mL = 500.0;
    attribute setPeakPressureLimit: Pressure_cmH2O = 35.0;
    attribute setOxygenFraction: Fraction_percent = 50.0;
    port breathingCircuitPort: GasPort {
      attribute permittedDirection = GasDirection::bidirectional;
      attribute maximumFlow = 120.0;
    }
    port pressureMonitorPort: PatientAirwayPort;
  }

  part def DoubleLumenEndobronchialTube {
    doc /*
      A double-lumen endobronchial tube is an airway device with separate tracheal
      and bronchial lumens. Its primary high-level function is to maintain a secure
      airway while independently routing ventilation to one lung, both lungs, or
      isolating one lung from ventilation, contamination, bleeding, or surgical collapse.
    */

    attribute nominalFrenchSize: Real = 37.0;
    attribute isLeftSidedTube: Boolean = true;
    attribute currentMode: VentilationMode = VentilationMode::bothLungVentilation;
    attribute selectedVentilatedSide: LungSide = LungSide::both;
    attribute positionStatus: TubePositionStatus = TubePositionStatus::outsidePatient;

    part connector: UniversalVentilatorConnector;
    part shaft: TubeShaft;
    part trachealCuff: TrachealCuff;
    part bronchialCuff: BronchialCuff;
    part trachealPilotBalloon: PilotBalloon;
    part bronchialPilotBalloon: PilotBalloon;

    port ventilatorPort: GasPort {
      attribute permittedDirection = GasDirection::bidirectional;
      attribute maximumFlow = 120.0;
    }

    port trachealAirwayPort: PatientAirwayPort {
      attribute connectedSide = LungSide::both;
    }

    port bronchialAirwayPort: PatientAirwayPort {
      attribute connectedSide = LungSide::left;
    }

    port trachealCuffPort: CuffInflationPort;
    port bronchialCuffPort: CuffInflationPort;
    port secretionRemovalPort: SuctionPort;
    port bronchoscopyPort: VisualizationPort;

    connect ventilatorPort to connector.ventilatorInterface;
    connect connector.trachealLumenInterface to shaft.trachealLumen.proximalGasPort;
    connect connector.bronchialLumenInterface to shaft.bronchialLumen.proximalGasPort;
    connect shaft.trachealLumen.distalAirwayPort to trachealAirwayPort;
    connect shaft.bronchialLumen.distalAirwayPort to bronchialAirwayPort;
    connect shaft.trachealLumen.suctionAccess to secretionRemovalPort;
    connect shaft.bronchialLumen.bronchoscopeAccess to bronchoscopyPort;
    connect trachealCuff.inflationPort to trachealCuffPort;
    connect bronchialCuff.inflationPort to bronchialCuffPort;
    connect trachealPilotBalloon.cuffLine to trachealCuff.inflationPort;
    connect bronchialPilotBalloon.cuffLine to bronchialCuff.inflationPort;
  }

  part def DoubleLumenTubeClinicalSystem {
    part tube: DoubleLumenEndobronchialTube;
    part ventilator: AnesthesiaVentilator;
    part patientAirway: PatientRespiratorySystem;

    connect ventilator.breathingCircuitPort to tube.ventilatorPort;
    connect tube.trachealAirwayPort to patientAirway.tracheaPort;
    connect tube.bronchialAirwayPort to patientAirway.leftBronchusPort;
  }

  action def InsertTube {
    in part tube: DoubleLumenEndobronchialTube;
    in part patientAirway: PatientRespiratorySystem;
    out attribute achievedPosition: TubePositionStatus;

    action advanceThroughMouthOrTracheostomy;
    action passTrachealCuffBeyondVocalCords;
    action rotateTowardTargetBronchus;
    action advanceBronchialTipIntoLeftMainBronchus;
    action setInitialPositionStatus {
      out attribute position: TubePositionStatus = TubePositionStatus::bronchialPlacement;
    }

    flow setInitialPositionStatus.position to achievedPosition;
  }

  action def InflateCuffs {
    in part tube: DoubleLumenEndobronchialTube;
    in item trachealInflationGas: CuffInflationGas;
    in item bronchialInflationGas: CuffInflationGas;
    out attribute trachealState: CuffInflationState;
    out attribute bronchialState: CuffInflationState;

    action inflateTrachealCuff {
      in item gas: CuffInflationGas;
      out attribute state: CuffInflationState = CuffInflationState::inflated;
    }

    action inflateBronchialCuff {
      in item gas: CuffInflationGas;
      out attribute state: CuffInflationState = CuffInflationState::inflated;
    }

    flow trachealInflationGas to inflateTrachealCuff.gas;
    flow bronchialInflationGas to inflateBronchialCuff.gas;
    flow inflateTrachealCuff.state to trachealState;
    flow inflateBronchialCuff.state to bronchialState;
  }

  action def ConfirmTubePosition {
    in part tube: DoubleLumenEndobronchialTube;
    in item image: BronchoscopeImage;
    out attribute confirmedStatus: TubePositionStatus;
    out attribute targetSide: LungSide;

    action inspectTrachealLumenOpening;
    action inspectBronchialCuffLocation;
    action inspectBronchialTip;
    action evaluateCarinalSeparation {
      in item bronchoscopeImage: BronchoscopeImage;
      out attribute status: TubePositionStatus = TubePositionStatus::confirmedByBronchoscopy;
      out attribute side: LungSide = LungSide::left;
    }

    flow image to evaluateCarinalSeparation.bronchoscopeImage;
    flow evaluateCarinalSeparation.status to confirmedStatus;
    flow evaluateCarinalSeparation.side to targetSide;
  }

  action def VentilateBothLungs {
    in part tube: DoubleLumenEndobronchialTube;
    in item inspiredGas: InspiredGas;
    out item expiredGas: ExpiredGas;
    out item airwayPressure: PatientAirwayPressure;

    action routeGasThroughTrachealLumen;
    action routeGasThroughBronchialLumen;
    action receiveCombinedExpiration;
  }

  action def VentilateSelectedLung {
    in part tube: DoubleLumenEndobronchialTube;
    in attribute selectedSide: LungSide;
    in item inspiredGas: InspiredGas;
    out item expiredGas: ExpiredGas;
    out item airwayPressure: PatientAirwayPressure;

    action clampNonVentilatedLumen;
    action routeInspiredGasToSelectedLumen;
    action maintainCuffSeal;
    action receiveExpiredGasFromSelectedLung;
    action monitorPressureAndVolume;

    flow inspiredGas to routeInspiredGasToSelectedLumen;
    flow routeInspiredGasToSelectedLumen to maintainCuffSeal;
    flow maintainCuffSeal to receiveExpiredGasFromSelectedLung;
    flow receiveExpiredGasFromSelectedLung to expiredGas;
  }

  action def IsolateLung {
    in part tube: DoubleLumenEndobronchialTube;
    in attribute isolatedSide: LungSide;
    out attribute activeMode: VentilationMode;

    action blockCrossVentilation;
    action sealTracheaWithTrachealCuff;
    action sealTargetBronchusWithBronchialCuff;
    action openNonIsolatedLumenForVentilation;
    action verifyNoLeak {
      out attribute mode: VentilationMode = VentilationMode::lungIsolation;
    }

    flow verifyNoLeak.mode to activeMode;
  }

  action def SuctionIsolatedLung {
    in part tube: DoubleLumenEndobronchialTube;
    in attribute suctionedSide: LungSide;
    out item removedSecretions: AirwaySecretions;

    action connectSuctionToLumen;
    action applyControlledNegativePressure;
    action collectSecretions {
      out item secretions: AirwaySecretions;
    }

    flow collectSecretions.secretions to removedSecretions;
  }

  state def DoubleLumenTubeOperationalState {
    entry action initialize {
      out attribute initialMode: VentilationMode = VentilationMode::bothLungVentilation;
    }

    state OutsidePatient;
    state InsertedUnconfirmed;
    state PositionConfirmed;
    state BothLungsVentilated;
    state LeftLungVentilatedRightLungIsolated;
    state RightLungVentilatedLeftLungIsolated;
    state IsolatedLungSuction;
    state EmergencyCuffsDeflated;
    state Removed;

    transition first OutsidePatient;

    transition insert
      first OutsidePatient
      then InsertedUnconfirmed;

    transition confirmWithBronchoscope
      first InsertedUnconfirmed
      then PositionConfirmed;

    transition beginTwoLungVentilation
      first PositionConfirmed
      then BothLungsVentilated;

    transition isolateRightLung
      first BothLungsVentilated
      then LeftLungVentilatedRightLungIsolated;

    transition isolateLeftLung
      first BothLungsVentilated
      then RightLungVentilatedLeftLungIsolated;

    transition suctionIsolatedLungFromLeftVentilation
      first LeftLungVentilatedRightLungIsolated
      then IsolatedLungSuction;

    transition suctionIsolatedLungFromRightVentilation
      first RightLungVentilatedLeftLungIsolated
      then IsolatedLungSuction;

    transition resumeLeftVentilation
      first IsolatedLungSuction
      then LeftLungVentilatedRightLungIsolated;

    transition resumeRightVentilation
      first IsolatedLungSuction
      then RightLungVentilatedLeftLungIsolated;

    transition returnToBothLungs
      first LeftLungVentilatedRightLungIsolated
      then BothLungsVentilated;

    transition returnToBothLungsFromRightVentilation
      first RightLungVentilatedLeftLungIsolated
      then BothLungsVentilated;

    transition emergencyDeflate
      first BothLungsVentilated
      then EmergencyCuffsDeflated;

    transition emergencyDeflateFromIsolation
      first LeftLungVentilatedRightLungIsolated
      then EmergencyCuffsDeflated;

    transition emergencyDeflateFromOppositeIsolation
      first RightLungVentilatedLeftLungIsolated
      then EmergencyCuffsDeflated;

    transition removeTube
      first EmergencyCuffsDeflated
      then Removed;
  }

  requirement def PrimaryFunctionRequirement {
    doc /*
      The system shall provide a secure double-lumen airway that enables independent
      ventilation of the left and right lungs and permits intentional one-lung
      ventilation or lung isolation during thoracic anesthesia and airway management.
    */
    subject tube: DoubleLumenEndobronchialTube;
    require constraint {
      tube.shaft.trachealLumen.innerDiameter > 0.0 and
      tube.shaft.bronchialLumen.innerDiameter > 0.0 and
      tube.trachealCuff.nominalVolume > 0.0 and
      tube.bronchialCuff.nominalVolume > 0.0
    }
  }

  requirement def LungIsolationRequirement {
    doc /*
      When lung isolation mode is selected, the tracheal and bronchial cuffs shall
      form seals sufficient to reduce cross-ventilation between lungs while preserving
      a patent ventilation path to the selected lung.
    */
    subject tube: DoubleLumenEndobronchialTube;
    require constraint {
      tube.trachealCuff.sealPressure <= tube.trachealCuff.maximumRecommendedPressure and
      tube.bronchialCuff.sealPressure <= tube.bronchialCuff.maximumRecommendedPressure
    }
  }

  requirement def IndependentLumenRequirement {
    doc /*
      The tube shall contain two physically separate gas pathways: one tracheal lumen
      terminating above the carina and one bronchial lumen terminating in the intended
      main bronchus.
    */
    subject tube: DoubleLumenEndobronchialTube;
    require constraint {
      tube.shaft.trachealLumen.lumenLength < tube.shaft.bronchialLumen.lumenLength and
      tube.shaft.bronchialLumen.intendedBronchus == LungSide::left
    }
  }

  requirement def CuffPressureSafetyRequirement {
    doc /*
      Cuff pressures shall remain within recommended limits to reduce risk of airway
      mucosal injury while maintaining a seal.
    */
    subject tube: DoubleLumenEndobronchialTube;
    require constraint {
      tube.trachealCuff.maximumRecommendedPressure <= 30.0 and
      tube.bronchialCuff.maximumRecommendedPressure <= 25.0
    }
  }

  requirement def VentilatorInterfaceRequirement {
    doc /*
      The proximal connector shall provide a standard ventilator interface capable
      of bidirectional inspiratory and expiratory gas flow.
    */
    subject tube: DoubleLumenEndobronchialTube;
    require constraint {
      tube.connector.connectorDiameter == 15.0 and
      tube.connector.ventilatorInterface.maximumFlow >= 100.0
    }
  }

  requirement def PositionConfirmationRequirement {
    doc /*
      The system shall support bronchoscopic confirmation of bronchial cuff and
      bronchial tip position before one-lung ventilation is initiated.
    */
    subject tube: DoubleLumenEndobronchialTube;
    require constraint {
      tube.positionStatus == TubePositionStatus::confirmedByBronchoscopy or
      tube.currentMode == VentilationMode::bothLungVentilation
    }
  }

  requirement def SecretionRemovalRequirement {
    doc /*
      The system shall allow suctioning or decompression through a lumen associated
      with the non-ventilated or isolated lung.
    */
    subject tube: DoubleLumenEndobronchialTube;
    require constraint {
      tube.secretionRemovalPort.maximumSuctionFlow <= 40.0
    }
  }

  satisfy PrimaryFunctionRequirement by DoubleLumenEndobronchialTube;
  satisfy LungIsolationRequirement by DoubleLumenEndobronchialTube;
  satisfy IndependentLumenRequirement by TubeShaft;
  satisfy CuffPressureSafetyRequirement by TrachealCuff;
  satisfy CuffPressureSafetyRequirement by BronchialCuff;
  satisfy VentilatorInterfaceRequirement by UniversalVentilatorConnector;
  satisfy PositionConfirmationRequirement by BronchialLumen;
  satisfy SecretionRemovalRequirement by TrachealLumen;

  package ExampleConfiguration {
    part clinicalUseCase: DoubleLumenTubeClinicalSystem {
      part tube {
        attribute nominalFrenchSize = 37.0;
        attribute isLeftSidedTube = true;
        attribute currentMode = VentilationMode::leftLungVentilation;
        attribute selectedVentilatedSide = LungSide::left;
        attribute positionStatus = TubePositionStatus::confirmedByBronchoscopy;
      }

      part ventilator {
        attribute setRespiratoryRate_per_min = 12.0;
        attribute setTidalVolume = 450.0;
        attribute setPeakPressureLimit = 35.0;
        attribute setOxygenFraction = 60.0;
      }

      part patientAirway {
        attribute trachealDiameter = 18.0;
        attribute leftMainBronchusDiameter = 12.0;
        attribute rightMainBronchusDiameter = 14.0;
        attribute currentPositionStatus = TubePositionStatus::confirmedByBronchoscopy;
      }
    }

    action clinicalSequence {
      first start;
      then insertTube: InsertTube {
        in tube = clinicalUseCase.tube;
        in patientAirway = clinicalUseCase.patientAirway;
      }
      then inflateCuffs: InflateCuffs {
        in tube = clinicalUseCase.tube;
      }
      then confirmPosition: ConfirmTubePosition {
        in tube = clinicalUseCase.tube;
      }
      then isolateRightLung: IsolateLung {
        in tube = clinicalUseCase.tube;
        in isolatedSide = LungSide::right;
      }
      then ventilateLeftLung: VentilateSelectedLung {
        in tube = clinicalUseCase.tube;
        in selectedSide = LungSide::left;
      }
      then done;
    }
  }
}
