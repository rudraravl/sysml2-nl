package HybridOperatingRoomSpecification {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percent :> Real;
  attribute def RiskScore :> Real;
  attribute def AvailabilityRatio :> Real;
  attribute def SterilityClass :> String;
  attribute def ProcedurePhaseName :> String;

  item def Patient {
    attribute patientIdentifier : String;
    attribute bodyMass : MassValue;
    attribute age : Integer;
    attribute surgicalSite : String;
    attribute physiologicStability : Percent;
  }

  item def SurgicalTeamMember {
    attribute role : String;
    attribute credentialLevel : String;
  }

  item def SterileInstrument {
    attribute instrumentName : String;
    attribute sterile : Boolean;
    attribute lotIdentifier : String;
  }

  item def MedicalImage {
    attribute modality : String;
    attribute acquisitionTime : TimeValue;
    attribute resolution : String;
    attribute patientIdentifier : String;
  }

  item def VitalSignSet {
    attribute heartRate : FrequencyValue;
    attribute arterialPressure : PressureValue;
    attribute oxygenSaturation : Percent;
    attribute endTidalCO2 : PressureValue;
    attribute bodyTemperature : TemperatureValue;
  }

  item def DeviceCommand {
    attribute commandName : String;
    attribute targetDevice : String;
    attribute requestedBy : String;
    attribute priority : Integer;
  }

  item def ClinicalData {
    attribute recordIdentifier : String;
    attribute patientIdentifier : String;
    attribute timestamp : TimeValue;
    attribute contentType : String;
  }

  item def Medication {
    attribute medicationName : String;
    attribute concentration : Real;
    attribute doseRate : Real;
  }

  item def WasteMaterial {
    attribute wasteType : String;
    attribute biohazardous : Boolean;
    attribute volume : VolumeValue;
  }

  port def PatientTransferPort {
    inout item patient : Patient;
  }

  port def StaffAccessPort {
    inout item staffMember : SurgicalTeamMember;
  }

  port def InstrumentPort {
    inout item instrument : SterileInstrument;
  }

  port def ImageDataPort {
    out item image : MedicalImage;
  }

  port def VitalSignsPort {
    out item vitalSigns : VitalSignSet;
  }

  port def CommandPort {
    in item command : DeviceCommand;
  }

  port def ClinicalDataPort {
    inout item clinicalData : ClinicalData;
  }

  port def MedicationPort {
    out item medication : Medication;
  }

  port def WastePort {
    out item waste : WasteMaterial;
  }

  port def PowerPort {
    in attribute voltage : ElectricPotentialValue;
    in attribute frequency : FrequencyValue;
    in attribute availablePower : PowerValue;
  }

  port def NetworkPort {
    inout item clinicalData : ClinicalData;
    inout item image : MedicalImage;
    in item command : DeviceCommand;
  }

  port def AirHandlingPort {
    in attribute supplyAirFlow : VolumeFlowRateValue;
    out attribute exhaustAirFlow : VolumeFlowRateValue;
    in attribute supplyAirTemperature : TemperatureValue;
  }

  part def ImagingSubsystem {
    port imageOut : ImageDataPort;
    port commandIn : CommandPort;
    port powerIn : PowerPort;
    port network : NetworkPort;

    attribute supportedModalities : String;
    attribute radiationOutputEnabled : Boolean;
    attribute maxImagingFieldDiameter : LengthValue;
    attribute imageLatency : TimeValue;
    attribute gantryClearance : LengthValue;

    action acquireImage {
      in item patient : Patient;
      in attribute requestedModality : String;
      out item image : MedicalImage;
    }

    action positionImager {
      in attribute tablePosition : LengthValue;
      in attribute targetAnatomy : String;
      out attribute positioned : Boolean;
    }

    state def ImagingState {
      state idle;
      state positioning;
      state acquiring;
      state imageAvailable;
      state faulted;

      transition first idle;
      transition idle_to_positioning
        first idle
        then positioning;

      transition positioning_to_acquiring
        first positioning
        then acquiring;

      transition acquiring_to_imageAvailable
        first acquiring
        then imageAvailable;

      transition imageAvailable_to_idle
        first imageAvailable
        then idle;

      transition any_to_faulted
        first idle
        then faulted;
    }

    attribute operatingState : ImagingState;
  }

  part def SurgicalTable {
    port patientInterface : PatientTransferPort;
    port commandIn : CommandPort;
    port powerIn : PowerPort;

    attribute longitudinalTravel : LengthValue;
    attribute lateralTravel : LengthValue;
    attribute heightRange : LengthValue;
    attribute maxPatientMass : MassValue;
    attribute radiolucentTop : Boolean;
    attribute locked : Boolean;

    action moveTable {
      in attribute longitudinalOffset : LengthValue;
      in attribute lateralOffset : LengthValue;
      in attribute heightOffset : LengthValue;
      out attribute completed : Boolean;
    }

    action lockForProcedure {
      out attribute lockedConfirmed : Boolean;
    }
  }

  part def AnesthesiaSubsystem {
    port patientInterface : PatientTransferPort;
    port vitalSignsOut : VitalSignsPort;
    port medicationOut : MedicationPort;
    port commandIn : CommandPort;
    port powerIn : PowerPort;
    port network : NetworkPort;

    attribute ventilatorMode : String;
    attribute oxygenFlow : VolumeFlowRateValue;
    attribute airwayPressureLimit : PressureValue;
    attribute anestheticAgent : String;
    attribute gasScavengingActive : Boolean;

    action induceAnesthesia {
      in item patient : Patient;
      out attribute patientAnesthetized : Boolean;
    }

    action maintainVentilation {
      in item vitalSigns : VitalSignSet;
      out attribute ventilationAdequate : Boolean;
    }

    action deliverMedication {
      in item medicationOrder : Medication;
      out attribute doseDelivered : Boolean;
    }

    state def AnesthesiaState {
      state standby;
      state preoxygenating;
      state induction;
      state maintenance;
      state emergence;
      state emergencySupport;

      transition first standby;
      transition standby_to_preoxygenating
        first standby
        then preoxygenating;

      transition preoxygenating_to_induction
        first preoxygenating
        then induction;

      transition induction_to_maintenance
        first induction
        then maintenance;

      transition maintenance_to_emergence
        first maintenance
        then emergence;

      transition maintenance_to_emergencySupport
        first maintenance
        then emergencySupport;

      transition emergencySupport_to_maintenance
        first emergencySupport
        then maintenance;
    }

    attribute operatingState : AnesthesiaState;
  }

  part def SurgicalBoom {
    port powerIn : PowerPort;
    port network : NetworkPort;
    port instrumentInterface : InstrumentPort;
    port commandIn : CommandPort;

    attribute numberOfGasOutlets : Integer;
    attribute numberOfPowerOutlets : Integer;
    attribute loadCapacity : MassValue;
    attribute rotationRange : AngleValue;

    action positionBoom {
      in attribute rotationAngle : AngleValue;
      in attribute height : LengthValue;
      out attribute positioned : Boolean;
    }
  }

  part def SterileFieldManagement {
    port instrumentInOut : InstrumentPort;
    port staffAccess : StaffAccessPort;
    port wasteOut : WastePort;

    attribute sterilityClass : SterilityClass;
    attribute positivePressureMaintained : Boolean;
    attribute contaminationDetected : Boolean;
    attribute sterileZoneArea : AreaValue;

    action verifySterility {
      in item instrument : SterileInstrument;
      out attribute accepted : Boolean;
    }

    action isolateContamination {
      out attribute sterileFieldRestored : Boolean;
    }
  }

  part def EnvironmentalControlSubsystem {
    port airHandling : AirHandlingPort;
    port commandIn : CommandPort;
    port powerIn : PowerPort;
    port network : NetworkPort;

    attribute airChangesPerHour : Real;
    attribute roomTemperature : TemperatureValue;
    attribute relativeHumidity : Percent;
    attribute roomPressureDifferential : PressureValue;
    attribute laminarFlowActive : Boolean;
    attribute particulateCount : Real;

    action maintainSurgicalEnvironment {
      out attribute environmentWithinLimits : Boolean;
    }

    action purgeRoomAir {
      in attribute purgeDuration : TimeValue;
      out attribute completed : Boolean;
    }
  }

  part def ClinicalIntegrationSubsystem {
    port network : NetworkPort;
    port clinicalData : ClinicalDataPort;
    port imageIn : ImageDataPort;
    port commandOut : CommandPort;

    attribute connectedToHospitalInformationSystem : Boolean;
    attribute connectedToPictureArchive : Boolean;
    attribute cybersecurityMode : String;
    attribute auditLoggingEnabled : Boolean;
    attribute maximumImageTransferLatency : TimeValue;

    action retrievePatientContext {
      in item patient : Patient;
      out item clinicalData : ClinicalData;
    }

    action storeProcedureRecord {
      in item clinicalData : ClinicalData;
      in item image : MedicalImage;
      out attribute stored : Boolean;
    }

    action routeDeviceCommand {
      in item command : DeviceCommand;
      out attribute routed : Boolean;
    }
  }

  part def SurgicalLightingSubsystem {
    port commandIn : CommandPort;
    port powerIn : PowerPort;

    attribute illuminanceAtField : IlluminanceValue;
    attribute colorTemperature : TemperatureValue;
    attribute shadowDilutionMode : String;
    attribute sterileHandleInstalled : Boolean;

    action adjustLighting {
      in attribute targetIlluminance : IlluminanceValue;
      in attribute targetColorTemperature : TemperatureValue;
      out attribute adjusted : Boolean;
    }
  }

  part def SafetyAndAlarmSubsystem {
    port vitalSignsIn : VitalSignsPort;
    port network : NetworkPort;
    port commandOut : CommandPort;
    port powerIn : PowerPort;

    attribute alarmPriority : Integer;
    attribute activeAlarmCount : Integer;
    attribute emergencyPowerAvailable : Boolean;
    attribute evacuationRouteClear : Boolean;

    action evaluatePatientSafety {
      in item vitalSigns : VitalSignSet;
      out attribute safeToContinue : Boolean;
    }

    action triggerClinicalAlarm {
      in attribute alarmReason : String;
      out item alarmCommand : DeviceCommand;
    }

    action enterEmergencyMode {
      out attribute emergencyModeActive : Boolean;
    }
  }

  part def HybridOperatingRoom {
    port patientEntry : PatientTransferPort;
    port staffEntry : StaffAccessPort;
    port sterileInstrumentSupply : InstrumentPort;
    port clinicalNetwork : NetworkPort;
    port facilityPower : PowerPort;
    port airSupply : AirHandlingPort;
    port wasteExit : WastePort;

    part imaging : ImagingSubsystem;
    part table : SurgicalTable;
    part anesthesia : AnesthesiaSubsystem;
    part boom : SurgicalBoom;
    part sterileField : SterileFieldManagement;
    part environment : EnvironmentalControlSubsystem;
    part integration : ClinicalIntegrationSubsystem;
    part lighting : SurgicalLightingSubsystem;
    part safety : SafetyAndAlarmSubsystem;

    attribute roomIdentifier : String;
    attribute usableFloorArea : AreaValue;
    attribute maximumOccupancy : Integer;
    attribute configuredForOpenSurgery : Boolean;
    attribute configuredForImageGuidedIntervention : Boolean;
    attribute clinicalAvailability : AvailabilityRatio;
    attribute currentProcedurePhase : ProcedurePhaseName;

    connect patientEntry to table.patientInterface;
    connect patientEntry to anesthesia.patientInterface;
    connect staffEntry to sterileField.staffAccess;
    connect sterileInstrumentSupply to sterileField.instrumentInOut;
    connect wasteExit to sterileField.wasteOut;

    connect facilityPower to imaging.powerIn;
    connect facilityPower to table.powerIn;
    connect facilityPower to anesthesia.powerIn;
    connect facilityPower to boom.powerIn;
    connect facilityPower to environment.powerIn;
    connect facilityPower to lighting.powerIn;
    connect facilityPower to safety.powerIn;

    connect airSupply to environment.airHandling;

    connect clinicalNetwork to integration.network;
    connect clinicalNetwork to imaging.network;
    connect clinicalNetwork to anesthesia.network;
    connect clinicalNetwork to environment.network;
    connect clinicalNetwork to safety.network;
    connect clinicalNetwork to boom.network;

    connect imaging.imageOut to integration.imageIn;
    connect anesthesia.vitalSignsOut to safety.vitalSignsIn;

    connect integration.commandOut to imaging.commandIn;
    connect integration.commandOut to table.commandIn;
    connect integration.commandOut to anesthesia.commandIn;
    connect integration.commandOut to boom.commandIn;
    connect integration.commandOut to environment.commandIn;
    connect integration.commandOut to lighting.commandIn;

    connect safety.commandOut to integration.commandOut;

    action performHybridProcedure {
      in item patient : Patient;
      in item primarySurgeon : SurgicalTeamMember;
      in attribute targetAnatomy : String;
      out item procedureRecord : ClinicalData;
      out attribute procedureCompleted : Boolean;

      first startCase;
      then prepareRoom;
      then receivePatient;
      then establishAnesthesia;
      then createSterileField;
      then acquireBaselineImages;
      then performImageGuidedTherapy;
      then closeProcedure;
      then transferPatientOut;

      action startCase {
        out attribute caseStarted : Boolean;
      }

      action prepareRoom {
        out attribute roomReady : Boolean;
      }

      action receivePatient {
        in item patient : Patient;
        out attribute patientPositioned : Boolean;
      }

      action establishAnesthesia {
        in item patient : Patient;
        out attribute anesthesiaReady : Boolean;
      }

      action createSterileField {
        out attribute sterileFieldReady : Boolean;
      }

      action acquireBaselineImages {
        in attribute targetAnatomy : String;
        out item baselineImage : MedicalImage;
      }

      action performImageGuidedTherapy {
        in item baselineImage : MedicalImage;
        out attribute therapyDelivered : Boolean;
      }

      action closeProcedure {
        out item procedureRecord : ClinicalData;
      }

      action transferPatientOut {
        out attribute patientTransferred : Boolean;
      }
    }

    state def RoomOperationalState {
      state offline;
      state idleReady;
      state setup;
      state patientInRoom;
      state anesthesiaActive;
      state sterileProcedureActive;
      state imagingActive;
      state emergencyMode;
      state turnover;
      state maintenance;

      transition first offline;

      transition offline_to_idleReady
        first offline
        then idleReady;

      transition idleReady_to_setup
        first idleReady
        then setup;

      transition setup_to_patientInRoom
        first setup
        then patientInRoom;

      transition patientInRoom_to_anesthesiaActive
        first patientInRoom
        then anesthesiaActive;

      transition anesthesiaActive_to_sterileProcedureActive
        first anesthesiaActive
        then sterileProcedureActive;

      transition sterileProcedureActive_to_imagingActive
        first sterileProcedureActive
        then imagingActive;

      transition imagingActive_to_sterileProcedureActive
        first imagingActive
        then sterileProcedureActive;

      transition sterileProcedureActive_to_turnover
        first sterileProcedureActive
        then turnover;

      transition turnover_to_idleReady
        first turnover
        then idleReady;

      transition idleReady_to_maintenance
        first idleReady
        then maintenance;

      transition maintenance_to_idleReady
        first maintenance
        then idleReady;

      transition anesthesiaActive_to_emergencyMode
        first anesthesiaActive
        then emergencyMode;

      transition sterileProcedureActive_to_emergencyMode
        first sterileProcedureActive
        then emergencyMode;

      transition imagingActive_to_emergencyMode
        first imagingActive
        then emergencyMode;

      transition emergencyMode_to_turnover
        first emergencyMode
        then turnover;
    }

    attribute operatingState : RoomOperationalState;
  }

  requirement def PrimaryFunctionRequirement {
    subject hybridOR : HybridOperatingRoom;

    doc
    /*
     The Hybrid Operating Room shall provide an integrated sterile surgical environment
     that combines open surgical capability, real-time medical imaging, anesthesia support,
     patient monitoring, device control, and clinical data integration so that clinicians
     can perform complex image-guided procedures without transferring the patient between
     separate operating and imaging locations.
    */

    require constraint {
      hybridOR.configuredForOpenSurgery == true and
      hybridOR.configuredForImageGuidedIntervention == true
    }
  }

  requirement def SterileEnvironmentRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.environment.airChangesPerHour >= 20.0 and
      hybridOR.environment.relativeHumidity >= 20.0 and
      hybridOR.environment.relativeHumidity <= 60.0 and
      hybridOR.environment.positivePressureMaintained == true
    }
  }

  requirement def ImagingAvailabilityRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.imaging.imageLatency <= 5 [s] and
      hybridOR.imaging.maxImagingFieldDiameter >= 300 [mm] and
      hybridOR.imaging.gantryClearance >= 900 [mm]
    }
  }

  requirement def PatientSupportRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.table.maxPatientMass >= 250 [kg] and
      hybridOR.table.radiolucentTop == true
    }
  }

  requirement def AnesthesiaSupportRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.anesthesia.airwayPressureLimit <= 6 [kPa] and
      hybridOR.anesthesia.gasScavengingActive == true
    }
  }

  requirement def ClinicalIntegrationRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.integration.connectedToHospitalInformationSystem == true and
      hybridOR.integration.connectedToPictureArchive == true and
      hybridOR.integration.auditLoggingEnabled == true and
      hybridOR.integration.maximumImageTransferLatency <= 10 [s]
    }
  }

  requirement def SafetyRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.safety.emergencyPowerAvailable == true and
      hybridOR.safety.activeAlarmCount >= 0
    }
  }

  requirement def AvailabilityRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.clinicalAvailability >= 0.98
    }
  }

  requirement def LightingRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.lighting.illuminanceAtField >= 40000 [lx] and
      hybridOR.lighting.illuminanceAtField <= 160000 [lx]
    }
  }

  requirement def RoomCapacityRequirement {
    subject hybridOR : HybridOperatingRoom;

    require constraint {
      hybridOR.usableFloorArea >= 70 [m^2] and
      hybridOR.maximumOccupancy >= 10
    }
  }

  satisfy PrimaryFunctionRequirement by HybridOperatingRoom;
  satisfy SterileEnvironmentRequirement by EnvironmentalControlSubsystem;
  satisfy ImagingAvailabilityRequirement by ImagingSubsystem;
  satisfy PatientSupportRequirement by SurgicalTable;
  satisfy AnesthesiaSupportRequirement by AnesthesiaSubsystem;
  satisfy ClinicalIntegrationRequirement by ClinicalIntegrationSubsystem;
  satisfy SafetyRequirement by SafetyAndAlarmSubsystem;
  satisfy AvailabilityRequirement by HybridOperatingRoom;
  satisfy LightingRequirement by SurgicalLightingSubsystem;
  satisfy RoomCapacityRequirement by HybridOperatingRoom;

  part hybridOperatingRoomExample : HybridOperatingRoom {
    attribute roomIdentifier = "HOR-01";
    attribute usableFloorArea = 82 [m^2];
    attribute maximumOccupancy = 14;
    attribute configuredForOpenSurgery = true;
    attribute configuredForImageGuidedIntervention = true;
    attribute clinicalAvailability = 0.985;
    attribute currentProcedurePhase = "IdleReady";

    part imaging {
      attribute supportedModalities = "Fixed C-arm fluoroscopy, digital subtraction angiography, cone-beam CT";
      attribute radiationOutputEnabled = false;
      attribute maxImagingFieldDiameter = 400 [mm];
      attribute imageLatency = 3 [s];
      attribute gantryClearance = 1000 [mm];
    }

    part table {
      attribute longitudinalTravel = 1200 [mm];
      attribute lateralTravel = 250 [mm];
      attribute heightRange = 500 [mm];
      attribute maxPatientMass = 275 [kg];
      attribute radiolucentTop = true;
      attribute locked = true;
    }

    part anesthesia {
      attribute ventilatorMode = "Volume controlled ventilation";
      attribute oxygenFlow = 10 [l/min];
      attribute airwayPressureLimit = 5.5 [kPa];
      attribute anestheticAgent = "Sevoflurane";
      attribute gasScavengingActive = true;
    }

    part boom {
      attribute numberOfGasOutlets = 8;
      attribute numberOfPowerOutlets = 16;
      attribute loadCapacity = 180 [kg];
      attribute rotationRange = 340 [deg];
    }

    part sterileField {
      attribute sterilityClass = "Operating room sterile field";
      attribute positivePressureMaintained = true;
      attribute contaminationDetected = false;
      attribute sterileZoneArea = 18 [m^2];
    }

    part environment {
      attribute airChangesPerHour = 25.0;
      attribute roomTemperature = 294 [K];
      attribute relativeHumidity = 45.0;
      attribute roomPressureDifferential = 15 [Pa];
      attribute laminarFlowActive = true;
      attribute particulateCount = 1200.0;
    }

    part integration {
      attribute connectedToHospitalInformationSystem = true;
      attribute connectedToPictureArchive = true;
      attribute cybersecurityMode = "Authenticated segmented clinical network";
      attribute auditLoggingEnabled = true;
      attribute maximumImageTransferLatency = 6 [s];
    }

    part lighting {
      attribute illuminanceAtField = 120000 [lx];
      attribute colorTemperature = 4300 [K];
      attribute shadowDilutionMode = "Dual head adaptive";
      attribute sterileHandleInstalled = true;
    }

    part safety {
      attribute alarmPriority = 1;
      attribute activeAlarmCount = 0;
      attribute emergencyPowerAvailable = true;
      attribute evacuationRouteClear = true;
    }
  }
}