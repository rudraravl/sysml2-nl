package BioroboticProsthesis {
    private import ScalarValues::*;
    
    value def ElectricPotential : Real { unit = 'V'; }
    value def ElectricCurrent : Real { unit = 'A'; }
    value def ElectricCharge : Real { unit = 'A*h'; }
    value def Frequency : Real { unit = 'Hz'; }
    value def Torque : Real { unit = 'N*m'; }
    value def Angle : Real { unit = 'deg'; }
    value def AngularVelocity : Real { unit = 'deg/s'; }
    value def Force : Real { unit = 'N'; }
    
    enum def ActionKind {
        none;
        grasp;
        flexJoint;
        extend;
        rotate;
    }
    
    item def NeuralSignal {
        attribute voltage : ElectricPotential;
        attribute frequency : Frequency;
    }
    
    item def MotorIntent {
        attribute actionType : ActionKind;
        attribute intensity : Real;
    }
    
    item def ActuatorCommand {
        attribute torque : Torque;
    }
    
    item def ProprioceptiveFeedback {
        attribute jointAngle : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute force : Force;
    }
    
    item def SafetyStatus {
        attribute isSafe : Boolean;
        attribute limitExceeded : Boolean;
    }
    
    item def PowerSupply {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }
    
    part def NeuralSensor {
        port signalOut { out signal : NeuralSignal; }
        port powerIn { in power : PowerSupply; }
        perform action senseSignals {
            in power : PowerSupply;
            out signal : NeuralSignal;
            first start;
            then action acquire;
            then action filterSignal;
            then done;
        }
    }
    
    part def SignalProcessor {
        port signalIn { in signal : NeuralSignal; }
        port intentOut { out intent : MotorIntent; }
        port powerIn { in power : PowerSupply; }
        perform action decodeIntent {
            in signal : NeuralSignal;
            out intent : MotorIntent;
            first start;
            then action filterNoise;
            then action extractFeatures;
            then action classifyIntent;
            then done;
        }
    }
    
    state def ControlStates {
        state startUp;
        state standby;
        state activeControl;
        state failSafe;
        transition initial to startUp;
        transition startUp to standby when (true);
        transition standby to activeControl when (intent.actionType != ActionKind::none);
        transition activeControl to standby when (intent.actionType == ActionKind::none);
        transition activeControl to failSafe when (safetyStatus.isSafe == false);
        transition standby to failSafe when (safetyStatus.isSafe == false);
        transition failSafe to standby when (safetyStatus.isSafe == true);
    }
    
    part def ControlUnit {
        port intentIn { in intent : MotorIntent; }
        port feedbackIn { in feedback : ProprioceptiveFeedback; }
        port safetyStatusIn { in safetyStatus : SafetyStatus; }
        port commandOut { out command : ActuatorCommand; }
        port powerIn { in power : PowerSupply; }
        exhibit ControlStates {
            in intent = intentIn.intent;
            in feedback = feedbackIn.feedback;
            in safetyStatus = safetyStatusIn.safetyStatus;
            out command = commandOut.command;
        }
        perform action calculateCommands {
            in intent : MotorIntent;
            in feedback : ProprioceptiveFeedback;
            in safetyStatus : SafetyStatus;
            out command : ActuatorCommand;
            first start;
            then action combineIntentAndFeedback;
            then action computeTorque;
            then done;
        }
    }
    
    part def BionicActuator {
        port commandIn { in command : ActuatorCommand; }
        port feedbackOut { out feedback : ProprioceptiveFeedback; }
        port powerIn { in power : PowerSupply; }
        perform action generateMotion {
            in command : ActuatorCommand;
            in power : PowerSupply;
            out feedback : ProprioceptiveFeedback;
            first start;
            then action applyTorque;
            then action measureJointState;
            then done;
        }
    }
    
    part def SafetyMonitor {
        port feedbackIn { in feedback : ProprioceptiveFeedback; }
        port statusOut { out safetyStatus : SafetyStatus; }
        port powerIn { in power : PowerSupply; }
        perform action monitorSafety {
            in feedback : ProprioceptiveFeedback;
            out safetyStatus : SafetyStatus;
            first start;
            then action checkJointLimits;
            then action checkForceLimits;
            then action evaluateSafety;
            then done;
        }
    }
    
    part def PowerManagement {
        port powerIn { in power : PowerSupply; }
        port powerOut { out power : PowerSupply; }
        port safetyIn { in safetyStatus : SafetyStatus; }
        perform action distributePower {
            in power : PowerSupply;
            in safetyStatus : SafetyStatus;
            out power : PowerSupply;
            first start;
            then action monitorBattery;
            then action regulateVoltage;
            then done;
        }
    }
    
    part def Battery {
        port powerOut { out power : PowerSupply; }
        attribute capacity : ElectricCharge;
        perform action providePower {
            out power : PowerSupply;
            first start;
            then action discharge;
            then done;
        }
    }
    
    part def BioroboticLimb {
        part neuralSensor : NeuralSensor;
        part signalProcessor : SignalProcessor;
        part controlUnit : ControlUnit;
        part bionicActuators[5] : BionicActuator;
        part safetyMonitor : SafetyMonitor;
        part powerManagement : PowerManagement;
        part battery : Battery;
        
        connect battery.powerOut to powerManagement.powerIn;
        connect powerManagement.powerOut to neuralSensor.powerIn;
        connect powerManagement.powerOut to signalProcessor.powerIn;
        connect powerManagement.powerOut to controlUnit.powerIn;
        connect powerManagement.powerOut to bionicActuators.powerIn;
        connect powerManagement.powerOut to safetyMonitor.powerIn;
        
        connect neuralSensor.signalOut to signalProcessor.signalIn;
        connect signalProcessor.intentOut to controlUnit.intentIn;
        connect controlUnit.commandOut to bionicActuators.commandIn;
        connect bionicActuators.feedbackOut to controlUnit.feedbackIn;
        connect bionicActuators.feedbackOut to safetyMonitor.feedbackIn;
        connect safetyMonitor.statusOut to controlUnit.safetyStatusIn;
        connect safetyMonitor.statusOut to powerManagement.safetyIn;
        
        flow neuralSignalFlow of NeuralSignal from neuralSensor.signalOut.signal to signalProcessor.signalIn.signal;
        flow motorIntentFlow of MotorIntent from signalProcessor.intentOut.intent to controlUnit.intentIn.intent;
        flow commandFlow of ActuatorCommand from controlUnit.commandOut.command to bionicActuators.commandIn.command;
        flow feedbackFlow of ProprioceptiveFeedback from bionicActuators.feedbackOut.feedback to controlUnit.feedbackIn.feedback;
        flow safetyFeedbackFlow of ProprioceptiveFeedback from bionicActuators.feedbackOut.feedback to safetyMonitor.feedbackIn.feedback;
        flow safetyStatusFlow of SafetyStatus from safetyMonitor.statusOut.safetyStatus to controlUnit.safetyStatusIn.safetyStatus;
        flow powerSafetyFlow of SafetyStatus from safetyMonitor.statusOut.safetyStatus to powerManagement.safetyIn.safetyStatus;
        flow powerFlow of PowerSupply from battery.powerOut.power to powerManagement.powerIn.power;
        flow distributedPowerFlow1 of PowerSupply from powerManagement.powerOut.power to neuralSensor.powerIn.power;
        flow distributedPowerFlow2 of PowerSupply from powerManagement.powerOut.power to signalProcessor.powerIn.power;
        flow distributedPowerFlow3 of PowerSupply from powerManagement.powerOut.power to controlUnit.powerIn.power;
        flow distributedPowerFlow4 of PowerSupply from powerManagement.powerOut.power to bionicActuators.powerIn.power;
        flow distributedPowerFlow5 of PowerSupply from powerManagement.powerOut.power to safetyMonitor.powerIn.power;
    }
    
    requirement def RestoreMotorFunction {
        doc "The prosthesis shall restore motor function for individuals with paralysis or limb loss.";
        subject prosthesis : BioroboticLimb;
    }
    
    requirement def DecodeBioelectricSignals {
        doc "The signal processor shall decode bioelectric signals to determine user motor intent.";
        subject processor : SignalProcessor;
    }
    
    requirement def EnsureSafeOperation {
        doc "The safety monitor shall ensure limb movements and forces stay within safe limits.";
        subject monitor : SafetyMonitor;
    }
    
    requirement def ProvideContinuousPower {
        doc "Power management shall distribute electricity from a rechargeable battery to all electronic components.";
        subject power : PowerManagement;
    }
    
    requirement def ProvideCoordinatedMotion {
        doc "The control unit shall combine motor intent with proprioceptive feedback to produce coordinated motor commands.";
        subject controller : ControlUnit;
    }
    
    part bioroboticLimb : BioroboticLimb;
    
    requirement restoreMotorFunction : RestoreMotorFunction {
        subject prosthesis = bioroboticLimb;
    }
    
    requirement decodeBioelectricSignals : DecodeBioelectricSignals {
        subject processor = bioroboticLimb.signalProcessor;
    }
    
    requirement ensureSafeOperation : EnsureSafeOperation {
        subject monitor = bioroboticLimb.safetyMonitor;
    }
    
    requirement provideContinuousPower : ProvideContinuousPower {
        subject power = bioroboticLimb.powerManagement;
    }
    
    requirement provideCoordinatedMotion : ProvideCoordinatedMotion {
        subject controller = bioroboticLimb.controlUnit;
    }
}
