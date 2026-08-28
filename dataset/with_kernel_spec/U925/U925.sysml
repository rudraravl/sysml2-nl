package TriDARNavigationSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;
    private import Time::*;
    private import MeasurementReferences::*;
    private import VectorFunctions::*;
    private import ISQ::Position3dVector;

    item def PointCloud {
        attribute points : Position3dVector[0..*];
    }

    item def Image {
        attribute width : Natural;
        attribute height : Natural;
        attribute pixelData : Integer[0..*];
    }

    item def StereoImagePair {
        attribute leftImage : Image;
        attribute rightImage : Image;
    }

    item def EulerAngles {
        attribute roll : ISQ::AngleValue;
        attribute pitch : ISQ::AngleValue;
        attribute yaw : ISQ::AngleValue;
    }

    item def PoseEstimate {
        attribute position : Position3dVector;
        attribute orientation : EulerAngles;
        attribute timestamp : Time::TimeInstantValue;
    }

    port def PowerInPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }

    port def PowerOutPort {
        out attribute voltage : Real;
        out attribute current : Real;
    }

    port def PointCloudOutPort {
        out item data : PointCloud;
    }

    port def PointCloudInPort {
        in item data : PointCloud;
    }

    port def StereoImageOutPort {
        out item data : StereoImagePair;
    }

    port def StereoImageInPort {
        in item data : StereoImagePair;
    }

    port def PoseOutPort {
        out item pose : PoseEstimate;
    }

    action def ScanLidar {
        out item result : PointCloud;
        first start;
        then action emitPulses;
        then action receiveReturns;
        then action constructPointCloud;
        then done;
    }

    action def CaptureImage {
        out item image : Image;
        first start;
        then action expose;
        then action readout;
        then done;
    }

    action def CaptureStereo {
        out item pair : StereoImagePair;
        first start;
        then action captureLeftImage;
        then action captureRightImage;
        then action generateStereoPair;
        then done;
    }

    action def FuseData {
        in item lidarData : PointCloud;
        in item stereoData : StereoImagePair;
        out item pose : PoseEstimate;
        first start;
        then action validateInputs;
        then action alignData;
        then action computePose;
        then done;
    }

    action def RegulatePower {
        first start;
        then action checkMainPower;
        then action distribute;
        then done;
    }

    part def LIDARScanner {
        port power : PowerInPort;
        port dataOut : PointCloudOutPort;
        attribute maxRange : ISQ::LengthValue = 50.0 [m];
        attribute distanceAccuracy : ISQ::LengthValue = 0.01 [m];
        perform action scan : ScanLidar;
        bind dataOut.data = scan.result;
    }

    part def Camera {
        attribute resolution : Natural = 1920;
        perform action capture : CaptureImage;
    }

    part def StereoCameraSystem {
        port power : PowerInPort;
        port dataOut : StereoImageOutPort;
        attribute baseline : ISQ::LengthValue = 0.5 [m];
        part leftCamera : Camera;
        part rightCamera : Camera;
        perform action captureStereoPair : CaptureStereo;
        bind dataOut.data = captureStereoPair.pair;
    }

    part def DataProcessingUnit {
        port power : PowerInPort;
        port lidarIn : PointCloudInPort;
        port stereoIn : StereoImageInPort;
        port poseOut : PoseOutPort;
        attribute outputRate : ISQ::FrequencyValue = 15.0 [Hz];
        attribute poseAccuracy : ISQ::LengthValue = 0.02 [m];
        attribute fusionComplete : Boolean = false;
        attribute dataReady : Boolean = false;
        state machine processingState {
            state idle;
            state receiving;
            state fusing;
            state outputting;
            transition from idle to receiving when dataReady == true;
            transition from receiving to fusing after 0.001[SI::s];
            transition from fusing to outputting when fusionComplete == true;
            transition from outputting to idle after 0.001[SI::s];
        }
        perform action fuseData : FuseData;
        bind lidarIn.data = fuseData.lidarData;
        bind stereoIn.data = fuseData.stereoData;
        bind poseOut.pose = fuseData.pose;
    }

    part def PowerManagementUnit {
        port mainPower : PowerInPort;
        port powerLidar : PowerOutPort;
        port powerCameras : PowerOutPort;
        port powerProcessor : PowerOutPort;
        attribute totalPowerLimit : ISQ::PowerValue = 85.0 [W];
        perform action regulatePower : RegulatePower;
    }

    part def TriDARSystem {
        part lidar : LIDARScanner;
        part cameras : StereoCameraSystem;
        part processor : DataProcessingUnit;
        part powerUnit : PowerManagementUnit;
        port navSolutionOut : PoseOutPort;
        attribute mass : ISQ::MassValue = 8.0 [kg];
        attribute powerConsumption : ISQ::PowerValue = 80.0 [W];
        attribute operationalRange : ISQ::LengthValue = 50.0 [m];
        attribute distanceAccuracy : ISQ::LengthValue = 0.01 [m];
        attribute poseAccuracy : ISQ::LengthValue = 0.02 [m];
        attribute outputRate : ISQ::FrequencyValue = 15.0 [Hz];
        attribute resetCommand : Boolean = false;
        connect powerUnit.powerLidar to lidar.power;
        connect powerUnit.powerCameras to cameras.power;
        connect powerUnit.powerProcessor to processor.power;
        connect lidar.dataOut to processor.lidarIn;
        connect cameras.dataOut to processor.stereoIn;
        connect processor.poseOut to navSolutionOut;
        state machine systemState {
            state off;
            state initializing;
            state scanning;
            state tracking;
            state error;
            transition from off to initializing when powerUnit.mainPower.voltage > 0;
            transition from initializing to scanning after 5.0[SI::s];
            transition from scanning to tracking when processor.fusionComplete == true;
            transition from tracking to scanning when processor.fusionComplete == false;
            transition from scanning to error when lidar.power.voltage == 0 or cameras.power.voltage == 0;
            transition from tracking to error when lidar.power.voltage == 0 or cameras.power.voltage == 0;
            transition from error to initializing when powerUnit.mainPower.voltage > 0 and resetCommand;
        }
        perform action provideNavigationSolution {
            first start;
            then lidar.scan;
            then cameras.captureStereoPair;
            then processor.fuseData;
            then done;
        }
    }

    part triDARSystem : TriDARSystem;

    requirement def MassRequirement {
        attribute maxMass : ISQ::MassValue = 8.5 [kg];
    }

    requirement def PowerRequirement {
        attribute maxPower : ISQ::PowerValue = 85.0 [W];
    }

    requirement def RangeRequirement {
        attribute maxRange : ISQ::LengthValue = 50.0 [m];
    }

    requirement def DistanceAccuracyRequirement {
        attribute accuracy : ISQ::LengthValue = 0.01 [m];
    }

    requirement def PoseAccuracyRequirement {
        attribute accuracy : ISQ::LengthValue = 0.02 [m];
    }

    requirement def OutputRateRequirement {
        attribute rate : ISQ::FrequencyValue = 15.0 [Hz];
    }

    requirement def AutonomousPoseDetermination;

    #derivation connection def PoseDerivation {
        end #original req : AutonomousPoseDetermination;
        end #derive range : RangeRequirement;
        end #derive distAcc : DistanceAccuracyRequirement;
        end #derive poseAcc : PoseAccuracyRequirement;
        end #derive rate : OutputRateRequirement;
    }

    part satisfactionContext {
        ref :>> triDARSystem;
        satisfy requirement massReq : MassRequirement by triDARSystem;
        satisfy requirement powerReq : PowerRequirement by triDARSystem.powerUnit;
        satisfy requirement rangeReq : RangeRequirement by triDARSystem.lidar;
        satisfy requirement distAccReq : DistanceAccuracyRequirement by triDARSystem.lidar;
        satisfy requirement poseAccReq : PoseAccuracyRequirement by triDARSystem.processor;
        satisfy requirement rateReq : OutputRateRequirement by triDARSystem.processor;
        satisfy requirement autoPose : AutonomousPoseDetermination by triDARSystem;
        #derivation connection : PoseDerivation {
            end req ::> autoPose;
            end range ::> rangeReq;
            end distAcc ::> distAccReq;
            end poseAcc ::> poseAccReq;
            end rate ::> rateReq;
        }
    }
}
