package BaranyChairSystem {
    public import ISQ::*;
    public import ScalarValues::*;
    public import Definitions::*;

    package Definitions {
        public import AttributeDefinitions::*;
        public import PortDefinitions::*;
        public import PartDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;

        package AttributeDefinitions {
            enum def RotationDirection {
                clockwise;
                counterClockwise;
            }

            attribute def TestParameters {
                attribute targetSpeed :> ISQ::angularVelocity;
                attribute duration :> ISQ::time;
                attribute direction : RotationDirection;
            }

            attribute def MotorCommand {
                attribute targetSpeed :> ISQ::angularVelocity;
                attribute direction : RotationDirection;
            }

            attribute def MotorFeedback {
                attribute currentSpeed :> ISQ::angularVelocity;
                attribute currentTorque :> ISQ::torque;
                attribute direction : RotationDirection;
            }

            attribute def VestibularResponse {
                attribute nystagmusDetected : Boolean;
                attribute dizzinessLevel : Integer;
            }

            attribute def SafetyStatus {
                attribute restraintsEngaged : Boolean;
                attribute speedWithinLimits : Boolean;
                attribute emergencyStopActive : Boolean;
            }

            attribute def StartTestSignal;
            attribute def EmergencyStopSignal;
            attribute def ResetSignal;
        }

        package PortDefinitions {
            port def OperatorInputPort {
                in testParams : TestParameters;
                in startSignal : StartTestSignal;
                in resetSignal : ResetSignal;
            }

            port def MotorCmdPort {
                out cmd : MotorCommand;
            }

            port def MotorFeedbackPort {
                out feedback : MotorFeedback;
            }

            port def ObservationDataPort {
                out response : VestibularResponse;
            }

            port def SafetyStatusPort {
                out status : SafetyStatus;
            }

            port def EmergencyStopPort {
                in emergencyStop : EmergencyStopSignal;
            }

            port def RestraintStatusPort {
                out harnessEngaged : Boolean;
            }
        }

        package PartDefinitions {
            part def BaranyChair {
                attribute maxSpeed :> ISQ::angularVelocity;
                attribute currentSpeed :> ISQ::angularVelocity;
                attribute targetSpeed :> ISQ::angularVelocity;
                attribute testDuration :> ISQ::time;
                attribute rotationDirection : RotationDirection;
                attribute emergencyStopActive : Boolean;

                port operatorPort : OperatorInputPort;
                port motorFeedbackPort : ~MotorFeedbackPort;
                port observationPort : ~ObservationDataPort;
                port safetyPort : ~SafetyStatusPort;
                port emergencyStopPort : EmergencyStopPort;

                part seatAssembly : SeatAssembly[1];
                part driveMotor : DriveMotor[1];
                part controlSystem : ControlSystem[1];
                part observationSystem : ObservationSystem[1];
                part safetySystem : SafetySystem[1];

                perform action accelerateChair;
                perform action maintainConstantSpeed;
                perform action decelerateChair;
                perform action executeEmergencyStop;

                exhibit state chairStates parallel {
                    state operationalStates {
                        entry action initial;
                        state idle;
                        transition initial then idle;

                        transition idle_to_accelerating
                            first idle
                            accept params : TestParameters via operatorPort
                            if params.targetSpeed <= maxSpeed
                            then accelerating;

                        state accelerating {
                            do accelerateChair;
                        }

                        transition accelerating_to_constantRotation
                            first accelerating
                            accept fb : MotorFeedback via motorFeedbackPort
                            if fb.currentSpeed >= targetSpeed
                            then constantRotation;

                        state constantRotation {
                            do maintainConstantSpeed;
                        }

                        transition constantRotation_to_decelerating
                            first constantRotation
                            accept after testDuration
                            then decelerating;

                        state decelerating {
                            do decelerateChair;
                        }

                        transition decelerating_to_stopped
                            first decelerating
                            accept fb : MotorFeedback via motorFeedbackPort
                            if fb.currentSpeed <= 0 [rad/s]
                            then stopped;

                        state stopped;

                        transition stopped_to_idle
                            first stopped
                            accept reset : ResetSignal via operatorPort
                            then idle;
                    }

                    state safetyStates {
                        entry action initial;
                        state safe;
                        state emergency;
                        transition initial then safe;

                        transition safe_to_emergency
                            first safe
                            accept eStop : EmergencyStopSignal via emergencyStopPort
                            do executeEmergencyStop
                            then emergency;

                        transition emergency_to_safe
                            first emergency
                            accept reset : ResetSignal via operatorPort
                            then safe;
                    }
                }

                connection controlToMotor connect controlSystem.motorCmdPort to driveMotor.motorCmdPort;
                connection motorToControl connect driveMotor.motorFeedbackPort to controlSystem.motorFeedbackPort;
                connection motorFbToChair connect driveMotor.motorFeedbackPort to motorFeedbackPort;
                connection obsToChair connect observationSystem.observationPort to observationPort;
                connection safetyToChair connect safetySystem.safetyPort to safetyPort;
                connection restraintToSafety connect seatAssembly.restraintPort to safetySystem.restraintInPort;
                connection motorFbToSafety connect driveMotor.motorFeedbackPort to safetySystem.motorStatusPort;
            }

            part def SeatAssembly {
                attribute patientWeight :> ISQ::mass;
                attribute harnessEngaged : Boolean;

                part headrest : Headrest[1];
                part safetyHarness : SafetyHarness[1];
                part seatBase : SeatBase[1];

                port restraintPort : RestraintStatusPort;

                perform action securePatient;
                perform action releasePatient;
            }

            part def Headrest {
                attribute heightAdjustment :> ISQ::length;
                attribute angleAdjustment :> ISQ::planeAngle;
            }

            part def SafetyHarness {
                attribute engaged : Boolean;
                attribute tensionLevel :> ISQ::force;

                perform action engage;
                perform action disengage;
            }

            part def SeatBase {
                attribute rotationAxisHeight :> ISQ::length;
            }

            part def DriveMotor {
                attribute maxTorque :> ISQ::torque;
                attribute currentTorque :> ISQ::torque;
                attribute currentSpeed :> ISQ::angularVelocity;
                attribute direction : RotationDirection;

                port motorCmdPort : ~MotorCmdPort;
                port motorFeedbackPort : MotorFeedbackPort;

                perform action accelerate;
                perform action decelerate;
                perform action maintainSpeed;
                perform action stop;
            }

            part def ControlSystem {
                attribute testParameters : TestParameters;

                port motorCmdPort : MotorCmdPort;
                port motorFeedbackPort : ~MotorFeedbackPort;

                perform action processOperatorInput;
                perform action generateMotorCommands;
                perform action monitorTestProgress;
                perform action handleEmergencyStop;
            }

            part def ObservationSystem {
                attribute nystagmusDetected : Boolean;
                attribute dizzinessLevel : Integer;

                port observationPort : ObservationDataPort;

                perform action detectNystagmus;
                perform action recordEyeMovements;
                perform action assessDizziness;
                perform action transmitObservationData;
            }

            part def SafetySystem {
                attribute speedWithinLimits : Boolean;
                attribute restraintsEngaged : Boolean;
                attribute emergencyStopActive : Boolean;

                port restraintInPort : ~RestraintStatusPort;
                port motorStatusPort : ~MotorFeedbackPort;
                port safetyPort : SafetyStatusPort;

                perform action monitorRestraints;
                perform action monitorSpeed;
                perform action triggerEmergencyStop;
                perform action verifySafetyConditions;
            }
        }

        package ActionDefinitions {
            action def AccelerateChair {
                in targetSpeed :> ISQ::angularVelocity;
                in direction : RotationDirection;
            }

            action def MaintainConstantSpeed {
                in targetSpeed :> ISQ::angularVelocity;
                in duration :> ISQ::time;
            }

            action def DecelerateChair {
                in decelerationRate :> ISQ::angularAcceleration;
            }

            action def ExecuteEmergencyStop;

            action def DetectNystagmus {
                out nystagmusDetected : Boolean;
            }

            action def RecordEyeMovements;

            action def AssessDizziness {
                out dizzinessLevel : Integer;
            }

            action def TransmitObservationData;

            action def MonitorRestraints {
                out restraintsEngaged : Boolean;
            }

            action def MonitorSpeed {
                in currentSpeed :> ISQ::angularVelocity;
                in maxSpeed :> ISQ::angularVelocity;
                out speedWithinLimits : Boolean;
            }

            action def TriggerEmergencyStop;
            action def VerifySafetyConditions;
            action def ProcessOperatorInput;
            action def GenerateMotorCommands;
            action def MonitorTestProgress;
            action def HandleEmergencyStop;
            action def SecurePatient;
            action def ReleasePatient;
            action def Engage;
            action def Disengage;
            action def Accelerate;
            action def Decelerate;
            action def MaintainSpeed;
            action def Stop;
        }

        package StateDefinitions {
            state def ChairStates;
            state def ControllerStates;
            state def SafetyStates;
        }

        package RequirementDefinitions {
            requirement def VestibularAssessment {
                doc /* The system shall subject the patient to precise, controlled rotational movements to stimulate the inner ear and observe physiological responses. */
                subject chair : BaranyChair;
            }

            requirement def PatientSafety {
                doc /* The system shall ensure patient safety through continuous monitoring of restraints and speed limits. */
                subject chair : BaranyChair;
                constraint { chair.safetySystem.restraintsEngaged == true }
                constraint { chair.safetySystem.speedWithinLimits == true }
            }

            requirement def EmergencyStopCapability {
                doc /* The system shall provide an emergency stop function that can halt rotation within 2 seconds. */
                subject chair : BaranyChair;
                constraint { chair.emergencyStopActive implies chair.currentSpeed == 0 }
            }

            requirement def NystagmusDetection {
                doc /* The observation system shall detect and record nystagmus during the test. */
                subject obs : ObservationSystem;
            }

            requirement def SpeedControl {
                doc /* The drive motor shall maintain target speed within tolerance during constant rotation. */
                subject chair : BaranyChair;
                constraint { chair.currentSpeed <= chair.targetSpeed * 1.05 and chair.currentSpeed >= chair.targetSpeed * 0.95 }
            }

            requirement def TestParameterValidation {
                doc /* The system shall validate that test parameters are within safe operating limits before starting. */
                subject chair : BaranyChair;
                constraint { chair.targetSpeed <= chair.maxSpeed }
            }
        }
    }
}
