package StabilizingUtensilSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQElectromagnetism::*;

    item def TremorData {
        attribute frequency : Real;
        attribute amplitude : Real;
    }

    item def CorrectionCommand {
        attribute pitchAdjust : Real;
        attribute rollAdjust : Real;
    }

    item def ElectricPower {
        attribute voltage : Real;
        attribute current : Real;
    }

    part def ErgonomicHandle;
    part def UtensilAttachment;
    part def Spoon :> UtensilAttachment;
    part def Fork :> UtensilAttachment;

    part def InertialSensor {
        port tremorDataOut {
            out tremorData : TremorData;
        }
        port powerIn {
            in power : ElectricPower;
        }
        action senseTremor {
            out tremor : TremorData;
        }
    }

    part def StabilizationProcessor {
        port tremorDataIn {
            in tremorData : TremorData;
        }
        port commandOut {
            out correctionCommand : CorrectionCommand;
        }
        port powerIn {
            in power : ElectricPower;
        }
        action calculateCorrection {
            in tremor : TremorData;
            out command : CorrectionCommand;
        }
    }

    part def GimbalActuator {
        port commandIn {
            in correctionCommand : CorrectionCommand;
        }
        port powerIn {
            in power : ElectricPower;
        }
        part attachment : UtensilAttachment;
        action actuateGimbal {
            in command : CorrectionCommand;
        }
    }

    part def BatteryPack {
        port powerOut {
            out power : ElectricPower;
        }
        attribute chargeLevel : Real;
        attribute isCharging : Boolean;
    }

    state def UtensilOperationStates {
        attribute tremorAmplitude : Real;
        attribute batteryLevel : Real;
        attribute chargerConnected : Boolean;

        state standby;
        state activeStabilization;
        state lowBattery;
        state charging;

        transition standby_to_active
            from standby to activeStabilization
            when tremorAmplitude > 0;
        transition active_to_standby
            from activeStabilization to standby
            when tremorAmplitude == 0;
        transition standby_to_lowBattery
            from standby to lowBattery
            when batteryLevel < 20;
        transition active_to_lowBattery
            from activeStabilization to lowBattery
            when batteryLevel < 20;
        transition lowBattery_to_charging
            from lowBattery to charging
            when chargerConnected;
        transition charging_to_standby
            from charging to standby
            when batteryLevel >= 100;
    }

    requirement def CancelTremors {
        doc /* The utensil shall actively cancel hand tremors in real-time to keep the utensil attachment level. */
    }

    requirement def SenseTremor {
        doc /* The sensor shall detect tremor frequency and amplitude. */
    }

    requirement def ProcessData {
        doc /* The processor shall calculate correction commands to counteract detected tremors. */
    }

    requirement def ActuateGimbal {
        doc /* The actuator shall move the attachment to counteract tremors and minimize spillage. */
    }

    requirement def ManagePower {
        doc /* The system shall manage power states including standby, active stabilization, low battery, and charging. */
    }

    part def StabilizingUtensil {
        part handle : ErgonomicHandle {
            part inertialSensor : InertialSensor;
            part stabilizationProcessor : StabilizationProcessor;
            part gimbalActuator : GimbalActuator {
                part attachment : UtensilAttachment;
            }
            part batteryPack : BatteryPack;
        }

        exhibit operationStates : UtensilOperationStates;

        flow tremorDataFlow of TremorData
            from handle.inertialSensor.tremorDataOut.tremorData
            to handle.stabilizationProcessor.tremorDataIn.tremorData;

        flow commandFlow of CorrectionCommand
            from handle.stabilizationProcessor.commandOut.correctionCommand
            to handle.gimbalActuator.commandIn.correctionCommand;

        flow powerToSensor of ElectricPower
            from handle.batteryPack.powerOut.power
            to handle.inertialSensor.powerIn.power;

        flow powerToProcessor of ElectricPower
            from handle.batteryPack.powerOut.power
            to handle.stabilizationProcessor.powerIn.power;

        flow powerToActuator of ElectricPower
            from handle.batteryPack.powerOut.power
            to handle.gimbalActuator.powerIn.power;
    }

    part utensilSystem : StabilizingUtensil {
        part :>> handle {
            part :>> gimbalActuator {
                part :>> attachment : Spoon;
            }
        }
    }

    part satisfactionContext {
        ref :>> utensilSystem;
        satisfy requirement req_cancel : CancelTremors by utensilSystem;
        satisfy requirement req_sense : SenseTremor by utensilSystem.handle.inertialSensor;
        satisfy requirement req_process : ProcessData by utensilSystem.handle.stabilizationProcessor;
        satisfy requirement req_actuate : ActuateGimbal by utensilSystem.handle.gimbalActuator;
        satisfy requirement req_power : ManagePower by utensilSystem.handle.batteryPack;
    }
}
