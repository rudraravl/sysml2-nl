package BioRoboticRehabilitationSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def MassValue :> Real;
    attribute def LengthValue :> Real;
    attribute def AngleValue :> Real;
    attribute def AngularVelocityValue :> Real;
    attribute def ForceValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def PowerValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def EnergyValue :> Real;
    attribute def TimeValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def RatioValue :> Real;

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    item def BatteryState {
        attribute stateOfCharge : RatioValue;
        attribute remainingEnergy : EnergyValue;
        attribute temperature : TemperatureValue;
    }

    item def LimbMotionTelemetry {
        attribute hipAngle : AngleValue;
        attribute kneeAngle : AngleValue;
        attribute ankleAngle : AngleValue;
        attribute hipAngularVelocity : AngularVelocityValue;
        attribute kneeAngularVelocity : AngularVelocityValue;
        attribute ankleAngularVelocity : AngularVelocityValue;
        attribute groundReactionForce : ForceValue;
        attribute sampleRate : FrequencyValue;
    }

    item def NeuralIntentSignal {
        attribute muscleActivationLevel : RatioValue;
        attribute intendedJointTorque : TorqueValue;
        attribute confidence : RatioValue;
        attribute latency : TimeValue;
    }

    item def SafetyStatus {
        attribute humanDetected : Boolean;
        attribute emergencyStopPressed : Boolean;
        attribute torqueLimitExceeded : Boolean;
        attribute sensorFaultDetected : Boolean;
        attribute batterySafe : Boolean;
    }

    item def TherapyPlan {
        attribute targetAssistRatio : RatioValue;
        attribute sessionDuration : TimeValue;
        attribute maximumJointTorque : TorqueValue;
        attribute preferredCadence : FrequencyValue;
        attribute gaitTrainingMode : String;
    }

    item def ActuatorCommand {
        attribute commandedHipTorque : TorqueValue;
        attribute commandedKneeTorque : TorqueValue;
        attribute commandedAnkleTorque : TorqueValue;
        attribute commandUpdatePeriod : TimeValue;
    }

    item def StimulationCommand {
        attribute pulseAmplitude : CurrentValue;
        attribute pulseWidth : TimeValue;
        attribute pulseFrequency : FrequencyValue;
        attribute enabled : Boolean;
    }

    item def MechanicalAssistTorque {
        attribute hipTorque : TorqueValue;
        attribute kneeTorque : TorqueValue;
        attribute ankleTorque : TorqueValue;
        attribute deliveredPower : PowerValue;
    }

    item def PatientFeedback {
        attribute perceivedComfort : RatioValue;
        attribute effortReduction : RatioValue;
        attribute painReported : Boolean;
        attribute interactionForce : ForceValue;
    }

    item def ClinicianCommand {
        attribute startSession : Boolean;
        attribute pauseSession : Boolean;
        attribute stopSession : Boolean;
        attribute requestedAssistRatio : RatioValue;
    }

    item def CalibrationData {
        attribute hipNeutralAngle : AngleValue;
        attribute kneeNeutralAngle : AngleValue;
        attribute ankleNeutralAngle : AngleValue;
        attribute patientMassEstimate : MassValue;
        attribute limbLengthEstimate : LengthValue;
    }

    item def PowerOnSignal;
    item def PowerOffSignal;
    item def SelfTestPassedSignal;
    item def SelfTestFailedSignal;
    item def CalibrationRequestedSignal;
    item def CalibrationCompleteSignal;
    item def TherapyStartSignal;
    item def TherapyPauseSignal;
    item def TherapyStopSignal;
    item def HazardDetectedSignal;
    item def HazardClearedSignal;

    port def ElectricalPowerSourcePort {
        out item electricalPower : ElectricalPower;
    }

    port def ElectricalPowerLoadPort {
        in item electricalPower : ElectricalPower;
    }

    port def BatteryStatusPort {
        out item batteryState : BatteryState;
    }

    port def LimbMotionOutPort {
        out item telemetry : LimbMotionTelemetry;
    }

    port def LimbMotionInPort {
        in item telemetry : LimbMotionTelemetry;
    }

    port def NeuralIntentOutPort {
        out item intent : NeuralIntentSignal;
    }

    port def NeuralIntentInPort {
        in item intent : NeuralIntentSignal;
    }

    port def SafetyStatusOutPort {
        out item safetyStatus : SafetyStatus;
    }

    port def SafetyStatusInPort {
        in item safetyStatus : SafetyStatus;
    }

    port def TherapyPlanOutPort {
        out item therapyPlan : TherapyPlan;
    }

    port def TherapyPlanInPort {
        in item therapyPlan : TherapyPlan;
    }

    port def ClinicianCommandInPort {
        in item command : ClinicianCommand;
    }

    port def ClinicianCommandOutPort {
        out item command : ClinicianCommand;
    }

    port def ActuatorCommandOutPort {
        out item command : ActuatorCommand;
    }

    port def ActuatorCommandInPort {
        in item command : ActuatorCommand;
    }

    port def StimulationCommandOutPort {
        out item command : StimulationCommand;
    }

    port def StimulationCommandInPort {
        in item command : StimulationCommand;
    }

    port def MechanicalAssistSourcePort {
        out item torque : MechanicalAssistTorque;
    }

    port def MechanicalAssistLoadPort {
        in item torque : MechanicalAssistTorque;
    }

    port def PatientFeedbackOutPort {
        out item feedback : PatientFeedback;
    }

    port def PatientFeedbackInPort {
        in item feedback : PatientFeedback;
    }

    port def CalibrationDataOutPort {
        out item calibrationData : CalibrationData;
    }

    port def CalibrationDataInPort {
        in item calibrationData : CalibrationData;
    }

    part def BioSignalSensorArray {
        attribute mass : MassValue = 0.35 [kg];
        attribute emgSampleRate : FrequencyValue = 1000 [Hz];
        attribute intentLatency : TimeValue = 0.020 [s];

        port powerIn : ElectricalPowerLoadPort;
        port intentOut : NeuralIntentOutPort;
    }

    part def KinematicSensorArray {
        attribute mass : MassValue = 0.55 [kg];
        attribute motionSampleRate : FrequencyValue = 200 [Hz];
        attribute angularResolution : AngleValue = 0.002 [rad];

        port powerIn : ElectricalPowerLoadPort;
        port telemetryOut : LimbMotionOutPort;
    }

    part def SafetySensorArray {
        attribute mass : MassValue = 0.40 [kg];
        attribute forceLimit : ForceValue = 450 [N];
        attribute safetyUpdatePeriod : TimeValue = 0.005 [s];

        port powerIn : ElectricalPowerLoadPort;
        port safetyOut : SafetyStatusOutPort;
    }

    part def PatientInterfaceHarness {
        attribute mass : MassValue = 2.20 [kg];
        attribute maximumContactPressure : PressureValue = 18000 [Pa];
        attribute thighCuffLength : LengthValue = 0.32 [m];
        attribute shankCuffLength : LengthValue = 0.28 [m];

        port assistIn : MechanicalAssistLoadPort;
        port feedbackOut : PatientFeedbackOutPort;
        port calibrationOut : CalibrationDataOutPort;
    }

    part def WearableExoskeletonFrame {
        attribute mass : MassValue = 6.50 [kg];
        attribute hipRangeOfMotion : AngleValue = 1.60 [rad];
        attribute kneeRangeOfMotion : AngleValue = 2.10 [rad];
        attribute ankleRangeOfMotion : AngleValue = 0.80 [rad];
        attribute structuralTorqueLimit : TorqueValue = 95 [N*m];

        port actuatorTorqueIn : MechanicalAssistLoadPort;
        port patientTorqueOut : MechanicalAssistSourcePort;
        port patientFeedbackIn : PatientFeedbackInPort;
    }

    part def JointActuatorSet {
        attribute mass : MassValue = 5.00 [kg];
        attribute peakHipTorque : TorqueValue = 75 [N*m];
        attribute peakKneeTorque : TorqueValue = 70 [N*m];
        attribute peakAnkleTorque : TorqueValue = 45 [N*m];
        attribute continuousMechanicalPower : PowerValue = 350 [W];
        attribute commandPeriod : TimeValue = 0.005 [s];

        port powerIn : ElectricalPowerLoadPort;
        port commandIn : ActuatorCommandInPort;
        port torqueOut : MechanicalAssistSourcePort;
    }

    part def NeuromuscularStimulationModule {
        attribute mass : MassValue = 0.60 [kg];
        attribute maximumPulseAmplitude : CurrentValue = 0.060 [A];
        attribute maximumPulseWidth : TimeValue = 0.0004 [s];
        attribute maximumPulseFrequency : FrequencyValue = 80 [Hz];

        port powerIn : ElectricalPowerLoadPort;
        port stimulationCommandIn : StimulationCommandInPort;
        port patientFeedbackIn : PatientFeedbackInPort;
    }

    part def EmbeddedControlComputer {
        attribute mass : MassValue = 0.90 [kg];
        attribute controlLoopPeriod : TimeValue = 0.005 [s];
        attribute processorPower : PowerValue = 22 [W];
        attribute maximumAssistTorque : TorqueValue = 70 [N*m];
        attribute nominalAssistRatio : RatioValue = 0.60;

        port powerIn : ElectricalPowerLoadPort;
        port telemetryIn : LimbMotionInPort;
        port intentIn : NeuralIntentInPort;
        port safetyIn : SafetyStatusInPort;
        port therapyPlanIn : TherapyPlanInPort;
        port patientFeedbackIn : PatientFeedbackInPort;
        port calibrationDataIn : CalibrationDataInPort;
        port actuatorCommandOut : ActuatorCommandOutPort;
        port stimulationCommandOut : StimulationCommandOutPort;
    }

    part def TherapyConsole {
        attribute mass : MassValue = 1.10 [kg];
        attribute displayPower : PowerValue = 8 [W];
        attribute clinicianUpdatePeriod : TimeValue = 0.100 [s];

        port powerIn : ElectricalPowerLoadPort;
        port clinicianCommandIn : ClinicianCommandInPort;
        port therapyPlanOut : TherapyPlanOutPort;
        port patientFeedbackIn : PatientFeedbackInPort;
        port safetyStatusIn : SafetyStatusInPort;
    }

    part def RechargeablePowerSubsystem {
        attribute mass : MassValue = 2.10 [kg];
        attribute nominalVoltage : VoltageValue = 48 [V];
        attribute maximumCurrent : CurrentValue = 20 [A];
        attribute usableEnergy : EnergyValue = 720000 [J];
        attribute outputPowerLimit : PowerValue = 650 [W];

        port powerOutForSensors : ElectricalPowerSourcePort;
        port powerOutForController : ElectricalPowerSourcePort;
        port powerOutForActuators : ElectricalPowerSourcePort;
        port powerOutForConsole : ElectricalPowerSourcePort;
        port batteryStatusOut : BatteryStatusPort;
    }

    action def AcquireHumanState {
        out item telemetry : LimbMotionTelemetry;
        out item intent : NeuralIntentSignal;
        out item safetyStatus : SafetyStatus;
        attribute acquisitionPeriod : TimeValue = 0.005 [s];
    }

    action def EstimateMovementIntent {
        in item telemetry : LimbMotionTelemetry;
        in item intent : NeuralIntentSignal;
        in item calibrationData : CalibrationData;
        out item therapyPlanAdjustedIntent : NeuralIntentSignal;
        attribute maximumEstimationLatency : TimeValue = 0.015 [s];
    }

    action def ComputeAssistiveCommand {
        in item plan : TherapyPlan;
        in item estimatedIntent : NeuralIntentSignal;
        in item telemetry : LimbMotionTelemetry;
        in item safetyStatus : SafetyStatus;
        out item actuatorCommand : ActuatorCommand;
        out item stimulationCommand : StimulationCommand;
        attribute computationPeriod : TimeValue = 0.005 [s];
        attribute defaultAssistRatio : RatioValue = 0.60;
    }

    action def DeliverSafeAssistance {
        in item actuatorCommand : ActuatorCommand;
        in item stimulationCommand : StimulationCommand;
        out item deliveredAssist : MechanicalAssistTorque;
        out item patientFeedback : PatientFeedback;
        attribute torqueRampTime : TimeValue = 0.100 [s];
        attribute peakDeliveredTorque : TorqueValue = 70 [N*m];
    }

    action def MonitorAndLimitRisk {
        in item safetyStatus : SafetyStatus;
        in item deliveredAssist : MechanicalAssistTorque;
        out item limitedCommand : ActuatorCommand;
        attribute safeStopTime : TimeValue = 0.050 [s];
        attribute hardTorqueLimit : TorqueValue = 80 [N*m];
    }

    action def AssistHumanMovement {
        in item therapyPlan : TherapyPlan;
        in item clinicianCommand : ClinicianCommand;
        out item patientFeedback : PatientFeedback;
        attribute primaryFunctionStatement : String = "Sense patient movement intent and limb state, compute rehabilitation assistance, and deliver safe torque support to improve human movement.";
        attribute highLevelCyclePeriod : TimeValue = 0.005 [s];

        action acquireHumanState : AcquireHumanState;
        action estimateMovementIntent : EstimateMovementIntent;
        action computeAssistiveCommand : ComputeAssistiveCommand;
        action deliverSafeAssistance : DeliverSafeAssistance;
        action monitorAndLimitRisk : MonitorAndLimitRisk;
    }

    state def RehabilitationOperatingStateMachine {
        state poweredOff;
        state selfTest;
        state standby;
        state calibration;
        state assistActive;
        state paused;
        state safeStop;
        state fault;

        transition initialPowerState first poweredOff;

        transition powerOn
            first poweredOff
            accept PowerOnSignal
            then selfTest;

        transition selfTestPassed
            first selfTest
            accept SelfTestPassedSignal
            then standby;

        transition selfTestFailed
            first selfTest
            accept SelfTestFailedSignal
            then fault;

        transition requestCalibration
            first standby
            accept CalibrationRequestedSignal
            then calibration;

        transition calibrationComplete
            first calibration
            accept CalibrationCompleteSignal
            then standby;

        transition startTherapy
            first standby
            accept TherapyStartSignal
            then assistActive;

        transition pauseTherapy
            first assistActive
            accept TherapyPauseSignal
            then paused;

        transition resumeTherapy
            first paused
            accept TherapyStartSignal
            then assistActive;

        transition stopFromActive
            first assistActive
            accept TherapyStopSignal
            then standby;

        transition stopFromPaused
            first paused
            accept TherapyStopSignal
            then standby;

        transition hazardFromAssist
            first assistActive
            accept HazardDetectedSignal
            then safeStop;

        transition hazardFromCalibration
            first calibration
            accept HazardDetectedSignal
            then safeStop;

        transition hazardCleared
            first safeStop
            accept HazardClearedSignal
            then standby;

        transition powerOffFromStandby
            first standby
            accept PowerOffSignal
            then poweredOff;
    }

    part def BioRoboticRehabilitationAssistant {
        attribute totalMass : MassValue = 19.70 [kg];
        attribute maximumAssistTorque : TorqueValue = 70 [N*m];
        attribute safetyTorqueLimit : TorqueValue = 80 [N*m];
        attribute controlLoopPeriod : TimeValue = 0.005 [s];
        attribute intendedSessionDuration : TimeValue = 1800 [s];
        attribute minimumOperatingEnergy : EnergyValue = 540000 [J];
        attribute patientMassRangeMinimum : MassValue = 45 [kg];
        attribute patientMassRangeMaximum : MassValue = 110 [kg];

        port clinicianCommandIn : ClinicianCommandInPort;
        port patientFeedbackOut : PatientFeedbackOutPort;
        port mechanicalAssistOut : MechanicalAssistSourcePort;

        part bioSignalSensors : BioSignalSensorArray;
        part kinematicSensors : KinematicSensorArray;
        part safetySensors : SafetySensorArray;
        part harness : PatientInterfaceHarness;
        part frame : WearableExoskeletonFrame;
        part actuators : JointActuatorSet;
        part stimulator : NeuromuscularStimulationModule;
        part controller : EmbeddedControlComputer;
        part console : TherapyConsole;
        part powerSubsystem : RechargeablePowerSubsystem;

        connect powerSubsystem.powerOutForSensors to bioSignalSensors.powerIn;
        connect powerSubsystem.powerOutForSensors to kinematicSensors.powerIn;
        connect powerSubsystem.powerOutForSensors to safetySensors.powerIn;
        connect powerSubsystem.powerOutForController to controller.powerIn;
        connect powerSubsystem.powerOutForConsole to console.powerIn;
        connect powerSubsystem.powerOutForActuators to actuators.powerIn;
        connect powerSubsystem.powerOutForActuators to stimulator.powerIn;

        connect bioSignalSensors.intentOut to controller.intentIn;
        connect kinematicSensors.telemetryOut to controller.telemetryIn;
        connect safetySensors.safetyOut to controller.safetyIn;
        connect safetySensors.safetyOut to console.safetyStatusIn;

        connect console.therapyPlanOut to controller.therapyPlanIn;
        connect clinicianCommandIn to console.clinicianCommandIn;

        connect harness.calibrationOut to controller.calibrationDataIn;
        connect harness.feedbackOut to controller.patientFeedbackIn;
        connect harness.feedbackOut to console.patientFeedbackIn;
        connect harness.feedbackOut to patientFeedbackOut;

        connect controller.actuatorCommandOut to actuators.commandIn;
        connect controller.stimulationCommandOut to stimulator.stimulationCommandIn;

        connect actuators.torqueOut to frame.actuatorTorqueIn;
        connect frame.patientTorqueOut to harness.assistIn;
        connect frame.patientTorqueOut to mechanicalAssistOut;
        connect harness.feedbackOut to frame.patientFeedbackIn;
        connect harness.feedbackOut to stimulator.patientFeedbackIn;

        perform action primaryAssistanceFunction : AssistHumanMovement;
        exhibit state operatingState : RehabilitationOperatingStateMachine;

        assert constraint assistTorqueWithinSafetyLimit {
            maximumAssistTorque <= safetyTorqueLimit
        }

        assert constraint controlLoopFastEnoughForHumanInteraction {
            controlLoopPeriod <= 0.010 [s]
        }

        assert constraint batteryEnergySupportsTherapySession {
            powerSubsystem.usableEnergy >= minimumOperatingEnergy
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : BioRoboticRehabilitationAssistant;

        doc /*
            The bio-robotic rehabilitation assistant shall sense patient neuromuscular intent and limb motion,
            interpret the desired movement, and provide controlled mechanical assistance and optional
            neuromuscular stimulation to support safe gait and limb rehabilitation.
        */

        require constraint {
            system.maximumAssistTorque >= 65 [N*m]
        }

        require constraint {
            system.controlLoopPeriod <= 0.010 [s]
        }
    }

    requirement def SafetyRequirement {
        subject system : BioRoboticRehabilitationAssistant;

        doc /*
            The system shall limit delivered assistive torque and enter a safe stop state when a hazard,
            emergency stop, sensor fault, or torque-limit exceedance is detected.
        */

        require constraint {
            system.safetyTorqueLimit <= 80 [N*m]
        }
    }

    requirement def WearabilityRequirement {
        subject system : BioRoboticRehabilitationAssistant;

        doc /*
            The wearable bio-robotic system shall remain portable for supervised rehabilitation use.
        */

        require constraint {
            system.totalMass <= 22 [kg]
        }
    }

    requirement def TherapyEnduranceRequirement {
        subject system : BioRoboticRehabilitationAssistant;

        doc /*
            The power subsystem shall provide sufficient stored energy for a nominal thirty-minute
            rehabilitation session.
        */

        require constraint {
            system.powerSubsystem.usableEnergy >= 540000 [J]
        }
    }

    requirement def HumanCompatibilityRequirement {
        subject system : BioRoboticRehabilitationAssistant;

        doc /*
            The system shall support adult patients within the specified patient mass range.
        */

        require constraint {
            system.patientMassRangeMinimum <= 45 [kg]
        }

        require constraint {
            system.patientMassRangeMaximum >= 110 [kg]
        }
    }

    part bioRoboticRehabilitationAssistant : BioRoboticRehabilitationAssistant;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject system = bioRoboticRehabilitationAssistant;
    }

    requirement safetyRequirement : SafetyRequirement {
        subject system = bioRoboticRehabilitationAssistant;
    }

    requirement wearabilityRequirement : WearabilityRequirement {
        subject system = bioRoboticRehabilitationAssistant;
    }

    requirement therapyEnduranceRequirement : TherapyEnduranceRequirement {
        subject system = bioRoboticRehabilitationAssistant;
    }

    requirement humanCompatibilityRequirement : HumanCompatibilityRequirement {
        subject system = bioRoboticRehabilitationAssistant;
    }
}
