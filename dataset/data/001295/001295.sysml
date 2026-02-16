package TriDAR_NavigationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def DistanceValue :> LengthValue;
    attribute def VelocityValue :> SpeedValue;
    attribute def AngularValue :> AngleValue;
    attribute def IntensityValue :> Real;
    attribute def AccuracyValue :> LengthValue;
    
    item def LaserPulse {
        attribute wavelength : LengthValue;
        attribute power : PowerValue;
        attribute timestamp : TimeValue;
    }
    
    item def ReturnSignal {
        attribute intensity : IntensityValue;
        attribute timeOfFlight : TimeValue;
        attribute range : DistanceValue;
    }
    
    item def ImageFrame {
        attribute width : Integer;
        attribute height : Integer;
        attribute timestamp : TimeValue;
    }
    
    item def PointCloud {
        attribute timestamp : TimeValue;
        attribute pointCount : Integer;
    }
    
    item def TargetPose {
        attribute confidence : Real;
    }
    
    port def LaserEmitterPort {
        out pulse : LaserPulse;
    }
    
    port def LaserReceiverPort {
        in returnSignal : ReturnSignal;
    }
    
    port def ImageOutputPort {
        out imageFrame : ImageFrame;
    }
    
    port def DataFusionPort {
        in lidarData : PointCloud;
        in imageData : ImageFrame;
        out fusedPose : TargetPose;
    }
    
    port def NavigationOutputPort {
        out targetPose : TargetPose;
        out pointCloud : PointCloud;
    }
    
    port def PowerPort {
        in voltage : Real;
        in current : Real;
    }
    
    part def LIDARScanner {
        attribute scanRate : Real;
        attribute maxRange : DistanceValue;
        attribute angularResolution : AngularValue;
        attribute fieldOfView : AngularValue;
        
        port emitter : LaserEmitterPort;
        port receiver : LaserReceiverPort;
        port powerIn : PowerPort;
        
        perform action scanCycle {
            first start;
            then emitLaser;
            action emitLaser {
                out laserPulse : LaserPulse;
            }
            then waitForReturn;
            action waitForReturn {
                in signal : ReturnSignal;
                out measuredRange : DistanceValue;
            }
            then accumulatePoint;
            action accumulatePoint {
                in range : DistanceValue;
                in currentAngle : AngularValue;
            }
            then decide;
                if currentAngle < fieldOfView then emitLaser;
                if currentAngle >= fieldOfView then generateCloud;
            action generateCloud {
                out cloud : PointCloud;
            }
            then done;
        }
    }
    
    part def StereoCameraSystem {
        attribute baselineDistance : DistanceValue;
        attribute focalLength : LengthValue;
        attribute frameRate : Real;
        
        port leftCameraOut : ImageOutputPort;
        port rightCameraOut : ImageOutputPort;
        port powerIn : PowerPort;
        
        part leftCamera {
            port imageOut : ImageOutputPort;
        }
        
        part rightCamera {
            port imageOut : ImageOutputPort;
        }
        
        perform action captureStereoPair {
            first start;
            then parallel captureImages;
            action captureImages {
                action captureLeft {
                    out leftFrame : ImageFrame;
                }
                action captureRight {
                    out rightFrame : ImageFrame;
                }
            }
            then synchronizeFrames;
            action synchronizeFrames {
                in leftFrame : ImageFrame;
                in rightFrame : ImageFrame;
            }
            then done;
        }
    }
    
    part def DataProcessingUnit {
        attribute processingRate : Real;
        attribute memoryCapacity : Real;
        attribute computePower : PowerValue;
        
        port lidarInput;
        port imageInput;
        port fusionOutput : DataFusionPort;
        port powerIn : PowerPort;
        
        perform action processAndFuse {
            first start;
            then merge processingLoop;
            then receiveInputs;
            action receiveInputs {
                in lidarCloud : PointCloud;
                in stereoImages : ImageFrame;
            }
            then parallel processStreams;
            action processStreams {
                action processLidar {
                    in cloud : PointCloud;
                    out filteredCloud : PointCloud;
                }
                action processImages {
                    in images : ImageFrame;
                }
            }
            then fuseData;
            action fuseData {
                in lidarCloud : PointCloud;
                out preliminaryPose : TargetPose;
            }
            then refineEstimate;
            action refineEstimate {
                in preliminaryPose : TargetPose;
                out refinedPose : TargetPose;
            }
            then validateOutput;
            action validateOutput {
                in pose : TargetPose;
                out validPose : TargetPose;
                out isValid : Boolean;
            }
            then decide;
                if isValid then outputPose;
                if !isValid then processingLoop;
            action outputPose {
                in finalPose : TargetPose;
            }
            then processingLoop;
        }
    }
    
    part def PowerManagementUnit {
        attribute inputVoltage : Real;
        attribute outputVoltage : Real;
        attribute maxCurrent : Real;
        attribute efficiency : Real;
        
        port powerInput;
        port lidarPower : PowerPort;
        port cameraPower : PowerPort;
        port processorPower : PowerPort;
        
        perform action distributePower {
            first start;
            then regulateVoltage;
            action regulateVoltage {
                in inputV : Real;
                out outputV : Real;
            }
            then allocatePower;
            action allocatePower {
                in totalPower : PowerValue;
                out lidarAllocation : PowerValue;
                out cameraAllocation : PowerValue;
                out processorAllocation : PowerValue;
            }
            then monitorLoad;
            action monitorLoad {
                in currentDraw : Real;
                out loadStatus : Boolean;
            }
            then done;
        }
    }
    
    part def TriDAR {
        doc /* 
         * Triangulation and LIDAR (TriDAR) sensor system combining 
         * 3D laser scanning with stereo imaging for autonomous navigation.
         * Provides precise range, bearing, and pose estimation of targets
         * for rendezvous, docking, and proximity operations.
         */
        
        attribute operatingRange : DistanceValue = 50.0 [m];
        attribute rangeAccuracy : AccuracyValue = 0.01 [m];
        attribute poseAccuracy : AccuracyValue = 0.02 [m];
        attribute updateRate : Real = 15.0;
        attribute fieldOfView : AngularValue = 60.0 [deg];
        attribute totalMass : MassValue = 8.5 [kg];
        attribute powerConsumption : PowerValue = 85.0 [W];
        
        part lidar : LIDARScanner {
            attribute :>> scanRate = 15.0;
            attribute :>> maxRange = 50.0 [m];
            attribute :>> angularResolution = 0.1 [deg];
            attribute :>> fieldOfView = 60.0 [deg];
        }
        
        part stereoCamera : StereoCameraSystem {
            attribute :>> baselineDistance = 0.3 [m];
            attribute :>> focalLength = 0.025 [m];
            attribute :>> frameRate = 30.0;
        }
        
        part processor : DataProcessingUnit {
            attribute :>> processingRate = 100.0;
            attribute :>> memoryCapacity = 16384.0;
            attribute :>> computePower = 50.0 [W];
        }
        
        part powerMgmt : PowerManagementUnit {
            attribute :>> inputVoltage = 28.0;
            attribute :>> outputVoltage = 12.0;
            attribute :>> maxCurrent = 8.0;
            attribute :>> efficiency = 0.92;
        }
        
        port navigationOutput : NavigationOutputPort;
        port systemPowerInput;
        
        connection lidarToProcessor connect 
            lidar.receiver to processor.lidarInput;
        
        connection cameraToProcessor connect 
            stereoCamera.leftCameraOut to processor.imageInput;
        
        connection processorToOutput connect 
            processor.fusionOutput to navigationOutput;
        
        connection powerToLidar connect 
            powerMgmt.lidarPower to lidar.powerIn;
        
        connection powerToCamera connect 
            powerMgmt.cameraPower to stereoCamera.powerIn;
        
        connection powerToProcessor connect 
            powerMgmt.processorPower to processor.powerIn;
        
        connection systemPowerToPMU connect 
            systemPowerInput to powerMgmt.powerInput;
        
        perform action autonomousTargetTracking {
            doc /* 
             * Primary function: Autonomously acquire, track, and determine 
             * the precise 6-DOF pose (position and orientation) of target 
             * objects using fused LIDAR and stereo vision data for safe 
             * proximity operations and autonomous rendezvous.
             */
            
            first start;
            then merge continuousTracking;
            then parallel acquireData;
            
            action acquireData {
                action performLidarScan references lidar.scanCycle;
                action captureStereoPair references stereoCamera.captureStereoPair;
            }
            
            then synchronizeData;
            action synchronizeData {
                in lidarCloud : PointCloud;
                in stereoImages : ImageFrame;
            }
            
            then processAndFuse references processor.processAndFuse;
            
            then outputNavigationSolution;
            action outputNavigationSolution {
                in targetPose : TargetPose;
                in pointCloud : PointCloud;
            }
            
            then evaluateTracking;
            action evaluateTracking {
                in pose : TargetPose;
                out trackingQuality : Real;
                out continueTracking : Boolean;
            }
            
            then decide;
                if continueTracking then continuousTracking;
                if !continueTracking then done;
            
            then done;
        }
    }
    
    requirement <'REQ-TRIDAR-100'> primaryMission {
        doc /* 
         * The TriDAR system shall autonomously determine the six-degree-of-freedom 
         * pose (position and orientation) of target objects in real-time using 
         * combined LIDAR and stereo triangulation techniques to enable safe 
         * autonomous rendezvous and proximity operations.
         */
        subject tridar : TriDAR;
        
        require rangePerformance;
        require accuracyPerformance;
        require updateRatePerformance;
        require fieldOfViewPerformance;
    }
    
    requirement <'REQ-TRIDAR-101'> rangePerformance {
        doc /* 
         * The system shall provide accurate pose measurements at ranges 
         * from 1 meter to 50 meters.
         */
        subject tridar : TriDAR;
        
        assert constraint {
            tridar.operatingRange >= 50.0 [m]
        }
    }
    
    requirement <'REQ-TRIDAR-102'> accuracyPerformance {
        doc /* 
         * The system shall provide range accuracy better than 1 cm and 
         * pose accuracy better than 2 cm at nominal operating distances.
         */
        subject tridar : TriDAR;
        
        assert constraint {
            tridar.rangeAccuracy <= 0.01 [m] and 
            tridar.poseAccuracy <= 0.02 [m]
        }
    }
    
    requirement <'REQ-TRIDAR-103'> updateRatePerformance {
        doc /* 
         * The system shall provide navigation data updates at a minimum 
         * rate of 15 Hz to support real-time control loops.
         */
        subject tridar : TriDAR;
        
        assert constraint {
            tridar.updateRate >= 15.0
        }
    }
    
    requirement <'REQ-TRIDAR-104'> fieldOfViewPerformance {
        doc /* 
         * The system shall provide a field of view of at least 60 degrees 
         * to enable wide-area target acquisition and tracking.
         */
        subject tridar : TriDAR;
        
        assert constraint {
            tridar.fieldOfView >= 60.0 [deg]
        }
    }
    
    requirement <'REQ-TRIDAR-105'> massConstraint {
        doc /* 
         * The total system mass shall not exceed 10 kg to meet 
         * spacecraft integration requirements.
         */
        subject tridar : TriDAR;
        
        assert constraint {
            tridar.totalMass <= 10.0 [kg]
        }
    }
    
    requirement <'REQ-TRIDAR-106'> powerConstraint {
        doc /* 
         * The system power consumption shall not exceed 100 W during 
         * normal operation.
         */
        subject tridar : TriDAR;
        
        assert constraint {
            tridar.powerConsumption <= 100.0 [W]
        }
    }
    
    part tridarNavigationSystem : TriDAR;
    
    satisfy primaryMission by tridarNavigationSystem;
    satisfy rangePerformance by tridarNavigationSystem;
    satisfy accuracyPerformance by tridarNavigationSystem;
    satisfy updateRatePerformance by tridarNavigationSystem;
    satisfy fieldOfViewPerformance by tridarNavigationSystem;
    satisfy massConstraint by tridarNavigationSystem;
    satisfy powerConstraint by tridarNavigationSystem;
}
