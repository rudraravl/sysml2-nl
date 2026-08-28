package 'Blind Spot Monitoring System' {
    private import ScalarValues::*;
    
    attribute def Distance :> Real { unit 'm'; }
    attribute def Speed :> Real { unit 'km/h'; }
    attribute def Angle :> Real { unit 'deg'; }
    
    enum def TurnSignalStatus { None; Left; Right; }
    enum def WarningLevel { Off; Standard; Escalated; }
    
    attribute def SpeedUpdate;
    
    item def BlindSpotData {
        attribute distance : Distance;
        attribute relativeSpeed : Speed;
        attribute angle : Angle;
    }
    
    part def RadarSensor {
        port dataPort {
            out data : BlindSpotData;
        }
        action scan {
            out data : BlindSpotData;
        }
    }
    
    part def VisualIndicator {
        port warningPort {
            in level : WarningLevel;
        }
        action display {
            in level : WarningLevel;
        }
    }
    
    part def ControlModule {
        port leftRadarPort {
            in data : BlindSpotData;
        }
        port rightRadarPort {
            in data : BlindSpotData;
        }
        port vehicleInfoPort {
            in speed : Speed;
            in signal : TurnSignalStatus;
        }
        port leftWarningPort {
            out level : WarningLevel;
        }
        port rightWarningPort {
            out level : WarningLevel;
        }
        attribute minSpeed : Speed = 10 ['km/h'];
        
        state controlBehavior {
            in vehicleSpeed : Speed;
            in turnSignal : TurnSignalStatus;
            in leftData : BlindSpotData;
            in rightData : BlindSpotData;
            out leftWarning : WarningLevel;
            out rightWarning : WarningLevel;
            
            entry; then inactive;
            
            state inactive;
            accept SpeedUpdate if vehicleSpeed > 10 ['km/h'] then active;
            
            state active {
                do action evaluateWarnings {
                    if leftData.distance < 50 ['m'] {
                        if turnSignal == TurnSignalStatus::Left {
                            leftWarning = WarningLevel::Escalated;
                        } else {
                            leftWarning = WarningLevel::Standard;
                        }
                    } else {
                        leftWarning = WarningLevel::Off;
                    }
                    if rightData.distance < 50 ['m'] {
                        if turnSignal == TurnSignalStatus::Right {
                            rightWarning = WarningLevel::Escalated;
                        } else {
                            rightWarning = WarningLevel::Standard;
                        }
                    } else {
                        rightWarning = WarningLevel::Off;
                    }
                }
            }
            accept SpeedUpdate if vehicleSpeed <= 10 ['km/h'] then inactive;
        }
    }
    
    part def Vehicle {
        attribute currentSpeed : Speed;
        attribute turnSignal : TurnSignalStatus;
        port infoPort {
            out speed : Speed;
            out signal : TurnSignalStatus;
        }
    }
    
    part vehicle : Vehicle {
        part leftRadar : RadarSensor;
        part rightRadar : RadarSensor;
        part controlModule : ControlModule;
        part leftIndicator : VisualIndicator;
        part rightIndicator : VisualIndicator;
        
        connect leftRadar.dataPort to controlModule.leftRadarPort;
        connect rightRadar.dataPort to controlModule.rightRadarPort;
        connect infoPort to controlModule.vehicleInfoPort;
        connect controlModule.leftWarningPort to leftIndicator.warningPort;
        connect controlModule.rightWarningPort to rightIndicator.warningPort;
    }
    
    requirement def MinimumSpeedOperation {
        doc /* The system shall operate only when the vehicle speed is above 10 km/h. Below this threshold, the system shall remain inactive. */
    }
    requirement def ContinuousScanning {
        doc /* The left and right radar sensors shall continuously scan their respective blind spot zones, measuring distance, relative speed, and angle of detected vehicles. */
    }
    requirement def StandardWarning {
        doc /* When a vehicle is detected in a blind spot and the corresponding turn signal is not active, the system shall illuminate a standard visual warning in the corresponding side mirror indicator. */
    }
    requirement def EscalatedWarning {
        doc /* When a vehicle is detected in a blind spot and the corresponding turn signal is active, the system shall escalate the visual warning by flashing or increasing brightness of the side mirror indicator. */
    }
    requirement def ResponseTime {
        doc /* The system shall update warnings within milliseconds of a detection change to provide timely feedback to the driver. */
    }
    
    requirement bsmRequirements {
        subject vehicle;
        requirement minSpeedReq : MinimumSpeedOperation;
        requirement scanningReq : ContinuousScanning;
        requirement standardWarnReq : StandardWarning;
        requirement escalatedWarnReq : EscalatedWarning;
        requirement responseTimeReq : ResponseTime;
    }
}
