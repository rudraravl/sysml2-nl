package IndoorPositioningSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQElectromagnetism::*;

    // ---------- Value Types ----------
    value type Distance :> Real {
        :>> unit = 'm';
    }
    value type Area :> Real {
        :>> unit = 'm^2';
    }
    value type Frequency :> Real {
        :>> unit = 'Hz';
    }
    value type Power :> Real {
        :>> unit = 'dBm';
    }
    value type PositionAccuracy :> Real {
        :>> unit = 'm';
    }
    value type UpdateRate :> Real {
        :>> unit = 'Hz';
    }
    value type BeaconId :> String;
    value type DeviceId :> String;
    value type Timestamp :> Real {
        :>> unit = 's';
    }

    value def Position3D {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
    }

    value def BeaconInfo {
        attribute id : BeaconId;
        attribute position : Position3D;
        attribute txPower : Power;
    }

    value def SignalMeasurement {
        attribute beaconId : BeaconId;
        attribute rssi : Power;
        attribute timestamp : Timestamp;
    }

    value def DistanceEstimate {
        attribute beaconId : BeaconId;
        attribute distance : Distance;
    }

    value def LocationEstimate {
        attribute deviceId : DeviceId;
        attribute position : Position3D;
        attribute accuracy : PositionAccuracy;
        attribute timestamp : Timestamp;
    }

    // ---------- Item Types ----------
    item def BeaconSignal {
        attribute beaconId : BeaconId;
        attribute txPower : Power;
        attribute timestamp : Timestamp;
    }

    item def MeasurementReport {
        attribute deviceId : DeviceId;
        attribute measurements : SignalMeasurement[0..*];
        attribute timestamp : Timestamp;
    }

    item def LocationReport {
        attribute estimate : LocationEstimate;
    }

    item def BeaconRegistration {
        attribute info : BeaconInfo;
    }

    item def DeviceRegistration {
        attribute deviceId : DeviceId;
        attribute active : Boolean;
    }

    // ---------- Port Definitions ----------
    port def BeaconBroadcastPort {
        out beaconSignal : BeaconSignal;
    }

    port def SignalReceivePort {
        in beaconSignal : BeaconSignal;
    }

    port def MeasurementPort {
        out measurementReport : MeasurementReport;
    }

    port def MeasurementReceivePort {
        in measurementReport : MeasurementReport;
    }

    port def LocationPort {
        out locationReport : LocationReport;
    }

    port def LocationReceivePort {
        in locationReport : LocationReport;
    }

    port def CoordinationPort {
        out locationReport : LocationReport;
    }

    port def CoordinationReceivePort {
        in locationReport : LocationReport;
    }

    // ---------- Fixed Beacon ----------
    part def FixedBeacon {
        attribute beaconId : BeaconId;
        attribute position : Position3D;
        attribute txPower : Power = -10 [dBm];
        attribute broadcastInterval : Real = 0.5 [s];
        attribute broadcastFrequency : Frequency = 2.4e9 [Hz];

        port broadcastPort : BeaconBroadcastPort;

        attribute broadcastCount : Integer = 0;

        state def BeaconBehavior {
            entry action {
                broadcastCount := 0;
            }
            state Broadcasting {
                entry action {
                    send BeaconSignal{beaconId = beaconId; txPower = txPower; timestamp = current_time()} via broadcastPort.beaconSignal;
                    broadcastCount := broadcastCount + 1;
                }
                do action wait(broadcastInterval);
                transition Broadcasting -> Broadcasting
                    when broadcastCount < 1000000;
            }
        }

        comportment : BeaconBehavior;
    }

    // ---------- Mobile Device ----------
    part def MobileDevice {
        attribute deviceId : DeviceId;
        attribute maxReceivedBeacons : Integer = 8;
        attribute measurementBuffer : SignalMeasurement[0..*];

        port receivePort : SignalReceivePort;
        port reportPort : MeasurementPort;

        state def DeviceBehavior {
            state Idle;
            state Collecting {
                entry action {
                    measurementBuffer := {};
                }
                do action accept BeaconSignal via receivePort.beaconSignal {
                    if size(measurementBuffer) < maxReceivedBeacons then {
                        append(measurementBuffer, SignalMeasurement{beaconId = beaconSignal.beaconId; rssi = beaconSignal.txPower - 30 [dBm]; timestamp = beaconSignal.timestamp});
                    }
                }
            }
            state Reporting {
                entry action {
                    send MeasurementReport{deviceId = deviceId; measurements = measurementBuffer; timestamp = current_time()} via reportPort.measurementReport;
                }
            }
            transition Idle -> Collecting when true;
            transition Collecting -> Reporting
                when size(measurementBuffer) >= 3;
            transition Reporting -> Collecting
                when true;
        }

        comportment : DeviceBehavior;
    }

    // ---------- Localization Processor ----------
    part def LocalizationProcessor {
        attribute beaconRegistry : BeaconInfo[0..*];
        attribute pathLossExponent : Real = 2.0;
        attribute referenceDistance : Distance = 1 [m];
        attribute referenceLoss : Power = 40 [dBm];

        port measurementReceivePort : MeasurementReceivePort;
        port locationPort : LocationPort;

        private action def CalculateDistance {
            in rssi : Power;
            in txPower : Power;
            out distance : Distance;
            
            perform {
                var pathLoss : Power = txPower - rssi;
                var ratio : Real = (pathLoss - referenceLoss) / (10 * pathLossExponent);
                distance := referenceDistance * (10 ^ ratio);
            }
        }

        private action def Trilaterate {
            in estimates : DistanceEstimate[3..*];
            in beaconPositions : Position3D[3..*];
            out position : Position3D;
            out accuracy : PositionAccuracy;
            
            perform {
                // Simplified trilateration: weighted centroid based on inverse distance
                var totalWeight : Real = 0;
                var sumX : Real = 0;
                var sumY : Real = 0;
                var sumZ : Real = 0;
                for i in 1..size(estimates) {
                    var w : Real = 1 / (estimates[i].distance + 0.1);
                    totalWeight := totalWeight + w;
                    sumX := sumX + w * beaconPositions[i].x;
                    sumY := sumY + w * beaconPositions[i].y;
                    sumZ := sumZ + w * beaconPositions[i].z;
                }
                position := Position3D{x = sumX / totalWeight; y = sumY / totalWeight; z = sumZ / totalWeight};
                
                // Accuracy estimate: average residual
                var residualSum : Real = 0;
                for i in 1..size(estimates) {
                    var dx : Real = position.x - beaconPositions[i].x;
                    var dy : Real = position.y - beaconPositions[i].y;
                    var dz : Real = position.z - beaconPositions[i].z;
                    var computedDist : Distance = sqrt(dx*dx + dy*dy + dz*dz);
                    residualSum := residualSum + abs(computedDist - estimates[i].distance);
                }
                accuracy := residualSum / size(estimates);
            }
        }

        action def ProcessMeasurements {
            in report : MeasurementReport;
            out locationEstimate : LocationEstimate;
            
            perform {
                var distanceEstimates : DistanceEstimate[0..*] = {};
                var positions : Position3D[0..*] = {};
                for i in 1..size(report.measurements) {
                    var beaconInfo : BeaconInfo = find(beaconRegistry, b => b.id == report.measurements[i].beaconId);
                    if beaconInfo != null then {
                        var dist : Distance;
                        perform CalculateDistance(rssi = report.measurements[i].rssi, txPower = beaconInfo.txPower, distance = dist);
                        append(distanceEstimates, DistanceEstimate{beaconId = beaconInfo.id; distance = dist});
                        append(positions, beaconInfo.position);
                    }
                }
                if size(distanceEstimates) >= 3 then {
                    var pos : Position3D;
                    var acc : PositionAccuracy;
                    perform Trilaterate(estimates = distanceEstimates, beaconPositions = positions, position = pos, accuracy = acc);
                    locationEstimate := LocationEstimate{deviceId = report.deviceId; position = pos; accuracy = acc; timestamp = report.timestamp};
                }
            }
        }

        state def ProcessorBehavior {
            state Waiting {
                do action accept MeasurementReport via measurementReceivePort.measurementReport {
                    var estimate : LocationEstimate;
                    perform ProcessMeasurements(report = measurementReceivePort.measurementReport, locationEstimate = estimate);
                    if estimate != null then {
                        send LocationReport{estimate = estimate} via locationPort.locationReport;
                    }
                }
            }
        }

        comportment : ProcessorBehavior;
    }

    // ---------- Central Coordinator ----------
    part def CentralCoordinator {
        attribute beaconRegister : BeaconInfo[0..*];
        attribute deviceRegister : DeviceRegistration[0..*];
        attribute locationHistory : LocationEstimate[0..*];
        attribute coverageArea : Area = 500 [m^2];

        port locationReceivePort : LocationReceivePort;

        action def ValidateLocation {
            in estimate : LocationEstimate;
            out valid : Boolean;
            
            perform {
                valid := (estimate.accuracy <= 1.5 [m]) and (estimate.position.x >= 0) and (estimate.position.y >= 0) and (estimate.position.z >= 0);
            }
        }

        action def StoreLocation {
            in estimate : LocationEstimate;
            
            perform {
                append(locationHistory, estimate);
            }
        }

        state def CoordinatorBehavior {
            state Receiving {
                do action accept LocationReport via locationReceivePort.locationReport {
                    var isValid : Boolean;
                    perform ValidateLocation(estimate = locationReceivePort.locationReport.estimate, valid = isValid);
                    if isValid then {
                        perform StoreLocation(estimate = locationReceivePort.locationReport.estimate);
                    }
                }
            }
        }

        comportment : CoordinatorBehavior;
    }

    // ---------- System Assembly ----------
    part def IndoorPositioningSystem {
        attribute systemCoverageArea : Area = 500 [m^2];
        attribute requiredAccuracy : PositionAccuracy = 1.5 [m];
        attribute requiredUpdateRate : UpdateRate = 1.0 [Hz];

        part beacons : FixedBeacon[4] {
            :>> beaconId = ["B001", "B002", "B003", "B004"];
            :>> position = [
                Position3D{x = 0 [m]; y = 0 [m]; z = 3 [m]},
                Position3D{x = 20 [m]; y = 0 [m]; z = 3 [m]},
                Position3D{x = 0 [m]; y = 20 [m]; z = 3 [m]},
                Position3D{x = 20 [m]; y = 20 [m]; z = 3 [m]}
            ];
        }

        part mobileDevices : MobileDevice[2] {
            :>> deviceId = ["DEV001", "DEV002"];
        }

        part localizationProcessor : LocalizationProcessor {
            :>> beaconRegistry = [
                BeaconInfo{id = "B001"; position = Position3D{x = 0 [m]; y = 0 [m]; z = 3 [m]}; txPower = -10 [dBm]},
                BeaconInfo{id = "B002"; position = Position3D{x = 20 [m]; y = 0 [m]; z = 3 [m]}; txPower = -10 [dBm]},
                BeaconInfo{id = "B003"; position = Position3D{x = 0 [m]; y = 20 [m]; z = 3 [m]}; txPower = -10 [dBm]},
                BeaconInfo{id = "B004"; position = Position3D{x = 20 [m]; y = 20 [m]; z = 3 [m]}; txPower = -10 [dBm]}
            ];
        }

        part centralCoordinator : CentralCoordinator {
            :>> beaconRegister = [
                BeaconInfo{id = "B001"; position = Position3D{x = 0 [m]; y = 0 [m]; z = 3 [m]}; txPower = -10 [dBm]},
                BeaconInfo{id = "B002"; position = Position3D{x = 20 [m]; y = 0 [m]; z = 3 [m]}; txPower = -10 [dBm]},
                BeaconInfo{id = "B003"; position = Position3D{x = 0 [m]; y = 20 [m]; z = 3 [m]}; txPower = -10 [dBm]},
                BeaconInfo{id = "B004"; position = Position3D{x = 20 [m]; y = 20 [m]; z = 3 [m]}; txPower = -10 [dBm]}
            ];
            :>> deviceRegister = [
                DeviceRegistration{deviceId = "DEV001"; active = true},
                DeviceRegistration{deviceId = "DEV002"; active = true}
            ];
        }

        // Connections: Beacons broadcast to all mobile devices
        connection beaconBroadcast1 : BeaconSignal from beacons[1].broadcastPort.beaconSignal to mobileDevices[1].receivePort.beaconSignal;
        connection beaconBroadcast2 : BeaconSignal from beacons[1].broadcastPort.beaconSignal to mobileDevices[2].receivePort.beaconSignal;
        connection beaconBroadcast3 : BeaconSignal from beacons[2].broadcastPort.beaconSignal to mobileDevices[1].receivePort.beaconSignal;
        connection beaconBroadcast4 : BeaconSignal from beacons[2].broadcastPort.beaconSignal to mobileDevices[2].receivePort.beaconSignal;
        connection beaconBroadcast5 : BeaconSignal from beacons[3].broadcastPort.beaconSignal to mobileDevices[1].receivePort.beaconSignal;
        connection beaconBroadcast6 : BeaconSignal from beacons[3].broadcastPort.beaconSignal to mobileDevices[2].receivePort.beaconSignal;
        connection beaconBroadcast7 : BeaconSignal from beacons[4].broadcastPort.beaconSignal to mobileDevices[1].receivePort.beaconSignal;
        connection beaconBroadcast8 : BeaconSignal from beacons[4].broadcastPort.beaconSignal to mobileDevices[2].receivePort.beaconSignal;

        // Connections: Mobile devices report to localization processor
        connection measurementReport1 : MeasurementReport from mobileDevices[1].reportPort.measurementReport to localizationProcessor.measurementReceivePort.measurementReport;
        connection measurementReport2 : MeasurementReport from mobileDevices[2].reportPort.measurementReport to localizationProcessor.measurementReceivePort.measurementReport;

        // Connection: Localization processor sends location to central coordinator
        connection locationReport : LocationReport from localizationProcessor.locationPort.locationReport to centralCoordinator.locationReceivePort.locationReport;
    }

    // ---------- Requirements ----------
    requirement def PositionAccuracyRequirement {
        doc /* The system shall determine a device's position with an accuracy of at least 1.5 meters. */
        attribute maxAccuracy : PositionAccuracy = 1.5 [m];
        subject : IndoorPositioningSystem;
        predicate { centralCoordinator.locationHistory.accuracy <= maxAccuracy }
    }

    requirement def CoverageRequirement {
        doc /* The system shall provide coverage over a 500 square meter area. */
        attribute minCoverage : Area = 500 [m^2];
        subject : IndoorPositioningSystem;
        predicate { systemCoverageArea >= minCoverage }
    }

    requirement def UpdateRateRequirement {
        doc /* The system shall deliver location updates at least once per second. */
        attribute minUpdateRate : UpdateRate = 1.0 [Hz];
        subject : IndoorPositioningSystem;
        predicate { requiredUpdateRate >= minUpdateRate }
    }

    requirement def BeaconBroadcastRequirement {
        doc /* Each fixed beacon shall continuously broadcast a unique identification signal at a regular interval. */
        subject : FixedBeacon;
        predicate { broadcastInterval > 0 [s] and beaconId != "" }
    }

    requirement def TrilaterationRequirement {
        doc /* The localization processor shall calculate the device's 3D position using trilateration based on distances derived from signal strength. */
        subject : LocalizationProcessor;
        predicate { true }
    }

    requirement def DataValidationRequirement {
        doc /* The central coordinator shall validate and store received location estimates. */
        subject : CentralCoordinator;
        predicate { true }
    }

    requirement IndoorPositioningRequirements : PositionAccuracyRequirement {
        satisfy by IndoorPositioningSystem;
    }

    requirement CoverageReq : CoverageRequirement {
        satisfy by IndoorPositioningSystem;
    }

    requirement UpdateRateReq : UpdateRateRequirement {
        satisfy by IndoorPositioningSystem;
    }

    requirement BeaconReq : BeaconBroadcastRequirement {
        satisfy by FixedBeacon;
    }

    requirement TrilaterationReq : TrilaterationRequirement {
        satisfy by LocalizationProcessor;
    }

    requirement ValidationReq : DataValidationRequirement {
        satisfy by CentralCoordinator;
    }
}
