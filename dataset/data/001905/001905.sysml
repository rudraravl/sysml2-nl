package 'SPHERES Autonomous Rendezvous System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ThrusterCommand {
        attribute thrusterId : Integer;
        attribute pulseDuration : ISQ::TimeValue;
        attribute pulseIntensity : Real;
    }
    
    attribute def StateVector {
        attribute position : ISQ::LengthValue[3];
        attribute velocity : ISQ::SpeedValue[3];
        attribute attitude : Real[3];
        attribute angularRate : ISQ::AngularVelocityValue[3];
    }
    
    attribute def NavigationData {
        attribute stateVector : StateVector;
        attribute timestamp : ISQ::TimeValue;
        attribute confidence : Real;
    }
    
    item def CO2Propellant {
        attribute mass :> ISQ::mass;
        attribute pressure :> ISQ::pressure;
        attribute temperature :> ISQ::temperature;
    }
    
    item def PowerSupply {
        attribute voltage : Real;
        attribute capacity : Real;
        attribute remainingCharge : Real;
    }
    
    port def SensorDataPort {
        out rangeData : ISQ::LengthValue[*];
        out imuData : StateVector;
    }
    
    port def ControlPort {
        in targetState : StateVector;
        out thrusterCommands : ThrusterCommand[*];
    }
    
    port def PowerPort {
        out voltage : Real;
        out current : ISQ::ElectricCurrentValue;
    }
    
    port def CommunicationPort {
        in commandUplink : Real[*];
        out telemetryDownlink : Real[*];
    }
    
    part def InertialMeasurementUnit {
        attribute sampleRate : ISQ::FrequencyValue;
        out accelerometer : ISQ::AccelerationValue[3];
        out gyroscope : ISQ::AngularVelocityValue[3];
    }
    
    part def UltrasonicBeacon {
        attribute beaconId : Integer;
        attribute frequency : ISQ::FrequencyValue;
        out range : ISQ::LengthValue;
        out bearing : Real[2];
    }
    
    part def ThrusterModule {
        attribute maxThrust : ISQ::ForceValue;
        attribute minImpulseBit : ISQ::MomentumValue;
        port thrusterInput : ControlPort;
        in command : ThrusterCommand;
        out thrust : ISQ::ForceValue;
    }
    
    part def PropulsionSubsystem {
        attribute totalThrusters : Integer = 12;
        part propellantTank : CO2Propellant {
            attribute mass :> ISQ::mass = 0.12[SI::kg];
            attribute pressure :> ISQ::pressure = 3000[SI::kPa];
        }
        part thruster1 : ThrusterModule;
        part thruster2 : ThrusterModule;
        part thruster3 : ThrusterModule;
        part thruster4 : ThrusterModule;
        part thruster5 : ThrusterModule;
        part thruster6 : ThrusterModule;
        part thruster7 : ThrusterModule;
        part thruster8 : ThrusterModule;
        part thruster9 : ThrusterModule;
        part thruster10 : ThrusterModule;
        part thruster11 : ThrusterModule;
        part thruster12 : ThrusterModule;
        
        port controlInput : ControlPort;
        
        connect controlInput to thruster1.thrusterInput;
        connect controlInput to thruster2.thrusterInput;
        connect controlInput to thruster3.thrusterInput;
        connect controlInput to thruster4.thrusterInput;
        connect controlInput to thruster5.thrusterInput;
        connect controlInput to thruster6.thrusterInput;
    }
    
    part def SensorSubsystem {
        part imu : InertialMeasurementUnit {
            attribute sampleRate : ISQ::FrequencyValue = 50[SI::Hz];
        }
        part beacon1 : UltrasonicBeacon {
            attribute beaconId : Integer = 1;
        }
        part beacon2 : UltrasonicBeacon {
            attribute beaconId : Integer = 2;
        }
        part beacon3 : UltrasonicBeacon {
            attribute beaconId : Integer = 3;
        }
        part beacon4 : UltrasonicBeacon {
            attribute beaconId : Integer = 4;
        }
        part beacon5 : UltrasonicBeacon {
            attribute beaconId : Integer = 5;
        }
        
        port sensorOutput : SensorDataPort;
    }
    
    part def GuidanceNavigationControlComputer {
        port sensorInput : SensorDataPort;
        port controlOutput : ControlPort;
        
        action estimateState {
            in rawSensorData : StateVector;
            in beaconRanges : ISQ::LengthValue[*];
            out navigationSolution : NavigationData;
        }
        
        action computeGuidance {
            in currentState : NavigationData;
            in targetState : StateVector;
            out desiredAcceleration : ISQ::AccelerationValue[3];
            out desiredTorque : ISQ::TorqueValue[3];
        }
        
        action allocateThrusters {
            in desiredForce : ISQ::ForceValue[3];
            in desiredTorque : ISQ::TorqueValue[3];
            out thrusterCommands : ThrusterCommand[12];
        }
    }
    
    part def CommunicationSubsystem {
        attribute dataRate : Real = 9600;
        attribute frequency : ISQ::FrequencyValue = 2.4[SI::GHz];
        port commPort : CommunicationPort;
    }
    
    part def PowerSubsystem {
        part battery : PowerSupply {
            attribute voltage : Real = 16.8;
            attribute capacity : Real = 7.2;
        }
        port powerOutput : PowerPort;
    }
    
    part def SPHERES {
        doc /* Synchronized Position Hold Engage Reorient Experimental Satellites - 
               A free-flying testbed for autonomous rendezvous, docking, and formation flight */
        
        attribute satelliteMass :> ISQ::mass = 4.3[SI::kg];
        attribute diameter :> ISQ::length = 0.22[SI::m];
        attribute operatingEnvironment : String = "ISS Microgravity";
        
        part power : PowerSubsystem;
        part sensors : SensorSubsystem;
        part gncComputer : GuidanceNavigationControlComputer;
        part propulsion : PropulsionSubsystem;
        part communications : CommunicationSubsystem;
        
        connect power.powerOutput to sensors;
        connect power.powerOutput to gncComputer;
        connect power.powerOutput to propulsion;
        connect power.powerOutput to communications;
        
        connect sensors.sensorOutput to gncComputer.sensorInput;
        connect gncComputer.controlOutput to propulsion.controlInput;
    }
    
    action def MeasureCurrentState {
        out currentState : StateVector;
        out rangeData : ISQ::LengthValue[*];
    }
    
    action def EstimateNavigation {
        in currentState : StateVector;
        in rangeData : ISQ::LengthValue[*];
        out navSolution : NavigationData;
    }
    
    action def ComputeControlLaw {
        in currentNav : NavigationData;
        in targetState : StateVector;
        out controlForce : ISQ::ForceValue[3];
        out controlTorque : ISQ::TorqueValue[3];
    }
    
    action def AllocateThrusters {
        in controlForce : ISQ::ForceValue[3];
        in controlTorque : ISQ::TorqueValue[3];
        out thrusterCmds : ThrusterCommand[12];
    }
    
    action def ExecuteThrusting {
        in thrusterCmds : ThrusterCommand[12];
        out appliedForce : ISQ::ForceValue[3];
        out appliedTorque : ISQ::TorqueValue[3];
    }
    
    action def AutonomousRendezvousManeuver {
        doc /* Primary mission function: Autonomously navigate to and dock with a target 
               satellite using onboard sensors and GN&C algorithms */
        
        in targetPosition : ISQ::LengthValue[3];
        in targetVelocity : ISQ::SpeedValue[3];
        in approachDistance : ISQ::LengthValue = 0.1[SI::m];
        out missionSuccess : Boolean;
        
        attribute currentDistance : ISQ::LengthValue;
        attribute targetStateVector : StateVector;
        
        first start;
        then merge navigationLoop;
        
        action measure : MeasureCurrentState {
            out currentState : StateVector;
            out rangeData : ISQ::LengthValue[*];
        }
        
        then action navigate : EstimateNavigation {
            in currentState = measure.currentState;
            in rangeData = measure.rangeData;
            out navSolution : NavigationData;
        }
        
        then action computeControl : ComputeControlLaw {
            in currentNav = navigate.navSolution;
            in targetState = targetStateVector;
            out controlForce : ISQ::ForceValue[3];
            out controlTorque : ISQ::TorqueValue[3];
        }
        
        then action allocate : AllocateThrusters {
            in controlForce = computeControl.controlForce;
            in controlTorque = computeControl.controlTorque;
            out thrusterCmds : ThrusterCommand[12];
        }
        
        then action executeThrust : ExecuteThrusting {
            in thrusterCmds = allocate.thrusterCmds;
            out appliedForce : ISQ::ForceValue[3];
            out appliedTorque : ISQ::TorqueValue[3];
        }
        
        then decide;
            if currentDistance > approachDistance then navigationLoop;
            if currentDistance <= approachDistance then finalApproach;
        
        action finalApproach {
            assign missionSuccess := true;
        }
        then done;
    }
    
    part spheresSatellite : SPHERES {
        perform action rendezvousMission[*] : AutonomousRendezvousManeuver;
    }
    
    requirement def MissionRequirement {
        doc /* Top-level requirements for SPHERES autonomous operations */
        subject satellite : SPHERES;
    }
    
    requirement <'SPHERES-REQ-001'> autonomousRendezvousCapability : MissionRequirement {
        doc /* The SPHERES satellite shall autonomously perform rendezvous and proximity 
               operations with a target satellite using onboard sensors and control algorithms */
        require positionControlAccuracy;
        require attitudeControlAccuracy;
        require propellantEfficiency;
    }
    
    requirement <'SPHERES-REQ-002'> positionControlAccuracy {
        doc /* Position control accuracy shall be within 2 cm in all axes */
        attribute maxPositionError : ISQ::LengthValue = 0.02[SI::m];
    }
    
    requirement <'SPHERES-REQ-003'> attitudeControlAccuracy {
        doc /* Attitude control accuracy shall be within 2 degrees in all axes */
        attribute maxAttitudeError : Real = 2.0;
    }
    
    requirement <'SPHERES-REQ-004'> propellantEfficiency {
        doc /* The system shall complete a 10-minute rendezvous maneuver using no more 
               than 20 grams of CO2 propellant */
        attribute maxPropellantMass : ISQ::MassValue = 0.02[SI::kg];
        attribute missionDuration : ISQ::TimeValue = 600[SI::s];
    }
    
    requirement <'SPHERES-REQ-005'> sixDOFControl {
        doc /* The propulsion system shall provide full 6-DOF force and torque authority */
        attribute degreesOfFreedom : Integer = 6;
    }
    
    requirement <'SPHERES-REQ-006'> safetyProximityLimit {
        doc /* The system shall maintain a minimum safe distance of 5 cm during final approach */
        attribute minSafeDistance : ISQ::LengthValue = 0.05[SI::m];
    }
}
