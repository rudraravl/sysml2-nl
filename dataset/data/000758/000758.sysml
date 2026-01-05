package Segs4VetsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VeteranID :> String;
    attribute def SessionID :> String;
    attribute def TherapyLevel :> Integer;
    
    attribute def BalanceScore :> Real {
        doc /* Balance assessment score from 0 to 100 */
    }
    
    attribute def TiltAngle :> ISQ::PlaneAngleValue {
        attribute :>> num : Real;
        attribute :>> mRef : SI::rad;
    }
    
    attribute def MotorTorque :> ISQ::TorqueValue {
        attribute :>> num : Real;
        attribute :>> mRef : SI::'N·m';
    }
    
    attribute def BatteryCharge :> Real {
        doc /* Battery charge percentage 0-100 */
    }
    
    attribute def TherapyDuration :> ISQ::TimeValue {
        attribute :>> num : Real;
        attribute :>> mRef : SI::min;
    }
    
    attribute def VelocityLimit :> ISQ::SpeedValue {
        attribute :>> num : Real;
        attribute :>> mRef : SI::'m/s';
    }
    
    item def VeteranProfile {
        attribute veteranID : VeteranID;
        attribute mobilityLevel : TherapyLevel;
        attribute balanceCapability : BalanceScore;
        attribute sessionCount : Integer;
        attribute totalTherapyTime : TherapyDuration;
    }
    
    item def TherapySession {
        attribute sessionID : SessionID;
        attribute startTime : String;
        attribute duration : TherapyDuration;
        attribute maxSpeed : VelocityLimit;
        attribute progressScore : BalanceScore;
    }
    
    item def SafetyParameters {
        attribute maxTilt : TiltAngle;
        attribute emergencyStopEnabled : Boolean;
        attribute stabilityThreshold : BalanceScore;
    }
    
    port def VeteranInterfacePort {
        in command : String;
        out feedback : String;
        out sessionData : TherapySession;
    }
    
    port def SensorPort {
        out tiltAngle : TiltAngle;
        out velocity : VelocityLimit;
        out balanceMetric : BalanceScore;
    }
    
    port def MotorControlPort {
        in leftTorque : MotorTorque;
        in rightTorque : MotorTorque;
        out motorStatus : String;
    }
    
    port def PowerPort {
        in chargeLevel : BatteryCharge;
        out powerAvailable : Boolean;
    }
    
    port def TherapistInterfacePort {
        in therapySettings : TherapyLevel;
        out progressReport : String;
        out safetyAlert : String;
    }
    
    part def BalanceSensor {
        port sensorOutput : ~SensorPort;
        attribute currentTilt : TiltAngle;
        attribute currentBalance : BalanceScore;
        
        action measureBalance {
            out tilt : TiltAngle;
            out balance : BalanceScore;
        }
    }
    
    part def MotorController {
        port motorCommand : ~MotorControlPort;
        attribute leftMotorTorque : MotorTorque;
        attribute rightMotorTorque : MotorTorque;
        
        action applyTorque {
            in leftCmd : MotorTorque;
            in rightCmd : MotorTorque;
            out status : String;
        }
    }
    
    part def BatterySystem {
        port power : ~PowerPort;
        attribute chargeLevel : BatteryCharge;
        attribute isCharging : Boolean;
        
        action monitorPower {
            out charge : BatteryCharge;
            out available : Boolean;
        }
    }
    
    part def TherapyController {
        port veteranInterface : VeteranInterfacePort;
        port therapistInterface : TherapistInterfacePort;
        port sensorInput : SensorPort;
        port motorOutput : MotorControlPort;
        
        attribute currentSession : TherapySession;
        attribute safetyParams : SafetyParameters;
        attribute activeVeteran : VeteranProfile;
        
        action calculateStabilization {
            in tilt : TiltAngle;
            in balance : BalanceScore;
            in therapyLevel : TherapyLevel;
            out leftTorque : MotorTorque;
            out rightTorque : MotorTorque;
            out safetyStatus : String;
        }
        
        perform action controlTherapy;
    }
    
    part def DisplayPanel {
        port display : ~VeteranInterfacePort;
        attribute currentMessage : String;
        attribute sessionInfo : TherapySession;
        
        action showFeedback {
            in session : TherapySession;
            out message : String;
        }
    }
    
    part def SafetyMonitor {
        port safetyCheck : ~TherapistInterfacePort;
        attribute alertActive : Boolean;
        attribute lastCheckTime : String;
        
        action evaluateSafety {
            in tilt : TiltAngle;
            in balance : BalanceScore;
            in maxTilt : TiltAngle;
            out alert : String;
            out safe : Boolean;
        }
    }
    
    action def InitiateTherapySession {
        in veteran : VeteranProfile;
        in therapyLevel : TherapyLevel;
        out session : TherapySession;
        out initialized : Boolean;
    }
    
    action def MonitorVeteranProgress {
        in session : TherapySession;
        in sensorData : BalanceScore;
        out progressUpdate : BalanceScore;
        out continueSession : Boolean;
    }
    
    action def AdjustStabilization {
        in tilt : TiltAngle;
        in targetBalance : BalanceScore;
        in therapyLevel : TherapyLevel;
        out leftMotorCmd : MotorTorque;
        out rightMotorCmd : MotorTorque;
    }
    
    action def EndTherapySession {
        in session : TherapySession;
        in finalScore : BalanceScore;
        out sessionComplete : Boolean;
        out veteranProfile : VeteranProfile;
    }
    
    action def ManageSegs4VetsOperation {
        doc /* 
            Primary function: Provide a self-balancing mobility therapy platform 
            for veterans with mobility impairments. The system delivers controlled 
            balance training through progressive therapy sessions, continuously 
            monitoring veteran progress and adjusting stabilization support to 
            improve mobility, balance, and independence.
        */
        
        first start;
        then merge sessionLoop;
        
        action receiveVeteranRegistration {
            out veteranData : VeteranProfile;
        }
        then assessMobilityLevel;
        
        action assessMobilityLevel {
            in veteran = receiveVeteranRegistration.veteranData;
            out therapyLevel : TherapyLevel;
            out safetySettings : SafetyParameters;
        }
        then initializeSession;
        
        action initializeSession : InitiateTherapySession {
            in veteran = receiveVeteranRegistration.veteranData;
            in therapyLevel = assessMobilityLevel.therapyLevel;
            out session;
            out initialized;
        }
        then decide sessionReady;
        
        if initializeSession.initialized then beginTherapy;
        if not initializeSession.initialized then assessMobilityLevel;
        
        action beginTherapy {
            in session = initializeSession.session;
            out therapyActive : Boolean;
        }
        then continuousMonitoring;
        
        action continuousMonitoring {
            loop {
                action readSensors {
                    out tilt : TiltAngle;
                    out balance : BalanceScore;
                    out velocity : VelocityLimit;
                }
                then evaluateSafety;
                
                action evaluateSafety {
                    in tilt = readSensors.tilt;
                    in balance = readSensors.balance;
                    in maxTilt = assessMobilityLevel.safetySettings.maxTilt;
                    out safe : Boolean;
                    out alert : String;
                }
                then decide safetyCheck;
                
                if not evaluateSafety.safe then emergencyShutdown;
                if evaluateSafety.safe then adjustStabilization;
                
                action adjustStabilization : AdjustStabilization {
                    in tilt = readSensors.tilt;
                    in targetBalance = 75.0;
                    in therapyLevel = assessMobilityLevel.therapyLevel;
                    out leftMotorCmd;
                    out rightMotorCmd;
                }
                then applyMotorCommands;
                
                action applyMotorCommands {
                    in leftCmd = adjustStabilization.leftMotorCmd;
                    in rightCmd = adjustStabilization.rightMotorCmd;
                    out motorsApplied : Boolean;
                }
                then updateProgress;
                
                action updateProgress : MonitorVeteranProgress {
                    in session = initializeSession.session;
                    in sensorData = readSensors.balance;
                    out progressUpdate;
                    out continueSession;
                }
                then decide sessionContinuation;
                
                if updateProgress.continueSession then readSensors;
                if not updateProgress.continueSession then finalizeTherapy;
            }
        }
        
        action emergencyShutdown {
            out systemStopped : Boolean;
        }
        then notifyTherapist;
        
        action notifyTherapist {
            in alert = "Emergency stop activated";
            out notificationSent : Boolean;
        }
        then sessionLoop;
        
        action finalizeTherapy : EndTherapySession {
            in session = initializeSession.session;
            in finalScore = updateProgress.progressUpdate;
            out sessionComplete;
            out veteranProfile;
        }
        then recordProgress;
        
        action recordProgress {
            in profile = finalizeTherapy.veteranProfile;
            out recorded : Boolean;
        }
        then sessionLoop;
        
        then done;
    }
    
    part segs4VetsPlatform {
        doc /* 
            Segs4Vets is an innovative rehabilitation system that provides 
            self-balancing mobility therapy for veterans with mobility challenges. 
            The platform uses a two-wheeled, self-stabilizing design to deliver 
            progressive balance training, helping veterans improve their mobility, 
            coordination, and confidence through controlled therapeutic sessions 
            monitored by healthcare professionals.
        */
        
        part therapyControl : TherapyController {
            perform action sessionManagement : ManageSegs4VetsOperation;
        }
        
        part balanceSensors : BalanceSensor {
            attribute currentTilt = 0.0 [SI::rad];
            attribute currentBalance = 50.0;
        }
        
        part motorControl : MotorController {
            attribute leftMotorTorque = 0.0 [SI::'N·m'];
            attribute rightMotorTorque = 0.0 [SI::'N·m'];
        }
        
        part battery : BatterySystem {
            attribute chargeLevel = 100.0;
            attribute isCharging = false;
        }
        
        part veteranDisplay : DisplayPanel;
        
        part safetySystem : SafetyMonitor {
            attribute alertActive = false;
        }
        
        connection sensorToController connect 
            balanceSensors.sensorOutput to therapyControl.sensorInput;
        
        connection controllerToMotor connect 
            therapyControl.motorOutput to motorControl.motorCommand;
        
        connection displayToVeteran connect 
            veteranDisplay.display to therapyControl.veteranInterface;
        
        connection safetyToTherapist connect 
            safetySystem.safetyCheck to therapyControl.therapistInterface;
    }
    
    requirement def MobilityTherapyRequirement {
        doc /* The Segs4Vets system shall provide effective mobility therapy for veterans. */
        
        require balanceImprovement : BalanceImprovementRequirement;
        require safetyCompliance : SafetyComplianceRequirement;
        require sessionEffectiveness : SessionEffectivenessRequirement;
    }
    
    requirement def BalanceImprovementRequirement;
    requirement def SafetyComplianceRequirement;
    requirement def SessionEffectivenessRequirement;
    
    requirement <'S4V-REQ-001'> balanceImprovement : BalanceImprovementRequirement {
        doc /* Veterans shall demonstrate measurable balance improvement over therapy sessions. */
        subject veteran : VeteranProfile;
        
        require constraint {
            veteran.balanceCapability > 0.0 and veteran.sessionCount >= 1
        }
    }
    
    requirement <'S4V-REQ-002'> safetyCompliance : SafetyComplianceRequirement {
        doc /* The system shall maintain safe operation within defined tilt and stability limits. */
        subject safety : SafetyParameters;
        
        require constraint {
            safety.maxTilt.num <= 15.0 and safety.emergencyStopEnabled
        }
    }
    
    requirement <'S4V-REQ-003'> sessionEffectiveness : SessionEffectivenessRequirement {
        doc /* Therapy sessions shall be at least 15 minutes to provide therapeutic benefit. */
        subject session : TherapySession;
        
        require constraint {
            session.duration.num >= 15.0
        }
    }
    
    requirement <'S4V-REQ-004'> batteryReliability {
        doc /* Battery charge shall remain above 20% during active therapy sessions. */
        subject battery : BatterySystem;
        
        require constraint {
            battery.chargeLevel >= 20.0
        }
    }
    
    requirement <'S4V-REQ-005'> progressTracking {
        doc /* The system shall track and record veteran progress across all therapy sessions. */
        subject veteran : VeteranProfile;
        
        assume constraint {
            veteran.veteranID != null
        }
        
        require constraint {
            veteran.totalTherapyTime.num > 0.0 and veteran.sessionCount > 0
        }
    }
}
