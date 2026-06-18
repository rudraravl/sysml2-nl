package MerilLifeSciences_CardiovascularInterventionSystem {

  import ScalarValues::*;

  enum def SterilityStatus {
    enum sterile;
    enum compromised;
    enum used;
  }

  enum def DeploymentState {
    enum packaged;
    enum prepared;
    enum vascularAccessEstablished;
    enum tracking;
    enum positioned;
    enum partiallyDeployed;
    enum fullyDeployed;
    enum verified;
    enum retrieved;
    enum disposed;
  }

  enum def ClinicalOutcome {
    enum notStarted;
    enum valveFunctionRestored;
    enum repositionRequired;
    enum deploymentAborted;
    enum adverseEventDetected;
  }

  enum def FlowDirection {
    enum antegrade;
    enum retrograde;
    enum none;
  }

  attribute def Length_mm {
    attribute value : Real;
    attribute unit : String = "mm";
  }

  attribute def Diameter_mm :> Length_mm;

  attribute def Area_mm2 {
    attribute value : Real;
    attribute unit : String = "mm^2";
  }

  attribute def Volume_mL {
    attribute value : Real;
    attribute unit : String = "mL";
  }

  attribute def Pressure_atm {
    attribute value : Real;
    attribute unit : String = "atm";
  }

  attribute def Pressure_mmHg {
    attribute value : Real;
    attribute unit : String = "mmHg";
  }

  attribute def Force_N {
    attribute value : Real;
    attribute unit : String = "N";
  }

  attribute def Mass_g {
    attribute value : Real;
    attribute unit : String = "g";
  }

  attribute def Time_s {
    attribute value : Real;
    attribute unit : String = "s";
  }

  attribute def Temperature_C {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def Dose_mg {
    attribute value : Real;
    attribute unit : String = "mg";
  }

  attribute def Percent {
    attribute value : Real;
    attribute unit : String = "%";
  }

  item def Patient {
    attribute patientIdentifier : String;
    attribute aorticAnnulusDiameter : Diameter_mm;
    attribute aorticPressure : Pressure_mmHg;
    attribute leftVentricularPressure : Pressure_mmHg;
    attribute bloodTemperature : Temperature_C;
    attribute baselineAorticValveArea : Area_mm2;
    attribute postProcedureAorticValveArea : Area_mm2;
    attribute clinicalOutcome : ClinicalOutcome;
  }

  item def NativeAorticValve {
    attribute annulusDiameter : Diameter_mm;
    attribute stenosisSeverity : Percent;
    attribute regurgitationSeverity : Percent;
    attribute calcificationSeverity : Percent;
  }

  item def BioprostheticValveImplant {
    attribute nominalDiameter : Diameter_mm;
    attribute frameMaterial : String = "cobalt chromium alloy";
    attribute leafletMaterial : String = "bovine pericardial tissue";
    attribute crimpedProfile : Diameter_mm;
    attribute expandedProfile : Diameter_mm;
    attribute implantMass : Mass_g;
    attribute expectedServiceLifeYears : Real;
    attribute sterility : SterilityStatus;
  }

  item def BalloonCatheter {
    attribute balloonNominalDiameter : Diameter_mm;
    attribute balloonRatedBurstPressure : Pressure_atm;
    attribute balloonFillVolume : Volume_mL;
    attribute shaftOuterDiameter : Diameter_mm;
    attribute usableLength : Length_mm;
  }

  item def Guidewire {
    attribute outerDiameter : Diameter_mm;
    attribute usableLength : Length_mm;
    attribute tipShape : String;
  }

  item def IntroducerSheath {
    attribute innerDiameter : Diameter_mm;
    attribute hemostasisValveLeakage : Volume_mL;
    attribute usableLength : Length_mm;
  }

  item def SterileSaline {
    attribute volume : Volume_mL;
    attribute temperature : Temperature_C;
    attribute sterility : SterilityStatus;
  }

  item def ContrastMedium {
    attribute volume : Volume_mL;
    attribute iodineConcentration : String;
    attribute temperature : Temperature_C;
  }

  item def ClinicianCommand {
    attribute commandName : String;
    attribute requestedDeploymentState : DeploymentState;
    attribute commandTime : Time_s;
  }

  item def DeviceStatus {
    attribute state : DeploymentState;
    attribute implantLoaded : Boolean;
    attribute pressureWithinLimit : Boolean;
    attribute positionAcceptable : Boolean;
    attribute sterility : SterilityStatus;
    attribute message : String;
  }

  item def FluoroscopyImage {
    attribute frameRate : Real;
    attribute imageWidth : Length_mm;
    attribute imageHeight : Length_mm;
    attribute contrastVisible : Boolean;
    attribute valveMarkerVisible : Boolean;
  }

  item def HemodynamicMeasurement {
    attribute aorticPressure : Pressure_mmHg;
    attribute ventricularPressure : Pressure_mmHg;
    attribute pressureGradient : Pressure_mmHg;
    attribute forwardFlowDirection : FlowDirection;
  }

  item def DeploymentRecord {
    attribute selectedValveDiameter : Diameter_mm;
    attribute maximumInflationPressure : Pressure_atm;
    attribute deploymentDuration : Time_s;
    attribute finalValveArea : Area_mm2;
    attribute finalPressureGradient : Pressure_mmHg;
    attribute outcome : ClinicalOutcome;
  }

  port def CommandStatusPort {
    in item command : ClinicianCommand;
    out item status : DeviceStatus;
  }

  port def ImagingPort {
    out item image : FluoroscopyImage;
  }

  port def HemodynamicPort {
    in item measurement : HemodynamicMeasurement;
  }

  port def ImplantMountPort {
    inout item implant : BioprostheticValveImplant;
  }

  port def CatheterLumenPort {
    in item saline : SterileSaline;
    in item contrast : ContrastMedium;
  }

  port def VascularInterfacePort {
    inout item patient : Patient;
    inout item nativeValve : NativeAorticValve;
  }

  port def InflationPort {
    in item saline : SterileSaline;
    out item status : DeviceStatus;
  }

  port def GuidewirePort {
    inout item wire : Guidewire;
  }

  interface def CommandInterface {
    end clinicianSide : CommandStatusPort;
    end deviceSide : CommandStatusPort;
  }

  interface def ImageGuidanceInterface {
    end imagingSource : ImagingPort;
    end operatorDisplay : ImagingPort;
  }

  interface def FluidPreparationInterface {
    end preparationSide : CatheterLumenPort;
    end catheterSide : CatheterLumenPort;
  }

  interface def InflationInterface {
    end inflationDeviceSide : InflationPort;
    end balloonSide : InflationPort;
  }

  interface def ImplantCarrierInterface {
    end catheterSide : ImplantMountPort;
    end implantSide : ImplantMountPort;
  }

  constraint def AnnulusValveSizingConstraint {
    in annulusDiameter : Diameter_mm;
    in valveDiameter : Diameter_mm;
    constraint sizingRule {
      valveDiameter.value >= annulusDiameter.value + 1.0 and
      valveDiameter.value <= annulusDiameter.value + 4.0
    }
  }

  constraint def BalloonPressureLimitConstraint {
    in actualPressure : Pressure_atm;
    in ratedBurstPressure : Pressure_atm;
    constraint pressureRule {
      actualPressure.value <= 0.90 * ratedBurstPressure.value
    }
  }

  constraint def SterilityConstraint {
    in status : SterilityStatus;
    constraint sterileRule {
      status == SterilityStatus::sterile
    }
  }

  constraint def HemodynamicSuccessConstraint {
    in finalGradient : Pressure_mmHg;
    in finalArea : Area_mm2;
    constraint successRule {
      finalGradient.value <= 20.0 and finalArea.value >= 150.0
    }
  }

  action def AssessPatientForTranscatheterValve {
    in item patient : Patient;
    in item nativeValve : NativeAorticValve;
    out item selectedValve : BioprostheticValveImplant;
    out item assessmentStatus : DeviceStatus;

    assert constraint AnnulusValveSizingConstraint {
      annulusDiameter = nativeValve.annulusDiameter;
      valveDiameter = selectedValve.nominalDiameter;
    }
  }

  action def PrepareSterileDeliveryKit {
    in item packagedImplant : BioprostheticValveImplant;
    in item catheter : BalloonCatheter;
    in item saline : SterileSaline;
    out item preparedImplant : BioprostheticValveImplant;
    out item preparedStatus : DeviceStatus;

    assert constraint SterilityConstraint {
      status = packagedImplant.sterility;
    }

    assert constraint SterilityConstraint {
      status = saline.sterility;
    }
  }

  action def EstablishFemoralVascularAccess {
    inout item patient : Patient;
    in item sheath : IntroducerSheath;
    in item guidewire : Guidewire;
    out item accessStatus : DeviceStatus;
  }

  action def TrackCatheterToAorticValve {
    inout item patient : Patient;
    in item catheter : BalloonCatheter;
    in item guidewire : Guidewire;
    in item image : FluoroscopyImage;
    out item trackingStatus : DeviceStatus;
  }

  action def PositionImplantAcrossNativeValve {
    inout item patient : Patient;
    in item nativeValve : NativeAorticValve;
    in item implant : BioprostheticValveImplant;
    in item image : FluoroscopyImage;
    out item positioningStatus : DeviceStatus;
  }

  action def DeployBalloonExpandableValve {
    inout item patient : Patient;
    in item implant : BioprostheticValveImplant;
    in item catheter : BalloonCatheter;
    in item saline : SterileSaline;
    out item deploymentStatus : DeviceStatus;
    out item record : DeploymentRecord;

    assert constraint BalloonPressureLimitConstraint {
      actualPressure = record.maximumInflationPressure;
      ratedBurstPressure = catheter.balloonRatedBurstPressure;
    }
  }

  action def VerifyValveFunction {
    inout item patient : Patient;
    in item implant : BioprostheticValveImplant;
    in item hemodynamics : HemodynamicMeasurement;
    in item image : FluoroscopyImage;
    out item verificationStatus : DeviceStatus;
    out item record : DeploymentRecord;

    assert constraint HemodynamicSuccessConstraint {
      finalGradient = hemodynamics.pressureGradient;
      finalArea = record.finalValveArea;
    }
  }

  action def RetrieveAndDisposeDeliverySystem {
    inout item patient : Patient;
    in item catheter : BalloonCatheter;
    in item sheath : IntroducerSheath;
    out item disposalStatus : DeviceStatus;
  }

  action def RestoreAorticValveFunction {
    inout item patient : Patient;
    in item nativeValve : NativeAorticValve;
    in item packagedImplant : BioprostheticValveImplant;
    in item catheter : BalloonCatheter;
    in item sheath : IntroducerSheath;
    in item guidewire : Guidewire;
    in item saline : SterileSaline;
    in item contrast : ContrastMedium;
    in item image : FluoroscopyImage;
    in item hemodynamics : HemodynamicMeasurement;
    out item procedureRecord : DeploymentRecord;

    action assess : AssessPatientForTranscatheterValve;
    action prepare : PrepareSterileDeliveryKit;
    action access : EstablishFemoralVascularAccess;
    action track : TrackCatheterToAorticValve;
    action position : PositionImplantAcrossNativeValve;
    action deploy : DeployBalloonExpandableValve;
    action verify : VerifyValveFunction;
    action retrieve : RetrieveAndDisposeDeliverySystem;

    flow patient to assess.patient;
    flow nativeValve to assess.nativeValve;
    flow packagedImplant to prepare.packagedImplant;
    flow catheter to prepare.catheter;
    flow saline to prepare.saline;
    flow patient to access.patient;
    flow sheath to access.sheath;
    flow guidewire to access.guidewire;
    flow patient to track.patient;
    flow catheter to track.catheter;
    flow guidewire to track.guidewire;
    flow image to track.image;
    flow patient to position.patient;
    flow nativeValve to position.nativeValve;
    flow prepare.preparedImplant to position.implant;
    flow image to position.image;
    flow patient to deploy.patient;
    flow prepare.preparedImplant to deploy.implant;
    flow catheter to deploy.catheter;
    flow saline to deploy.saline;
    flow patient to verify.patient;
    flow prepare.preparedImplant to verify.implant;
    flow hemodynamics to verify.hemodynamics;
    flow image to verify.image;
    flow verify.record to procedureRecord;
    flow patient to retrieve.patient;
    flow catheter to retrieve.catheter;
    flow sheath to retrieve.sheath;
  }

  state def InterventionWorkflow {
    state sterilePackaged;
    state preparedAndFlushed;
    state accessEstablished;
    state catheterTracked;
    state valvePositioned;
    state valvePartiallyDeployed;
    state valveFullyDeployed;
    state valveFunctionVerified;
    state deliverySystemRetrieved;
    state procedureCompleted;
    state procedureAborted;

    transition initial then sterilePackaged;

    transition openSterilePackage
      first sterilePackaged
      accept ClinicianCommand
      if command.commandName == "open sterile kit"
      then preparedAndFlushed;

    transition establishAccess
      first preparedAndFlushed
      accept ClinicianCommand
      if command.commandName == "establish vascular access"
      then accessEstablished;

    transition trackToValve
      first accessEstablished
      accept ClinicianCommand
      if command.commandName == "track catheter"
      then catheterTracked;

    transition positionValve
      first catheterTracked
      accept ClinicianCommand
      if command.commandName == "position implant"
      then valvePositioned;

    transition beginDeployment
      first valvePositioned
      accept ClinicianCommand
      if command.requestedDeploymentState == DeploymentState::partiallyDeployed
      then valvePartiallyDeployed;

    transition completeDeployment
      first valvePartiallyDeployed
      accept ClinicianCommand
      if command.requestedDeploymentState == DeploymentState::fullyDeployed
      then valveFullyDeployed;

    transition verify
      first valveFullyDeployed
      accept HemodynamicMeasurement
      if measurement.pressureGradient.value <= 20.0
      then valveFunctionVerified;

    transition retrieve
      first valveFunctionVerified
      accept ClinicianCommand
      if command.commandName == "retrieve delivery system"
      then deliverySystemRetrieved;

    transition complete
      first deliverySystemRetrieved
      then procedureCompleted;

    transition abortFromPositioning
      first valvePositioned
      accept ClinicianCommand
      if command.commandName == "abort deployment"
      then procedureAborted;

    transition abortFromPartialDeployment
      first valvePartiallyDeployed
      accept ClinicianCommand
      if command.commandName == "abort deployment"
      then procedureAborted;
  }

  part def SterilePackaging {
    attribute barrierIntegrity : Percent;
    attribute shelfLifeMonths : Real;
    attribute ethyleneOxideResidual : Dose_mg;
    attribute sterility : SterilityStatus;

    port kitOutput : ImplantMountPort;
  }

  part def ValveCrimper {
    attribute minimumCrimpDiameter : Diameter_mm;
    attribute maximumCrimpForce : Force_N;
    attribute crimpTime : Time_s;

    port implantPort : ImplantMountPort;
    port commandPort : CommandStatusPort;
  }

  part def InflationDevice {
    attribute maximumPressure : Pressure_atm;
    attribute currentPressure : Pressure_atm;
    attribute reservoirVolume : Volume_mL;

    port fluidPort : InflationPort;
    port commandPort : CommandStatusPort;
  }

  part def DeliveryHandle {
    attribute triggerTravel : Length_mm;
    attribute lockEngaged : Boolean;
    attribute tactileFeedbackForce : Force_N;

    port commandPort : CommandStatusPort;
    port catheterCommandPort : CommandStatusPort;
  }

  part def BalloonDeliveryCatheterAssembly {
    attribute shaftOuterDiameter : Diameter_mm;
    attribute usableLength : Length_mm;
    attribute minimumGuidewireDiameter : Diameter_mm;
    attribute maximumTrackForce : Force_N;
    attribute deploymentState : DeploymentState;

    part balloon : BalloonCatheter {
      attribute balloonNominalDiameter : Diameter_mm = (value = 26.0, unit = "mm");
      attribute balloonRatedBurstPressure : Pressure_atm = (value = 8.0, unit = "atm");
      attribute balloonFillVolume : Volume_mL = (value = 22.0, unit = "mL");
      attribute shaftOuterDiameter : Diameter_mm = (value = 5.5, unit = "mm");
      attribute usableLength : Length_mm = (value = 1100.0, unit = "mm");
    }

    port commandPort : CommandStatusPort;
    port lumenPort : CatheterLumenPort;
    port inflationPort : InflationPort;
    port implantCarrierPort : ImplantMountPort;
    port guidewirePort : GuidewirePort;
    port vascularPort : VascularInterfacePort;
  }

  part def ImageGuidanceConsole {
    attribute fluoroscopyFrameRate : Real;
    attribute imageLatency : Time_s;
    attribute markerDetectionConfidence : Percent;

    port imagePort : ImagingPort;
  }

  part def HemodynamicMonitor {
    attribute samplePeriod : Time_s;
    attribute pressureAccuracy : Pressure_mmHg;

    port hemodynamicPort : HemodynamicPort;
  }

  part def ClinicianInterface {
    attribute displayBrightness : Percent;
    attribute audibleAlarmVolume : Percent;
    attribute currentMessage : String;

    port commandStatusPort : CommandStatusPort;
    port imageInputPort : ImagingPort;
    port hemodynamicInputPort : HemodynamicPort;
  }

  part def SterilePreparationTray {
    attribute workingVolume : Volume_mL;
    attribute surfaceSterility : SterilityStatus;
    attribute fluidTemperature : Temperature_C;

    port catheterLumenPort : CatheterLumenPort;
    port implantPort : ImplantMountPort;
  }

  part def MerilInspiredCardiovascularInterventionSystem {
    attribute manufacturerBasis : String = "Meril Life Sciences cardiovascular and structural-heart medical-device portfolio";
    attribute systemName : String = "Meril-inspired transcatheter aortic valve intervention system";
    attribute primaryFunction : String = "Restore regulated one-way blood flow across a diseased aortic valve by enabling sterile, image-guided transcatheter delivery, positioning, balloon expansion, and verification of a bioprosthetic valve implant.";
    attribute intendedUseEnvironment : String = "hybrid catheterization laboratory or cardiac operating suite";
    attribute nominalProcedureDuration : Time_s = (value = 5400.0, unit = "s");

    part sterilePackaging : SterilePackaging {
      attribute barrierIntegrity : Percent = (value = 100.0, unit = "%");
      attribute shelfLifeMonths : Real = 24.0;
      attribute ethyleneOxideResidual : Dose_mg = (value = 0.5, unit = "mg");
      attribute sterility : SterilityStatus = SterilityStatus::sterile;
    }

    part valveImplant : BioprostheticValveImplant {
      attribute nominalDiameter : Diameter_mm = (value = 26.0, unit = "mm");
      attribute crimpedProfile : Diameter_mm = (value = 6.0, unit = "mm");
      attribute expandedProfile : Diameter_mm = (value = 26.0, unit = "mm");
      attribute implantMass : Mass_g = (value = 8.5, unit = "g");
      attribute expectedServiceLifeYears : Real = 10.0;
      attribute sterility : SterilityStatus = SterilityStatus::sterile;
    }

    part deliveryCatheter : BalloonDeliveryCatheterAssembly {
      attribute shaftOuterDiameter : Diameter_mm = (value = 5.5, unit = "mm");
      attribute usableLength : Length_mm = (value = 1100.0, unit = "mm");
      attribute minimumGuidewireDiameter : Diameter_mm = (value = 0.89, unit = "mm");
      attribute maximumTrackForce : Force_N = (value = 12.0, unit = "N");
      attribute deploymentState : DeploymentState = DeploymentState::packaged;
    }

    part deliveryHandle : DeliveryHandle {
      attribute triggerTravel : Length_mm = (value = 35.0, unit = "mm");
      attribute lockEngaged : Boolean = true;
      attribute tactileFeedbackForce : Force_N = (value = 4.0, unit = "N");
    }

    part crimper : ValveCrimper {
      attribute minimumCrimpDiameter : Diameter_mm = (value = 6.0, unit = "mm");
      attribute maximumCrimpForce : Force_N = (value = 180.0, unit = "N");
      attribute crimpTime : Time_s = (value = 45.0, unit = "s");
    }

    part inflationDevice : InflationDevice {
      attribute maximumPressure : Pressure_atm = (value = 7.2, unit = "atm");
      attribute currentPressure : Pressure_atm = (value = 0.0, unit = "atm");
      attribute reservoirVolume : Volume_mL = (value = 30.0, unit = "mL");
    }

    part preparationTray : SterilePreparationTray {
      attribute workingVolume : Volume_mL = (value = 500.0, unit = "mL");
      attribute surfaceSterility : SterilityStatus = SterilityStatus::sterile;
      attribute fluidTemperature : Temperature_C = (value = 22.0, unit = "degC");
    }

    part imagingConsole : ImageGuidanceConsole {
      attribute fluoroscopyFrameRate : Real = 15.0;
      attribute imageLatency : Time_s = (value = 0.15, unit = "s");
      attribute markerDetectionConfidence : Percent = (value = 98.0, unit = "%");
    }

    part hemodynamicMonitor : HemodynamicMonitor {
      attribute samplePeriod : Time_s = (value = 0.02, unit = "s");
      attribute pressureAccuracy : Pressure_mmHg = (value = 2.0, unit = "mmHg");
    }

    part clinicianInterface : ClinicianInterface {
      attribute displayBrightness : Percent = (value = 80.0, unit = "%");
      attribute audibleAlarmVolume : Percent = (value = 70.0, unit = "%");
      attribute currentMessage : String = "System ready for sterile preparation";
    }

    part introducerSheath : IntroducerSheath {
      attribute innerDiameter : Diameter_mm = (value = 6.7, unit = "mm");
      attribute hemostasisValveLeakage : Volume_mL = (value = 1.0, unit = "mL");
      attribute usableLength : Length_mm = (value = 250.0, unit = "mm");
    }

    part guidewire : Guidewire {
      attribute outerDiameter : Diameter_mm = (value = 0.89, unit = "mm");
      attribute usableLength : Length_mm = (value = 2600.0, unit = "mm");
      attribute tipShape : String = "pre-shaped atraumatic J tip";
    }

    port clinicianCommandPort : CommandStatusPort;
    port patientInterfacePort : VascularInterfacePort;
    port imageOutputPort : ImagingPort;
    port hemodynamicInputPort : HemodynamicPort;

    connect deliveryHandle.catheterCommandPort to deliveryCatheter.commandPort;
    connect deliveryHandle.commandPort to clinicianInterface.commandStatusPort;
    connect inflationDevice.fluidPort to deliveryCatheter.inflationPort;
    connect preparationTray.catheterLumenPort to deliveryCatheter.lumenPort;
    connect crimper.implantPort to deliveryCatheter.implantCarrierPort;
    connect sterilePackaging.kitOutput to preparationTray.implantPort;
    connect deliveryCatheter.implantCarrierPort to valveImplant;
    connect deliveryCatheter.guidewirePort to guidewire;
    connect deliveryCatheter.vascularPort to patientInterfacePort;
    connect imagingConsole.imagePort to clinicianInterface.imageInputPort;
    connect imagingConsole.imagePort to imageOutputPort;
    connect hemodynamicMonitor.hemodynamicPort to clinicianInterface.hemodynamicInputPort;
    connect hemodynamicMonitor.hemodynamicPort to hemodynamicInputPort;
    connect clinicianCommandPort to clinicianInterface.commandStatusPort;

    exhibit state workflow : InterventionWorkflow;

    perform action primaryBehavior : RestoreAorticValveFunction;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide the high-level clinical function of restoring regulated one-way blood flow across a diseased aortic valve using sterile, image-guided transcatheter delivery and deployment of a bioprosthetic valve. */

    subject system : MerilInspiredCardiovascularInterventionSystem;

    require constraint primaryFunctionText {
      system.primaryFunction == "Restore regulated one-way blood flow across a diseased aortic valve by enabling sterile, image-guided transcatheter delivery, positioning, balloon expansion, and verification of a bioprosthetic valve implant."
    }
  }

  requirement def SterileUseRequirement {
    doc /* All implant-contacting components shall remain sterile until patient introduction. */

    subject system : MerilInspiredCardiovascularInterventionSystem;

    require constraint sterileImplant {
      system.valveImplant.sterility == SterilityStatus::sterile
    }

    require constraint sterilePackage {
      system.sterilePackaging.sterility == SterilityStatus::sterile
    }

    require constraint sterileTray {
      system.preparationTray.surfaceSterility == SterilityStatus::sterile
    }
  }

  requirement def ValveSizingRequirement {
    doc /* The selected implant diameter shall be compatible with the measured aortic annulus diameter. */

    subject patient : Patient;
    subject implant : BioprostheticValveImplant;

    require constraint AnnulusValveSizingConstraint {
      annulusDiameter = patient.aorticAnnulusDiameter;
      valveDiameter = implant.nominalDiameter;
    }
  }

  requirement def DeploymentPressureRequirement {
    doc /* Balloon inflation shall not exceed ninety percent of rated burst pressure during deployment. */

    subject catheter : BalloonCatheter;
    subject record : DeploymentRecord;

    require constraint BalloonPressureLimitConstraint {
      actualPressure = record.maximumInflationPressure;
      ratedBurstPressure = catheter.balloonRatedBurstPressure;
    }
  }

  requirement def ImageGuidanceRequirement {
    doc /* The image guidance function shall provide visible implant markers with sufficient confidence for positioning before deployment. */

    subject image : FluoroscopyImage;
    subject console : ImageGuidanceConsole;

    require constraint markerVisibility {
      image.valveMarkerVisible == true and console.markerDetectionConfidence.value >= 95.0
    }

    require constraint latencyLimit {
      console.imageLatency.value <= 0.25
    }
  }

  requirement def HemodynamicEffectivenessRequirement {
    doc /* After deployment, residual transvalvular pressure gradient and valve area shall indicate restored valve function. */

    subject measurement : HemodynamicMeasurement;
    subject record : DeploymentRecord;

    require constraint HemodynamicSuccessConstraint {
      finalGradient = measurement.pressureGradient;
      finalArea = record.finalValveArea;
    }
  }

  requirement def RetrievalRequirement {
    doc /* The delivery catheter and sheath shall be retrievable after implant release without removing the deployed valve. */

    subject system : MerilInspiredCardiovascularInterventionSystem;

    require constraint retrievalState {
      system.deliveryCatheter.deploymentState == DeploymentState::verified or
      system.deliveryCatheter.deploymentState == DeploymentState::retrieved
    }
  }

  part merilCardiovascularSystem : MerilInspiredCardiovascularInterventionSystem;

}
