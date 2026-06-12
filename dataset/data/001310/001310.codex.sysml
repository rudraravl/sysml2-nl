package VisualSensorNetworkSensingUnitModel {
    import ScalarValues::*;
    import SI::*;

    value type Illuminance {
        unit = "lx";
        quantityKind = "illuminance";
    }

    value type LuminousExposure {
        unit = "lx*s";
        quantityKind = "luminousExposure";
    }

    value type PixelCount {
        unit = "px";
        quantityKind = "pixelCount";
    }

    value type FrameRate {
        unit = "Hz";
        quantityKind = "frequency";
    }

    value type DataRate {
        unit = "Mbit/s";
        quantityKind = "dataRate";
    }

    value type TimeStamp {
        unit = "ms";
        quantityKind = "time";
    }

    value type Length {
        unit = "m";
        quantityKind = "length";
    }

    value type Angle {
        unit = "deg";
        quantityKind = "planeAngle";
    }

    value type Temperature {
        unit = "degC";
        quantityKind = "temperature";
    }

    value type Voltage {
        unit = "V";
        quantityKind = "electricPotential";
    }

    value type Power {
        unit = "W";
        quantityKind = "power";
    }

    value type Probability {
        unit = "1";
        quantityKind = "probability";
    }

    value type Confidence {
        unit = "1";
        quantityKind = "confidence";
    }

    value type ObjectCount {
        unit = "1";
        quantityKind = "count";
    }

    enum def SensorHealth {
        enum operational;
        enum degraded;
        enum failed;
        enum calibrating;
        enum offline;
    }

    enum def NetworkMode {
        enum initializing;
        enum synchronizing;
        enum acquiring;
        enum fusing;
        enum reporting;
        enum faultHandling;
        enum shutdown;
    }

    item def PhotonFlux {
        attribute illuminance : Illuminance;
        attribute exposure : LuminousExposure;
        attribute wavelengthMin : Real;
        attribute wavelengthMax : Real;
    }

    item def ImageFrame {
        attribute width : PixelCount;
        attribute height : PixelCount;
        attribute frameRate : FrameRate;
        attribute captureTime : TimeStamp;
        attribute exposure : LuminousExposure;
        attribute sensorId : String;
    }

    item def FeatureSet {
        attribute featureCount : ObjectCount;
        attribute sourceSensorId : String;
        attribute extractionTime : TimeStamp;
        attribute averageConfidence : Confidence;
    }

    item def VisualDetection {
        attribute detectionId : String;
        attribute objectClass : String;
        attribute bearingAzimuth : Angle;
        attribute bearingElevation : Angle;
        attribute angularUncertainty : Angle;
        attribute confidence : Confidence;
        attribute sourceSensorId : String;
        attribute timeOfObservation : TimeStamp;
    }

    item def FusedVisualMeasurement {
        attribute targetId : String;
        attribute positionX : Length;
        attribute positionY : Length;
        attribute positionZ : Length;
        attribute range : Length;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute objectCount : ObjectCount;
        attribute positionUncertainty : Length;
        attribute confidence : Confidence;
        attribute measurementTime : TimeStamp;
    }

    item def HealthReport {
        attribute reportingSensorId : String;
        attribute health : SensorHealth;
        attribute temperature : Temperature;
        attribute supplyVoltage : Voltage;
        attribute droppedFrames : ObjectCount;
        attribute linkQuality : Confidence;
    }

    item def TimeSyncSignal {
        attribute networkTime : TimeStamp;
        attribute syncAccuracy : TimeStamp;
        attribute sequenceNumber : Integer;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute requestedMode : NetworkMode;
        attribute exposureSetpoint : LuminousExposure;
        attribute frameRateSetpoint : FrameRate;
    }

    port def OpticalInputPort {
        in item photons : PhotonFlux;
    }

    port def ImageOutputPort {
        out item frame : ImageFrame;
    }

    port def FeatureOutputPort {
        out item features : FeatureSet;
        out item detection : VisualDetection;
    }

    port def MeasurementOutputPort {
        out item measurement : FusedVisualMeasurement;
    }

    port def HealthOutputPort {
        out item health : HealthReport;
    }

    port def SyncPort {
        in item syncIn : TimeSyncSignal;
        out item syncOut : TimeSyncSignal;
    }

    port def ControlPort {
        in item command : ControlCommand;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute availablePower : Power;
    }

    part def LensAssembly {
        attribute focalLength : Length = 0.006;
        attribute apertureFNumber : Real = 1.8;
        attribute horizontalFieldOfView : Angle = 92.0;
        attribute verticalFieldOfView : Angle = 58.0;
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalInputPort;
    }

    part def ImageSensor {
        attribute pixelWidth : PixelCount = 3840;
        attribute pixelHeight : PixelCount = 2160;
        attribute maximumFrameRate : FrameRate = 60.0;
        attribute minimumIlluminance : Illuminance = 0.5;
        attribute operatingTemperature : Temperature;
        attribute health : SensorHealth;
        port opticalIn : OpticalInputPort;
        port imageOut : ImageOutputPort;
        port power : PowerPort;
        port sync : SyncPort;
    }

    part def VisionProcessor {
        attribute processingLatency : TimeStamp = 18.0;
        attribute detectionProbability : Probability = 0.97;
        attribute falseAlarmProbability : Probability = 0.01;
        port imageIn : ImageOutputPort;
        port featureOut : FeatureOutputPort;
        port command : ControlPort;
        port power : PowerPort;
    }

    part def CameraNode {
        attribute nodeId : String;
        attribute mountingX : Length;
        attribute mountingY : Length;
        attribute mountingZ : Length;
        attribute yaw : Angle;
        attribute pitch : Angle;
        attribute roll : Angle;
        attribute baselineReference : Length;
        attribute health : SensorHealth;

        part lens : LensAssembly;
        part sensor : ImageSensor;
        part processor : VisionProcessor;

        port opticalIn : OpticalInputPort;
        port featuresOut : FeatureOutputPort;
        port healthOut : HealthOutputPort;
        port sync : SyncPort;
        port control : ControlPort;
        port power : PowerPort;

        connection opticalPath1 connect opticalIn to lens.opticalIn;
        connection opticalPath2 connect lens.opticalOut to sensor.opticalIn;
        connection framePath connect sensor.imageOut to processor.imageIn;
        connection featurePath connect processor.featureOut to featuresOut;
        connection syncPath connect sync to sensor.sync;
        connection controlPath connect control to processor.command;
        connection powerSensor connect power to sensor.power;
        connection powerProcessor connect power to processor.power;
    }

    part def TimeSynchronizationHub {
        attribute syncAccuracy : TimeStamp = 0.5;
        attribute holdoverDuration : TimeStamp = 5000.0;
        port syncA : SyncPort;
        port syncB : SyncPort;
        port syncC : SyncPort;
        port syncD : SyncPort;
        port power : PowerPort;
    }

    part def VisualFusionComputer {
        attribute fusionLatency : TimeStamp = 35.0;
        attribute minimumTriangulationBaseline : Length = 0.5;
        attribute maximumMeasurementRange : Length = 80.0;
        attribute requiredSensorsPerMeasurement : Integer = 2;
        port featureInA : FeatureOutputPort;
        port featureInB : FeatureOutputPort;
        port featureInC : FeatureOutputPort;
        port featureInD : FeatureOutputPort;
        port measurementOut : MeasurementOutputPort;
        port command : ControlPort;
        port power : PowerPort;
    }

    part def NetworkSwitch {
        attribute uplinkRate : DataRate = 1000.0;
        attribute perPortRate : DataRate = 1000.0;
        attribute switchingLatency : TimeStamp = 1.0;
        port nodeA : FeatureOutputPort;
        port nodeB : FeatureOutputPort;
        port nodeC : FeatureOutputPort;
        port nodeD : FeatureOutputPort;
        port fusionA : FeatureOutputPort;
        port fusionB : FeatureOutputPort;
        port fusionC : FeatureOutputPort;
        port fusionD : FeatureOutputPort;
        port power : PowerPort;
    }

    part def PowerConditioner {
        attribute inputVoltage : Voltage = 24.0;
        attribute regulatedVoltage : Voltage = 12.0;
        attribute maximumPower : Power = 65.0;
        port source : PowerPort;
        port cameraA : PowerPort;
        port cameraB : PowerPort;
        port cameraC : PowerPort;
        port cameraD : PowerPort;
        port switchPower : PowerPort;
        port fusionPower : PowerPort;
        port syncPower : PowerPort;
    }

    action def AcquireVisualFrame {
        in item opticalFlux : PhotonFlux;
        in item sync : TimeSyncSignal;
        out item frame : ImageFrame;
    }

    action def ExtractVisualFeatures {
        in item frame : ImageFrame;
        out item features : FeatureSet;
        out item detection : VisualDetection;
    }

    action def TriangulateTargetPosition {
        in item detectionA : VisualDetection;
        in item detectionB : VisualDetection;
        in item detectionC : VisualDetection;
        out item measurement : FusedVisualMeasurement;
    }

    action def ReportMeasurement {
        in item measurement : FusedVisualMeasurement;
        out item reportedMeasurement : FusedVisualMeasurement;
    }

    action def DiagnoseSensorNetwork {
        in item healthA : HealthReport;
        in item healthB : HealthReport;
        in item healthC : HealthReport;
        in item healthD : HealthReport;
        out attribute networkHealth : SensorHealth;
    }

    state def VisualSensorNetworkStateMachine {
        attribute mode : NetworkMode;

        state Initializing;
        state Synchronizing;
        state Acquiring;
        state Fusing;
        state Reporting;
        state FaultHandling;
        state Shutdown;

        transition start first Initializing;
        transition initialized
            first Initializing
            then Synchronizing;

        transition synchronized
            first Synchronizing
            then Acquiring;

        transition frameSetAvailable
            first Acquiring
            then Fusing;

        transition fusedMeasurementAvailable
            first Fusing
            then Reporting;

        transition reportComplete
            first Reporting
            then Acquiring;

        transition faultDetectedFromAcquire
            first Acquiring
            then FaultHandling;

        transition faultDetectedFromFusion
            first Fusing
            then FaultHandling;

        transition recovered
            first FaultHandling
            then Synchronizing;

        transition unrecoverableFault
            first FaultHandling
            then Shutdown;
    }

    part def VisualSensorNetworkSensingUnit {
        attribute unitId : String = "VSN-SU-001";
        attribute measuredQuantity : String = "three-dimensional target position and object count from visual observations";
        attribute operatingRange : Length = 80.0;
        attribute measurementUpdateRate : FrameRate = 20.0;
        attribute targetPositionAccuracy : Length = 0.25;
        attribute totalPowerConsumption : Power = 48.0;
        attribute ambientIlluminanceMinimum : Illuminance = 1.0;

        part cameraFrontLeft : CameraNode {
            :>> nodeId = "CAM-FL";
            :>> mountingX = -0.75;
            :>> mountingY = 0.50;
            :>> mountingZ = 2.20;
            :>> yaw = 35.0;
            :>> pitch = -8.0;
            :>> roll = 0.0;
            :>> baselineReference = 1.50;
        }

        part cameraFrontRight : CameraNode {
            :>> nodeId = "CAM-FR";
            :>> mountingX = 0.75;
            :>> mountingY = 0.50;
            :>> mountingZ = 2.20;
            :>> yaw = -35.0;
            :>> pitch = -8.0;
            :>> roll = 0.0;
            :>> baselineReference = 1.50;
        }

        part cameraRearLeft : CameraNode {
            :>> nodeId = "CAM-RL";
            :>> mountingX = -0.75;
            :>> mountingY = -0.50;
            :>> mountingZ = 2.20;
            :>> yaw = 145.0;
            :>> pitch = -8.0;
            :>> roll = 0.0;
            :>> baselineReference = 1.50;
        }

        part cameraRearRight : CameraNode {
            :>> nodeId = "CAM-RR";
            :>> mountingX = 0.75;
            :>> mountingY = -0.50;
            :>> mountingZ = 2.20;
            :>> yaw = -145.0;
            :>> pitch = -8.0;
            :>> roll = 0.0;
            :>> baselineReference = 1.50;
        }

        part syncHub : TimeSynchronizationHub;
        part fusionComputer : VisualFusionComputer;
        part networkSwitch : NetworkSwitch;
        part powerConditioner : PowerConditioner;
        part operationalBehavior : VisualSensorNetworkStateMachine;

        port powerInput : PowerPort;
        port controlInput : ControlPort;
        port visualMeasurementOutput : MeasurementOutputPort;
        port networkHealthOutput : HealthOutputPort;

        connection powerSource connect powerInput to powerConditioner.source;
        connection powerToFrontLeft connect powerConditioner.cameraA to cameraFrontLeft.power;
        connection powerToFrontRight connect powerConditioner.cameraB to cameraFrontRight.power;
        connection powerToRearLeft connect powerConditioner.cameraC to cameraRearLeft.power;
        connection powerToRearRight connect powerConditioner.cameraD to cameraRearRight.power;
        connection powerToSwitch connect powerConditioner.switchPower to networkSwitch.power;
        connection powerToFusion connect powerConditioner.fusionPower to fusionComputer.power;
        connection powerToSync connect powerConditioner.syncPower to syncHub.power;

        connection syncFrontLeft connect syncHub.syncA to cameraFrontLeft.sync;
        connection syncFrontRight connect syncHub.syncB to cameraFrontRight.sync;
        connection syncRearLeft connect syncHub.syncC to cameraRearLeft.sync;
        connection syncRearRight connect syncHub.syncD to cameraRearRight.sync;

        connection featureFrontLeftToSwitch connect cameraFrontLeft.featuresOut to networkSwitch.nodeA;
        connection featureFrontRightToSwitch connect cameraFrontRight.featuresOut to networkSwitch.nodeB;
        connection featureRearLeftToSwitch connect cameraRearLeft.featuresOut to networkSwitch.nodeC;
        connection featureRearRightToSwitch connect cameraRearRight.featuresOut to networkSwitch.nodeD;

        connection featureSwitchToFusionA connect networkSwitch.fusionA to fusionComputer.featureInA;
        connection featureSwitchToFusionB connect networkSwitch.fusionB to fusionComputer.featureInB;
        connection featureSwitchToFusionC connect networkSwitch.fusionC to fusionComputer.featureInC;
        connection featureSwitchToFusionD connect networkSwitch.fusionD to fusionComputer.featureInD;

        connection measurementOutputPath connect fusionComputer.measurementOut to visualMeasurementOutput;
        connection controlToFusion connect controlInput to fusionComputer.command;
        connection controlToFrontLeft connect controlInput to cameraFrontLeft.control;
        connection controlToFrontRight connect controlInput to cameraFrontRight.control;
        connection controlToRearLeft connect controlInput to cameraRearLeft.control;
        connection controlToRearRight connect controlInput to cameraRearRight.control;
    }

    requirement def MeasureVisualSceneState {
        subject sensingUnit : VisualSensorNetworkSensingUnit;
        require constraint {
            sensingUnit.measurementUpdateRate >= 10.0 and
            sensingUnit.operatingRange >= 50.0
        }
    }

    requirement def PositionAccuracy {
        subject sensingUnit : VisualSensorNetworkSensingUnit;
        require constraint {
            sensingUnit.targetPositionAccuracy <= 0.30
        }
    }

    requirement def SynchronizedImageCapture {
        subject syncHub : TimeSynchronizationHub;
        require constraint {
            syncHub.syncAccuracy <= 1.0
        }
    }

    requirement def MultiSensorFusion {
        subject fusionComputer : VisualFusionComputer;
        require constraint {
            fusionComputer.requiredSensorsPerMeasurement >= 2 and
            fusionComputer.fusionLatency <= 50.0
        }
    }

    requirement def LowLightOperation {
        subject sensingUnit : VisualSensorNetworkSensingUnit;
        require constraint {
            sensingUnit.ambientIlluminanceMinimum <= 1.0
        }
    }

    requirement def PowerLimit {
        subject sensingUnit : VisualSensorNetworkSensingUnit;
        require constraint {
            sensingUnit.totalPowerConsumption <= 60.0
        }
    }

    requirement def DetectionConfidence {
        subject processor : VisionProcessor;
        require constraint {
            processor.detectionProbability >= 0.95 and
            processor.falseAlarmProbability <= 0.02
        }
    }

    requirement def CameraResolution {
        subject sensor : ImageSensor;
        require constraint {
            sensor.pixelWidth >= 1920 and
            sensor.pixelHeight >= 1080 and
            sensor.maximumFrameRate >= 30.0
        }
    }

    satisfy MeasureVisualSceneState by VisualSensorNetworkSensingUnit;
    satisfy PositionAccuracy by VisualSensorNetworkSensingUnit;
    satisfy SynchronizedImageCapture by TimeSynchronizationHub;
    satisfy MultiSensorFusion by VisualFusionComputer;
    satisfy LowLightOperation by VisualSensorNetworkSensingUnit;
    satisfy PowerLimit by VisualSensorNetworkSensingUnit;
    satisfy DetectionConfidence by VisionProcessor;
    satisfy CameraResolution by ImageSensor;
}