package ProgrammableCommunicatingThermostatSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityLevel :> Real;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def OccupancyState :> Boolean;
    
    enum def HVACMode {
        off;
        heating;
        cooling;
        fan;
        auto;
    }
    
    enum def DayOfWeek {
        monday;
        tuesday;
        wednesday;
        thursday;
        friday;
        saturday;
        sunday;
    }
    
    attribute def ScheduleEntry {
        attribute day : DayOfWeek;
        attribute startTime : TimeValue;
        attribute endTime : TimeValue;
        attribute setpoint : TemperatureSetpoint;
    }
    
    attribute def NetworkCommand {
        attribute commandType : String;
        attribute targetSetpoint : TemperatureSetpoint;
        attribute timestamp : TimeValue;
    }
    
    attribute def StatusReport {
        attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        attribute currentMode : HVACMode;
        attribute setpoint : TemperatureSetpoint;
        attribute timestamp : TimeValue;
    }
    
    port def EnvironmentSensorPort {
        out temperature : ISQ::ThermodynamicTemperatureValue;
        out humidity : HumidityLevel;
        out occupancy : OccupancyState;
    }
    
    port def HVACControlPort {
        out mode : HVACMode;
        out heatingDemand : Real;
        out coolingDemand : Real;
        out fanSpeed : Real;
        in acknowledgment : Boolean;
    }
    
    port def NetworkCommunicationPort {
        in remoteCommand : NetworkCommand;
        out statusUpdate : StatusReport;
    }
    
    port def UserInterfacePort {
        in manualSetpoint : TemperatureSetpoint;
        in scheduleEntry : ScheduleEntry;
        out displayTemperature : ISQ::ThermodynamicTemperatureValue;
        out displayMode : HVACMode;
    }
    
    part def TemperatureSensor {
        port output {
            out measuredTemperature : ISQ::ThermodynamicTemperatureValue;
        }
        
        action def MeasureTemperature {
            out temperature : ISQ::ThermodynamicTemperatureValue;
        }
    }
    
    part def HumiditySensor {
        port output {
            out measuredHumidity : HumidityLevel;
        }
        
        action def MeasureHumidity {
            out humidity : HumidityLevel;
        }
    }
    
    part def OccupancySensor {
        port output {
            out occupancyDetected : OccupancyState;
        }
        
        action def DetectOccupancy {
            out occupied : OccupancyState;
        }
    }
    
    part def HVACEquipment {
        port controlInterface : ~HVACControlPort;
        
        part furnace {
            attribute heatingCapacity : ISQ::PowerValue;
        }
        
        part airConditioner {
            attribute coolingCapacity : ISQ::PowerValue;
        }
        
        part blower {
            attribute maxAirflow : Real;
        }
    }
    
    part def NetworkModule {
        attribute ipAddress : String;
        port networkInterface : NetworkCommunicationPort;
        
        action def ReceiveCommand {
            in command : NetworkCommand;
            out processedSetpoint : TemperatureSetpoint;
        }
        
        action def TransmitStatus {
            in status : StatusReport;
            out transmitted : Boolean;
        }
    }
    
    part def UserDisplay {
        port displayInterface : UserInterfacePort;
        
        action def UpdateDisplay {
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            in currentMode : HVACMode;
            out displayRefreshed : Boolean;
        }
    }
    
    part def ScheduleController {
        attribute weeklySchedule : ScheduleEntry[*];
        
        action def EvaluateSchedule {
            in currentTime : TimeValue;
            in currentDay : DayOfWeek;
            in schedule : ScheduleEntry[*];
            out activeSetpoint : TemperatureSetpoint;
        }
        
        action def UpdateSchedule {
            in newEntry : ScheduleEntry;
            out scheduleUpdated : Boolean;
        }
    }
    
    part def ControlLogic {
        attribute temperatureDeadband : ISQ::ThermodynamicTemperatureValue;
        attribute currentMode : HVACMode;
        
        action def DetermineHVACMode {
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            in targetTemp : TemperatureSetpoint;
            in deadband : ISQ::ThermodynamicTemperatureValue;
            out mode : HVACMode;
            out heatingLevel : Real;
            out coolingLevel : Real;
        }
    }
    
    part def ProgrammableCommunicatingThermostat {
        doc /* A programmable communicating thermostat that automatically maintains 
               indoor climate comfort by controlling HVAC equipment based on programmed 
               schedules, real-time sensor data, manual user input, and remote network 
               commands. The system optimizes energy efficiency while ensuring occupant 
               comfort through intelligent temperature regulation. */
        
        attribute deviceID : String;
        attribute firmwareVersion : String;
        attribute activeSetpoint : TemperatureSetpoint;
        attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute operatingMode : HVACMode;
        
        port environmentSensors : EnvironmentSensorPort;
        port hvacControl : HVACControlPort;
        port networkComm : NetworkCommunicationPort;
        port userInterface : UserInterfacePort;
        
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part occupancySensor : OccupancySensor;
        part scheduleController : ScheduleController;
        part controlLogic : ControlLogic;
        part networkModule : NetworkModule;
        part display : UserDisplay;
        
        connect tempSensor.output.measuredTemperature to environmentSensors.temperature;
        connect humiditySensor.output.measuredHumidity to environmentSensors.humidity;
        connect occupancySensor.output.occupancyDetected to environmentSensors.occupancy;
        connect networkModule.networkInterface to networkComm;
        connect display.displayInterface to userInterface;
        
        state machine ThermostatStateMachine {
            initial state Initializing;
            
            state Monitoring {
                entry action sampleSensors {
                    perform action readTemp {
                        out temp : ISQ::ThermodynamicTemperatureValue;
                    }
                    then assign currentTemperature := readTemp.temp;
                }
            }
            
            state EvaluatingSetpoint {
                entry action determineTarget {
                    perform action checkSchedule : ScheduleController::EvaluateSchedule {
                        in currentTime : TimeValue;
                        in currentDay : DayOfWeek;
                        in schedule = scheduleController.weeklySchedule;
                        out activeSetpoint : TemperatureSetpoint;
                    }
                    then decide;
                        if networkComm.remoteCommand != null then processRemote;
                        if userInterface.manualSetpoint != null then processManual;
                        else useScheduled;
                    
                    action processRemote {
                        perform action applyRemote : NetworkModule::ReceiveCommand {
                            in command = networkComm.remoteCommand;
                            out processedSetpoint : TemperatureSetpoint;
                        }
                        then assign activeSetpoint := applyRemote.processedSetpoint;
                    }
                    
                    action processManual {
                        assign activeSetpoint := userInterface.manualSetpoint;
                    }
                    
                    action useScheduled {
                        assign activeSetpoint := checkSchedule.activeSetpoint;
                    }
                }
            }
            
            state ControllingHVAC {
                entry action computeControl {
                    perform action calculateMode : ControlLogic::DetermineHVACMode {
                        in currentTemp = currentTemperature;
                        in targetTemp = activeSetpoint;
                        in deadband = controlLogic.temperatureDeadband;
                        out mode : HVACMode;
                        out heatingLevel : Real;
                        out coolingLevel : Real;
                    }
                    then assign operatingMode := calculateMode.mode;
                    then assign hvacControl.mode := calculateMode.mode;
                    then assign hvacControl.heatingDemand := calculateMode.heatingLevel;
                    then assign hvacControl.coolingDemand := calculateMode.coolingLevel;
                }
            }
            
            state ReportingStatus {
                entry action sendStatus {
                    perform action transmit : NetworkModule::TransmitStatus {
                        in status : StatusReport {
                            attribute currentTemp = currentTemperature;
                            attribute currentMode = operatingMode;
                            attribute setpoint = activeSetpoint;
                            attribute timestamp : TimeValue;
                        }
                        out transmitted : Boolean;
                    }
                    then perform action updateUI : UserDisplay::UpdateDisplay {
                        in currentTemp = currentTemperature;
                        in currentMode = operatingMode;
                        out displayRefreshed : Boolean;
                    }
                }
            }
            
            transition from Initializing to Monitoring;
            transition from Monitoring to EvaluatingSetpoint;
            transition from EvaluatingSetpoint to ControllingHVAC;
            transition from ControllingHVAC to ReportingStatus;
            transition from ReportingStatus to Monitoring;
        }
        
        perform action regulateClimate {
            first start;
            then merge controlCycle;
            
            action monitorEnvironment {
                out ambientTemp : ISQ::ThermodynamicTemperatureValue;
                out ambientHumidity : HumidityLevel;
                out occupied : OccupancyState;
            }
            then assign currentTemperature := monitorEnvironment.ambientTemp;
            
            then action determineSetpoint {
                perform action evalSchedule : ScheduleController::EvaluateSchedule {
                    in currentTime : TimeValue;
                    in currentDay : DayOfWeek;
                    in schedule = scheduleController.weeklySchedule;
                    out activeSetpoint : TemperatureSetpoint;
                }
                out targetSetpoint : TemperatureSetpoint;
            }
            then assign activeSetpoint := determineSetpoint.targetSetpoint;
            
            then action controlHVAC : ControlLogic::DetermineHVACMode {
                in currentTemp = currentTemperature;
                in targetTemp = activeSetpoint;
                in deadband = controlLogic.temperatureDeadband;
                out mode : HVACMode;
                out heatingLevel : Real;
                out coolingLevel : Real;
            }
            then assign operatingMode := controlHVAC.mode;
            then assign hvacControl.mode := controlHVAC.mode;
            then assign hvacControl.heatingDemand := controlHVAC.heatingLevel;
            then assign hvacControl.coolingDemand := controlHVAC.coolingLevel;
            
            then action reportStatus : NetworkModule::TransmitStatus {
                in status : StatusReport {
                    attribute currentTemp = currentTemperature;
                    attribute currentMode = operatingMode;
                    attribute setpoint = activeSetpoint;
                    attribute timestamp : TimeValue;
                }
                out transmitted : Boolean;
            }
            
            then controlCycle;
        }
    }
    
    part climateControlSystem {
        doc /* Complete climate control system integrating thermostat and HVAC equipment. */
        
        part thermostat : ProgrammableCommunicatingThermostat {
            attribute deviceID = "THERM-001";
            attribute firmwareVersion = "2.4.1";
        }
        
        part hvacEquipment : HVACEquipment;
        
        connect thermostat.hvacControl to hvacEquipment.controlInterface;
    }
    
    requirement def ThermostatSystemRequirements;
    
    requirement <'REQ-001'> primaryFunction : ThermostatSystemRequirements {
        doc /* The programmable communicating thermostat system shall automatically 
               regulate indoor temperature by controlling HVAC equipment to maintain 
               occupant comfort based on programmed schedules, manual inputs, and 
               remote commands while optimizing energy efficiency. */
        
        subject thermostat : ProgrammableCommunicatingThermostat;
    }
    
    requirement <'REQ-002'> temperatureControl : ThermostatSystemRequirements {
        doc /* The system shall maintain indoor temperature within +/- 0.5 degrees 
               Celsius of the active setpoint under normal operating conditions. */
        
        subject thermostat : ProgrammableCommunicatingThermostat;
        
        require constraint {
            abs(thermostat.currentTemperature - thermostat.activeSetpoint) <= 0.5
        }
    }
    
    requirement <'REQ-003'> schedulingCapability : ThermostatSystemRequirements {
        doc /* The system shall support programmable weekly schedules with at least 
               four setpoint periods per day for each day of the week. */
        
        subject thermostat : ProgrammableCommunicatingThermostat;
        
        require constraint {
            thermostat.scheduleController.weeklySchedule->size() >= 28
        }
    }
    
    requirement <'REQ-004'> networkCommunication : ThermostatSystemRequirements {
        doc /* The system shall communicate status updates and accept remote setpoint 
               commands via network interface with response time under 2 seconds. */
        
        subject thermostat : ProgrammableCommunicatingThermostat;
        
        assume constraint {
            thermostat.networkModule.ipAddress != null
        }
    }
    
    requirement <'REQ-005'> energyEfficiency : ThermostatSystemRequirements {
        doc /* The system shall minimize HVAC cycling by implementing temperature 
               deadband control and occupancy-based setpoint adjustment. */
        
        subject thermostat : ProgrammableCommunicatingThermostat;
        
        require constraint {
            thermostat.controlLogic.temperatureDeadband >= 0.3
        }
    }
    
    requirement <'REQ-006'> userInterface : ThermostatSystemRequirements {
        doc /* The system shall provide local user interface for manual setpoint 
               override and schedule programming with real-time temperature display. */
        
        subject thermostat : ProgrammableCommunicatingThermostat;
    }
    
    satisfy primaryFunction by climateControlSystem.thermostat;
    satisfy temperatureControl by climateControlSystem.thermostat.controlLogic;
    satisfy schedulingCapability by climateControlSystem.thermostat.scheduleController;
    satisfy networkCommunication by climateControlSystem.thermostat.networkModule;
    satisfy energyEfficiency by climateControlSystem.thermostat.controlLogic;
    satisfy userInterface by climateControlSystem.thermostat.display;
}
