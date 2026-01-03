package VaimosSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def OperationalMode;
    attribute def NavigationCommand;
    attribute def SensorReading;
    attribute def ControlCommand;
    attribute def SystemHealth;
    
    value def Position {
        attribute x : ISQ::LengthValue;
        attribute y : ISQ::LengthValue;
        attribute z : ISQ::LengthValue;
    }
    
    value def Velocity {
        attribute vx : ISQ::SpeedValue;
        attribute vy : ISQ::SpeedValue;
        attribute vz : ISQ::SpeedValue;
    }
    
    value def Orientation {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    value def ThrustVector {
        attribute magnitude : ISQ::ForceValue;
        attribute direction : Orientation;
    }
    
    item def NavigationData {
        attribute timestamp : ISQ::TimeValue;
        attribute position : Position;
        attribute velocity : Velocity;
        attribute orientation : Orientation;
    }
    
    item def SensorData {
        attribute timestamp : ISQ::TimeValue;
        attribute readings : SensorReading[*];
        attribute quality : Real;
    }
    
    item def ControlData {
        attribute timestamp : ISQ::TimeValue;
        attribute thrustCommand : ThrustVector;
        attribute stabilizationCommand : Orientation;
    }
    
    port def NavigationPort {
        out item navData : NavigationData;
    }
    
    port def SensorPort {
        out item sensorData : SensorData;
    }
    
    port def ControlPort {
        in item controlData : ControlData;
    }
    
    port def PowerPort {
        out attribute voltage : ISQ::ElectricPotentialValue;
        out attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def NavigationSystem {
        attribute updateRate : ISQ::FrequencyValue;
        port navOut : ~NavigationPort;
        
        perform action computeNavigation {
            out navData : NavigationData;
        }
    }
    
    part def SensorArray {
        attribute sensorCount : Integer;
        attribute samplingRate : ISQ::FrequencyValue;
        port sensorOut : ~SensorPort;
        
        perform action acquireSensorData {
            out sensorData : SensorData;
        }
    }
    
    part def GuidanceComputer {
        attribute processingPower : ISQ::PowerValue;
        port navIn : NavigationPort;
        port sensorIn : SensorPort;
        port controlOut : ~ControlPort;
        
        perform action computeGuidance {
            in navData : NavigationData;
            in sensorData : SensorData;
            out controlData : ControlData;
        }
    }
    
    part def PropulsionSystem {
        attribute maxThrust : ISQ::ForceValue;
        attribute efficiency : Real;
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        
        perform action generateThrust {
            in controlData : ControlData;
            in power : ISQ::PowerValue;
            out thrust : ThrustVector;
        }
    }
    
    part def StabilizationSystem {
        attribute responseTime : ISQ::TimeValue;
        port controlIn : ControlPort;
        
        perform action stabilize {
            in controlData : ControlData;
            out stabilizationForce : ThrustVector;
        }
    }
    
    part def PowerManagement {
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentCharge : ISQ::EnergyValue;
        port powerOut : ~PowerPort[*];
        
        perform action distributePower {
            out powerAllocation : ISQ::PowerValue[*];
        }
    }
    
    part def CommunicationModule {
        attribute bandwidth : ISQ::FrequencyValue;
        attribute range : ISQ::LengthValue;
        
        perform action transmitTelemetry {
            in navData : NavigationData;
            in sensorData : SensorData;
            in systemHealth : SystemHealth;
        }
    }
    
    action def AcquireEnvironmentData {
        out navData : NavigationData;
        out sensorData : SensorData;
        
        action computeNavigation {
            out navData : NavigationData;
        }
        
        action acquireSensorData {
            out sensorData : SensorData;
        }
    }
    
    action def ComputeTrajectory {
        in currentNav : NavigationData;
        in targetPosition : Position;
        out trajectoryCommand : ControlData;
        
        action computeGuidance {
            in navData : NavigationData;
            out controlData : ControlData;
        }
    }
    
    action def ExecuteManeuver {
        in controlData : ControlData;
        out thrustOutput : ThrustVector;
        out stabilizationOutput : ThrustVector;
        
        action generateThrust {
            in controlData : ControlData;
            out thrust : ThrustVector;
        }
        
        action stabilize {
            in controlData : ControlData;
            out stabilizationForce : ThrustVector;
        }
    }
    
    action def MonitorSystemHealth {
        in powerStatus : ISQ::EnergyValue;
        in sensorStatus : SensorData;
        out healthReport : SystemHealth;
        
        action distributePower {
            out powerAllocation : ISQ::PowerValue[*];
        }
    }
    
    action def FinalizeMission {
        action transmitFinalData;
        then action safePowerDown;
    }
    
    action def VaimosOperation {
        in attribute missionWaypoints : Position[*] ordered;
        in attribute missionDuration : ISQ::TimeValue;
        
        private attribute currentWaypointIndex : Integer := 0;
        private attribute operationalMode : OperationalMode;
        private attribute systemHealthStatus : SystemHealth;
        private attribute waypointReached : Boolean := false;
        private attribute missionComplete : Boolean := false;
        
        first start;
        then merge operationCycle;
        
        action initialize {
            action powerUp;
            then action calibrateSensors;
            then action establishCommunication;
        }
        
        then operationCycle;
        
        action mainOperationLoop {
            action acquire : AcquireEnvironmentData {
                out navData;
                out sensorData;
            }
            
            flow acquire.navData to computeTraj.currentNav;
            flow acquire.sensorData to monitor.sensorStatus;
            
            then action computeTraj : ComputeTrajectory {
                in currentNav;
                in targetPosition = missionWaypoints#(currentWaypointIndex);
                out trajectoryCommand;
            }
            
            flow computeTraj.trajectoryCommand to execute.controlData;
            
            then action execute : ExecuteManeuver {
                in controlData;
                out thrustOutput;
                out stabilizationOutput;
            }
            
            then action monitor : MonitorSystemHealth {
                in powerStatus;
                in sensorStatus;
                out healthReport;
            }
            
            then assign systemHealthStatus := monitor.healthReport;
            
            then decide;
                if waypointReached then advanceWaypoint;
                if missionComplete then finalizeMission;
                else operationCycle;
            
            action advanceWaypoint {
                assign currentWaypointIndex := currentWaypointIndex + 1;
            }
            then operationCycle;
            
            action finalizeMission : FinalizeMission;
            then done;
        }
        
        then mainOperationLoop;
    }
    
    part def Vaimos {
        doc /* 
            Vaimos is an autonomous vehicle system designed for precision navigation 
            and environmental monitoring. The system integrates advanced navigation, 
            sensor fusion, guidance computation, and propulsion control to autonomously 
            traverse designated waypoints while collecting and transmitting environmental 
            data. Its primary function is to execute autonomous missions in challenging 
            environments with minimal human intervention.
        */
        
        attribute systemId : String;
        attribute missionProfile : String;
        attribute operationalStatus : SystemHealth;
        attribute maxOperatingTime : ISQ::TimeValue = 86400.0 [SI::s];
        attribute navigationAccuracy : ISQ::LengthValue = 5.0 [SI::m];
        
        part navigation : NavigationSystem {
            :>> updateRate = 10.0 [SI::Hz];
        }
        
        part sensors : SensorArray {
            :>> sensorCount = 8;
            :>> samplingRate = 100.0 [SI::Hz];
        }
        
        part guidance : GuidanceComputer {
            :>> processingPower = 50.0 [SI::W];
        }
        
        part propulsion : PropulsionSystem {
            :>> maxThrust = 1000.0 [SI::N];
            :>> efficiency = 0.85;
        }
        
        part stabilization : StabilizationSystem {
            :>> responseTime = 0.1 [SI::s];
        }
        
        part power : PowerManagement {
            :>> batteryCapacity = 360000.0 [SI::J];
            :>> currentCharge = 360000.0 [SI::J];
        }
        
        part comms : CommunicationModule {
            :>> bandwidth = 1000000.0 [SI::Hz];
            :>> range = 50000.0 [SI::m];
        }
        
        connection navToGuidance connect navigation.navOut to guidance.navIn;
        connection sensorToGuidance connect sensors.sensorOut to guidance.sensorIn;
        connection guidanceToPropulsion connect guidance.controlOut to propulsion.controlIn;
        connection guidanceToStabilization connect guidance.controlOut to stabilization.controlIn;
        connection powerToPropulsion connect power.powerOut to propulsion.powerIn;
        
        perform action mission[*] ordered references VaimosOperation;
        
        part navigation {
            perform mission.mainOperationLoop.acquire.computeNavigation;
        }
        
        part sensors {
            perform mission.mainOperationLoop.acquire.acquireSensorData;
        }
        
        part guidance {
            perform mission.mainOperationLoop.computeTraj.computeGuidance;
        }
        
        part propulsion {
            perform mission.mainOperationLoop.execute.generateThrust;
        }
        
        part stabilization {
            perform mission.mainOperationLoop.execute.stabilize;
        }
        
        part power {
            perform mission.mainOperationLoop.monitor.distributePower;
        }
        
        part comms {
            perform mission.mainOperationLoop.finalizeMission.transmitFinalData;
        }
    }
    
    requirement def VaimosRequirements {
        doc /* System-level requirements for Vaimos autonomous vehicle */
        
        requirement <'VR-001'> autonomousNavigation {
            doc /* The Vaimos system shall autonomously navigate to designated waypoints 
                   with a position accuracy of 5 meters or better. */
            subject vaimosSystem : Vaimos;
            require constraint {
                vaimosSystem.navigationAccuracy <= 5.0 [SI::m]
            }
        }
        
        requirement <'VR-002'> missionDuration {
            doc /* The Vaimos system shall operate continuously for at least 24 hours 
                   on a single battery charge. */
            subject vaimosSystem : Vaimos;
            require constraint {
                vaimosSystem.maxOperatingTime >= 86400.0 [SI::s]
            }
        }
        
        requirement <'VR-003'> sensorDataAcquisition {
            doc /* The Vaimos system shall acquire environmental sensor data at a minimum 
                   rate of 100 Hz throughout the mission. */
            subject vaimosSystem : Vaimos;
            require constraint {
                vaimosSystem.sensors.samplingRate >= 100.0 [SI::Hz]
            }
        }
        
        requirement <'VR-004'> propulsionCapability {
            doc /* The Vaimos system shall provide sufficient thrust to maintain trajectory 
                   control in nominal operating conditions. */
            subject vaimosSystem : Vaimos;
            require constraint {
                vaimosSystem.propulsion.maxThrust >= 1000.0 [SI::N]
            }
        }
        
        requirement <'VR-005'> communicationRange {
            doc /* The Vaimos system shall maintain communication capability over a range 
                   of at least 50 kilometers. */
            subject vaimosSystem : Vaimos;
            require constraint {
                vaimosSystem.comms.range >= 50000.0 [SI::m]
            }
        }
    }
    
    part vaimosInstance : Vaimos {
        :>> systemId = "VAIMOS-001";
        :>> missionProfile = "Environmental Monitoring and Navigation";
    }
    
    requirement vaimosSystemRequirements : VaimosRequirements {
        subject vaimosInstance;
    }
}
