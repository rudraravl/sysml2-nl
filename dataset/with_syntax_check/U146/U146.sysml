package ArcticSunTemperatureManagementSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def TemperatureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def PressureValue :> Real;
    attribute def PowerValue :> Real;
    
    enum def TherapyPhase {
        induction;
        maintenance;
        rewarming;
    }
    
    enum def SystemState {
        standby;
        priming;
        active;
        paused;
        alarm;
        shutdown;
    }
    
    enum def AlarmCondition {
        none;
        temperatureDeviation;
        lowFluidLevel;
        pumpFailure;
        sensorDisconnected;
        overTemperature;
        underTemperature;
    }
    
    item def CoolingFluid {
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
    }
    
    item def Patient {
        attribute coreTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue;
        attribute bodyMass : MassValue;
    }
    
    port def FluidPort {
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def ElectricalPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def SensorPort {
        attribute reading : TemperatureValue;
        attribute timestamp : Real;
    }
    
    port def ControlPort {
        attribute command : Real;
        attribute feedback : Real;
    }
    
    part def TemperatureSensor {
        attribute accuracy : TemperatureValue = 0.1;
        attribute responseTime : TimeValue = 2.0;
        out port sensorOutput : SensorPort;
        
        action sense {
            out measuredTemp : TemperatureValue;
        }
    }
    
    part def FluidReservoir {
        attribute capacity : VolumeValue = 5.0;
        attribute currentLevel : VolumeValue;
        attribute minLevel : VolumeValue = 1.0;
        out port fluidOut : FluidPort;
        
        assert constraint levelCheck {
            currentLevel >= minLevel
        }
    }
    
    part def CirculationPump {
        attribute maxFlowRate : FlowRateValue = 3.0;
        attribute currentSpeed : Real;
        in port fluidIn : FluidPort;
        out port fluidOut : FluidPort;
        in port powerIn : ElectricalPort;
        in port control : ControlPort;
        
        action pumpFluid {
            in commandedSpeed : Real;
            out actualFlowRate : FlowRateValue;
        }
    }
    
    part def HeatExchanger {
        attribute coolingCapacity : PowerValue = 800;
        attribute heatingCapacity : PowerValue = 600;
        attribute setpoint : TemperatureValue;
        in port fluidIn : FluidPort;
        out port fluidOut : FluidPort;
        in port powerIn : ElectricalPort;
        in port control : ControlPort;
        
        action adjustTemperature {
            in targetTemp : TemperatureValue;
            in inletTemp : TemperatureValue;
            out outletTemp : TemperatureValue;
        }
    }
    
    part def CoolingPad {
        attribute surfaceArea : AreaValue = 0.2;
        attribute thermalConductivity : Real;
        in port fluidIn : FluidPort;
        out port fluidOut : FluidPort;
        
        action transferHeat {
            in fluidTemp : TemperatureValue;
            in patientTemp : TemperatureValue;
            out heatTransferRate : PowerValue;
        }
    }
    
    part def ControlModule {
        attribute currentState : SystemState = SystemState::standby;
        attribute currentPhase : TherapyPhase;
        attribute targetTemp : TemperatureValue;
        attribute temperatureTolerance : TemperatureValue = 0.2;
        attribute activeAlarm : AlarmCondition = AlarmCondition::none;
        
        in port patientTempIn : SensorPort;
        in port fluidTempIn : SensorPort;
        in port reservoirLevelIn : SensorPort;
        out port pumpControl : ControlPort;
        out port exchangerControl : ControlPort;
        
        action monitorPatient {
            in currentTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            out tempDelta : TemperatureValue;
        }
        
        action calculateControl {
            in tempDelta : TemperatureValue;
            out pumpSpeed : Real;
            out exchangerSetpoint : TemperatureValue;
        }
        
        action checkAlarms {
            in patientTemp : TemperatureValue;
            in fluidLevel : VolumeValue;
            in systemState : SystemState;
            out alarmStatus : AlarmCondition;
        }
    }
    
    state def ControlStateMachine {
        entry; then init;
        
        state init;
        
        transition init_to_standby
            first init
            then standby;
        
        state standby {
            entry assign currentState = SystemState::standby;
        }
        
        transition standby_to_priming
            first standby
            accept StartTherapy
            then priming;
        
        state priming {
            entry assign currentState = SystemState::priming;
        }
        
        transition priming_to_active
            first priming
            accept PrimingComplete
            then active;
        
        state active {
            entry assign currentState = SystemState::active;
            
            entry; then induction;
            
            state induction {
                entry assign currentPhase = TherapyPhase::induction;
            }
            
            transition induction_to_maintenance
                first induction
                accept TargetReached
                then maintenance;
            
            state maintenance {
                entry assign currentPhase = TherapyPhase::maintenance;
            }
            
            transition maintenance_to_rewarming
                first maintenance
                accept BeginRewarming
                then rewarming;
            
            state rewarming {
                entry assign currentPhase = TherapyPhase::rewarming;
            }
        }
        
        transition active_to_paused
            first active
            accept PauseTherapy
            then paused;
        
        state paused {
            entry assign currentState = SystemState::paused;
        }
        
        transition paused_to_active
            first paused
            accept ResumeTherapy
            then active;
        
        transition any_to_alarm
            first standby
            accept AlarmTriggered
            then alarm;
        
        transition any_to_alarm2
            first priming
            accept AlarmTriggered
            then alarm;
        
        transition any_to_alarm3
            first active
            accept AlarmTriggered
            then alarm;
        
        transition any_to_alarm4
            first paused
            accept AlarmTriggered
            then alarm;
        
        state alarm {
            entry assign currentState = SystemState::alarm;
        }
        
        transition alarm_to_standby
            first alarm
            accept AlarmCleared
            then standby;
        
        transition active_to_shutdown
            first active
            accept StopTherapy
            then shutdown;
        
        state shutdown {
            entry assign currentState = SystemState::shutdown;
        }
    }
    
    part def UserInterface {
        attribute displayedTemp : TemperatureValue;
        attribute displayedPhase : TherapyPhase;
        attribute displayedAlarm : AlarmCondition;
        in port dataIn : ControlPort;
        out port commandOut : ControlPort;
    }
    
    part def PowerSupply {
        attribute inputVoltage : ElectricPotentialValue = 120;
        attribute outputVoltage : ElectricPotentialValue = 24;
        attribute maxCurrent : ElectricCurrentValue = 15;
        attribute batteryBackup : TimeValue = 30;
        out port powerOut : ElectricalPort;
    }
    
    action def TemperatureManagementProtocol {
        in targetTemperature : TemperatureValue;
        in therapyDuration : TimeValue;
        
        first start;
        then merge controlLoop;
        
        then action monitor {
            in currentTemp : TemperatureValue;
            in targetTemp = targetTemperature;
            out tempDelta : TemperatureValue;
        }
        
        then action checkSafety {
            in patientTemp = monitor.currentTemp;
            in fluidLevel : VolumeValue;
            in systemState : SystemState;
            out alarmStatus : AlarmCondition;
        }
        
        then decide;
            if checkSafety.alarmStatus != AlarmCondition::none then handleAlarm;
            if checkSafety.alarmStatus == AlarmCondition::none then regulate;
        
        action handleAlarm {
            in alarm = checkSafety.alarmStatus;
        }
        then controlLoop;
        
        action regulate {
            in tempDelta = monitor.tempDelta;
            out pumpSpeed : Real;
            out exchangerSetpoint : TemperatureValue;
        }
        then controlLoop;
    }
    
    part arcticSunSystem {
        doc /* Arctic Sun Temperature Management System provides precise 
             * control of patient core body temperature through surface 
             * cooling using circulating temperature-controlled water 
             * through gel pads applied to the patient's skin.
             */
        
        attribute systemSerialNumber : String;
        
        part controller : ControlModule {
            attribute :>> targetTemp : TemperatureValue;
            attribute :>> temperatureTolerance = 0.2;
        }
        
        part reservoir : FluidReservoir {
            attribute :>> capacity = 5.0;
            attribute :>> currentLevel = 4.8;
        }
        
        part pump : CirculationPump {
            attribute :>> maxFlowRate = 3.0;
            attribute :>> currentSpeed = 0.0;
        }
        
        part exchanger : HeatExchanger {
            attribute :>> coolingCapacity = 800;
            attribute :>> heatingCapacity = 600;
        }
        
        part pads : CoolingPad[4] {
            attribute :>> surfaceArea = 0.2;
        }
        
        part patientSensor : TemperatureSensor {
            attribute :>> accuracy = 0.1;
        }
        
        part fluidSensor : TemperatureSensor {
            attribute :>> accuracy = 0.2;
        }
        
        part ui : UserInterface;
        
        part power : PowerSupply {
            attribute :>> inputVoltage = 120;
            attribute :>> outputVoltage = 24;
        }
        
        ref item treatedPatient : Patient {
            attribute :>> coreTemperature : TemperatureValue;
            attribute :>> targetTemperature : TemperatureValue;
            attribute :>> bodyMass = 75;
        }
        
        item circulatingFluid : CoolingFluid {
            attribute :>> temperature : TemperatureValue;
            attribute :>> volume = 4.8;
        }
        
        connection fluidCirculation {
            end reservoir.fluidOut;
            end pump.fluidIn;
        }
        
        connection pumpToExchanger {
            end pump.fluidOut;
            end exchanger.fluidIn;
        }
        
        connection exchangerToPads {
            end exchanger.fluidOut;
            end pads.fluidIn;
        }
        
        connection padsToReservoir {
            end pads.fluidOut;
            end reservoir.fluidOut;
        }
        
        connection patientSensorToController {
            end patientSensor.sensorOutput;
            end controller.patientTempIn;
        }
        
        connection fluidSensorToController {
            end fluidSensor.sensorOutput;
            end controller.fluidTempIn;
        }
        
        connection controllerToPump {
            end controller.pumpControl;
            end pump.control;
        }
        
        connection controllerToExchanger {
            end controller.exchangerControl;
            end exchanger.control;
        }
        
        connection powerToPump {
            end power.powerOut;
            end pump.powerIn;
        }
        
        connection powerToExchanger {
            end power.powerOut;
            end exchanger.powerIn;
        }
        
        perform action therapy : TemperatureManagementProtocol;
        
        exhibit state behavior : ControlStateMachine;
    }
    
    requirement <'REQ-AS-100'> therapeuticTemperatureManagement {
        doc /* The Arctic Sun system shall provide controlled therapeutic 
             * temperature management for patients requiring induced 
             * hypothermia, normothermia maintenance, or controlled 
             * rewarming following cardiac arrest, stroke, or traumatic 
             * brain injury.
             */
        subject system :> arcticSunSystem;
        
        require temperatureRangeReq;
        require temperatureAccuracyReq;
        require coolingRateReq;
        require safetyMonitoringReq;
    }
    
    requirement <'REQ-AS-101'> temperatureRangeReq {
        doc /* The system shall maintain patient core temperature within 
             * the range of 32°C to 38°C with a precision of ±0.2°C 
             * during the maintenance phase.
             */
        subject system :> arcticSunSystem;
        
        assert constraint {
            system.treatedPatient.targetTemperature >= 32.0 and
            system.treatedPatient.targetTemperature <= 38.0
        }
    }
    
    requirement <'REQ-AS-102'> temperatureAccuracyReq {
        doc /* Patient temperature monitoring shall have an accuracy of 
             * ±0.1°C to ensure precise therapeutic control.
             */
        subject sensor :> arcticSunSystem.patientSensor;
        
        assert constraint {
            sensor.accuracy <= 0.1
        }
    }
    
    requirement <'REQ-AS-103'> coolingRateReq {
        doc /* The system shall achieve a cooling rate of at least 
             * 1.5°C per hour for a 75 kg patient during the induction 
             * phase.
             */
        subject system :> arcticSunSystem;
    }
    
    requirement <'REQ-AS-104'> safetyMonitoringReq {
        doc /* The system shall continuously monitor patient temperature, 
             * fluid levels, pump operation, and sensor connectivity, 
             * generating alarms for any out-of-range or fault conditions.
             */
        subject controller :> arcticSunSystem.controller;
    }
    
    requirement <'REQ-AS-105'> fluidCapacityReq {
        doc /* The fluid reservoir shall maintain a minimum capacity of 
             * 5 liters to support continuous therapy for at least 24 hours.
             */
        subject reservoir :> arcticSunSystem.reservoir;
        
        assert constraint {
            reservoir.capacity >= 5.0
        }
    }
    
    requirement <'REQ-AS-106'> backupPowerReq {
        doc /* The system shall include battery backup capable of 
             * maintaining operation for at least 30 minutes during 
             * AC power interruption.
             */
        subject power :> arcticSunSystem.power;
        
        assert constraint {
            power.batteryBackup >= 30
        }
    }
    
    requirement <'REQ-AS-107'> surfaceCoverageReq {
        doc /* The cooling pads shall provide a minimum total surface 
             * area of 0.8 m² to ensure effective heat transfer.
             */
        subject pads :> arcticSunSystem.pads;
    }
    
    satisfy therapeuticTemperatureManagement by arcticSunSystem;
}
