package 'Blind Spot Monitor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Distance :> ISQ::LengthValue;
    attribute def Speed :> ISQ::SpeedValue;
    attribute def Angle :> ISQ::PlaneAngleValue;
    attribute def TimeInterval :> ISQ::DurationValue;
    
    enum def ZoneSide {
        left;
        right;
    }
    
    enum def AlertIntensity {
        none;
        standardWarning;
        escalated;
    }
    
    enum def SystemState {
        inactive;
        active;
        fault;
    }
    
    item def VehicleDetection {
        attribute side : ZoneSide;
        attribute range : Distance;
        attribute relativeVelocity : Speed;
        attribute azimuthAngle : Angle;
        attribute timestamp : TimeInterval;
    }
    
    item def AlertCommand {
        attribute targetSide : ZoneSide;
        attribute intensity : AlertIntensity;
        attribute activate : Boolean;
    }
    
    item def VehicleState {
        attribute currentSpeed : Speed;
        attribute leftTurnSignal : Boolean;
        attribute rightTurnSignal : Boolean;
        attribute gearPosition : Integer;
    }
    
    port def RadarOutputPort {
        out detection : VehicleDetection;
    }
    
    port def AlertInputPort {
        in command : AlertCommand;
    }
    
    port def VehicleDataPort {
        in state : VehicleState;
    }
    
    port def ControlOutputPort {
        out leftAlert : AlertCommand;
        out rightAlert : AlertCommand;
    }
    
    part def RadarSensor {
        attribute monitoredSide : ZoneSide;
        attribute detectionRange : Distance;
        attribute scanAngle : Angle;
        attribute updateRate : Real;
        
        port radarOut : RadarOutputPort;
        
        action def ScanBlindSpotZone {
            out detectionData : VehicleDetection;
        }
        
        perform action continuousScan : ScanBlindSpotZone;
    }
    
    part def VisualIndicator {
        attribute indicatorSide : ZoneSide;
        attribute brightness : Real;
        
        port alertIn : AlertInputPort;
        
        state machine IndicatorStateMachine {
            initial state Off;
            state StandardWarning;
            state EscalatedWarning;
            
            transition offToStandard
                first Off
                accept command : AlertCommand
                if command.activate and command.intensity == AlertIntensity::standardWarning
                then StandardWarning;
            
            transition offToEscalated
                first Off
                accept command : AlertCommand
                if command.activate and command.intensity == AlertIntensity::escalated
                then EscalatedWarning;
            
            transition standardToEscalated
                first StandardWarning
                accept command : AlertCommand
                if command.intensity == AlertIntensity::escalated
                then EscalatedWarning;
            
            transition escalatedToStandard
                first EscalatedWarning
                accept command : AlertCommand
                if command.intensity == AlertIntensity::standardWarning
                then StandardWarning;
            
            transition toOff
                first StandardWarning
                accept command : AlertCommand
                if not command.activate
                then Off;
            
            transition escalatedToOff
                first EscalatedWarning
                accept command : AlertCommand
                if not command.activate
                then Off;
        }
        
        action def DisplayAlert {
            in alertCmd : AlertCommand;
        }
    }
    
    part def ControlModule {
        attribute activationSpeed : Speed;
        attribute warningDistance : Distance;
        attribute criticalDistance : Distance;
        attribute processingCycleTime : TimeInterval;
        
        port leftRadarIn : ~RadarOutputPort;
        port rightRadarIn : ~RadarOutputPort;
        port vehicleDataIn : VehicleDataPort;
        port controlOut : ControlOutputPort;
        
        action def EvaluateThreat {
            in detection : VehicleDetection;
            in vehicleSpeed : Speed;
            in turnSignalActive : Boolean;
            in warningThreshold : Distance;
            in criticalThreshold : Distance;
            out threatLevel : AlertIntensity;
            out shouldAlert : Boolean;
            
            first start;
            then decide;
                if detection.range > warningThreshold then noThreat;
                if detection.range <= criticalThreshold and turnSignalActive then criticalThreat;
                if detection.range <= warningThreshold then standardThreat;
            
            action noThreat {
                assign threatLevel := AlertIntensity::none;
                assign shouldAlert := false;
            }
            
            action standardThreat {
                assign threatLevel := AlertIntensity::standardWarning;
                assign shouldAlert := true;
            }
            
            action criticalThreat {
                assign threatLevel := AlertIntensity::escalated;
                assign shouldAlert := true;
            }
            
            then done;
        }
        
        action def ProcessDetections {
            in leftDetection : VehicleDetection;
            in rightDetection : VehicleDetection;
            in vehicleState : VehicleState;
            out leftAlertCmd : AlertCommand;
            out rightAlertCmd : AlertCommand;
            
            first start;
            
            then decide;
                if vehicleState.currentSpeed < activationSpeed then deactivateSystem;
                else processThreats;
            
            action deactivateSystem {
                assign leftAlertCmd := AlertCommand {
                    targetSide = ZoneSide::left;
                    intensity = AlertIntensity::none;
                    activate = false;
                }
                assign rightAlertCmd := AlertCommand {
                    targetSide = ZoneSide::right;
                    intensity = AlertIntensity::none;
                    activate = false;
                }
            }
            
            action processThreats {
                action evaluateLeft : EvaluateThreat {
                    in detection = leftDetection;
                    in vehicleSpeed = vehicleState.currentSpeed;
                    in turnSignalActive = vehicleState.leftTurnSignal;
                    in warningThreshold = warningDistance;
                    in criticalThreshold = criticalDistance;
                    out threatLevel;
                    out shouldAlert;
                }
                
                then action evaluateRight : EvaluateThreat {
                    in detection = rightDetection;
                    in vehicleSpeed = vehicleState.currentSpeed;
                    in turnSignalActive = vehicleState.rightTurnSignal;
                    in warningThreshold = warningDistance;
                    in criticalThreshold = criticalDistance;
                    out threatLevel;
                    out shouldAlert;
                }
                
                then assign leftAlertCmd := AlertCommand {
                    targetSide = ZoneSide::left;
                    intensity = evaluateLeft.threatLevel;
                    activate = evaluateLeft.shouldAlert;
                }
                
                then assign rightAlertCmd := AlertCommand {
                    targetSide = ZoneSide::right;
                    intensity = evaluateRight.threatLevel;
                    activate = evaluateRight.shouldAlert;
                }
            }
            
            then done;
        }
        
        action def MonitorBlindSpots {
            in leftRadar : VehicleDetection;
            in rightRadar : VehicleDetection;
            in vehicleData : VehicleState;
            out leftAlert : AlertCommand;
            out rightAlert : AlertCommand;
            
            first start;
            then merge continuousMonitoring;
            
            then action process : ProcessDetections {
                in leftDetection = leftRadar;
                in rightDetection = rightRadar;
                in vehicleState = vehicleData;
                out leftAlertCmd;
                out rightAlertCmd;
            }
            
            then assign leftAlert := process.leftAlertCmd;
            then assign rightAlert := process.rightAlertCmd;
            then continuousMonitoring;
        }
    }
    
    part def BlindSpotMonitoringSystem {
        doc /*
        The Blind Spot Monitoring System continuously detects vehicles in the driver's 
        blind spot zones using radar sensors and provides visual warnings through 
        side mirror indicators. The system activates above a minimum speed threshold 
        and escalates warnings when the driver signals a lane change toward a detected vehicle.
        */
        
        part leftRadar : RadarSensor {
            attribute :>> monitoredSide = ZoneSide::left;
            attribute :>> detectionRange = 6.0 [SI::m];
            attribute :>> scanAngle = 70.0 [SI::deg];
            attribute :>> updateRate = 20.0;
        }
        
        part rightRadar : RadarSensor {
            attribute :>> monitoredSide = ZoneSide::right;
            attribute :>> detectionRange = 6.0 [SI::m];
            attribute :>> scanAngle = 70.0 [SI::deg];
            attribute :>> updateRate = 20.0;
        }
        
        part controller : ControlModule {
            attribute :>> activationSpeed = 10.0 [SI::'km/h'];
            attribute :>> warningDistance = 5.0 [SI::m];
            attribute :>> criticalDistance = 2.5 [SI::m];
            attribute :>> processingCycleTime = 50.0 [SI::ms];
        }
        
        part leftIndicator : VisualIndicator {
            attribute :>> indicatorSide = ZoneSide::left;
            attribute :>> brightness = 0.8;
        }
        
        part rightIndicator : VisualIndicator {
            attribute :>> indicatorSide = ZoneSide::right;
            attribute :>> brightness = 0.8;
        }
        
        connect leftRadar.radarOut to controller.leftRadarIn;
        connect rightRadar.radarOut to controller.rightRadarIn;
        connect controller.controlOut to leftIndicator.alertIn;
        connect controller.controlOut to rightIndicator.alertIn;
        
        perform action systemOperation : controller.MonitorBlindSpots;
    }
    
    part blindSpotSystem : BlindSpotMonitoringSystem;
    
    requirement def FunctionalRequirement {
        doc /* Base requirement for system functional capabilities */
    }
    
    requirement def PerformanceRequirement {
        doc /* Base requirement for system performance characteristics */
    }
    
    requirement def SafetyRequirement {
        doc /* Base requirement for system safety features */
    }
    
    requirement <'BSM-REQ-001'> detectVehiclesInBlindSpot : FunctionalRequirement {
        doc /*
        The system shall detect vehicles in the left and right blind spot zones 
        within a range of 6 meters from the host vehicle.
        */
        subject blindSpotSystem;
    }
    
    requirement <'BSM-REQ-002'> provideVisualWarning : FunctionalRequirement {
        doc /*
        The system shall provide visual warnings through side mirror indicators 
        when a vehicle is detected in the corresponding blind spot zone.
        */
        subject blindSpotSystem;
        refine detectVehiclesInBlindSpot;
    }
    
    requirement <'BSM-REQ-003'> escalateWarningOnTurnSignal : SafetyRequirement {
        doc /*
        The system shall escalate the visual warning intensity when the driver 
        activates the turn signal toward a blind spot containing a detected vehicle.
        */
        subject blindSpotSystem;
        refine provideVisualWarning;
    }
    
    requirement <'BSM-REQ-004'> speedActivationThreshold : PerformanceRequirement {
        doc /*
        The system shall activate monitoring functions only when the host vehicle 
        speed exceeds 10 km/h and deactivate below this threshold.
        */
        subject blindSpotSystem;
    }
    
    requirement <'BSM-REQ-005'> detectionLatency : PerformanceRequirement {
        doc /*
        The system shall process radar detections and update warning indicators 
        within 50 milliseconds of receiving sensor data.
        */
        subject blindSpotSystem;
    }
    
    requirement <'BSM-REQ-006'> coverageZone : FunctionalRequirement {
        doc /*
        The system shall monitor zones extending 70 degrees laterally from the 
        rear quarter panels on both sides of the vehicle.
        */
        subject blindSpotSystem;
        refine detectVehiclesInBlindSpot;
    }
}
