package HybridOperatingRoomSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type Length :> Real { unit 'm'; }
    value type Angle :> Real { unit 'deg'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type Temperature :> Real { unit 'K'; }
    value type Pressure :> Real { unit 'Pa'; }
    value type Percentage :> Real { unit '%'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Volume :> Real { unit 'm3'; }
    value type FlowRate :> Real { unit 'm3/s'; }
    value type Mass :> Real { unit 'kg'; }
    value type Duration :> Real { unit 's'; }
    value type Dose :> Real { unit 'Gy'; }
    value type LuminousIntensity :> Real { unit 'cd'; }
    value type ColorTemperature :> Real { unit 'K'; }
    value type HeartRate :> Real { unit 'bpm'; }
    value type RespiratoryRate :> Real { unit 'breaths/min'; }
    value type Illuminance :> Real { unit 'lx'; }
    value type Humidity :> Real { unit '%RH'; }

    // ===== Enumerations =====
    enum def SeverityKind { low; medium; high; critical; }
    enum def TableAxis { height; lateral; longitudinal; tilt; }
    enum def ImagingMode { fluoroscopy; radiography; cine; }
    enum def AlarmState { silent; active; acknowledged; }
    enum def VentilationMode { manual; assist; control; }
    enum def LightMode { ambient; surgical; focused; }

    // ===== Item Definitions =====
    item def XRayImage {
        attribute resolution : Integer;
        attribute dose : Dose;
        attribute mode : ImagingMode;
        attribute timestamp : String;
    }

    item def ProcessedImage {
        attribute resolution : Integer;
        attribute clarity : Percentage;
        attribute sourceImage : XRayImage;
        attribute timestamp : String;
    }

    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute oxygenSaturation : Percentage;
        attribute bloodPressureSystolic : Pressure;
        attribute bloodPressureDiastolic : Pressure;
        attribute bodyTemperature : Temperature;
        attribute timestamp : String;
    }

    item def AlarmSignal {
        attribute severity : SeverityKind;
        attribute source : String;
        attribute message : String;
    }

    item def AnestheticGas {
        attribute agent : String;
        attribute concentration : Percentage;
        attribute flowRate : FlowRate;
    }

    item def Breath {
        attribute tidalVolume : Volume;
        attribute rate : RespiratoryRate;
        attribute pressure : Pressure;
    }

    item def AirFlow {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute pressure : Pressure;
        attribute particleCount : Integer;
    }

    item def NavigationData {
        attribute instrumentPosition : Length[3];
        attribute orientation : Angle[3];
        attribute timestamp : String;
    }

    item def DisplayContent {
        attribute source : String;
        attribute priority : Integer;
        attribute contentRef : String;
    }

    item def TableCommand {
        attribute axis : TableAxis;
        attribute targetValue : Real;
    }

    item def LightCommand {
        attribute mode : LightMode;
        attribute intensity : LuminousIntensity;
        attribute colorTemperature : ColorTemperature;
    }

    // ===== Port Definitions =====
    port def XRayOutPort { out image : XRayImage; }
    port def ProcessedImageOutPort { out image : ProcessedImage; }
    port def ImageInPort { in image : ProcessedImage; }
    port def VitalSignsOutPort { out vitals : VitalSigns; }
    port def VitalSignsInPort { in vitals : VitalSigns; }
    port def AlarmOutPort { out alarm : AlarmSignal; }
    port def AlarmInPort { in alarm : AlarmSignal; }
    port def GasOutPort { out gas : AnestheticGas; }
    port def GasInPort { in gas : AnestheticGas; }
    port def BreathOutPort { out breath : Breath; }
    port def BreathInPort { in breath : Breath; }
    port def AirOutPort { out air : AirFlow; }
    port def AirInPort { in air : AirFlow; }
    port def NavOutPort { out nav : NavigationData; }
    port def NavInPort { in nav : NavigationData; }
    port def DisplayInPort { in content : DisplayContent; }
    port def TableCommandPort { in command : TableCommand; }
    port def LightCommandPort { in command : LightCommand; }
    port def DoseReportPort { out cumulativeDose : Dose; }

    // ===== Requirements =====
    requirement def SafetyRequirement {
        doc "Base safety requirement for the hybrid operating room."
    }

    requirement def RadiationSafety :> SafetyRequirement {
        subject cumulativeDose : Dose;
        requirement { cumulativeDose <= 2.0 'Gy'; }
    }

    requirement def VitalSignsMonitoring :> SafetyRequirement {
        subject monitoringInterval : Duration;
        requirement { monitoringInterval <= 1.0 's'; }
    }

    requirement def AlarmResponse :> SafetyRequirement {
        subject responseTime : Duration;
        requirement { responseTime <= 2.0 's'; }
    }

    requirement def SterileEnvironment :> SafetyRequirement {
        subject particleCount : Integer;
        requirement { particleCount <= 10000; }
    }

    requirement def ImageLatency :> SafetyRequirement {
        subject latency : Duration;
        requirement { latency <= 0.5 's'; }
    }

    // ===== Part Definitions =====

    part def XRaySource {
        attribute voltage : Voltage = 80.0 'V';
        attribute current : Current = 200.0 'mA';
        attribute maxDosePerShot : Dose = 0.01 'Gy';
        port xrayOut : XRayOutPort;
        action def emit :> Action {
            in mode : ImagingMode;
            out image : XRayImage;
        }
    }

    part def XRayDetector {
        attribute resolution : Integer = 1024;
        port imageOut : XRayOutPort;
        action def detect :> Action {
            in radiation : XRayImage;
            out detected : XRayImage;
        }
    }

    part def ImageProcessor {
        attribute clarityFactor : Percentage = 95.0 '%';
        port imageIn : XRayOutPort;
        port processedOut : ProcessedImageOutPort;
        action def process :> Action {
            in raw : XRayImage;
            out processed : ProcessedImage;
        }
    }

    part def DoseTracker {
        attribute cumulativeDose : Dose = 0.0 'Gy';
        attribute doseLimit : Dose = 2.0 'Gy';
        port doseReport : DoseReportPort;
        action def accumulate :> Action {
            in dose : Dose;
            update cumulativeDose;
        }
    }

    part def ImagingSystem {
        attribute mode : ImagingMode = fluoroscopy;
        attribute isMobile : Boolean = true;
        attribute position : Length[3] = (0.0 'm', 0.0 'm', 0.0 'm');
        attribute orientation : Angle[3] = (0.0 'deg', 0.0 'deg', 0.0 'deg');

        part source : XRaySource {
            port xrayOut : XRayOutPort;
        }
        part detector : XRayDetector {
            port imageOut : XRayOutPort;
        }
        part processor : ImageProcessor {
            port imageIn : XRayOutPort;
            port processedOut : ProcessedImageOutPort;
        }
        part doseTracker : DoseTracker {
            port doseReport : DoseReportPort;
        }

        port imageOut : ProcessedImageOutPort;
        port doseReport : DoseReportPort;

        connection source.xrayOut to detector.imageOut;
        connection detector.imageOut to processor.imageIn;
        connection processor.processedOut to imageOut;

        exhibit ImagingStateMachine {
            state Idle;
            state Positioning;
            state Acquiring;
            state Processing;
            state Transmitting;
            state SafetyHold;

            transition Idle to Positioning
                when (mode != Idle);
            transition Positioning to Acquiring
                when (position == targetPosition);
            transition Acquiring to Processing
                when (detector.imageOut.image != null);
            transition Processing to Transmitting
                when (processor.processedOut.image != null);
            transition Transmitting to Idle
                when (true);
            transition any to SafetyHold
                when (doseTracker.cumulativeDose >= doseTracker.doseLimit);
            transition SafetyHold to Idle
                when (doseTracker.cumulativeDose < doseTracker.doseLimit);
        }
    }

    part def SurgicalTable {
        attribute height : Length = 0.8 'm';
        attribute lateralPosition : Length = 0.0 'm';
        attribute longitudinalPosition : Length = 0.0 'm';
        attribute tilt : Angle = 0.0 'deg';
        attribute maxLoad : Mass = 250.0 'kg';

        port commandIn : TableCommandPort;

        action def adjust :> Action {
            in command : TableCommand;
            update height, lateralPosition, longitudinalPosition, tilt;
        }
    }

    part def ECGSensor {
        attribute heartRate : HeartRate = 72.0 'bpm';
        port vitalsOut : VitalSignsOutPort;
        action def measure :> Action {
            out heartRate : HeartRate;
        }
    }

    part def PulseOximeter {
        attribute oxygenSaturation : Percentage = 98.0 '%';
        port vitalsOut : VitalSignsOutPort;
        action def measure :> Action {
            out oxygenSaturation : Percentage;
        }
    }

    part def BloodPressureMonitor {
        attribute systolic : Pressure = 12000.0 'Pa';
        attribute diastolic : Pressure = 8000.0 'Pa';
        port vitalsOut : VitalSignsOutPort;
        action def measure :> Action {
            out systolic, diastolic : Pressure;
        }
    }

    part def TemperatureSensor {
        attribute bodyTemperature : Temperature = 310.15 'K';
        port vitalsOut : VitalSignsOutPort;
        action def measure :> Action {
            out bodyTemperature : Temperature;
        }
    }

    part def AlarmManager {
        attribute state : AlarmState = silent;
        attribute safeHeartRateMin : HeartRate = 40.0 'bpm';
        attribute safeHeartRateMax : HeartRate = 120.0 'bpm';
        attribute safeSpO2Min : Percentage = 90.0 '%';
        attribute safeTempMin : Temperature = 308.15 'K';
        attribute safeTempMax : Temperature = 312.15 'K';

        port vitalsIn : VitalSignsInPort;
        port alarmOut : AlarmOutPort;

        action def evaluate :> Action {
            in vitals : VitalSigns;
            out alarm : AlarmSignal;
        }
    }

    part def PatientMonitoringSystem {
        part ecg : ECGSensor;
        part pulseOx : PulseOximeter;
        part bpMonitor : BloodPressureMonitor;
        part tempSensor : TemperatureSensor;
        part alarmMgr : AlarmManager;

        port vitalsOut : VitalSignsOutPort;
        port alarmOut : AlarmOutPort;

        connection ecg.vitalsOut to alarmMgr.vitalsIn;
        connection pulseOx.vitalsOut to alarmMgr.vitalsIn;
        connection bpMonitor.vitalsOut to alarmMgr.vitalsIn;
        connection tempSensor.vitalsOut to alarmMgr.vitalsIn;
        connection alarmMgr.alarmOut to alarmOut;

        exhibit MonitoringStateMachine {
            state Normal;
            state Warning;
            state Critical;
            state Acknowledged;

            transition Normal to Warning
                when (alarmMgr.evaluate.alarm.severity == medium);
            transition Normal to Critical
                when (alarmMgr.evaluate.alarm.severity == critical);
            transition Warning to Critical
                when (alarmMgr.evaluate.alarm.severity == critical);
            transition Critical to Acknowledged
                when (state == Acknowledged);
            transition Acknowledged to Normal
                when (alarmMgr.evaluate.alarm.severity == low);
        }
    }

    part def AnesthesiaDeliverySystem {
        attribute gasAgent : String = "Sevoflurane";
        attribute concentration : Percentage = 2.0 '%';
        attribute flowRate : FlowRate = 0.0001 'm3/s';
        attribute ventilationMode : VentilationMode = assist;
        attribute respiratoryRate : RespiratoryRate = 12.0 'breaths/min';
        attribute tidalVolume : Volume = 0.0005 'm3';

        port gasOut : GasOutPort;
        port breathOut : BreathOutPort;

        action def deliverGas :> Action {
            out gas : AnestheticGas;
        }
        action def ventilate :> Action {
            out breath : Breath;
        }

        exhibit AnesthesiaStateMachine {
            state Idle;
            state Inducing;
            state Maintaining;
            state Ventilating;
            state Emergency;

            transition Idle to Inducing when (ventilationMode != manual);
            transition Inducing to Maintaining when (concentration >= 1.0 '%');
            transition Maintaining to Ventilating when (respiratoryRate > 0.0 'breaths/min');
            transition Ventilating to Maintaining when (true);
            transition any to Emergency when (alarmMgr.alarmOut.alarm.severity == critical);
        }
    }

    part def SurgicalLightHead {
        attribute intensity : LuminousIntensity = 40000.0 'cd';
        attribute colorTemperature : ColorTemperature = 5000.0 'K';
        attribute shadowReduction : Percentage = 90.0 '%';
        port commandIn : LightCommandPort;
        action def illuminate :> Action;
    }

    part def SurgicalLightingSystem {
        part mainLight : SurgicalLightHead;
        part secondaryLight : SurgicalLightHead;
        part ambientLight : SurgicalLightHead;

        port commandIn : LightCommandPort;

        connection commandIn to mainLight.commandIn;
        connection commandIn to secondaryLight.commandIn;
    }

    part def HEPAFilter {
        attribute efficiency : Percentage = 99.97 '%';
        attribute maxParticleSize : Length = 0.0000003 'm';
        action def filter :> Action {
            in air : AirFlow;
            out filteredAir : AirFlow;
        }
    }

    part def HVACUnit {
        attribute targetTemperature : Temperature = 294.15 'K';
        attribute targetHumidity : Humidity = 50.0 '%RH';
        attribute targetPressure : Pressure = 101325.0 'Pa';
        port airOut : AirOutPort;
        action def condition :> Action {
            out air : AirFlow;
        }
    }

    part def EnvironmentalControlSystem {
        part hvac : HVACUnit;
        part hepa : HEPAFilter;
        attribute positivePressureDelta : Pressure = 10.0 'Pa';
        attribute particleCount : Integer = 5000;

        port airOut : AirOutPort;

        connection hvac.airOut to hepa.filter.air;
        connection hepa.filter.filteredAir to airOut;

        exhibit EnvironmentalStateMachine {
            state Off;
            state WarmingUp;
            state Stable;
            state Adjusting;

            transition Off to WarmingUp when (true);
            transition WarmingUp to Stable
                when (hvac.targetTemperature - 1.0 'K' <= hvac.condition.air.temperature
                    and hvac.condition.air.temperature <= hvac.targetTemperature + 1.0 'K');
            transition Stable to Adjusting
                when (hvac.condition.air.temperature > hvac.targetTemperature + 1.0 'K');
            transition Adjusting to Stable
                when (hvac.condition.air.temperature <= hvac.targetTemperature + 1.0 'K');
        }
    }

    part def DisplayScreen {
        attribute resolution : Integer = 3840;
        attribute size : Length = 0.55 'm';
        port contentIn : DisplayInPort;
        action def render :> Action {
            in content : DisplayContent;
        }
    }

    part def DisplaySystem {
        part imageScreen : DisplayScreen;
        part vitalsScreen : DisplayScreen;
        part navScreen : DisplayScreen;
        part overviewScreen : DisplayScreen;

        port imageIn : ImageInPort;
        port vitalsIn : VitalSignsInPort;
        port navIn : NavInPort;
        port alarmIn : AlarmInPort;

        connection imageIn to imageScreen.contentIn;
        connection vitalsIn to vitalsScreen.contentIn;
        connection navIn to navScreen.contentIn;
        connection alarmIn to overviewScreen.contentIn;
    }

    part def InstrumentTracker {
        attribute trackedInstruments : Integer = 4;
        attribute accuracy : Length = 0.001 'm';
        port navOut : NavOutPort;
        action def track :> Action {
            out nav : NavigationData;
        }
    }

    part def SurgicalNavigationSystem {
        part tracker : InstrumentTracker;
        port navOut : NavOutPort;
        port imageIn : ImageInPort;
        connection tracker.navOut to navOut;

        exhibit NavigationStateMachine {
            state Idle;
            state Calibrating;
            state Tracking;
            state Overlaying;

            transition Idle to Calibrating when (true);
            transition Calibrating to Tracking when (tracker.accuracy <= 0.001 'm');
            transition Tracking to Overlaying when (imageIn.image != null);
            transition Overlaying to Tracking when (true);
        }
    }

    // ===== Top-Level System =====
    part def HybridOperatingRoom {
        attribute roomTemperature : Temperature = 294.15 'K';
        attribute roomPressure : Pressure = 101335.0 'Pa';
        attribute isSterile : Boolean = true;

        part imaging : ImagingSystem;
        part table : SurgicalTable;
        part monitoring : PatientMonitoringSystem;
        part anesthesia : AnesthesiaDeliverySystem;
        part lighting : SurgicalLightingSystem;
        part environment : EnvironmentalControlSystem;
        part display : DisplaySystem;
        part navigation : SurgicalNavigationSystem;

        // Inter-subsystem connections
        connection imaging.imageOut to display.imageIn;
        connection monitoring.vitalsOut to display.vitalsIn;
        connection monitoring.vitalsOut to anesthesia.breathOut;
        connection monitoring.alarmOut to display.alarmIn;
        connection navigation.navOut to display.navIn;
        connection imaging.imageOut to navigation.imageIn;
        connection environment.airOut to display.imageIn;

        // Requirements satisfaction
        satisfy RadiationSafety by imaging.doseTracker.cumulativeDose;
        satisfy VitalSignsMonitoring by monitoring;
        satisfy AlarmResponse by monitoring.alarmMgr;
        satisfy SterileEnvironment by environment;
        satisfy ImageLatency by imaging.processor;

        exhibit ProcedureStateMachine {
            state PreProcedure;
            state PatientPositioning;
            state AnesthesiaInduction;
            state SurgeryActive;
            state ImageGuidedIntervention;
            state PostProcedure;
            state EmergencyResponse;

            transition PreProcedure to PatientPositioning when (table.height > 0.0 'm');
            transition PatientPositioning to AnesthesiaInduction when (anesthesia.ventilationMode != manual);
            transition AnesthesiaInduction to SurgeryActive when (monitoring.alarmMgr.state == silent);
            transition SurgeryActive to ImageGuidedIntervention when (imaging.mode != Idle);
            transition ImageGuidedIntervention to SurgeryActive when (imaging.mode == Idle);
            transition SurgeryActive to PostProcedure when (surgeryComplete == true);
            transition any to EmergencyResponse when (monitoring.alarmMgr.alarmOut.alarm.severity == critical);
            transition EmergencyResponse to SurgeryActive when (monitoring.alarmMgr.state == acknowledged);
        }
    }
}
