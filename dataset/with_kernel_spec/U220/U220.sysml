package MedicalExaminationTable {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def PositionCommand {
            attribute targetHeight : LengthValue;
            attribute targetTilt : PlaneAngleValue;
        }
        item def PositionFeedback {
            attribute currentHeight : LengthValue;
            attribute currentTilt : PlaneAngleValue;
        }
        item def WeightReading {
            attribute value : MassValue;
        }
        item def MotorCommand;
        item def EmergencyStopSignal;
        item def PowerCutoff;
        item def LowVoltagePower;
        item def ResetSignal;

        port def CommandPort {
            out command : PositionCommand;
        }
        port def FeedbackPort {
            out feedback : PositionFeedback;
        }
        port def WeightPort {
            out weight : WeightReading;
        }
        port def EmergencyPort {
            out stop : EmergencyStopSignal;
        }
        port def MotorCommandPort {
            out command : MotorCommand;
        }
        port def MotorPowerPort {
            in power : LowVoltagePower;
        }
        port def SafetyCutoffPort {
            out cutoff : PowerCutoff;
        }

        part def TableSurface {
            attribute maxLoad : MassValue = 250 [kg];
        }
        part def MechanicalBase;
        part def HeightActuator {
            port cmdIn : MotorCommandPort;
            port powerIn : MotorPowerPort;
            perform action adjustHeight;
        }
        part def TiltActuator {
            port cmdIn : MotorCommandPort;
            port powerIn : MotorPowerPort;
            perform action adjustTilt;
        }
        part def MotionController {
            port cmdIn : CommandPort;
            port feedbackIn : FeedbackPort;
            port heightCmdOut : MotorCommandPort;
            port tiltCmdOut : MotorCommandPort;
            exhibit state operationalStates : TableStates;
        }
        part def OperatorPanel {
            port cmdOut : CommandPort;
        }
        part def PositionSensor {
            port feedbackOut : FeedbackPort;
        }
        part def LoadCell {
            port weightOut : WeightPort;
        }
        part def SafetyController {
            port weightIn : WeightPort;
            port estopIn : EmergencyPort;
            port cutoffOut : SafetyCutoffPort;
        }
        part def EmergencyStopButton {
            port estopOut : EmergencyPort;
        }
        part def PowerSupply {
            port cutoffIn : SafetyCutoffPort;
            port lvPowerOut : MotorPowerPort;
            attribute inputVoltage : ElectricPotentialValue = 230 [V];
            attribute outputVoltage : ElectricPotentialValue = 24 [V];
            attribute powerEnabled : Boolean = true;
        }

        part def ExaminationTable {
            part surface : TableSurface;
            part base : MechanicalBase;
            part heightActuator : HeightActuator;
            part tiltActuator : TiltActuator;
            part motionController : MotionController;
            part operatorPanel : OperatorPanel;
            part positionSensor : PositionSensor;
            part safetyController : SafetyController;
            part loadCell : LoadCell;
            part estopButton : EmergencyStopButton;
            part powerSupply : PowerSupply;

            attribute currentWeight : MassValue;
            attribute currentHeight : LengthValue;
            attribute currentTilt : PlaneAngleValue;
            attribute targetHeight : LengthValue;
            attribute targetTilt : PlaneAngleValue;
            attribute estopActive : Boolean;

            connect operatorPanel.cmdOut to motionController.cmdIn;
            connect positionSensor.feedbackOut to motionController.feedbackIn;
            connect motionController.heightCmdOut to heightActuator.cmdIn;
            connect motionController.tiltCmdOut to tiltActuator.cmdIn;
            connect loadCell.weightOut to safetyController.weightIn;
            connect estopButton.estopOut to safetyController.estopIn;
            connect safetyController.cutoffOut to powerSupply.cutoffIn;
            connect powerSupply.lvPowerOut to heightActuator.powerIn;
            connect powerSupply.lvPowerOut to tiltActuator.powerIn;
        }

        action def CheckWeight { out value : MassValue; }
        action def MoveToTarget;
        action def LockPosition;
        action def CutPower;

        state def TableStates;

        requirement def SafeWeightLimit {
            subject table : ExaminationTable;
            constraint { table.currentWeight <= table.surface.maxLoad }
        }
        requirement def EmergencyStopResponse {
            subject table : ExaminationTable;
            constraint { table.estopActive == true implies table.powerSupply.powerEnabled == false }
        }
        requirement def PositionAccuracy {
            subject table : ExaminationTable;
            constraint { table.currentHeight == table.targetHeight and table.currentTilt == table.targetTilt }
        }
    }

    package Usages {
        private import Definitions::*;

        action 'check weight': CheckWeight { out value; }
        action 'move to target': MoveToTarget;
        action 'lock position': LockPosition;
        action 'cut power': CutPower;

        part examinationTable : ExaminationTable;

        state 'table states': TableStates {
            entry; then idle;
            state idle;
            accept PositionCommand
                then 'checking weight';
            state 'checking weight' {
                entry 'check weight';
            }
            accept when 'check weight'.value <= examinationTable.surface.maxLoad
                then adjusting;
            accept when 'check weight'.value > examinationTable.surface.maxLoad
                then emergency;
            state adjusting {
                entry 'move to target';
            }
            accept when examinationTable.currentHeight == examinationTable.targetHeight
                and examinationTable.currentTilt == examinationTable.targetTilt
                then locked;
            accept EmergencyStopSignal
                then emergency;
            state locked {
                entry 'lock position';
            }
            accept PositionCommand
                then 'checking weight';
            state emergency {
                entry 'cut power';
            }
            accept ResetSignal
                then idle;
        }

        requirement safeWeightLimit : SafeWeightLimit;
        requirement emergencyStopResponse : EmergencyStopResponse;
        requirement positionAccuracy : PositionAccuracy;

        satisfy safeWeightLimit by examinationTable;
        satisfy emergencyStopResponse by examinationTable;
        satisfy positionAccuracy by examinationTable;
    }
}
