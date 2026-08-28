package OBGYN_Instrumentation_System {
    import ScalarValues::*;

    enum DeviceStatus { off; standby; active; alarm; }
    enum AlarmSeverity { info; warning; critical; }
    enum MedicationType { oxytocin; analgesic; antibiotic; saline; }
    enum UltrasoundMode { bmode; mmode; doppler; }

    unit def bpm;
    unit def mmHg;
    unit def mL_per_h;
    unit def mL;
    unit def MHz;
    unit def mm;

    value def HeartRateValue :> Real { unit bpm; }
    value def PressureValue :> Real { unit mmHg; }
    value def FlowRateValue :> Real { unit mL_per_h; }
    value def VolumeValue :> Real { unit mL; }
    value def FrequencyValue :> Real { unit MHz; }
    value def LengthValue :> Real { unit mm; }
    value def MagnificationValue :> Real;

    item def FetalHeartRateData {
        attribute heartRate : HeartRateValue;
        attribute signalQuality : String;
        attribute timestamp : String;
    }

    item def UterineContractionData {
        attribute pressure : PressureValue;
        attribute contractionDuration : Real;
        attribute timestamp : String;
    }

    item def UltrasoundImage {
        attribute imageData : String;
        attribute mode : UltrasoundMode;
        attribute gestationalAge : String;
    }

    item def InfusionStatus {
        attribute flowRate : FlowRateValue;
        attribute volumeInfused : VolumeValue;
        attribute remainingVolume : VolumeValue;
        attribute medication : MedicationType;
        attribute alarmStatus : DeviceStatus;
    }

    item def ColposcopyImage {
        attribute imageData : String;
        attribute magnification : MagnificationValue;
        attribute examinationFindings : String;
    }

    item def AspirationData {
        attribute volumeCollected : VolumeValue;
        attribute suctionPressure : PressureValue;
    }

    item def AlarmEvent {
        attribute severity : AlarmSeverity;
        attribute sourceDevice : String;
        attribute messageText : String;
        attribute timestamp : String;
    }

    port def FetalDataPort {
        out fhrData : FetalHeartRateData;
        out ucData : UterineContractionData;
        out alarm : AlarmEvent;
    }

    port def UltrasoundImagePort {
        out image : UltrasoundImage;
    }

    port def InfusionDataPort {
        out status : InfusionStatus;
        out alarm : AlarmEvent;
    }

    port def ColposcopyImagePort {
        out image : ColposcopyImage;
    }

    port def AspirationDataPort {
        out data : AspirationData;
    }

    abstract part def MedicalDevice {
        attribute deviceId : String;
        attribute status : DeviceStatus;
        attribute poweredOn : Boolean;
    }

    part def Cardiotocograph :> MedicalDevice {
        doc /* Cardiotocograph for continuous tracking of fetal heart rate
             * and maternal uterine contractions during labor. */

        part fetalHeartTransducer {
            attribute sensingRangeMin : HeartRateValue = 50;
            attribute sensingRangeMax : HeartRateValue = 210;
        }

        part tocotransducer {
            attribute sensingRangeMax : PressureValue = 100;
        }

        port fetalDataPort : FetalDataPort;

        attribute fetalHeartRate : HeartRateValue;
        attribute uterinePressure : PressureValue;
        attribute monitoringActive : Boolean;

        action def MonitorFetalVitals {
            out fhr : FetalHeartRateData;
            out uc : UterineContractionData;
        }

        action monitorVitals : MonitorFetalVitals;

        state fetalMonitoring {
            state Idle;
            state Monitoring;
            state FetalDistressAlarm;
            transition startMonitoring : Idle -> Monitoring {
                guard monitoringActive == true;
            }
            transition stopMonitoring : Monitoring -> Idle {
                guard monitoringActive == false;
            }
            transition detectDistress : Monitoring -> FetalDistressAlarm {
                guard fetalHeartRate < 60 | fetalHeartRate > 160;
            }
            transition resolveDistress : FetalDistressAlarm -> Monitoring {
                guard fetalHeartRate >= 60 & fetalHeartRate <= 160;
            }
        }
    }

    part def DiagnosticUltrasoundSystem :> MedicalDevice {
        doc /* Diagnostic ultrasound system for fetal development assessment,
             * growth measurement, and anatomical examination. */

        part transducer {
            attribute frequency : FrequencyValue = 3.5;
            attribute transducerType : String;
        }

        part imageProcessor {
            attribute processingMode : UltrasoundMode;
        }

        part display;

        port ultrasoundPort : UltrasoundImagePort;

        attribute imageDepth : LengthValue;
        attribute measuredBPD : LengthValue;
        attribute measuredFL : LengthValue;

        action def PerformUltrasoundScan {
            in scanTarget : String;
            out image : UltrasoundImage;
        }

        action def MeasureGrowthParameters {
            in image : UltrasoundImage;
            out bpd : LengthValue;
            out fl : LengthValue;
        }

        action scan : PerformUltrasoundScan;
        action measure : MeasureGrowthParameters;
    }

    part def InfusionPump :> MedicalDevice {
        doc /* Infusion pump for controlled delivery of medications and fluids
             * with safety monitoring for occlusions and air bubbles. */

        part pumpMechanism {
            attribute maxFlowRate : FlowRateValue = 1000;
        }

        part fluidReservoir {
            attribute capacity : VolumeValue;
            attribute remainingVolume : VolumeValue;
            attribute medication : MedicationType;
        }

        part airDetector {
            attribute detected : Boolean = false;
        }

        part occlusionDetector {
            attribute detected : Boolean = false;
        }

        port infusionPort : InfusionDataPort;

        attribute prescribedFlowRate : FlowRateValue;
        attribute actualFlowRate : FlowRateValue;
        attribute totalVolumeInfused : VolumeValue;
        attribute alarmActive : Boolean;

        calc def ComputeInfusedVolume {
            in flowRate : FlowRateValue;
            in durationHours : Real;
            return volume : VolumeValue = flowRate * durationHours;
        }

        calc infusedCalc : ComputeInfusedVolume {
            in flowRate = actualFlowRate;
            in durationHours = 1.0;
            return volume = totalVolumeInfused;
        }

        state infusionControl {
            state Stopped;
            state Infusing;
            state OcclusionAlarm;
            state AirBubbleAlarm;
            state InfusionComplete;
            transition startInfusion : Stopped -> Infusing {
                guard prescribedFlowRate > 0;
            }
            transition detectOcclusion : Infusing -> OcclusionAlarm {
                guard occlusionDetector.detected == true;
            }
            transition detectAirBubble : Infusing -> AirBubbleAlarm {
                guard airDetector.detected == true;
            }
            transition clearOcclusion : OcclusionAlarm -> Infusing {
                guard occlusionDetector.detected == false;
            }
            transition clearAirBubble : AirBubbleAlarm -> Infusing {
                guard airDetector.detected == false;
            }
            transition completeInfusion : Infusing -> InfusionComplete {
                guard fluidReservoir.remainingVolume == 0;
            }
            transition resetComplete : InfusionComplete -> Stopped;
        }
    }

    part def Colposcope :> MedicalDevice {
        doc /* Colposcope with magnification and illumination for detailed
             * visual examination of the cervix and image documentation. */

        part opticalSystem {
            attribute magnificationMin : MagnificationValue = 3;
            attribute magnificationMax : MagnificationValue = 40;
            attribute currentMagnification : MagnificationValue;
        }

        part illuminationSource {
            attribute intensity : Real;
            attribute lightType : String;
        }

        part camera {
            attribute resolution : String;
        }

        port colposcopyPort : ColposcopyImagePort;

        action def PerformCervicalExam {
            in examinationTarget : String;
            out image : ColposcopyImage;
        }

        action examination : PerformCervicalExam;
    }

    part def VacuumAspirator :> MedicalDevice {
        doc /* Vacuum aspirator for suction-based fluid collection
             * during gynecological procedures. */

        part suctionPump {
            attribute maxPressure : PressureValue;
            attribute currentPressure : PressureValue;
        }

        part collectionContainer {
            attribute capacity : VolumeValue;
            attribute collectedVolume : VolumeValue;
        }

        part pressureRegulator;

        port aspirationPort : AspirationDataPort;

        attribute suctionActive : Boolean;

        state aspirationControl {
            state Off;
            state Suctioning;
            state ContainerFull;
            transition startSuction : Off -> Suctioning {
                guard suctionActive == true;
            }
            transition stopSuction : Suctioning -> Off {
                guard suctionActive == false;
            }
            transition detectFull : Suctioning -> ContainerFull {
                guard collectionContainer.collectedVolume >= collectionContainer.capacity;
            }
            transition emptyContainer : ContainerFull -> Off;
        }
    }

    part def CentralMonitoringStation {
        doc /* Central monitoring station aggregating data, images, and alarms
             * from all connected medical devices for unified patient monitoring. */

        attribute stationId : String;
        attribute displayActive : Boolean;

        part display {
            attribute resolution : String;
        }

        part alarmManager {
            attribute activeAlarms : AlarmEvent[0..*];
        }

        part dataAggregator;

        port fetalInput : ~FetalDataPort;
        port ultrasoundInput : ~UltrasoundImagePort;
        port infusionInput : ~InfusionDataPort;
        port colposcopyInput : ~ColposcopyImagePort;
        port aspirationInput : ~AspirationDataPort;

        action def AggregateData {
            in fhr : FetalHeartRateData;
            in uc : UterineContractionData;
            in usImage : UltrasoundImage;
            in infusion : InfusionStatus;
            in colpoImage : ColposcopyImage;
            in aspiration : AspirationData;
            out unifiedView : String;
        }

        action def RaiseAlarm {
            in alarm : AlarmEvent;
        }

        action aggregate : AggregateData;
        action handleAlarm : RaiseAlarm;
    }

    part def OBGYNSystem {
        doc /* Integrated Obstetrics and Gynecology Instrumentation System
             * providing comprehensive monitoring, diagnostic, and therapeutic care. */

        part cardiotocograph : Cardiotocograph;
        part ultrasound : DiagnosticUltrasoundSystem;
        part infusionPump : InfusionPump;
        part colposcope : Colposcope;
        part vacuumAspirator : VacuumAspirator;
        part centralStation : CentralMonitoringStation;

        connection fetalDataLink {
            end ctgEnd = cardiotocograph.fetalDataPort;
            end stationEnd = centralStation.fetalInput;
        }
        connection ultrasoundDataLink {
            end usEnd = ultrasound.ultrasoundPort;
            end stationEnd = centralStation.ultrasoundInput;
        }
        connection infusionDataLink {
            end pumpEnd = infusionPump.infusionPort;
            end stationEnd = centralStation.infusionInput;
        }
        connection colposcopyDataLink {
            end colpoEnd = colposcope.colposcopyPort;
            end stationEnd = centralStation.colposcopyInput;
        }
        connection aspirationDataLink {
            end aspiratorEnd = vacuumAspirator.aspirationPort;
            end stationEnd = centralStation.aspirationInput;
        }
    }

    requirement def FetalMonitoringRequirement {
        subject monitor : Cardiotocograph;
        doc /* Requirements for fetal monitoring capabilities. */

        requirement shallTrackFetalHeartRate {
            doc /* The cardiotocograph shall continuously track fetal heart rate
                 * within the range of 50 to 210 bpm. */
        }

        requirement shallTrackUterineContractions {
            doc /* The cardiotocograph shall continuously track uterine
                 * contraction pressure during labor. */
        }

        requirement shallRaiseFetalDistressAlarm {
            doc /* The system shall raise an alarm when fetal heart rate
                 * falls below 60 bpm or exceeds 160 bpm. */
        }
    }

    requirement def UltrasoundImagingRequirement {
        subject ultrasound : DiagnosticUltrasoundSystem;
        doc /* Requirements for diagnostic ultrasound imaging. */

        requirement shallGenerateFetalImages {
            doc /* The ultrasound system shall generate detailed images
                 * for assessing fetal development and anatomy. */
        }

        requirement shallMeasureGrowthParameters {
            doc /* The ultrasound system shall measure fetal growth parameters
                 * including biparietal diameter and femur length. */
        }
    }

    requirement def InfusionSafetyRequirement {
        subject pump : InfusionPump;
        doc /* Requirements for infusion pump safety. */

        requirement shallDeliverAtPrescribedRate {
            doc /* The infusion pump shall deliver medication at the
                 * prescribed flow rate with precision. */
        }

        requirement shallDetectOcclusion {
            doc /* The pump shall detect line occlusions and raise an alarm. */
        }

        requirement shallDetectAirBubbles {
            doc /* The pump shall detect air bubbles in the infusion line
                 * and raise an alarm. */
        }
    }

    requirement def ColposcopyRequirement {
        subject colposcope : Colposcope;
        doc /* Requirements for colposcopic examination. */

        requirement shallProvideMagnification {
            doc /* The colposcope shall provide adjustable magnification
                 * from 3x to 40x for cervical examination. */
        }

        requirement shallProvideIllumination {
            doc /* The colposcope shall provide adjustable illumination
                 * for clear visualization. */
        }

        requirement shallCaptureImages {
            doc /* The colposcope shall capture images for documentation
                 * of examination findings. */
        }
    }

    requirement def AspirationRequirement {
        subject aspirator : VacuumAspirator;
        doc /* Requirements for vacuum aspiration. */

        requirement shallProvideControlledSuction {
            doc /* The vacuum aspirator shall provide controlled suction
                 * for fluid collection procedures. */
        }

        requirement shallIndicateFullContainer {
            doc /* The aspirator shall indicate when the collection container
                 * is full. */
        }
    }

    requirement def CentralIntegrationRequirement {
        subject station : CentralMonitoringStation;
        doc /* Requirements for central monitoring integration. */

        requirement shallAggregateAllDeviceData {
            doc /* The central station shall aggregate data, images, and alarms
                 * from all connected medical devices. */
        }

        requirement shallProvideUnifiedDisplay {
            doc /* The central station shall provide a unified display showing
                 * fetal well-being, ultrasound results, and infusion status. */
        }

        requirement shallManageAlarms {
            doc /* The central station shall manage and prioritize alarms
                 * from all connected devices. */
        }
    }

    requirement def SystemIntegrationRequirement {
        subject system : OBGYNSystem;
        doc /* Overall system integration requirements. */

        requirement shallSupportFetalStressTests {
            doc /* The system shall support fetal stress test procedures. */
        }

        requirement shallSupportObstetricUltrasound {
            doc /* The system shall support obstetric ultrasound examinations. */
        }

        requirement shallSupportMedicationManagement {
            doc /* The system shall support medication management during labor. */
        }

        requirement shallSupportCervicalExaminations {
            doc /* The system shall support cervical examination procedures. */
        }
    }

    part obgynSystem : OBGYNSystem;
}
