package LidarSystem {
    doc
    /*
     * Complete model of a LiDAR (Light Detection and Ranging) range imaging system.
     * The system measures distances using time-of-flight of laser pulses and produces
     * depth maps and point clouds for 3D environmental mapping.
     */

    private import ISQ::*;
    private import Time::*;
    private import ScalarValues::*;
    private import SequenceFunctions::size;

    attribute def Distance :> LengthValue;
    attribute def Power :> PowerValue;
    attribute def AngularFOV :> PlaneAngleValue;
    attribute def FrameRate :> FrequencyValue;

    item def LaserPulse {
        attribute wavelength : LengthValue;
        attribute emissionTime : TimeInstantValue;
        attribute intensity : Real;
    }

    item def Reflection {
        ref item sourcePulse : LaserPulse;
        attribute returnTime : TimeInstantValue;
        attribute intensity : Real;
        attribute azimuth : AngularFOV;
        attribute elevation : AngularFOV;
    }

    item def RawMeasurement {
        attribute distance : Distance;
        attribute intensity : Real;
        attribute azimuth : AngularFOV;
        attribute elevation : AngularFOV;
        attribute timestamp : TimeInstantValue;
    }

    attribute def Point3D {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute intensity : Real;
    }

    item def PointCloud {
        attribute points : Point3D[0..*] ordered;
        attribute pointCount : Integer = points->size();
    }

    item def DepthMap {
        attribute width : Integer = 640;
        attribute height : Integer = 480;
        attribute pixelDepths : Distance[0..*] ordered;
        attribute pixelCount : Integer = width * height;
    }

    part def LaserEmitter {
        out port emittedPulses : LaserPulse[0..*];
        attribute pulseRate : FrameRate;
        attribute wavelength : LengthValue;
        attribute powerConsumption : Power;
    }

    part def ScanningMirror {
        in port incomingPulses : LaserPulse[0..*];
        out port directedPulses : LaserPulse[0..*];
        attribute horizontalFOV : AngularFOV = 120;
        attribute verticalFOV : AngularFOV = 30;
        attribute powerConsumption : Power;
    }

    part def PhotodetectorArray {
        in port reflectedPulses : Reflection[0..*];
        out port detectedReflections : Reflection[0..*];
        attribute detectionEfficiency : Real;
        attribute powerConsumption : Power;
    }

    part def TimeOfFlightProcessor {
        in port detectedReflections : Reflection[0..*];
        out port rawMeasurements : RawMeasurement[0..*];
        attribute powerConsumption : Power;

        calc computeDistance {
            in emissionTime : TimeInstantValue;
            in returnTime : TimeInstantValue;
            return distance : Distance;
        }
    }

    part def DepthMapGenerator {
        in port rawMeasurements : RawMeasurement[0..*];
        out port depthMap : DepthMap;
        attribute frameWidth : Integer = 640;
        attribute frameHeight : Integer = 480;
        attribute powerConsumption : Power;
    }

    part def PointCloudProcessor {
        in port rawMeasurements : RawMeasurement[0..*];
        out port pointCloud : PointCloud;
        attribute maxPoints : Integer;
        attribute powerConsumption : Power;
    }

    part def Lidar {
        in port trigger : Boolean;
        out port depthMapOutput : DepthMap;
        out port pointCloudOutput : PointCloud;

        attribute powerBudget : Power = 100;
        attribute frameRate : FrameRate = 10;
        attribute maxRange : Distance = 200;

        part emitter : LaserEmitter;
        part mirror : ScanningMirror;
        part detector : PhotodetectorArray;
        part tofProcessor : TimeOfFlightProcessor;
        part depthGen : DepthMapGenerator;
        part cloudGen : PointCloudProcessor;

        flow emitter.emittedPulses to mirror.incomingPulses;
        flow mirror.directedPulses to detector.reflectedPulses;
        flow detector.detectedReflections to tofProcessor.detectedReflections;
        flow tofProcessor.rawMeasurements to depthGen.rawMeasurements;
        flow tofProcessor.rawMeasurements to cloudGen.rawMeasurements;
        flow depthGen.depthMap to depthMapOutput;
        flow cloudGen.pointCloud to pointCloudOutput;

        state machine operatingStates {
            initial state idle;
            state scanning;
            state processing;
            state outputting;

            transition from idle to scanning when trigger;
            transition from scanning to processing;
            transition from processing to outputting;
            transition from outputting to idle;
        }
    }

    requirement def LidarRequirements {
        doc
        /*
         * Top-level requirements for the LiDAR range imaging system.
         */
        subject lidar : Lidar;

        requirement frameRateReq {
            doc
            /* The system shall capture 3D data at 10 frames per second or more. */
            lidar.frameRate >= 10;
        }
        requirement rangeReq {
            doc
            /* The effective range shall be at least 200 meters. */
            lidar.maxRange >= 200;
        }
        requirement powerReq {
            doc
            /* The power consumption shall not exceed 100 watts. */
            lidar.powerBudget <= 100;
        }
        requirement fovReq {
            doc
            /* The field of view shall be 120 degrees horizontal and 30 degrees vertical. */
            lidar.mirror.horizontalFOV == 120 and lidar.mirror.verticalFOV == 30;
        }
        requirement resolutionReq {
            doc
            /* The depth map resolution shall be 640 by 480 pixels. */
            lidar.depthGen.frameWidth == 640 and lidar.depthGen.frameHeight == 480;
        }
    }

    requirement lidarSpec : LidarRequirements;
}
