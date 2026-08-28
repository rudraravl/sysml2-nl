package RoboticTechVest {
    attribute def Degrees :> Real;
    attribute def NewtonMeters :> Real;
    attribute def Milliseconds :> Real;
    attribute def Hours :> Real;
    attribute def Percent :> Real;

    item def PostureData {
        attribute spineAngles[5] : Degrees;
        attribute shoulderAngles[2] : Degrees;
    }

    item def TorqueCommand {
        attribute torque : NewtonMeters;
        attribute jointId : Integer;
    }

    item def HapticCommand {
        attribute intensity : Real;
        attribute locationId : Integer;
    }

    item def BatteryStatus {
        attribute chargeLevel : Percent;
    }

    attribute def PowerOn;
    attribute def PowerOff;
    attribute def PostureDeviation;
    attribute def PostureCorrected;
    attribute def LowBattery;
    attribute def BatteryRecovered;

    port def SensorOutPort {
        out item postureData : PostureData;
    }

    port def SensorInPort {
        in item sensorData : PostureData;
    }

    port def ActuatorInPort {
        in item command : TorqueCommand;
    }

    port def ActuatorOutPort {
        out item command : TorqueCommand;
    }

    port def HapticInPort {
        in item command : HapticCommand;
    }

    port def HapticOutPort {
        out item command : HapticCommand;
    }

    port def BatteryOutPort {
        out item status : BatteryStatus;
    }

    port def BatteryInPort {
        in item batteryStatus : BatteryStatus;
    }

    part def PostureSensor {
        port sensorOut : SensorOutPort;
        perform action readPosture {
            out item postureData : PostureData;
            first start;
            then action sampleSensors;
            then action formatData;
            then done;
        }
    }

    part def ExoskeletonActuator {
        port actuatorIn : ActuatorInPort;
        attribute maxTorque : NewtonMeters;
        perform action applyTorque {
            in item command : TorqueCommand;
            first start;
            then action validateSafety;
            then action driveMotor;
            then done;
        }
    }

    part def HapticModule {
        port hapticIn : HapticInPort;
        perform action generateVibration {
            in item command : HapticCommand;
            first start;
            then action setIntensity;
            then action pulse;
            then done;
        }
    }

    part def BatteryModule {
        port batteryOut : BatteryOutPort;
        attribute capacity : Hours = 8 [h];
        attribute lowThreshold : Percent = 20;
        perform action monitorCharge {
            out item status : BatteryStatus;
            first start;
            then action readVoltage;
            then action estimateRemaining;
            then done;
        }
    }

    part def ControlUnit {
        port sensorIn : SensorInPort;
        port batteryIn : BatteryInPort;
        port actuatorOut : ActuatorOutPort;
        port hapticOut : HapticOutPort;
        perform action adaptivePostureControl {
            in item sensorData : PostureData;
            in item batteryStatus : BatteryStatus;
            out item actuatorCommand : TorqueCommand;
            out item hapticCommand : HapticCommand;
            first start;
            then action analyzePosture;
            then action computeCorrection;
            then action checkSafetyLimits;
            then action generateCommands;
            then done;
        }
    }

    part def VestSystem {
        attribute responseTime : Milliseconds = 100 [ms];
        attribute safeTorqueLimit : NewtonMeters = 20 [N*m];

        part spineSensors[5] : PostureSensor;
        part shoulderSensors[2] : PostureSensor;
        part spineActuators[5] : ExoskeletonActuator {
            :>> maxTorque = 10 [N*m];
        }
        part shoulderActuators[2] : ExoskeletonActuator {
            :>> maxTorque = 5 [N*m];
        }
        part hipActuators[2] : ExoskeletonActuator {
            :>> maxTorque = 15 [N*m];
        }
        part hapticModules[6] : HapticModule;
        part battery : BatteryModule;
        part controlUnit : ControlUnit;

        connect spineSensors.sensorOut to controlUnit.sensorIn;
        connect shoulderSensors.sensorOut to controlUnit.sensorIn;
        connect battery.batteryOut to controlUnit.batteryIn;
        connect controlUnit.actuatorOut to spineActuators.actuatorIn;
        connect controlUnit.actuatorOut to shoulderActuators.actuatorIn;
        connect controlUnit.actuatorOut to hipActuators.actuatorIn;
        connect controlUnit.hapticOut to hapticModules.hapticIn;

        state vestStates {
            entry; then standby;
            state standby {
                do action awaitActivation;
            }
            transition first standby accept PowerOn then activeMonitoring;
            state activeMonitoring {
                do action monitorPosture;
            }
            transition first activeMonitoring accept PostureDeviation then supporting;
            transition first activeMonitoring accept LowBattery then lowPower;
            state supporting {
                do action provideSupport;
            }
            transition first supporting accept PostureCorrected then activeMonitoring;
            state lowPower {
                do action conserveEnergy;
            }
            transition first lowPower accept BatteryRecovered then activeMonitoring;
            transition first standby accept PowerOff then done;
        }
    }

    requirement def RapidResponseRequirement {
        doc /* The system shall respond to postural deviation within 100 milliseconds from detection to actuator support. */
        attribute maxResponseTime : Milliseconds = 100 [ms];
    }

    requirement def SafetyLimitRequirement {
        doc /* Actuator torque shall not exceed built-in safety limits to prevent injury to the user. */
        attribute maxSafeTorque : NewtonMeters = 20 [N*m];
    }

    requirement def BatteryLifeRequirement {
        doc /* The rechargeable battery module shall support at least 8 hours of continuous operation. */
        attribute minOperationTime : Hours = 8 [h];
    }

    part roboticTechVest : VestSystem;

    requirement rapidResponseReq : RapidResponseRequirement;
    requirement safetyLimitReq : SafetyLimitRequirement;
    requirement batteryLifeReq : BatteryLifeRequirement;

    satisfy rapidResponseReq by roboticTechVest;
    satisfy safetyLimitReq by roboticTechVest.spineActuators;
    satisfy safetyLimitReq by roboticTechVest.shoulderActuators;
    satisfy safetyLimitReq by roboticTechVest.hipActuators;
    satisfy batteryLifeReq by roboticTechVest.battery;
}
