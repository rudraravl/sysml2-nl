package IndoorPositioningSystemModel {
    private import ScalarValues::*;
    private import SI::*;

    attribute def Distance :> Real {
        :>> unit = "m";
    }

    attribute def TimeDuration :> Real {
        :>> unit = "s";
    }

    attribute def Frequency :> Real {
        :>> unit = "Hz";
    }

    attribute def PowerLevel :> Real {
        :>> unit = "dBm";
    }

    attribute def DataRate :> Real {
        :>> unit = "Mb/s";
    }

    attribute def AccuracyRadius :> Distance;
    attribute def Confidence :> Real;
    attribute def FloorNumber :> Integer;

    item def UwbRangingFrame {
        attribute sourceId : String;
        attribute destinationId : String;
        attribute timestamp : TimeDuration;
        attribute transmitPower : PowerLevel;
        attribute channelFrequency : Frequency;
    }

    item def BleAdvertisement {
        attribute beaconId : String;
        attribute rssi : PowerLevel;
        attribute timestamp : TimeDuration;
    }

    item def RangeMeasurement {
        attribute anchorId : String;
        attribute tagId : String;
        attribute range : Distance;
        attribute uncertainty : Distance;
        attribute timestamp : TimeDuration;
    }

    item def PositionEstimate {
        attribute tagId : String;
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute floor : FloorNumber;
        attribute accuracy : AccuracyRadius;
        attribute confidence : Confidence;
        attribute timestamp : TimeDuration;
    }

    item def FloorMap {
        attribute buildingId : String;
        attribute floor : FloorNumber;
        attribute mapRevision : String;
        attribute coordinateOriginX : Distance;
        attribute coordinateOriginY : Distance;
    }

    item def PositionAlert {
        attribute tagId : String;
        attribute alertKind : String;
        attribute message : String;
        attribute timestamp : TimeDuration;
    }

    port def UwbRadioPort {
        out item txFrame : UwbRangingFrame;
        in item rxFrame : UwbRangingFrame;
    }

    port def BleRadioPort {
        out item advertisement : BleAdvertisement;
    }

    port def MeasurementPort {
        out item measurement : RangeMeasurement;
    }

    port def MapPort {
        in item map : FloorMap;
    }

    port def PositionPort {
        out item position : PositionEstimate;
    }

    port def AlertPort {
        out item alert : PositionAlert;
    }

    port def DataNetworkPort {
        in item inboundMeasurement : RangeMeasurement;
        out item outboundPosition : PositionEstimate;
        out item outboundAlert : PositionAlert;
    }

    port def PowerPort {
        in attribute supplyVoltage : Real {
            :>> unit = "V";
        }
        in attribute supplyCurrent : Real {
            :>> unit = "A";
        }
    }

    action def CollectRangeMeasurements {
        in item uwbFrame : UwbRangingFrame;
        out item measurement : RangeMeasurement;
    }

    action def FuseMeasurements {
        in item rangeA : RangeMeasurement;
        in item rangeB : RangeMeasurement;
        in item rangeC : RangeMeasurement;
        in item rangeD : RangeMeasurement;
        in item map : FloorMap;
        out item position : PositionEstimate;
    }

    action def ValidatePosition {
        in item candidatePosition : PositionEstimate;
        out item validatedPosition : PositionEstimate;
        out attribute valid : Boolean;
    }

    action def PublishPosition {
        in item validatedPosition : PositionEstimate;
        out item streamedPosition : PositionEstimate;
    }

    action def DetectZoneViolation {
        in item validatedPosition : PositionEstimate;
        out item alert : PositionAlert;
    }

    action def LocateMobileAsset {
        in item map : FloorMap;
        in item northRange : RangeMeasurement;
        in item eastRange : RangeMeasurement;
        in item southRange : RangeMeasurement;
        in item westRange : RangeMeasurement;
        out item currentPosition : PositionEstimate;
        out item zoneAlert : PositionAlert;

        action fuse : FuseMeasurements;
        action validate : ValidatePosition;
        action publish : PublishPosition;
        action detectAlert : DetectZoneViolation;

        flow northRange to fuse.rangeA;
        flow eastRange to fuse.rangeB;
        flow southRange to fuse.rangeC;
        flow westRange to fuse.rangeD;
        flow map to fuse.map;
        flow fuse.position to validate.candidatePosition;
        flow validate.validatedPosition to publish.validatedPosition;
        flow validate.validatedPosition to detectAlert.validatedPosition;
        flow publish.streamedPosition to currentPosition;
        flow detectAlert.alert to zoneAlert;
    }

    state def TrackingStateMachine {
        state initializing;
        state calibrating;
        state tracking;
        state degradedTracking;
        state lost;
        state maintenance;

        entry action initializing {
            then calibrating;
        }

        transition initializing_to_calibrating
            first initializing
            then calibrating;

        transition calibration_complete
            first calibrating
            then tracking;

        transition insufficient_anchors
            first tracking
            then degradedTracking;

        transition signal_restored
            first degradedTracking
            then tracking;

        transition tag_not_observed
            first degradedTracking
            then lost;

        transition tag_reacquired
            first lost
            then tracking;

        transition service_requested
            first tracking
            then maintenance;

        transition service_complete
            first maintenance
            then calibrating;
    }

    part def UwbAnchor {
        attribute anchorId : String;
        attribute installedX : Distance;
        attribute installedY : Distance;
        attribute installedZ : Distance;
        attribute clockDrift : TimeDuration;
        attribute radioFrequency : Frequency = 6489000000.0;
        port uwb : UwbRadioPort;
        port measurementOut : MeasurementPort;
        port power : PowerPort;
    }

    part def MobileTag {
        attribute tagId : String;
        attribute batteryCharge : Real;
        attribute updateRate : Frequency = 10.0;
        attribute transmitPower : PowerLevel = -14.0;
        port uwb : UwbRadioPort;
        port ble : BleRadioPort;
        port power : PowerPort;
    }

    part def EdgeGateway {
        attribute gatewayId : String;
        attribute processingLatency : TimeDuration;
        attribute networkDataRate : DataRate = 1000.0;
        port northMeasurement : MeasurementPort;
        port eastMeasurement : MeasurementPort;
        port southMeasurement : MeasurementPort;
        port westMeasurement : MeasurementPort;
        port network : DataNetworkPort;
        port power : PowerPort;
    }

    part def PositioningEngine {
        attribute engineId : String;
        attribute minimumAnchorCount : Integer = 3;
        attribute nominalAccuracy : AccuracyRadius = 0.30;
        attribute maximumLatency : TimeDuration = 0.50;
        port mapIn : MapPort;
        port network : DataNetworkPort;
        port positionOut : PositionPort;
        port alertOut : AlertPort;

        behavior locateAsset : LocateMobileAsset;
        behavior trackingStates : TrackingStateMachine;
    }

    part def OperatorDisplay {
        attribute displayId : String;
        attribute refreshRate : Frequency = 2.0;
        port positionIn : PositionPort;
        port alertIn : AlertPort;
    }

    part def IndoorPositioningSystem {
        attribute systemName : String = "Indoor Positioning System";
        attribute primaryFunction : String = "Determine and publish the real-time indoor location of tagged assets and people within a mapped building where satellite navigation is unavailable or unreliable.";
        attribute supportedFloorCount : Integer = 6;
        attribute nominalUpdateRate : Frequency = 10.0;
        attribute requiredAccuracy : AccuracyRadius = 0.50;
        attribute requiredAvailability : Real = 0.995;

        part northAnchor : UwbAnchor {
            :>> anchorId = "ANCHOR-NORTH";
            :>> installedX = 0.0;
            :>> installedY = 20.0;
            :>> installedZ = 3.2;
        }

        part eastAnchor : UwbAnchor {
            :>> anchorId = "ANCHOR-EAST";
            :>> installedX = 30.0;
            :>> installedY = 10.0;
            :>> installedZ = 3.2;
        }

        part southAnchor : UwbAnchor {
            :>> anchorId = "ANCHOR-SOUTH";
            :>> installedX = 0.0;
            :>> installedY = 0.0;
            :>> installedZ = 3.2;
        }

        part westAnchor : UwbAnchor {
            :>> anchorId = "ANCHOR-WEST";
            :>> installedX = -30.0;
            :>> installedY = 10.0;
            :>> installedZ = 3.2;
        }

        part trackedTag : MobileTag {
            :>> tagId = "TAG-ASSET-001";
            :>> batteryCharge = 0.85;
        }

        part gateway : EdgeGateway {
            :>> gatewayId = "GW-FLOOR-03";
            :>> processingLatency = 0.08;
        }

        part engine : PositioningEngine {
            :>> engineId = "PE-BUILDING-A";
        }

        part display : OperatorDisplay {
            :>> displayId = "OPS-DISPLAY-01";
        }

        item floor3Map : FloorMap {
            :>> buildingId = "BUILDING-A";
            :>> floor = 3;
            :>> mapRevision = "2026.06";
            :>> coordinateOriginX = 0.0;
            :>> coordinateOriginY = 0.0;
        }

        connect trackedTag.uwb to northAnchor.uwb;
        connect trackedTag.uwb to eastAnchor.uwb;
        connect trackedTag.uwb to southAnchor.uwb;
        connect trackedTag.uwb to westAnchor.uwb;

        connect northAnchor.measurementOut to gateway.northMeasurement;
        connect eastAnchor.measurementOut to gateway.eastMeasurement;
        connect southAnchor.measurementOut to gateway.southMeasurement;
        connect westAnchor.measurementOut to gateway.westMeasurement;

        connect gateway.network to engine.network;
        connect engine.positionOut to display.positionIn;
        connect engine.alertOut to display.alertIn;

        flow floor3Map to engine.mapIn.map;
    }

    requirement def ProvideIndoorPosition {
        subject ips : IndoorPositioningSystem;
        require constraint {
            ips.requiredAccuracy <= 0.50
        }
        doc /* The system shall estimate and publish the indoor position of a mobile tag with an accuracy radius of 0.50 m or better under nominal radio conditions. */
    }

    requirement def RealTimeUpdate {
        subject ips : IndoorPositioningSystem;
        require constraint {
            ips.nominalUpdateRate >= 10.0
        }
        doc /* The system shall update tracked tag positions at a nominal rate of at least 10 Hz. */
    }

    requirement def HighAvailability {
        subject ips : IndoorPositioningSystem;
        require constraint {
            ips.requiredAvailability >= 0.995
        }
        doc /* The system shall maintain indoor location service availability of at least 99.5 percent during normal building operation. */
    }

    requirement def DegradedModeOperation {
        doc /* The system shall continue to provide a marked degraded position estimate when fewer than four anchors are available but at least three anchors remain observable. */
    }

    requirement def ZoneAlerting {
        doc /* The system shall generate an alert when a tracked tag enters a restricted indoor zone defined by the active floor map. */
    }

    satisfy ProvideIndoorPosition by IndoorPositioningSystem::engine;
    satisfy RealTimeUpdate by IndoorPositioningSystem::trackedTag;
    satisfy HighAvailability by IndoorPositioningSystem::gateway;
    satisfy DegradedModeOperation by IndoorPositioningSystem::engine::trackingStates;
    satisfy ZoneAlerting by IndoorPositioningSystem::engine::locateAsset;
}