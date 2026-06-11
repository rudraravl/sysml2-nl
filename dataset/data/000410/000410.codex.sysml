package MineCamSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Percentage {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def Lux {
        :> ScalarValues::Real;
        unit = "lx";
    }

    attribute def Celsius {
        :> ScalarValues::Real;
        unit = "degC";
    }

    attribute def Meter {
        :> ScalarValues::Real;
        unit = "m";
    }

    attribute def MeterPerSecond {
        :> ScalarValues::Real;
        unit = "m/s";
    }

    attribute def Hertz {
        :> ScalarValues::Real;
        unit = "Hz";
    }

    attribute def MegabitPerSecond {
        :> ScalarValues::Real;
        unit = "Mbit/s";
    }

    attribute def WattHour {
        :> ScalarValues::Real;
        unit = "Wh";
    }

    attribute def Volt {
        :> ScalarValues::Real;
        unit = "V";
    }

    enum def IlluminationMode {
        enum lowPower;
        enum normal;
        enum highPenetration;
        enum strobeMarker;
    }

    enum def CameraOperatingMode {
        enum poweredOff;
        enum standby;
        enum surveying;
        enum streaming;
        enum recording;
        enum degraded;
        enum emergencyBeacon;
    }

    enum def HazardClassification {
        enum clear;
        enum dustObscured;
        enum unstableRoof;
        enum waterIngress;
        enum gasWarning;
        enum blockedPassage;
        enum equipmentObstacle;
    }

    item def VideoFrame {
        attribute frameId : Integer;
        attribute timestamp : Real;
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : Hertz;
        attribute averageIllumination : Lux;
        attribute thermalOverlayEnabled : Boolean;
    }

    item def AudioSample {
        attribute timestamp : Real;
        attribute sampleRate : Hertz;
        attribute soundPressureLevel : Real;
    }

    item def EnvironmentalReading {
        attribute timestamp : Real;
        attribute ambientTemperature : Celsius;
        attribute relativeHumidity : Percentage;
        attribute methaneConcentration : Percentage;
        attribute carbonMonoxidePPM : Real;
        attribute oxygenConcentration : Percentage;
        attribute dustOpacity : Percentage;
    }

    item def PositionEstimate {
        attribute timestamp : Real;
        attribute distanceFromEntry : Meter;
        attribute lateralOffset : Meter;
        attribute verticalOffset : Meter;
        attribute confidence : Percentage;
    }

    item def HazardReport {
        attribute timestamp : Real;
        attribute classification : HazardClassification;
        attribute confidence : Percentage;
        attribute rangeToHazard : Meter;
        attribute recommendedAction : String;
    }

    item def OperatorCommand {
        attribute timestamp : Real;
        attribute requestedMode : CameraOperatingMode;
        attribute requestedIllumination : IlluminationMode;
        attribute startRecording : Boolean;
        attribute stopRecording : Boolean;
        attribute requestSnapshot : Boolean;
        attribute returnToStandby : Boolean;
    }

    item def HealthStatus {
        attribute timestamp : Real;
        attribute batteryStateOfCharge : Percentage;
        attribute internalTemperature : Celsius;
        attribute storageRemaining : Percentage;
        attribute linkQuality : Percentage;
        attribute degradedOperation : Boolean;
        attribute faultMessage : String;
    }

    port def VideoOutPort {
        out item video : VideoFrame;
    }

    port def AudioOutPort {
        out item audio : AudioSample;
    }

    port def EnvironmentalOutPort {
        out item environment : EnvironmentalReading;
    }

    port def PositionOutPort {
        out item position : PositionEstimate;
    }

    port def HazardOutPort {
        out item hazard : HazardReport;
    }

    port def CommandInPort {
        in item command : OperatorCommand;
    }

    port def HealthOutPort {
        out item health : HealthStatus;
    }

    port def PowerPort {
        inout attribute voltage : Volt;
        inout attribute availableEnergy : WattHour;
    }

    port def DataLinkPort {
        out item video : VideoFrame;
        out item audio : AudioSample;
        out item environment : EnvironmentalReading;
        out item position : PositionEstimate;
        out item hazard : HazardReport;
        out item health : HealthStatus;
        in item command : OperatorCommand;
        attribute throughput : MegabitPerSecond;
        attribute linkQuality : Percentage;
    }

    part def ImageSensor {
        attribute horizontalResolution : Integer = 3840;
        attribute verticalResolution : Integer = 2160;
        attribute maximumFrameRate : Hertz = 60;
        attribute minimumSceneIllumination : Lux = 0.01;
        attribute dustRejectionEnabled : Boolean = true;

        port videoOut : VideoOutPort;
    }

    part def ThermalSensor {
        attribute horizontalResolution : Integer = 640;
        attribute verticalResolution : Integer = 512;
        attribute thermalSensitivity : Celsius = 0.05;
        attribute maximumFrameRate : Hertz = 30;

        port videoOut : VideoOutPort;
    }

    part def MicrophoneArray {
        attribute microphoneCount : Integer = 4;
        attribute sampleRate : Hertz = 48000;
        attribute beamformingEnabled : Boolean = true;

        port audioOut : AudioOutPort;
    }

    part def IlluminationUnit {
        attribute mode : IlluminationMode = IlluminationMode::normal;
        attribute visibleLightOutput : Lux = 1200;
        attribute infraredLightOutput : Lux = 800;
        attribute maximumRange : Meter = 35;
        attribute powerDraw : Real = 18.0;

        action adjustIllumination {
            in attribute requestedMode : IlluminationMode;
            out attribute selectedMode : IlluminationMode;

            selectedMode = requestedMode;
        }
    }

    part def EnvironmentalSensorSuite {
        attribute methaneAlarmThreshold : Percentage = 1.0;
        attribute carbonMonoxideAlarmThresholdPPM : Real = 35.0;
        attribute oxygenLowThreshold : Percentage = 19.5;
        attribute dustOpacityWarningThreshold : Percentage = 65.0;

        port environmentOut : EnvironmentalOutPort;
    }

    part def NavigationUnit {
        attribute inertialDriftRate : Meter = 0.05;
        attribute visualOdometryEnabled : Boolean = true;
        attribute maximumSurveySpeed : MeterPerSecond = 1.5;

        port positionOut : PositionOutPort;
    }

    part def HazardProcessor {
        attribute minimumReportConfidence : Percentage = 75.0;
        attribute roofCrackDetectionEnabled : Boolean = true;
        attribute waterIngressDetectionEnabled : Boolean = true;
        attribute obstacleDetectionEnabled : Boolean = true;
        attribute gasWarningFusionEnabled : Boolean = true;

        port hazardOut : HazardOutPort;

        action classifyHazard {
            in item frame : VideoFrame;
            in item environment : EnvironmentalReading;
            out item report : HazardReport;
        }
    }

    part def OnboardRecorder {
        attribute storageCapacityGB : Real = 512.0;
        attribute storageRemaining : Percentage = 100.0;
        attribute encryptedStorageEnabled : Boolean = true;
        attribute retentionHours : Real = 24.0;

        action recordSurveyData {
            in item frame : VideoFrame;
            in item audio : AudioSample;
            in item environment : EnvironmentalReading;
            in item position : PositionEstimate;
            in item hazard : HazardReport;
        }
    }

    part def CommunicationModule {
        attribute primaryRadioFrequencyMHz : Real = 915.0;
        attribute fallbackRadioFrequencyMHz : Real = 433.0;
        attribute maximumThroughput : MegabitPerSecond = 20.0;
        attribute minimumOperationalLinkQuality : Percentage = 30.0;
        attribute meshRelayEnabled : Boolean = true;

        port link : DataLinkPort;
    }

    part def PowerSubsystem {
        attribute nominalVoltage : Volt = 24.0;
        attribute batteryCapacity : WattHour = 420.0;
        attribute stateOfCharge : Percentage = 100.0;
        attribute reserveThreshold : Percentage = 15.0;
        attribute hotSwapCapable : Boolean = true;

        port power : PowerPort;
    }

    part def RuggedEnclosure {
        attribute ingressProtectionRating : String = "IP68";
        attribute impactRating : String = "IK10";
        attribute minimumOperatingTemperature : Celsius = -20.0;
        attribute maximumOperatingTemperature : Celsius = 60.0;
        attribute corrosionResistant : Boolean = true;
    }

    part def MineCam {
        attribute operatingMode : CameraOperatingMode = CameraOperatingMode::poweredOff;
        attribute primaryFunction : String = "Capture, enhance, analyze, record, and transmit visual, thermal, audio, environmental, position, and hazard information from underground mine workings to support remote inspection and operator situational awareness.";
        attribute maximumOperatingDepthEquivalent : Meter = 500.0;
        attribute targetSurveySpeed : MeterPerSecond = 1.0;
        attribute minimumMissionDurationHours : Real = 8.0;

        part visibleCamera : ImageSensor;
        part thermalCamera : ThermalSensor;
        part microphones : MicrophoneArray;
        part illuminator : IlluminationUnit;
        part environmentalSensors : EnvironmentalSensorSuite;
        part navigator : NavigationUnit;
        part hazardProcessor : HazardProcessor;
        part recorder : OnboardRecorder;
        part communications : CommunicationModule;
        part powerSystem : PowerSubsystem;
        part enclosure : RuggedEnclosure;

        port commandIn : CommandInPort;
        port dataLink : DataLinkPort;
        port healthOut : HealthOutPort;

        connect visibleCamera.videoOut.video to communications.link.video;
        connect thermalCamera.videoOut.video to communications.link.video;
        connect microphones.audioOut.audio to communications.link.audio;
        connect environmentalSensors.environmentOut.environment to communications.link.environment;
        connect navigator.positionOut.position to communications.link.position;
        connect hazardProcessor.hazardOut.hazard to communications.link.hazard;
        connect communications.link.command to commandIn.command;
        connect communications.link.video to dataLink.video;
        connect communications.link.audio to dataLink.audio;
        connect communications.link.environment to dataLink.environment;
        connect communications.link.position to dataLink.position;
        connect communications.link.hazard to dataLink.hazard;
        connect communications.link.health to dataLink.health;
        connect healthOut.health to dataLink.health;
        connect powerSystem.power to dataLink;

        action performMineSurvey {
            in item command : OperatorCommand;
            out item video : VideoFrame;
            out item environment : EnvironmentalReading;
            out item position : PositionEstimate;
            out item hazard : HazardReport;
            out item health : HealthStatus;

            first startAcquisition;
            then enhanceImagery;
            then fuseEnvironmentAndPosition;
            then detectHazards;
            then recordAndTransmit;

            action startAcquisition {
                out item rawVideo : VideoFrame;
                out item rawEnvironment : EnvironmentalReading;
                out item rawPosition : PositionEstimate;
            }

            action enhanceImagery {
                in item rawVideo : VideoFrame;
                out item video : VideoFrame;
            }

            action fuseEnvironmentAndPosition {
                in item rawEnvironment : EnvironmentalReading;
                in item rawPosition : PositionEstimate;
                out item environment : EnvironmentalReading;
                out item position : PositionEstimate;
            }

            action detectHazards {
                in item video : VideoFrame;
                in item environment : EnvironmentalReading;
                out item hazard : HazardReport;
            }

            action recordAndTransmit {
                in item video : VideoFrame;
                in item environment : EnvironmentalReading;
                in item position : PositionEstimate;
                in item hazard : HazardReport;
                out item health : HealthStatus;
            }
        }

        state def MineCamOperationalState {
            entry action initializeSelfTest;

            state poweredOff;
            state standby;
            state surveying;
            state streaming;
            state recording;
            state degraded;
            state emergencyBeacon;

            transition first poweredOff;
            transition poweredOff_to_standby
                first poweredOff
                accept OperatorCommand
                if command.requestedMode == CameraOperatingMode::standby
                then standby;

            transition standby_to_surveying
                first standby
                accept OperatorCommand
                if command.requestedMode == CameraOperatingMode::surveying
                then surveying;

            transition surveying_to_streaming
                first surveying
                accept OperatorCommand
                if command.requestedMode == CameraOperatingMode::streaming
                then streaming;

            transition streaming_to_recording
                first streaming
                accept OperatorCommand
                if command.startRecording == true
                then recording;

            transition recording_to_streaming
                first recording
                accept OperatorCommand
                if command.stopRecording == true
                then streaming;

            transition active_to_degraded
                first surveying
                accept HealthStatus
                if health.linkQuality < 30.0 or health.batteryStateOfCharge < 15.0
                then degraded;

            transition degraded_to_emergency
                first degraded
                accept EnvironmentalReading
                if environment.methaneConcentration >= 1.0 or environment.oxygenConcentration < 19.5
                then emergencyBeacon;

            transition emergency_to_standby
                first emergencyBeacon
                accept OperatorCommand
                if command.returnToStandby == true
                then standby;
        }
    }

    part def OperatorStation {
        attribute displayResolutionWidth : Integer = 2560;
        attribute displayResolutionHeight : Integer = 1440;
        attribute storesMissionArchive : Boolean = true;
        attribute operatorAlertLatencySeconds : Real = 1.0;

        port link : DataLinkPort;
    }

    part def MineInspectionSystem {
        part mineCam : MineCam;
        part operatorStation : OperatorStation;

        connect mineCam.dataLink to operatorStation.link;
    }

    requirement def PrimaryFunctionRequirement {
        subject mineCam : MineCam;
        attribute requiredMissionDurationHours : Real = 8.0;
        attribute requiredVideoFrameRate : Hertz = 30.0;
        attribute requiredHazardConfidence : Percentage = 75.0;
        attribute requiredTransmissionRange : Meter = 300.0;

        require constraint {
            mineCam.minimumMissionDurationHours >= requiredMissionDurationHours
        }

        require constraint {
            mineCam.visibleCamera.maximumFrameRate >= requiredVideoFrameRate
        }

        require constraint {
            mineCam.hazardProcessor.minimumReportConfidence >= requiredHazardConfidence
        }

        doc /* The MineCam shall provide a high-level primary function of remote underground mine inspection by capturing enhanced visual and thermal imagery, collecting environmental and position data, detecting hazards, recording mission evidence, and transmitting actionable situational awareness to an operator station. */
    }

    requirement def LowLightImagingRequirement {
        subject mineCam : MineCam;

        require constraint {
            mineCam.visibleCamera.minimumSceneIllumination <= 0.01
        }

        require constraint {
            mineCam.illuminator.maximumRange >= 35.0
        }
    }

    requirement def EnvironmentalSafetyRequirement {
        subject mineCam : MineCam;

        require constraint {
            mineCam.environmentalSensors.methaneAlarmThreshold <= 1.0
        }

        require constraint {
            mineCam.environmentalSensors.oxygenLowThreshold >= 19.5
        }
    }

    requirement def RuggedizationRequirement {
        subject mineCam : MineCam;

        require constraint {
            mineCam.enclosure.ingressProtectionRating == "IP68"
        }

        require constraint {
            mineCam.enclosure.minimumOperatingTemperature <= -20.0
        }

        require constraint {
            mineCam.enclosure.maximumOperatingTemperature >= 60.0
        }
    }

    satisfy PrimaryFunctionRequirement by MineInspectionSystem::mineCam;
    satisfy LowLightImagingRequirement by MineInspectionSystem::mineCam.visibleCamera;
    satisfy EnvironmentalSafetyRequirement by MineInspectionSystem::mineCam.environmentalSensors;
    satisfy RuggedizationRequirement by MineInspectionSystem::mineCam.enclosure;
}