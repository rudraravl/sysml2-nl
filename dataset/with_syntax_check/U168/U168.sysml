package BirthingChairSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PositionCommand;
    attribute def EmergencyStop;
    attribute def BirthStage;
    
    attribute def BackrestAngle :> Real {
        doc /* Backrest inclination angle from vertical in degrees */
    }
    
    attribute def SeatTiltAngle :> Real {
        doc /* Seat tilt angle from horizontal in degrees */
    }
    
    attribute def LegSupportAngle :> Real {
        doc /* Leg support angle from horizontal in degrees */
    }
    
    attribute def SupportPressure :> Real {
        doc /* Pressure distribution across support surfaces in kPa */
    }
    
    item def PositionProfile {
        attribute backrestAngle : BackrestAngle;
        attribute seatTiltAngle : SeatTiltAngle;
        attribute legSupportAngle : LegSupportAngle;
        attribute legSeparation : LengthValue;
        attribute armrestHeight : LengthValue;
    }
    
    port def ControlPort {
        in positionCmd : PositionCommand;
        in emergencyStop : EmergencyStop;
        out currentPosition : PositionProfile;
        out systemStatus : String;
    }
    
    port def LoadPort {
        in appliedLoad : ForceValue;
        out supportForce : ForceValue;
        out pressureDistribution : SupportPressure;
    }
    
    port def ActuatorPort {
        in targetPosition : Real;
        out currentPosition : Real;
        out motorTorque : TorqueValue;
    }
    
    part def BackrestModule {
        attribute currentAngle : BackrestAngle;
        attribute minAngle : BackrestAngle = 15.0;
        attribute maxAngle : BackrestAngle = 90.0;
        
        port loadInterface : LoadPort;
        port actuatorInterface : ActuatorPort;
        
        part motorActuator {
            attribute maxTorque : TorqueValue;
            attribute speed : AngularVelocityValue;
        }
        
        part paddedSupport {
            attribute thickness : LengthValue;
            attribute density : Real;
        }
        
        part lockingMechanism {
            attribute engaged : Boolean;
            attribute holdingForce : ForceValue;
        }
    }
    
    part def SeatModule {
        attribute currentTiltAngle : SeatTiltAngle;
        attribute minTiltAngle : SeatTiltAngle = -10.0;
        attribute maxTiltAngle : SeatTiltAngle = 20.0;
        attribute birthingOpeningDiameter : LengthValue;
        
        port loadInterface : LoadPort;
        port actuatorInterface : ActuatorPort;
        
        part tiltActuator {
            attribute maxTorque : TorqueValue;
        }
        
        part birthingOpening {
            attribute diameter : LengthValue;
            attribute edgePadding : LengthValue;
        }
        
        part supportCushion {
            attribute material : String = "medical-grade foam";
            attribute firmness : Real;
        }
    }
    
    part def LegSupportModule {
        attribute currentAngle : LegSupportAngle;
        attribute currentSeparation : LengthValue;
        attribute minAngle : LegSupportAngle = 0.0;
        attribute maxAngle : LegSupportAngle = 90.0;
        attribute minSeparation : LengthValue;
        attribute maxSeparation : LengthValue;
        
        port leftLoadPort : LoadPort;
        port rightLoadPort : LoadPort;
        port leftActuatorPort : ActuatorPort;
        port rightActuatorPort : ActuatorPort;
        
        part leftLegSupport {
            attribute angle : LegSupportAngle;
            part actuator {
                attribute maxTorque : TorqueValue;
            }
            part stirrup {
                attribute adjustableHeight : LengthValue;
            }
        }
        
        part rightLegSupport {
            attribute angle : LegSupportAngle;
            part actuator {
                attribute maxTorque : TorqueValue;
            }
            part stirrup {
                attribute adjustableHeight : LengthValue;
            }
        }
        
        part separationMechanism {
            attribute currentWidth : LengthValue;
        }
    }
    
    part def ArmrestModule {
        attribute currentHeight : LengthValue;
        attribute minHeight : LengthValue;
        attribute maxHeight : LengthValue;
        
        part leftArmrest {
            attribute height : LengthValue;
            attribute gripDiameter : LengthValue;
            part heightAdjuster {
                attribute positions : Integer = 10;
            }
        }
        
        part rightArmrest {
            attribute height : LengthValue;
            attribute gripDiameter : LengthValue;
            part heightAdjuster {
                attribute positions : Integer = 10;
            }
        }
    }
    
    part def StructuralFrame {
        attribute baseDimensions : LengthValue;
        attribute maxLoadCapacity : ForceValue;
        attribute material : String = "reinforced steel";
        
        part baseFrame {
            attribute width : LengthValue;
            attribute length : LengthValue;
        }
        
        part stabilizers {
            attribute numberOfPoints : Integer = 4;
            attribute footDiameter : LengthValue;
        }
        
        part heightAdjustment {
            attribute minHeight : LengthValue;
            attribute maxHeight : LengthValue;
        }
    }
    
    part def ControlUnit {
        port controlInterface : ControlPort;
        
        attribute currentProfile : PositionProfile;
        attribute targetProfile : PositionProfile;
        attribute operationalMode : String;
        
        part microcontroller {
            attribute processingSpeed : FrequencyValue;
            attribute memoryCapacity : Real;
        }
        
        part positionSensors {
            attribute accuracy : LengthValue;
            attribute sampleRate : FrequencyValue;
        }
        
        part loadSensors {
            attribute maxLoad : ForceValue;
            attribute resolution : ForceValue;
        }
        
        part safetyController {
            attribute emergencyStopActive : Boolean;
            attribute overloadDetection : Boolean;
        }
    }
    
    action def AdjustBackrest {
        in targetAngle : BackrestAngle;
        in currentAngle : BackrestAngle;
        in maxTorque : TorqueValue;
        out achievedAngle : BackrestAngle;
        out appliedTorque : TorqueValue;
    }
    
    action def AdjustSeatTilt {
        in targetTilt : SeatTiltAngle;
        in currentTilt : SeatTiltAngle;
        out achievedTilt : SeatTiltAngle;
    }
    
    action def AdjustLegSupports {
        in targetAngle : LegSupportAngle;
        in targetSeparation : LengthValue;
        in currentAngle : LegSupportAngle;
        in currentSeparation : LengthValue;
        out achievedAngle : LegSupportAngle;
        out achievedSeparation : LengthValue;
    }
    
    action def AdjustArmrests {
        in targetHeight : LengthValue;
        in currentHeight : LengthValue;
        out achievedHeight : LengthValue;
    }
    
    action def MonitorLoadDistribution {
        in totalLoad : ForceValue;
        in backrestLoad : ForceValue;
        in seatLoad : ForceValue;
        in legLoad : ForceValue;
        out pressureMap : SupportPressure;
        out safetyStatus : Boolean;
    }
    
    action def ProvideGravityAssistedSupport {
        in desiredProfile : PositionProfile;
        in currentStage : BirthStage;
        out achievedProfile : PositionProfile;
        out supportQuality : Real;
        
        first start;
        then merge evaluatePosition;
        
        action evaluatePosition {
            action monitorLoadAction : MonitorLoadDistribution {
                in totalLoad;
                in backrestLoad;
                in seatLoad;
                in legLoad;
                out pressureMap;
                out safetyStatus;
            }
        }
        
        then decide;
            if evaluatePosition.monitorLoadAction.safetyStatus == true then adjustToTarget;
            if evaluatePosition.monitorLoadAction.safetyStatus == false then emergencyHalt;
        
        action adjustToTarget {
            action adjustBack : AdjustBackrest {
                in targetAngle = desiredProfile.backrestAngle;
                in currentAngle;
                in maxTorque;
                out achievedAngle;
                out appliedTorque;
            }
            
            flow adjustBack.achievedAngle to adjustSeat.currentTilt;
            
            action adjustSeat : AdjustSeatTilt {
                in targetTilt = desiredProfile.seatTiltAngle;
                in currentTilt;
                out achievedTilt;
            }
            
            flow adjustSeat.achievedTilt to adjustLegs.currentAngle;
            
            action adjustLegs : AdjustLegSupports {
                in targetAngle = desiredProfile.legSupportAngle;
                in targetSeparation = desiredProfile.legSeparation;
                in currentAngle;
                in currentSeparation;
                out achievedAngle;
                out achievedSeparation;
            }
            
            flow adjustLegs.achievedAngle to adjustArms.currentHeight;
            
            action adjustArms : AdjustArmrests {
                in targetHeight = desiredProfile.armrestHeight;
                in currentHeight;
                out achievedHeight;
            }
        }
        
        then evaluatePosition;
        
        action emergencyHalt {
            out haltStatus : String;
        }
        
        then done;
    }
    
    state def ChairOperationalStates {
        entry; then standby;
        
        state standby {
            entry assign currentMode := "Standby";
        }
        
        state positioning {
            entry assign currentMode := "Adjusting Position";
            do action adjust : ProvideGravityAssistedSupport;
        }
        
        state activeSupport {
            entry assign currentMode := "Active Support";
            do action maintain {
                in profile : PositionProfile;
                out stability : Real;
            }
        }
        
        state emergency {
            entry assign currentMode := "Emergency Stop";
            do action lockAll {
                out lockStatus : Boolean;
            }
        }
        
        transition first standby to positioning
            accept positionRequest : PositionProfile;
        
        transition second positioning to activeSupport
            accept completionSignal;
        
        transition third activeSupport to positioning
            accept repositionRequest : PositionProfile;
        
        transition fourth activeSupport to emergency
            accept emergencySignal : EmergencyStop;
        
        transition fifth emergency to standby
            accept resetCommand;
        
        attribute currentMode : String;
    }
    
    part def BirthingChair;
    
    part birthingChair : BirthingChair {
        doc /* 
            Birthing chair system designed to provide adjustable, gravity-assisted 
            positional support during labor and delivery. The system enables various 
            upright and semi-upright birthing positions that utilize gravitational 
            forces to facilitate the birthing process while maintaining maternal 
            comfort, safety, and clinical access.
        */
        
        attribute totalMass : MassValue;
        attribute maxOccupantLoad : ForceValue;
        attribute overallHeight : LengthValue;
        attribute footprint : AreaValue;
        
        port mainControl : ControlPort;
        port backrestLoad : LoadPort;
        port seatLoad : LoadPort;
        
        part backrest : BackrestModule {
            attribute currentAngle = 60.0;
        }
        
        part seat : SeatModule {
            attribute currentTiltAngle = 5.0;
        }
        
        part legSupports : LegSupportModule {
            attribute currentAngle = 45.0;
        }
        
        part armrests : ArmrestModule;
        
        part frame : StructuralFrame;
        
        part controlUnit : ControlUnit {
            attribute operationalMode = "Standby";
        }
        
        connection backrestControl connect 
            controlUnit.controlInterface to backrest.actuatorInterface;
        
        connection seatControl connect 
            controlUnit.controlInterface to seat.actuatorInterface;
        
        connection legControl connect 
            controlUnit.controlInterface to legSupports.leftActuatorPort;
        
        connection backrestLoadPath connect 
            backrest.loadInterface to frame.baseFrame;
        
        connection seatLoadPath connect 
            seat.loadInterface to frame.baseFrame;
        
        perform action provideBirthingSupport : ProvideGravityAssistedSupport {
            in desiredProfile;
            in currentStage;
            out achievedProfile;
            out supportQuality;
        }
        
        exhibit state operationalState : ChairOperationalStates;
    }
    
    requirement def StructuralSafetyRequirement {
        doc /* Structural integrity and load-bearing safety requirements */
        
        require constraint maxLoadCapacity {
            doc /* Chair shall support maximum occupant load with safety factor */
        }
        
        require constraint stabilityRequirement {
            doc /* Chair shall maintain stability during all position adjustments */
        }
        
        require constraint emergencyLocking {
            doc /* All actuators shall lock immediately upon emergency stop */
        }
    }
    
    requirement def PositionalAdjustabilityRequirement {
        doc /* Range and precision of position adjustments */
        
        require constraint backrestRange {
            doc /* Backrest shall adjust from 15 to 90 degrees from vertical */
        }
        
        require constraint seatTiltRange {
            doc /* Seat tilt shall adjust from -10 to +20 degrees from horizontal */
        }
        
        require constraint legSupportRange {
            doc /* Leg supports shall adjust from 0 to 90 degrees */
        }
        
        require constraint legSeparationRange {
            doc /* Leg separation shall adjust from 400 to 800 mm */
        }
    }
    
    requirement def ComfortAndAccessRequirement {
        doc /* Maternal comfort and clinical access requirements */
        
        require constraint pressureDistribution {
            doc /* Support surfaces shall distribute pressure to prevent discomfort */
        }
        
        require constraint birthingOpening {
            doc /* Seat opening shall provide adequate access for delivery */
        }
        
        require constraint cushionQuality {
            doc /* All contact surfaces shall use medical-grade padding */
        }
    }
    
    requirement def OperationalRequirement {
        doc /* System operational and control requirements */
        
        require constraint positioningAccuracy {
            doc /* Position adjustments shall achieve target within 2 degrees */
        }
        
        require constraint responseTime {
            doc /* System shall respond to position commands within 2 seconds */
        }
        
        require constraint loadMonitoring {
            doc /* System shall continuously monitor load distribution */
        }
    }
    
    requirement birthingChairSystemRequirements {
        doc /* 
            The birthing chair system shall provide safe, adjustable, gravity-assisted 
            positional support during labor and delivery, enabling upright and 
            semi-upright birthing positions while ensuring maternal comfort, 
            structural safety, and clinical access.
        */
        
        subject birthingChair;
        
        require structuralSafety : StructuralSafetyRequirement;
        require positionalAdjustability : PositionalAdjustabilityRequirement;
        require comfortAndAccess : ComfortAndAccessRequirement;
        require operational : OperationalRequirement;
        
        satisfy by birthingChair.provideBirthingSupport;
    }
}
