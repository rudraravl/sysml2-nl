package StereotaxisMagneticNavigationSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        private import ISQ::*;
        private import ScalarValues::*;

        enum def OperationMode {
            manual;
            semiAutomated;
            fullyAutomated;
        }

        item def MagneticFieldCommand {
            attribute strength :> ISQ::magneticFluxDensity;
            attribute orientation : Real;
        }

        item def FluoroscopyImage {
            attribute resolution : Real;
            attribute timestamp : Real;
        }

        item def CatheterPosition {
            attribute x :> ISQ::length;
            attribute y :> ISQ::length;
            attribute z :> ISQ::length;
        }

        item def NavigationPlan {
            attribute waypoints : CatheterPosition[0..*];
            attribute target : CatheterPosition;
        }

        item def SafetyAlert {
            attribute severity : Integer;
            attribute alertText : String;
        }

        item def EmergencyStopSignal {
            attribute reason : String;
        }

        item def ForceMeasurement {
            attribute magnitude :> ISQ::force;
        }

        port def MagnetCommandInPort {
            in command : MagneticFieldCommand;
        }

        port def WorkstationOutPort {
            out command : MagneticFieldCommand;
        }

        port def FieldOutPort {
            out appliedField : MagneticFieldCommand;
        }

        port def FieldInPort {
            in appliedField : MagneticFieldCommand;
        }

        port def ImagingOutPort {
            out image : FluoroscopyImage;
            out position : CatheterPosition;
        }

        port def ImagingInPort {
            in image : FluoroscopyImage;
            in position : CatheterPosition;
        }

        port def SafetyOutPort {
            out alert : SafetyAlert;
            out stop : EmergencyStopSignal;
        }

        port def SafetyInPort {
            in alert : SafetyAlert;
            in stop : EmergencyStopSignal;
        }

        port def ForceOutPort {
            out force : ForceMeasurement;
        }

        port def ForceInPort {
            in force : ForceMeasurement;
        }

        port def PhysicianOutPort {
            out plan : NavigationPlan;
            out mode : OperationMode;
        }

        port def PhysicianInPort {
            in plan : NavigationPlan;
            in mode : OperationMode;
        }

        part def Magnet {
            attribute orientation : Real;
            attribute maxStrength :> ISQ::magneticFluxDensity;
        }

        part def ExternalMagnetSystem {
            part magnetLeft : Magnet;
            part magnetRight : Magnet;
            port controlPort : MagnetCommandInPort;
            port fieldPort : FieldOutPort;
            attribute currentFieldStrength :> ISQ::magneticFluxDensity;
            perform action generateMagneticField : GenerateMagneticField;
        }

        part def FluoroscopyImagingSystem {
            port imagingPort : ImagingOutPort;
            attribute frameRate : Real;
            attribute latency :> ISQ::time;
            perform action captureImage : CaptureImage;
            perform action processPosition : ProcessPosition;
        }

        part def NavigationSoftware {
            attribute activeMode : OperationMode;
            perform action planPath : PlanPath;
            perform action calculateField : CalculateField;
            perform action sendCommand : SendCommand;
        }

        part def NavigationWorkstation {
            port physicianPort : PhysicianInPort;
            port imagingPort : ImagingInPort;
            port safetyPort : SafetyInPort;
            port commandPort : WorkstationOutPort;
            attribute operationMode : OperationMode;
            part software : NavigationSoftware;
            perform action planPath : PlanPath;
            perform action calculateField : CalculateField;
            perform action sendCommand : SendCommand;
        }

        part def SafetyMonitoringSystem {
            port sensorPort : ForceInPort;
            port alertPort : SafetyOutPort;
            attribute maxTipForce :> ISQ::force = 0.5 [N];
            attribute maxProcedureDuration :> ISQ::time = 120 [min];
            attribute currentForce :> ISQ::force;
            attribute currentDuration :> ISQ::time;
            perform action monitorForce : MonitorForce;
            perform action monitorDuration : MonitorDuration;
            perform action triggerWarning : TriggerWarning;
            perform action triggerEmergencyStop : TriggerEmergencyStop;
        }

        part def MagneticTip {
            attribute magnetization :> ISQ::magneticFluxDensity;
        }

        part def Catheter {
            part magneticTip : MagneticTip;
            port sensorPort : ForceOutPort;
            port fieldPort : FieldInPort;
            attribute flexibility : Real;
            attribute currentTipForce :> ISQ::force;
        }

        part def TargetArea {
            attribute location : CatheterPosition;
        }

        part def CardiovascularSystem {
            attribute vesselCount : Integer;
        }

        part def Patient {
            part cardiovascularSystem : CardiovascularSystem;
            part targetArea : TargetArea;
        }

        part def Physician {
            port controlPort : PhysicianOutPort;
        }

        part def StereotaxisSystem {
            part externalMagnetSystem : ExternalMagnetSystem;
            part fluoroscopyImagingSystem : FluoroscopyImagingSystem;
            part navigationWorkstation : NavigationWorkstation;
            part safetyMonitoringSystem : SafetyMonitoringSystem;
            part catheter : Catheter;
            ref part patient : Patient;
            ref part physician : Physician;
            attribute elapsedTime :> ISQ::time;
            attribute navigationError :> ISQ::length;
        }

        action def GenerateMagneticField {
            in command : MagneticFieldCommand;
        }

        action def CaptureImage {
            out image : FluoroscopyImage;
            out position : CatheterPosition;
        }

        action def ProcessPosition {
            in image : FluoroscopyImage;
            out position : CatheterPosition;
        }

        action def PlanPath {
            in image : FluoroscopyImage;
            in target : CatheterPosition;
            out plan : NavigationPlan;
        }

        action def CalculateField {
            in plan : NavigationPlan;
            in currentPosition : CatheterPosition;
            out command : MagneticFieldCommand;
        }

        action def SendCommand {
            in command : MagneticFieldCommand;
        }

        action def MonitorForce {
            in force : ForceMeasurement;
            out alert : SafetyAlert;
            out stop : EmergencyStopSignal;
        }

        action def MonitorDuration {
            in duration :> ISQ::time;
            out alert : SafetyAlert;
            out stop : EmergencyStopSignal;
        }

        action def TriggerWarning;
        action def TriggerEmergencyStop;
        action def PerformIntervention;
        action def RetractCatheter;

        state def ProcedurePhases;
        state def OperationalModes;
        state def SafetyStates;

        attribute def StartPlanning;
        attribute def PlanReady;
        attribute def TargetReached;
        attribute def InterventionComplete;
        attribute def CatheterRetracted;
        attribute def SafetyReset;

        requirement def NavigationAccuracyRequirement {
            doc /* The catheter tip shall be positioned within 1 mm of the planned target. */
            subject system : StereotaxisSystem;
            attribute maxError :> ISQ::length = 1 [mm];
            assert constraint {
                system.navigationError <= maxError
            }
        }

        requirement def MaxTipForceRequirement {
            doc /* The force exerted by the catheter tip shall not exceed 0.5 N. */
            subject system : StereotaxisSystem;
            attribute maxForce :> ISQ::force = 0.5 [N];
            assert constraint {
                system.catheter.currentTipForce <= maxForce
            }
        }

        requirement def MaxProcedureDurationRequirement {
            doc /* The total procedure duration shall not exceed 120 minutes. */
            subject system : StereotaxisSystem;
            attribute maxDuration :> ISQ::time = 120 [min];
            assert constraint {
                system.elapsedTime <= maxDuration
            }
        }

        requirement def RealTimeImagingRequirement {
            doc /* Fluoroscopy imaging latency shall be less than 50 milliseconds. */
            subject system : StereotaxisSystem;
            attribute maxLatency :> ISQ::time = 0.05 [s];
            assert constraint {
                system.fluoroscopyImagingSystem.latency <= maxLatency
            }
        }
    }

    package Structure {
        private import Definitions::*;

        action performIntervention : PerformIntervention;
        action retractCatheter : RetractCatheter;

        part stereotaxisSystem : StereotaxisSystem {
            part externalMagnetSystem : ExternalMagnetSystem;
            part fluoroscopyImagingSystem : FluoroscopyImagingSystem;

            part navigationWorkstation : NavigationWorkstation {
                exhibit state operationalModes : OperationalModes {
                    entry; then manual;
                    state manual;
                    accept when operationMode == OperationMode::semiAutomated
                        then semiAutomated;
                    state semiAutomated;
                    accept when operationMode == OperationMode::fullyAutomated
                        then fullyAutomated;
                    state fullyAutomated;
                    accept when operationMode == OperationMode::manual
                        then manual;
                }
            }

            part safetyMonitoringSystem : SafetyMonitoringSystem {
                exhibit state safetyStates : SafetyStates {
                    entry; then normal;
                    state normal {
                        do monitorForce;
                        do monitorDuration;
                    }
                    accept when currentForce > maxTipForce
                        then warning;
                    accept when currentDuration > maxProcedureDuration
                        then warning;
                    state warning {
                        entry triggerWarning;
                    }
                    accept when currentForce > 2 * maxTipForce
                        or currentDuration > 1.1 * maxProcedureDuration
                        then emergencyStop;
                    state emergencyStop {
                        entry triggerEmergencyStop;
                    }
                    accept SafetyReset
                        then normal;
                }
            }

            part catheter : Catheter;
            ref part patient : Patient;
            ref part physician : Physician;

            interface PhysicianToWorkstation connect physician.controlPort to navigationWorkstation.physicianPort {
                flow planFlow of NavigationPlan
                    from physician.controlPort.plan to navigationWorkstation.physicianPort.plan;
                flow modeFlow of OperationMode
                    from physician.controlPort.mode to navigationWorkstation.physicianPort.mode;
            }

            interface FluoroToWorkstation connect fluoroscopyImagingSystem.imagingPort to navigationWorkstation.imagingPort {
                flow imageFlow of FluoroscopyImage
                    from fluoroscopyImagingSystem.imagingPort.image to navigationWorkstation.imagingPort.image;
                flow positionFlow of CatheterPosition
                    from fluoroscopyImagingSystem.imagingPort.position to navigationWorkstation.imagingPort.position;
            }

            interface WorkstationToMagnets connect navigationWorkstation.commandPort to externalMagnetSystem.controlPort {
                flow commandFlow of MagneticFieldCommand
                    from navigationWorkstation.commandPort.command to externalMagnetSystem.controlPort.command;
            }

            interface MagnetsToCatheter connect externalMagnetSystem.fieldPort to catheter.fieldPort {
                flow fieldFlow of MagneticFieldCommand
                    from externalMagnetSystem.fieldPort.appliedField to catheter.fieldPort.appliedField;
            }

            interface CatheterToSafety connect catheter.sensorPort to safetyMonitoringSystem.sensorPort {
                flow forceFlow of ForceMeasurement
                    from catheter.sensorPort.force to safetyMonitoringSystem.sensorPort.force;
            }

            interface SafetyToWorkstation connect safetyMonitoringSystem.alertPort to navigationWorkstation.safetyPort {
                flow alertFlow of SafetyAlert
                    from safetyMonitoringSystem.alertPort.alert to navigationWorkstation.safetyPort.alert;
                flow stopFlow of EmergencyStopSignal
                    from safetyMonitoringSystem.alertPort.stop to navigationWorkstation.safetyPort.stop;
            }

            exhibit state procedurePhases : ProcedurePhases {
                entry; then idle;
                state idle;
                accept StartPlanning
                    then planning;
                state planning {
                    do navigationWorkstation.planPath;
                }
                accept PlanReady
                    then navigating;
                state navigating {
                    do navigationWorkstation.calculateField;
                    do navigationWorkstation.sendCommand;
                }
                accept TargetReached
                    then intervening;
                state intervening {
                    do performIntervention;
                }
                accept InterventionComplete
                    then retracting;
                state retracting {
                    do retractCatheter;
                }
                accept CatheterRetracted
                    then completed;
                state completed;
            }
        }

        requirement maxTipForceReq : MaxTipForceRequirement;
        requirement maxProcDurationReq : MaxProcedureDurationRequirement;
        requirement navAccuracyReq : NavigationAccuracyRequirement;
        requirement realTimeImagingReq : RealTimeImagingRequirement;

        satisfy maxTipForceReq by stereotaxisSystem.safetyMonitoringSystem;
        satisfy maxProcDurationReq by stereotaxisSystem.safetyMonitoringSystem;
        satisfy navAccuracyReq by stereotaxisSystem.navigationWorkstation;
        satisfy realTimeImagingReq by stereotaxisSystem.fluoroscopyImagingSystem;
    }
}
