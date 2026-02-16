package EucomedMedicalDeviceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def FlowRateValue :> ISQ::VolumeValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def ConcentrationValue {
        attribute value : Real;
        attribute unit : String = "mg/mL";
    }
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;

    enum def DeviceState {
        enum off;
        enum standby;
        enum priming;
        enum delivering;
        enum paused;
        enum alarming;
        enum maintenance;
    }

    enum def AlarmType {
        enum occlusion;
        enum airInLine;
        enum emptyReservoir;
        enum batteryLow;
        enum systemError;
    }

    item def TherapeuticFluid {
        attribute concentration : ConcentrationValue;
        attribute temperature : TemperatureValue;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }

    port def FluidInputPort {
        in fluidSupply : TherapeuticFluid;
    }

    port def FluidOutputPort {
        out fluidDelivery : TherapeuticFluid;
        out deliveryPressure : PressureValue;
    }

    port def PowerInputPort {
        in mainsPower : ElectricalPower;
    }

    port def UserInterfacePort {
        in programmedFlowRate : FlowRateValue;
        in programmedVolume : VolumeValue;
        in startCommand : Boolean;
        in stopCommand : Boolean;
        out currentStatus : DeviceState;
        out deliveredVolume : VolumeValue;
        out activeAlarms : AlarmType[*];
    }

    port def SensorDataPort {
        out measuredPressure : PressureValue;
        out measuredFlowRate : FlowRateValue;
        out airDetected : Boolean;
        out fluidLevel : VolumeValue;
    }

    part def PumpingMechanism {
        doc /* Peristaltic or syringe-based mechanism for precise fluid delivery */
        
        attribute motorSpeed : ISQ::AngularVelocityValue;
        attribute strokeVolume : VolumeValue;
        
        port motorControl;
        port fluidIn : FluidInputPort;
        port fluidOut : FluidOutputPort;
    }

    part def PressureSensor {
        attribute measurementRange : PressureValue;
        attribute accuracy : Real = 0.02;
        
        port fluidLine;
        port pressureData : ~SensorDataPort;
    }

    part def FlowSensor {
        attribute measurementRange : FlowRateValue;
        attribute resolution : FlowRateValue;
        
        port fluidLine;
        port flowData : ~SensorDataPort;
    }

    part def AirDetector {
        attribute sensitivity : Real = 0.05;
        
        port fluidLine;
        port airData : ~SensorDataPort;
    }

    part def ReservoirSensor {
        attribute capacity : VolumeValue;
        
        port reservoir;
        port levelData : ~SensorDataPort;
    }

    part def ControlProcessor {
        doc /* Microprocessor-based control unit managing all device functions */
        
        attribute processingFrequency : ISQ::FrequencyValue;
        attribute memoryCapacity : Real;
        
        port sensorInputs : SensorDataPort;
        port userInterface : UserInterfacePort;
        port pumpControl;
        port alarmControl;
    }

    part def AlarmSubsystem {
        attribute alarmVolume : Real;
        attribute visualIndicators : Boolean;
        
        port alarmTrigger;
        port alarmStatus : ~UserInterfacePort;
    }

    part def PowerManagement {
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute batteryLevel : Real;
        
        port powerIn : PowerInputPort;
        port powerOut;
        port batteryStatus : ~SensorDataPort;
    }

    part def FluidReservoir {
        attribute maxCapacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        
        port fluidInput : FluidInputPort;
        port fluidOutput : ~FluidInputPort;
        port levelSensor : ~SensorDataPort;
    }

    part def InfusionPump {
        doc /* 
         * Medical infusion pump system compliant with Eucomed standards for safe 
         * and accurate delivery of therapeutic fluids to patients. The device 
         * provides controlled administration of medications, nutrients, or other 
         * fluids at precise flow rates with comprehensive safety monitoring.
         */
        
        attribute targetFlowRate : FlowRateValue;
        attribute targetVolume : VolumeValue;
        attribute deliveredVolume : VolumeValue;
        attribute currentState : DeviceState;
        
        port fluidIntake : FluidInputPort;
        port patientDelivery : FluidOutputPort;
        port powerSupply : PowerInputPort;
        port userControl : UserInterfacePort;
        
        part reservoir : FluidReservoir {
            attribute :>> maxCapacity = 500.0 [SI::mL];
        }
        
        part pumpMechanism : PumpingMechanism;
        
        part pressureMonitor : PressureSensor {
            attribute :>> measurementRange = 1000.0 [SI::Pa];
        }
        
        part flowMonitor : FlowSensor {
            attribute :>> measurementRange = 1000.0 [SI::mL];
            attribute :>> resolution = 0.1 [SI::mL];
        }
        
        part airSensor : AirDetector;
        
        part levelSensor : ReservoirSensor {
            attribute :>> capacity = 500.0 [SI::mL];
        }
        
        part controller : ControlProcessor {
            attribute :>> processingFrequency = 100.0 [SI::Hz];
        }
        
        part alarmSystem : AlarmSubsystem;
        
        part powerUnit : PowerManagement {
            attribute :>> batteryCapacity = 50.0 [SI::J];
        }
        
        connect fluidIntake to reservoir.fluidInput;
        connect reservoir.fluidOutput to pumpMechanism.fluidIn;
        connect pumpMechanism.fluidOut to pressureMonitor.fluidLine;
        connect pressureMonitor.fluidLine to flowMonitor.fluidLine;
        connect flowMonitor.fluidLine to airSensor.fluidLine;
        connect airSensor.fluidLine to patientDelivery;
        
        connect reservoir.levelSensor to levelSensor.reservoir;
        
        connect pressureMonitor.pressureData to controller.sensorInputs;
        connect flowMonitor.flowData to controller.sensorInputs;
        connect airSensor.airData to controller.sensorInputs;
        connect levelSensor.levelData to controller.sensorInputs;
        
        connect controller.userInterface to userControl;
        connect controller.pumpControl to pumpMechanism.motorControl;
        connect controller.alarmControl to alarmSystem.alarmTrigger;
        connect alarmSystem.alarmStatus to userControl;
        
        connect powerSupply to powerUnit.powerIn;
        connect powerUnit.powerOut to controller;
        connect powerUnit.powerOut to pumpMechanism;
        connect powerUnit.batteryStatus to controller.sensorInputs;
    }

    action def InitializeSystem {
        out systemReady : Boolean;
    }

    action def PrimeFluidPath {
        in flowRate : FlowRateValue;
        out pathPrimed : Boolean;
    }

    action def MonitorDelivery {
        in targetFlow : FlowRateValue;
        in measuredFlow : FlowRateValue;
        in measuredPressure : PressureValue;
        out flowError : FlowRateValue;
        out occlusionDetected : Boolean;
    }

    action def AdjustPumpSpeed {
        in flowError : FlowRateValue;
        out motorSpeed : ISQ::AngularVelocityValue;
    }

    action def CheckSafetyConditions {
        in pressure : PressureValue;
        in airPresent : Boolean;
        in fluidLevel : VolumeValue;
        in batteryLevel : Real;
        out alarms : AlarmType[*];
    }

    action def DeliverTherapeuticFluid {
        doc /* 
         * Primary function: Continuously deliver therapeutic fluid to a patient 
         * at a precisely controlled flow rate while monitoring for safety conditions 
         * including occlusions, air in line, and reservoir depletion.
         */
        
        in prescribedFlowRate : FlowRateValue;
        in prescribedVolume : VolumeValue;
        out totalDelivered : VolumeValue;
        out safetyAlarms : AlarmType[*];
        
        private attribute accumulatedVolume : VolumeValue := 0.0 [SI::mL];
        private attribute currentPressure : PressureValue;
        private attribute currentFlow : FlowRateValue;
        private attribute alarmsEmpty : Boolean;
        
        first start;
        then action initialize : InitializeSystem {
            out systemReady;
        }
        
        then action prime : PrimeFluidPath {
            in flowRate = 100.0 [SI::mL];
            out pathPrimed;
        }
        
        then merge deliveryLoop;
        
        action monitor : MonitorDelivery {
            in targetFlow = prescribedFlowRate;
            in measuredFlow = currentFlow;
            in measuredPressure = currentPressure;
            out flowError;
            out occlusionDetected;
        }
        
        then action adjust : AdjustPumpSpeed {
            in flowError = monitor.flowError;
            out motorSpeed;
        }
        
        then action checkSafety : CheckSafetyConditions {
            in pressure = currentPressure;
            in airPresent;
            in fluidLevel;
            in batteryLevel;
            out alarms;
        }
        
        then decide;
            if alarmsEmpty and accumulatedVolume < prescribedVolume 
                then continueDelivery;
            if not alarmsEmpty 
                then handleAlarm;
            if accumulatedVolume >= prescribedVolume 
                then completeDelivery;
        
        action continueDelivery {
            assign accumulatedVolume := accumulatedVolume + currentFlow;
        }
        then deliveryLoop;
        
        action handleAlarm {
            assign safetyAlarms := checkSafety.alarms;
        }
        then done;
        
        action completeDelivery {
            assign totalDelivered := accumulatedVolume;
        }
        then done;
    }

    state def InfusionPumpStateMachine {
        entry; then powerOff;
        
        state powerOff;
        
        accept powerOn;
        then selfTest;
        
        state selfTest {
            do action runDiagnostics;
        }
        
        accept testPassed;
        then standby;
        
        state standby {
            accept programReceived;
            then priming;
        }
        
        state priming {
            do action primePath : PrimeFluidPath;
            
            accept primingComplete;
            then ready;
        }
        
        state ready {
            accept startInfusion;
            then delivering;
        }
        
        state delivering {
            do action deliverFluid : DeliverTherapeuticFluid;
            
            accept pausePressed;
            then paused;
            
            accept alarmCondition;
            then alarm;
            
            accept volumeComplete;
            then standby;
        }
        
        state paused {
            accept resumePressed;
            then delivering;
            
            accept stopPressed;
            then standby;
        }
        
        state alarm {
            do action activateAlarm;
            
            accept alarmCleared;
            then delivering;
            
            accept alarmSilenced;
            then standby;
        }
        
        accept maintenanceMode;
        then maintenance;
        
        state maintenance {
            accept maintenanceComplete;
            then standby;
        }
    }

    action def runDiagnostics;
    action def activateAlarm;

    requirement def AccuracyRequirement {
        doc /* 
         * The infusion pump shall deliver fluid volume with an accuracy of ±5% 
         * of the programmed volume over the full operating range.
         */
        
        subject pump : InfusionPump;
    }

    requirement def OcclusionDetectionRequirement {
        doc /* 
         * The system shall detect downstream occlusions when pressure exceeds 
         * 500 kPa and trigger an alarm within 30 seconds.
         */
        
        subject monitor : PressureSensor;
    }

    requirement def AirDetectionRequirement {
        doc /* 
         * The system shall detect air bubbles greater than 50 microliters in 
         * the fluid path and halt delivery immediately.
         */
        
        subject detector : AirDetector;
    }

    requirement def BatteryBackupRequirement {
        doc /* 
         * The device shall operate for a minimum of 4 hours on battery power 
         * at typical flow rates.
         */
        
        subject power : PowerManagement;
    }

    requirement def FlowRateRangeRequirement {
        doc /* 
         * The pump shall support programmable flow rates from 0.1 mL/h to 
         * 1000 mL/h with 0.1 mL/h resolution.
         */
        
        subject sensor : FlowSensor;
    }

    part eucomedInfusionSystem : InfusionPump {
        attribute :>> targetFlowRate = 125.0 [SI::mL];
        attribute :>> targetVolume = 1000.0 [SI::mL];
        
        perform action therapeuticDelivery : DeliverTherapeuticFluid {
            in prescribedFlowRate = targetFlowRate;
            in prescribedVolume = targetVolume;
            out totalDelivered;
            out safetyAlarms;
        }
        
        exhibit state operatingBehavior : InfusionPumpStateMachine;
        
        satisfy accuracyReq : AccuracyRequirement;
        satisfy occlusionReq : OcclusionDetectionRequirement;
        satisfy airReq : AirDetectionRequirement;
        satisfy batteryReq : BatteryBackupRequirement;
        satisfy flowReq : FlowRateRangeRequirement;
    }
}
