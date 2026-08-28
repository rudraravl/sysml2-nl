package 'Nanorobotic Targeted Therapy System' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def ConfidenceValue :> Real;
        attribute def PHValue :> Real;
        attribute def DrugMassValue :> Real;

        attribute def StartMission;
        attribute def StopMission;
        attribute def TargetDetected;
        attribute def ArrivedAtTarget;
        attribute def TargetConfirmed;
        attribute def TargetRejected;
        attribute def DeliveryComplete;
        attribute def NextTarget;
        attribute def PayloadDepleted;
        attribute def PowerLow;
        attribute def MissionComplete;
        attribute def AbortMission;

        attribute def TargetLocation {
            attribute x : ISQ::LengthValue;
            attribute y : ISQ::LengthValue;
            attribute z : ISQ::LengthValue;
        }
        attribute def Position {
            attribute x : ISQ::LengthValue;
            attribute y : ISQ::LengthValue;
            attribute z : ISQ::LengthValue;
        }
        item def TherapeuticDrug {
            attribute mass : DrugMassValue;
        }
        attribute def StatusData {
            attribute temperature : ISQ::TemperatureValue;
            attribute ph : PHValue;
            attribute remainingPayload : Integer;
            attribute remainingPower : ISQ::DurationValue;
        }
        attribute def Command {
            attribute commandType : String;
        }

        action def ScanEnvironment {
            out biomarkerDetected : Boolean;
            out confidence : ConfidenceValue;
            out temperature : ISQ::TemperatureValue;
            out ph : PHValue;
        }
        action def CalculatePath {
            in targetLocation : TargetLocation;
            out pathCalculated : Boolean;
        }
        action def Propel {
            in targetLocation : TargetLocation;
            out currentPosition : Position;
            out distanceToTarget : ISQ::LengthValue;
        }
        action def VerifyTarget {
            in currentPosition : Position;
            out confirmed : Boolean;
        }
        action def ReleasePayload {
            in confirmed : Boolean;
            out drugReleased : Boolean;
            out remainingPayload : Integer;
        }
        action def MonitorEnvironment {
            out temperature : ISQ::TemperatureValue;
            out ph : PHValue;
        }
        action def TransmitStatus {
            in status : StatusData;
            out transmitted : Boolean;
        }
        action def ReceiveCommand {
            out command : Command;
        }
        action def ConsumePower {
            in duration : ISQ::DurationValue;
            out remainingPower : ISQ::DurationValue;
        }

        state def RobotStates;

        part def BiosensorArray {
            attribute detectionConfidenceThreshold : ConfidenceValue = 95;
            port sensorOut {
                out attribute biomarkerDetected : Boolean;
                out attribute confidence : ConfidenceValue;
                out attribute temperature : ISQ::TemperatureValue;
                out attribute ph : PHValue;
            }
            perform action scan : ScanEnvironment;
        }

        part def NavigationController {
            attribute arrivalPrecisionThreshold : ISQ::LengthValue = 10;
            port navIn {
                in attribute biomarkerDetected : Boolean;
                in attribute confidence : ConfidenceValue;
            }
            port navOut {
                out attribute currentPosition : Position;
                out attribute distanceToTarget : ISQ::LengthValue;
            }
            port releaseOut {
                out attribute confirmed : Boolean;
            }
            perform action calculatePath : CalculatePath;
            perform action propel : Propel;
        }

        part def PayloadModule {
            attribute payloadCapacity : Integer = 10;
            attribute remainingPayload : Integer = payloadCapacity;
            port releaseIn {
                in attribute confirmed : Boolean;
            }
            port payloadOut {
                out attribute drugReleased : Boolean;
                out attribute remainingPayloadCount : Integer;
            }
            perform action releasePayload : ReleasePayload;
        }

        part def PowerManagementUnit {
            attribute missionDuration : ISQ::DurationValue = 60;
            attribute remainingPower : ISQ::DurationValue = missionDuration;
            port powerOut {
                out attribute remainingPowerLevel : ISQ::DurationValue;
            }
            perform action consumePower : ConsumePower;
        }

        part def CommunicationModule {
            port commIn {
                in attribute command : Command;
            }
            port commOut {
                out attribute status : StatusData;
                out attribute transmitted : Boolean;
            }
            perform action transmitStatus : TransmitStatus;
            perform action receiveCommand : ReceiveCommand;
        }

        part def TherapeuticNanorobot {
            attribute maxSize : ISQ::LengthValue = 500;
            attribute size : ISQ::LengthValue;
            attribute currentTarget : TargetLocation;
            attribute currentPosition : Position;
            attribute currentConfidence : ConfidenceValue;
            attribute targetConfirmed : Boolean;

            exhibit state robotStates : RobotStates;

            part biosensorArray : BiosensorArray;
            part navigationController : NavigationController;
            part payloadModule : PayloadModule;
            part powerManagementUnit : PowerManagementUnit;
            part communicationModule : CommunicationModule;

            connect biosensorArray.sensorOut to navigationController.navIn;
            connect navigationController.releaseOut to payloadModule.releaseIn;
            connect payloadModule.payloadOut to communicationModule.commIn;
        }

        part def NanorobotSwarm {
            part nanorobots [1..*] : TherapeuticNanorobot;
            part coordinator {
                port coordIn {
                    in attribute status : StatusData;
                }
                port coordOut {
                    out attribute command : Command;
                }
            }
        }
    }

    import Definitions::*;

    package Usages {
        private import Definitions::*;

        action 'scan environment' : ScanEnvironment;
        action 'calculate path' : CalculatePath;
        action 'propel' : Propel;
        action 'verify target' : VerifyTarget;
        action 'release payload' : ReleasePayload;
        action 'monitor environment' : MonitorEnvironment;
        action 'transmit status' : TransmitStatus;
        action 'receive command' : ReceiveCommand;
        action 'consume power' : ConsumePower;

        part nanorobot1 : TherapeuticNanorobot {
            attribute size : ISQ::LengthValue = 450;

            part biosensorArray : BiosensorArray {
                attribute detectionConfidenceThreshold : ConfidenceValue = 95;
            }
            part navigationController : NavigationController {
                attribute arrivalPrecisionThreshold : ISQ::LengthValue = 10;
            }
            part payloadModule : PayloadModule {
                attribute payloadCapacity : Integer = 10;
                attribute remainingPayload : Integer = 10;
            }
            part powerManagementUnit : PowerManagementUnit {
                attribute missionDuration : ISQ::DurationValue = 60;
                attribute remainingPower : ISQ::DurationValue = 60;
            }
            part communicationModule : CommunicationModule;

            state robotStates : RobotStates parallel {
                state 'mission sequence' {
                    entry; then Searching;

                    state Searching {
                        do 'scan environment';
                    }
                    accept when 'scan environment'.confidence > 95
                        then Navigating;

                    state Navigating {
                        entry 'calculate path';
                        do 'propel';
                    }
                    accept when 'propel'.distanceToTarget <= 10
                        then Verifying;

                    state Verifying {
                        do 'verify target';
                    }
                    accept when 'verify target'.confirmed == true
                        then Delivering;
                    accept when 'verify target'.confirmed == false
                        then Searching;

                    state Delivering {
                        do 'release payload';
                    }
                    accept when 'release payload'.remainingPayload == 0
                        then Done;
                    accept when 'release payload'.drugReleased == true
                        then Monitoring;

                    state Monitoring {
                        entry 'monitor environment';
                        do 'transmit status';
                    }
                    accept NextTarget
                        then Searching;
                    accept MissionComplete
                        then Done;

                    state Done;
                }

                state 'power management' {
                    entry; then Nominal;

                    state Nominal {
                        do 'consume power';
                    }
                    accept when 'consume power'.remainingPower < 10
                        then LowPower;

                    state LowPower {
                        do 'transmit status';
                    }
                    accept when 'consume power'.remainingPower == 0
                        then Depleted;

                    state Depleted;
                }
            }
        }

        part swarm1 : NanorobotSwarm {
            part nanorobots [5] : TherapeuticNanorobot;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def 'Size Constraint' {
            doc /* The nanorobot must be smaller than 500 nanometers to navigate blood vessels safely. */
            subject nanorobot : TherapeuticNanorobot;
            require nanorobot.size <= nanorobot.maxSize;
        }

        requirement def 'Detection Confidence' {
            doc /* The biosensor array must achieve over 95% confidence before identifying a target. */
            subject sensor : BiosensorArray;
            require sensor.detectionConfidenceThreshold > 95;
        }

        requirement def 'Navigation Precision' {
            doc /* The nanorobot must arrive within 10 nanometers of its target. */
            subject navController : NavigationController;
            require navController.arrivalPrecisionThreshold <= 10;
        }

        requirement def 'Mission Duration' {
            doc /* The power management unit must sustain operation for at least 60 minutes. */
            subject powerUnit : PowerManagementUnit;
            require powerUnit.missionDuration >= 60;
        }

        requirement def 'Payload Safety' {
            doc /* The payload module must only release drug after confirmed target verification. */
            subject payload : PayloadModule;
            require payload.remainingPayload >= 0;
        }

        requirement def 'Therapeutic Efficacy' {
            doc /* The nanorobot must locate diseased cells and deliver therapeutic drug with minimal harm to healthy tissue. */
            subject robot : TherapeuticNanorobot;
        }
    }
}
