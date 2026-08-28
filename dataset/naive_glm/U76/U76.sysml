package OB_GYN_Instrumentation_System {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def HeartRate :> Real { unit 'beats/min'; }
    value def ContractionPressure :> Real { unit 'mmHg'; }
    value def FlowRate :> Real { unit 'mL/h'; }
    value def Volume :> Real { unit 'mL'; }
    value def Magnification :> Real { unit 'x'; }
    value def Illuminance :> Real { unit 'lx'; }
    value def SuctionPressure :> Real {> 0; unit 'mmHg'; }
    value def Frequency :> Real { unit 'MHz'; }
    value def Duration :> Real { unit 's'; }
    value def AcousticPower :> Real { unit 'mW'; }
    value def ImageDepth :> Real { unit 'mm'; }
    value def Temperature :> Real { unit 'degC'; }

    // ===== Item Definitions =====
    item def Patient {
        attribute identifier : String;
        attribute name : String;
        attribute age : Integer;
        attribute gestationalAgeWeeks : Integer;
    }

    item def FetalVitalData {
        attribute fetalHeartRate : HeartRate;
        attribute contractionIntensity : ContractionPressure;
        attribute timestamp : String;
    }

    item def UltrasoundImageData {
        attribute image : Binary;
        attribute depth : ImageDepth;
        attribute measuredHeadCircumference : ImageDepth;
        attribute femurLength : ImageDepth;
        attribute timestamp : String;
    }

    item def InfusionStatus {
        attribute currentFlowRate : FlowRate;
        attribute volumeInfused : Volume;
        attribute volumeRemaining : Volume;
        attribute blockageDetected : Boolean;
        attribute airBubbleDetected : Boolean;
        attribute timestamp : String;
    }

    item def CervicalExaminationImage {
        attribute image : Binary;
        attribute magnification : Magnification;
        attribute timestamp : String;
    }

    item def AspirationSample {
        attribute collectedVolume : Volume;
        attribute containerId : String;
        attribute timestamp : String;
    }

    item def DeviceAlarm {
        attribute sourceDevice : String;
        attribute severity : String;
        attribute message : String;
        attribute timestamp : String;
    }

    item def DeviceStatusReport {
        attribute deviceName : String;
        attribute operational : Boolean;
        attribute batteryLevel : Real;
        attribute timestamp : String;
    }

    item def Medication {
        attribute name : String;
        attribute concentration : Real;
        attribute prescribedFlowRate : FlowRate;
    }

    // ===== Port Definitions =====
    port def FetalDataOut {
        out fetalData : FetalVitalData;
        out fetalAlarm : DeviceAlarm;
        out status : DeviceStatusReport;
    }

    port def UltrasoundDataOut {
        out ultrasoundImage : UltrasoundImageData;
        out ultrasoundAlarm : DeviceAlarm;
        out status : DeviceStatusReport;
    }

    port def InfusionDataOut {
        out infusionStatus : InfusionStatus;
        out infusionAlarm : DeviceAlarm;
        out status : DeviceStatusReport;
    }

    port def ColposcopeDataOut {
        out cervicalImage : CervicalExaminationImage;
        out colposcopeAlarm : DeviceAlarm;
        out status : DeviceStatusReport;
    }

    port def AspiratorDataOut {
        out aspirationSample : AspirationSample;
        out aspiratorAlarm : DeviceAlarm;
        out status : DeviceStatusReport;
    }

    port def DeviceDataIn {
        in fetalData : FetalVitalData;
        in ultrasoundImage : UltrasoundImageData;
        in infusionStatus : InfusionStatus;
        in cervicalImage : CervicalExaminationImage;
        in aspirationSample : AspirationSample;
        in alarm : DeviceAlarm;
        in status : DeviceStatusReport;
    }

    port def PatientInterface {
        inout patient : Patient;
    }

    // ===== Requirements =====
    requirement def IntegratedMonitoringRequirement {
        subject system : OB_GYN_System;
        objective {
            doc "The system shall aggregate data, images, and alarms from all connected devices into a unified display."
        }
        assume { system.centralStation.aggregatedView.available == true; }
    }

    requirement def FetalMonitoringRequirement {
        subject monitor : Cardiotocograph;
        objective {
            doc "The cardiotocograph shall continuously track fetal heart rate and uterine contractions with accuracy within +/- 2 bpm and +/- 5 mmHg respectively."
        }
    }

    requirement def UltrasoundImagingRequirement {
        subject ultrasound : DiagnosticUltrasoundSystem;
        objective {
            doc "The ultrasound system shall generate images sufficient to measure fetal head circumference and femur length."
        }
    }

    requirement def InfusionSafetyRequirement {
        subject pump : InfusionPump;
        objective {
            doc "The infusion pump shall detect line blockages and air bubbles and halt infusion upon detection."
        }
    }

    requirement def ColposcopyRequirement {
        subject colposcope : Colposcope;
        objective {
            doc "The colposcope shall provide magnified, illuminated visualization of the cervix and capture images for documentation."
        }
    }

    requirement def AspirationRequirement {
        subject aspirator : VacuumAspirator;
        objective {
            doc "The vacuum aspirator shall collect fluid samples at a controlled suction pressure."
        }
    }

    // ===== Behaviors =====
    state def CardiotocographStates {
        entry; then Off;
        state Off;
        transition off_to_init
            first Off
            then Powered;
        state Powered;
        transition init_to_standby
            first Powered
            then Standby;
        state Standby;
        transition standby_to_monitoring
            first Standby
            then Monitoring;
        state Monitoring {
            entry { send fetalData; }
            do { sampleFetalHeartRate(); sampleUterineContractions(); }
            exit { send fetalAlarm; }
        }
        transition monitoring_to_standby
            first Monitoring
            then Standby;
        transition any_to_off
            first Standby
            then Off;
    }

    state def UltrasoundStates {
        entry; then Off;
        state Off;
        transition off_to_on
            first Off
            then Ready;
        state Ready;
        transition ready_to_scanning
            first Ready
            then Scanning;
        state Scanning {
            entry { emitSoundWaves(); }
            do { processReflectedWaves(); renderImage(); }
            exit { send ultrasoundImage; }
        }
        transition scanning_to_ready
            first Scanning
            then Ready;
        transition ready_to_off
            first Ready
            then Off;
    }

    state def InfusionPumpStates {
        entry; then Off;
        state Off;
        transition off_to_idle
            first Off
            then Idle;
        state Idle;
        transition idle_to_programming
            first Idle
            then Programming;
        state Programming {
            do { setFlowRate(); }
        }
        transition programming_to_running
            first Programming
            then Running;
        state Running {
            do { deliverMedication(); monitorLine(); }
        }
        transition running_to_fault
            first Running
            then Faulted;
        state Faulted {
            entry { haltInfusion(); send infusionAlarm; }
        }
        transition faulted_to_idle
            first Faulted
            then Idle;
        transition running_to_complete
            first Running
            then Complete;
        state Complete;
        transition complete_to_idle
            first Complete
            then Idle;
        transition idle_to_off
            first Idle
            then Off;
    }

    state def ColposcopeStates {
        entry; then Off;
        state Off;
        transition off_to_on
            first Off
            then Ready;
        state Ready;
        transition ready_to_examining
            first Ready
            then Examining;
        state Examining {
            do { illuminateCervix(); magnifyView(); captureImage(); }
            exit { send cervicalImage; }
        }
        transition examining_to_ready
            first Examining
            then Ready;
        transition ready_to_off
            first Ready
            then Off;
    }

    state def VacuumAspiratorStates {
        entry; then Off;
        state Off;
        transition off_to_idle
            first Off
            then Idle;
        state Idle;
        transition idle_to_aspirating
            first Idle
            then Aspirating;
        state Aspirating {
            do { applySuction(); collectFluid(); }
            exit { send aspirationSample; }
        }
        transition aspirating_to_idle
            first Aspirating
            then Idle;
        transition idle_to_off
            first Idle
            then Off;
    }

    state def CentralStationStates {
        entry; then Booting;
        state Booting;
        transition booting_to_active
            first Booting
            then Active;
        state Active {
            do { aggregateData(); renderUnifiedDisplay(); routeAlarms(); }
        }
        transition active_to_booting
            first Active
            then Booting;
    }

    // ===== Actions =====
    action def sampleFetalHeartRate {
        out heartRate : HeartRate;
    }
    action def sampleUterineContractions {
        out pressure : ContractionPressure;
    }
    action def emitSoundWaves {
        out frequency : Frequency;
    }
    action def processReflectedWaves {
        in frequency : Frequency;
        out rawSignal : Binary;
    }
    action def renderImage {
        in rawSignal : Binary;
        out image : UltrasoundImageData;
    }
    action def setFlowRate {
        out rate : FlowRate;
    }
    action def deliverMedication {
        in rate : FlowRate;
        out volumeDelivered : Volume;
    }
    action def monitorLine {
        out blockage : Boolean;
        out airBubble : Boolean;
    }
    action def haltInfusion;
    action def illuminateCervix {
        out illuminance : Illuminance;
    }
    action def magnifyView {
        out magnification : Magnification;
    }
    action def captureImage {
        out image : CervicalExaminationImage;
    }
    action def applySuction {
        out pressure : SuctionPressure;
    }
    action def collectFluid {
        out sample : AspirationSample;
    }
    action def aggregateData {
        in fetalData : FetalVitalData;
        in ultrasoundImage : UltrasoundImageData;
        in infusionStatus : InfusionStatus;
        in cervicalImage : CervicalExaminationImage;
        in aspirationSample : AspirationSample;
    }
    action def renderUnifiedDisplay;
    action def routeAlarms {
        in alarm : DeviceAlarm;
    }

    // ===== Parts =====
    part def Cardiotocograph {
        port patientPort : PatientInterface;
        port dataPort : FetalDataOut;
        attribute deviceName : String = "Cardiotocograph";
        attribute fhrAccuracy : HeartRate = 2;
        attribute contractionAccuracy : ContractionPressure = 5;
        part fetalHeartTransducer {
            attribute samplingRate : Frequency = 1.0;
        }
        part tocodynamometer {
            attribute samplingRate : Frequency = 1.0;
        }
        part display;
        exhibit state behavior : CardiotocographStates;
        satisfy FetalMonitoringRequirement;
    }

    part def DiagnosticUltrasoundSystem {
        port patientPort : PatientInterface;
        port dataPort : UltrasoundDataOut;
        attribute deviceName : String = "DiagnosticUltrasound";
        attribute operatingFrequency : Frequency = 3.5;
        attribute maxAcousticPower : AcousticPower = 100;
        part handheldTransducer {
            attribute frequencyRange : Frequency;
            attribute elementCount : Integer;
        }
        part beamformer;
        part imageProcessor;
        part display;
        exhibit state behavior : UltrasoundStates;
        satisfy UltrasoundImagingRequirement;
    }

    part def InfusionPump {
        port patientPort : PatientInterface;
        port dataPort : InfusionDataOut;
        attribute deviceName : String = "InfusionPump";
        attribute prescribedFlowRate : FlowRate;
        attribute maxFlowRate : FlowRate = 1200;
        part reservoir {
            attribute capacity : Volume = 500;
            attribute currentVolume : Volume;
        }
        part pumpingMechanism;
        part airBubbleDetector;
        part occlusionDetector;
        part controlUnit;
        exhibit state behavior : InfusionPumpStates;
        satisfy InfusionSafetyRequirement;
    }

    part def Colposcope {
        port patientPort : PatientInterface;
        port dataPort : ColposcopeDataOut;
        attribute deviceName : String = "Colposcope";
        attribute magnificationRange : Magnification = 40;
        attribute illuminanceLevel : Illuminance = 15000;
        part opticalSystem {
            attribute magnification : Magnification;
            attribute focusRange : ImageDepth;
        }
        part lightSource {
            attribute illuminance : Illuminance;
        }
        part camera {
            attribute resolution : Integer;
        }
        exhibit state behavior : ColposcopeStates;
        satisfy ColposcopyRequirement;
    }

    part def VacuumAspirator {
        port patientPort : PatientInterface;
        port dataPort : AspiratorDataOut;
        attribute deviceName : String = "VacuumAspirator";
        attribute maxSuctionPressure : SuctionPressure = 600;
        part suctionPump {
            attribute currentPressure : SuctionPressure;
        }
        part collectionCanister {
            attribute capacity : Volume = 2000;
            attribute currentVolume : Volume;
        }
        part tubing;
        part controlUnit;
        exhibit state behavior : VacuumAspiratorStates;
        satisfy AspirationRequirement;
    }

    part def CentralMonitoringStation {
        port fetalIn : FetalDataOut;
        port ultrasoundIn : UltrasoundDataOut;
        port infusionIn : InfusionDataOut;
        port colposcopeIn : ColposcopeDataOut;
        port aspiratorIn : AspiratorDataOut;
        attribute stationName : String = "CentralStation";
        part display {
            attribute aggregatedView : Boolean;
        }
        part dataAggregator;
        part alarmManager;
        part networkInterface;
        exhibit state behavior : CentralStationStates;
        satisfy IntegratedMonitoringRequirement;
    }

    // ===== Top-Level System =====
    part def OB_GYN_System {
        attribute systemName : String = "Integrated OB/GYN Instrumentation System";
        part cardiotocograph : Cardiotocograph;
        part ultrasound : DiagnosticUltrasoundSystem;
        part infusionPump : InfusionPump;
        part colposcope : Colposcope;
        part vacuumAspirator : VacuumAspirator;
        part centralStation : CentralMonitoringStation;

        connection fetalLink connect cardiotocograph.dataPort to centralStation.fetalIn;
        connection ultrasoundLink connect ultrasound.dataPort to centralStation.ultrasoundIn;
        connection infusionLink connect infusionPump.dataPort to centralStation.infusionIn;
        connection colposcopeLink connect colposcope.dataPort to centralStation.colposcopeIn;
        connection aspiratorLink connect vacuumAspirator.dataPort to centralStation.aspiratorIn;

        connection patientFetal connect cardiotocograph.patientPort to patient;
        connection patientUltrasound connect ultrasound.patientPort to patient;
        connection patientInfusion connect infusionPump.patientPort to patient;
        connection patientColposcope connect colposcope.patientPort to patient;
        connection patientAspirator connect vacuumAspirator.patientPort to patient;

        part patient : Patient;

        satisfy IntegratedMonitoringRequirement;
    }
}
