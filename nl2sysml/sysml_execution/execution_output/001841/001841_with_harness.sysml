package PumpingSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;

    attribute def FlowRateValue :> Real;
    attribute def PressureValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def PowerValue :> Real;
    attribute def LevelValue :> Real;

    enum def PumpStatus {
        stopped;
        starting;
        running;
        stopping;
        faulted;
    }

    enum def ValveState {
        closed;
        opening;
        open;
        closing;
    }

    item def Fluid {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    port def FluidPort {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }

    port def PowerPort {
        attribute power : PowerValue;
        attribute voltage : Real;
    }

    port def ControlPort {
        attribute commandSignal : Real;
        attribute feedbackSignal : Real;
    }

    part def Motor {
        attribute ratedPower : PowerValue;
        attribute currentSpeed : Real;
        attribute efficiency : Real;
        port powerIn : PowerPort;
        port mechanicalOut;
    }

    part def Impeller {
        attribute diameter : LengthValue;
        attribute bladeCount : Integer;
        attribute rotationalSpeed : Real;
        port mechanicalIn;
    }

    part def Pump {
        attribute maxFlowRate : FlowRateValue;
        attribute maxDischargePressure : PressureValue;
        attribute status : PumpStatus;
        
        part motor : Motor {
            attribute :>> ratedPower = 7500;
            attribute :>> efficiency = 0.92;
        }
        
        part impeller : Impeller {
            attribute :>> diameter = 200 [mm];
            attribute :>> bladeCount = 6;
        }
        
        port inlet : FluidPort;
        port outlet : FluidPort;
        
        connection driveConnection connect motor.mechanicalOut to impeller.mechanicalIn;
    }

    part def Valve {
        attribute state : ValveState;
        attribute maxFlowCapacity : FlowRateValue;
        attribute positionPercent : Real;
        
        port inlet : FluidPort;
        port outlet : FluidPort;
        port control : ControlPort;
    }

    part def Tank {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute currentLevel : LevelValue;
        
        port inlet : FluidPort;
        port outlet : FluidPort;
        
        assert constraint levelConstraint {
            currentLevel == currentVolume / capacity
        }
        
        assert constraint volumeLimit {
            currentVolume <= capacity
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute accuracy : Real;
        
        port sensing : FluidPort;
        port signalOut : ControlPort;
    }

    part def FlowMeter {
        attribute measuredFlowRate : FlowRateValue;
        attribute accuracy : Real;
        
        port sensing : FluidPort;
        port signalOut : ControlPort;
    }

    part def LevelSensor {
        attribute measuredLevel : LevelValue;
        attribute accuracy : Real;
        
        port signalOut : ControlPort;
    }

    part def SystemController {
        attribute targetFlowRate : FlowRateValue;
        attribute targetPressure : PressureValue;
        attribute lowLevelThreshold : LevelValue;
        attribute highLevelThreshold : LevelValue;
        
        port pressureInput : ControlPort;
        port flowInput : ControlPort;
        port sourceLevelInput : ControlPort;
        port destLevelInput : ControlPort;
        port pumpControl : ControlPort;
        port valveControl : ControlPort;
        
        perform action controlLoop : PumpControlLoop;
    }

    action def MonitorConditions {
        in sourceLevelValue : LevelValue;
        in destLevelValue : LevelValue;
        in pressureValue : PressureValue;
        in flowValue : FlowRateValue;
        out canOperate : Boolean;
        out needsAdjustment : Boolean;
    }

    action def StartPump {
        out pumpStatus : PumpStatus;
    }

    action def StopPump {
        out pumpStatus : PumpStatus;
    }

    action def AdjustFlow {
        in currentFlow : FlowRateValue;
        in targetFlow : FlowRateValue;
        out valvePosition : Real;
    }

    action def HandleFault {
        in faultCondition : Boolean;
        out safeState : Boolean;
    }

    action PumpControlLoop {
        in targetFlow : FlowRateValue;
        in targetPressure : PressureValue;
        in lowLevel : LevelValue;
        in highLevel : LevelValue;
        
        first start;
        then merge monitorLoop;
        
        then action monitor : MonitorConditions {
            in sourceLevelValue : LevelValue;
            in destLevelValue : LevelValue;
            in pressureValue : PressureValue;
            in flowValue : FlowRateValue;
            out canOperate : Boolean;
            out needsAdjustment : Boolean;
        }
        
        then decide;
            if monitor.sourceLevelValue <= lowLevel then stopOperation;
            if monitor.destLevelValue >= highLevel then stopOperation;
            if monitor.canOperate and not monitor.needsAdjustment then continueOperation;
            if monitor.canOperate and monitor.needsAdjustment then adjustOperation;
        
        action stopOperation : StopPump {
            out pumpStatus : PumpStatus;
        }
        then monitorLoop;
        
        action continueOperation {
        }
        then monitorLoop;
        
        action adjustOperation : AdjustFlow {
            in currentFlow : FlowRateValue;
            in targetFlow = targetFlow;
            out valvePosition : Real;
        }
        then monitorLoop;
    }

    part pumpingSystem {
        doc /* A fluid transfer system that moves liquid from a source reservoir 
             * to a destination reservoir through controlled pumping action with 
             * continuous monitoring and automatic safety controls.
             */
        
        attribute operatingFlowRate : FlowRateValue = 0.08;
        attribute operatingPressure : PressureValue = 600000;
        attribute minSourceLevel : LevelValue = 0.10;
        attribute maxDestLevel : LevelValue = 0.90;
        
        part sourceReservoir : Tank {
            attribute :>> capacity = 15;
            attribute :>> currentVolume = 12;
        }
        
        part destinationReservoir : Tank {
            attribute :>> capacity = 12;
            attribute :>> currentVolume = 3;
        }
        
        part inletValve : Valve {
            attribute :>> state = ValveState::closed;
            attribute :>> maxFlowCapacity = 0.12;
        }
        
        part mainPump : Pump {
            attribute :>> maxFlowRate = 0.15;
            attribute :>> maxDischargePressure = 800000;
            attribute :>> status = PumpStatus::stopped;
        }
        
        part dischargeValve : Valve {
            attribute :>> state = ValveState::closed;
            attribute :>> maxFlowCapacity = 0.12;
        }
        
        part checkValve : Valve {
            attribute :>> state = ValveState::closed;
            attribute :>> maxFlowCapacity = 0.12;
        }
        
        part dischargePressureSensor : PressureSensor {
            attribute :>> accuracy = 0.02;
        }
        
        part flowMeter : FlowMeter {
            attribute :>> accuracy = 0.015;
        }
        
        part sourceLevelSensor : LevelSensor {
            attribute :>> accuracy = 0.01;
        }
        
        part destLevelSensor : LevelSensor {
            attribute :>> accuracy = 0.01;
        }
        
        part controller : SystemController {
            attribute :>> targetFlowRate = operatingFlowRate;
            attribute :>> targetPressure = operatingPressure;
            attribute :>> lowLevelThreshold = minSourceLevel;
            attribute :>> highLevelThreshold = maxDestLevel;
        }
        
        connection sourceToInlet connect sourceReservoir.outlet to inletValve.inlet;
        connection inletToPump connect inletValve.outlet to mainPump.inlet;
        connection pumpToDischarge connect mainPump.outlet to dischargeValve.inlet;
        connection dischargeToCheck connect dischargeValve.outlet to checkValve.inlet;
        connection checkToDest connect checkValve.outlet to destinationReservoir.inlet;
        
        connection pressureSensing connect dischargePressureSensor.sensing to dischargeValve.outlet;
        connection flowSensing connect flowMeter.sensing to dischargeValve.outlet;
        
        connection pressureMonitoring connect dischargePressureSensor.signalOut to controller.pressureInput;
        connection flowMonitoring connect flowMeter.signalOut to controller.flowInput;
        connection sourceLevelMonitoring connect sourceLevelSensor.signalOut to controller.sourceLevelInput;
        connection destLevelMonitoring connect destLevelSensor.signalOut to controller.destLevelInput;
        
        connection pumpControlSignal connect controller.pumpControl to mainPump.motor.powerIn;
        connection valveControlSignal connect controller.valveControl to dischargeValve.control;
        
        perform action transferFluid : PumpControlLoop {
            in targetFlow = operatingFlowRate;
            in targetPressure = operatingPressure;
            in lowLevel = minSourceLevel;
            in highLevel = maxDestLevel;
        }
    }

    requirement <'REQ-PUMP-001'> primaryFunction {
        doc /* The pumping system shall transfer fluid from the source reservoir 
             * to the destination reservoir by maintaining controlled flow rate 
             * and pressure through continuous monitoring and automated control.
             */
        subject system :>> pumpingSystem;
        
        require flowRateRequirement;
        require pressureRequirement;
        require safetyRequirement;
    }

    requirement <'REQ-PUMP-002'> flowRateRequirement {
        doc /* The system shall maintain a flow rate of 0.08 cubic meters per second
             * with a tolerance of +/- 5 percent during normal operation.
             */
        subject system :>> pumpingSystem;
        
        assert constraint {
            system.flowMeter.measuredFlowRate >= 0.076 and
            system.flowMeter.measuredFlowRate <= 0.084
        }
    }

    requirement <'REQ-PUMP-003'> pressureRequirement {
        doc /* The system shall maintain discharge pressure of 600 kPa
             * with a tolerance of +/- 8 percent at the outlet.
             */
        subject system :>> pumpingSystem;
        
        assert constraint {
            system.dischargePressureSensor.measuredPressure >= 552000 and
            system.dischargePressureSensor.measuredPressure <= 648000
        }
    }

    requirement <'REQ-PUMP-004'> safetyRequirement {
        doc /* The system shall automatically stop pumping when source level 
             * falls below 10 percent or destination level exceeds 90 percent 
             * to prevent damage and overflow.
             */
        subject system :>> pumpingSystem;
        
        assert constraint lowLevelProtection {
            if system.sourceReservoir.currentLevel <= 0.10 
            then system.mainPump.status == PumpStatus::stopped
        }
        
        assert constraint highLevelProtection {
            if system.destinationReservoir.currentLevel >= 0.90 
            then system.mainPump.status == PumpStatus::stopped
        }
    }

    requirement <'REQ-PUMP-005'> pumpCapacityRequirement {
        doc /* The pump shall have sufficient capacity to exceed the maximum
             * required flow rate and pressure with adequate margin.
             */
        subject pump :>> pumpingSystem.mainPump;
        
        assert constraint {
            pump.maxFlowRate >= 0.15 and
            pump.maxDischargePressure >= 800000
        }
    }

    requirement <'REQ-PUMP-006'> reliabilityRequirement {
        doc /* The system shall detect fault conditions and transition to 
             * a safe stopped state to protect equipment and prevent hazards.
             */
        subject system :>> pumpingSystem;
    }

    satisfy primaryFunction by pumpingSystem;
    satisfy flowRateRequirement by pumpingSystem.controller;
    satisfy pressureRequirement by pumpingSystem.controller;
    satisfy safetyRequirement by pumpingSystem.controller;
    satisfy pumpCapacityRequirement by pumpingSystem.mainPump;
    satisfy reliabilityRequirement by pumpingSystem.controller;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    private import PumpingSystemModel::*;
}
