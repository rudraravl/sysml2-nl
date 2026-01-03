package DockingSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AlignmentData {
        attribute lateralOffset : LengthValue;
        attribute angularOffset : Real;
        attribute relativeVelocity : SpeedValue;
        attribute range : LengthValue;
    }
    
    attribute def DockingStatus {
        attribute isAligned : Boolean;
        attribute isCaptured : Boolean;
        attribute isLatched : Boolean;
        attribute sealPressure : PressureValue;
        attribute structuralLoad : ForceValue;
    }
    
    attribute def CaptureCommand;
    attribute def ReleaseCommand;
    attribute def AlignmentCommand;
    attribute def LatchCommand;
    attribute def SealCommand;
    
    item def DockingRing {
        attribute ringDiameter : LengthValue;
        attribute captureRange : LengthValue;
        attribute alignmentTolerance : LengthValue;
    }
    
    item def CaptureLatches {
        attribute latchCount : Integer;
        attribute latchForce : ForceValue;
        attribute engagementTime : TimeValue;
    }
    
    item def AlignmentSensors {
        attribute sensorType : String;
        attribute measurementAccuracy : LengthValue;
        attribute updateRate : FrequencyValue;
    }
    
    item def PressureSeal {
        attribute sealMaterial : String;
        attribute maxPressureDifferential : PressureValue;
        attribute sealDiameter : LengthValue;
    }
    
    item def StructuralInterface {
        attribute boltCount : Integer;
        attribute boltTorque : TorqueValue;
        attribute loadCapacity : ForceValue;
    }
    
    port def MechanicalPort {
        in contactForce : ForceValue;
        out alignmentFeedback : AlignmentData;
    }
    
    port def SensorPort {
        out alignmentMeasurement : AlignmentData;
    }
    
    port def ControlPort {
        in command : CaptureCommand;
        out status : DockingStatus;
    }
    
    action def MeasureAlignment {
        out alignmentData : AlignmentData;
    }
    
    action def EvaluateAlignment {
        in alignmentData : AlignmentData;
        in tolerances : AlignmentData;
        out withinTolerance : Boolean;
    }
    
    action def AdjustApproach {
        in currentAlignment : AlignmentData;
        out correctionApplied : Boolean;
    }
    
    action def InitiateCapture {
        in captureCmd : CaptureCommand;
        out captureInitiated : Boolean;
    }
    
    action def EngageLatches {
        in latchCmd : LatchCommand;
        out latchesEngaged : Boolean;
    }
    
    action def ActivateSeal {
        in sealCmd : SealCommand;
        out sealActivated : Boolean;
        out sealPressure : PressureValue;
    }
    
    action def VerifyConnection {
        in currentStatus : DockingStatus;
        out connectionVerified : Boolean;
    }
    
    action def ReleaseConnection {
        in releaseCmd : ReleaseCommand;
        out released : Boolean;
    }
    
    action def PerformDocking {
        in captureCommand : CaptureCommand;
        in alignmentTolerances : AlignmentData;
        out finalStatus : DockingStatus;
        
        private attribute currentAlignment : AlignmentData;
        private attribute captureComplete : Boolean := false;
        
        first start;
        then merge monitorApproach;
        
        then action measureAlignment : MeasureAlignment {
            out alignmentData : AlignmentData;
        }
        
        then assign currentAlignment := measureAlignment.alignmentData;
        
        then action evaluateAlignment : EvaluateAlignment {
            in alignmentData = currentAlignment;
            in tolerances = alignmentTolerances;
            out withinTolerance : Boolean;
        }
        
        then decide;
            if evaluateAlignment.withinTolerance == false then correctApproach;
            if evaluateAlignment.withinTolerance == true then proceedToCapture;
        
        action correctApproach : AdjustApproach {
            in currentAlignment = currentAlignment;
            out correctionApplied : Boolean;
        }
        then monitorApproach;
        
        action proceedToCapture {
            first action initiateCapture : InitiateCapture {
                in captureCmd = captureCommand;
                out captureInitiated : Boolean;
            }
            
            then action engageLatches : EngageLatches {
                in latchCmd : LatchCommand;
                out latchesEngaged : Boolean;
            }
            
            then action activateSeal : ActivateSeal {
                in sealCmd : SealCommand;
                out sealActivated : Boolean;
                out sealPressure : PressureValue;
            }
            
            then action verifyConnection : VerifyConnection {
                in currentStatus : DockingStatus;
                out connectionVerified : Boolean;
            }
        }
        
        then decide;
            if proceedToCapture.verifyConnection.connectionVerified == true then completeDocking;
            if proceedToCapture.verifyConnection.connectionVerified == false then handleAbort;
        
        action completeDocking;
        then assign finalStatus := DockingStatus {
            isAligned = true;
            isCaptured = true;
            isLatched = true;
            sealPressure = 101325.0[Pa];
            structuralLoad = 5000.0[N];
        };
        then done;
        
        action handleAbort {
            first action releaseConnection : ReleaseConnection {
                in releaseCmd : ReleaseCommand;
                out released : Boolean;
            }
            
            then action setAbortStatus;
        }
        then assign finalStatus := DockingStatus {
            isAligned = false;
            isCaptured = false;
            isLatched = false;
            sealPressure = 0.0[Pa];
            structuralLoad = 0.0[N];
        };
        then done;
    }
    
    part def ActiveDockingMechanism {
        attribute maxCaptureForce : ForceValue;
        attribute minOperatingTemperature : TemperatureValue;
        attribute maxOperatingTemperature : TemperatureValue;
        
        port mechanicalInterface : MechanicalPort;
        port sensorInterface : SensorPort;
        port controlInterface : ControlPort;
        
        part dockingRing : DockingRing {
            attribute :>> ringDiameter = 1.2[m];
            attribute :>> captureRange = 0.15[m];
            attribute :>> alignmentTolerance = 0.05[m];
        }
        
        part latches : CaptureLatches {
            attribute :>> latchCount = 16;
            attribute :>> latchForce = 1000.0[N];
            attribute :>> engagementTime = 2.0[s];
        }
        
        part sensors : AlignmentSensors {
            attribute :>> sensorType = "Laser Rangefinder";
            attribute :>> measurementAccuracy = 0.001[m];
            attribute :>> updateRate = 10.0[Hz];
        }
        
        part seal : PressureSeal {
            attribute :>> sealMaterial = "Silicone Elastomer";
            attribute :>> maxPressureDifferential = 150000.0[Pa];
            attribute :>> sealDiameter = 1.0[m];
        }
        
        part structuralInterface : StructuralInterface {
            attribute :>> boltCount = 24;
            attribute :>> boltTorque = 200.0[N*m];
            attribute :>> loadCapacity = 50000.0[N];
        }
        
        perform action dockingOperation : PerformDocking;
    }
    
    part def PassiveDockingAdapter {
        attribute receptionRange : LengthValue;
        
        port mechanicalInterface : MechanicalPort;
        
        part receptacleRing : DockingRing {
            attribute :>> ringDiameter = 1.2[m];
            attribute :>> captureRange = 0.15[m];
            attribute :>> alignmentTolerance = 0.05[m];
        }
        
        part guidePetals {
            attribute petalCount : Integer = 4;
            attribute petalLength : LengthValue = 0.3[m];
        }
        
        part passiveSeal : PressureSeal {
            attribute :>> sealMaterial = "Silicone Elastomer";
            attribute :>> maxPressureDifferential = 150000.0[Pa];
            attribute :>> sealDiameter = 1.0[m];
        }
    }
    
    part dockingSystem {
        doc /* A docking system that autonomously captures, aligns, and secures two 
                spacecraft modules by sensing relative position, engaging mechanical latches, 
                and activating pressure seals to establish a rigid, pressurized connection. */
        
        attribute systemMass : MassValue = 200.0[kg];
        attribute powerRequirement : PowerValue = 300.0[W];
        attribute designLifetime : TimeValue = 15.0[yr];
        
        part activeMechanism : ActiveDockingMechanism {
            attribute :>> maxCaptureForce = 2000.0[N];
            attribute :>> minOperatingTemperature = 193.15[K];
            attribute :>> maxOperatingTemperature = 373.15[K];
        }
        
        part passiveMechanism : PassiveDockingAdapter {
            attribute :>> receptionRange = 0.2[m];
        }
        
        connect activeMechanism.mechanicalInterface to passiveMechanism.mechanicalInterface;
    }
    
    requirement <'DOCK-REQ-001'> primaryDockingFunction {
        doc /* The docking system shall autonomously perform capture, alignment, latching, 
                and sealing operations to establish a secure mechanical and pressurized 
                connection between two spacecraft modules. */
        
        subject dockingSystem;
        
        require constraint alignmentAccuracyRequirement {
            doc /* Lateral alignment error shall not exceed 50mm and angular misalignment 
                    shall not exceed 2 degrees at the moment of capture. */
            dockingSystem.activeMechanism.dockingRing.alignmentTolerance <= 0.05[m]
        }
        
        require constraint captureForceRequirement {
            doc /* Each capture latch shall provide minimum holding force of 1000N. */
            dockingSystem.activeMechanism.latches.latchForce >= 1000.0[N]
        }
        
        require constraint sealIntegrityRequirement {
            doc /* Pressure seal shall maintain differential pressure of at least 100 kPa 
                    without leakage. */
            dockingSystem.activeMechanism.seal.maxPressureDifferential >= 100000.0[Pa]
        }
        
        require constraint structuralLoadRequirement {
            doc /* Structural interface shall withstand combined loads of at least 50 kN. */
            dockingSystem.activeMechanism.structuralInterface.loadCapacity >= 50000.0[N]
        }
    }
    
    requirement <'DOCK-REQ-002'> safetyRequirement {
        doc /* The docking system shall abort the docking sequence and safely disengage 
                if alignment tolerances are exceeded, verification fails, or anomalies 
                are detected during any phase of the operation. */
        
        subject dockingSystem;
        
        assume constraint approachVelocityConstraint {
            doc /* Relative approach velocity shall not exceed 0.1 m/s during final 
                    capture phase to prevent damage. */
        }
        
        assume constraint environmentalConstraint {
            doc /* Docking operations shall only be attempted within the specified 
                    operating temperature range. */
        }
        
        require primaryDockingFunction;
    }
    
    requirement <'DOCK-REQ-003'> reliabilityRequirement {
        doc /* The docking system shall achieve a minimum success rate of 99.5% over 
                its design lifetime with proper maintenance. */
        
        subject dockingSystem;
        
        require constraint redundancyRequirement {
            doc /* Critical sensors and actuators shall have redundant backups. */
        }
        
        require safetyRequirement;
    }
}
