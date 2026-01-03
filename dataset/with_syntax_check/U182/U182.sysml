package CardiopulmonaryBypassSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BloodOxygenSaturation :> Real;
    attribute def CO2Concentration :> Real;
    attribute def HematocritLevel :> Real;
    
    item def Blood {
        attribute oxygenSaturation : BloodOxygenSaturation;
        attribute co2Level : CO2Concentration;
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
        attribute hematocrit : HematocritLevel;
    }
    
    item def VenousBlood specializes Blood {
        attribute oxygenSaturation : BloodOxygenSaturation := 70.0;
    }
    
    item def ArterialBlood specializes Blood {
        attribute oxygenSaturation : BloodOxygenSaturation := 98.0;
    }
    
    port def BloodFlowPort {
        in item blood : Blood;
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }
    
    part def VenousCannula {
        doc /* Drains deoxygenated blood from patient's venous system */
        port patientConnection : BloodFlowPort;
        port circuitConnection : BloodFlowPort;
        attribute canulaDiameter : LengthValue;
    }
    
    part def ArterialCannula {
        doc /* Returns oxygenated blood to patient's arterial system */
        port circuitConnection : BloodFlowPort;
        port patientConnection : BloodFlowPort;
        attribute canulaDiameter : LengthValue;
    }
    
    part def VenousReservoir {
        doc /* Collects venous blood and provides volume buffer */
        port inlet : BloodFlowPort;
        port outlet : BloodFlowPort;
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute minimumLevel : VolumeValue;
    }
    
    part def RollerPump {
        doc /* Propels blood through bypass circuit */
        port inlet : BloodFlowPort;
        port outlet : BloodFlowPort;
        attribute rotationSpeed : Real;
        attribute targetFlowRate : VolumeFlowRateValue;
        attribute actualFlowRate : VolumeFlowRateValue;
    }
    
    part def MembraneOxygenator {
        doc /* Performs gas exchange: adds oxygen and removes CO2 */
        port bloodInlet : BloodFlowPort;
        port bloodOutlet : BloodFlowPort;
        port oxygenInlet;
        port exhaustOutlet;
        attribute membraneArea : AreaValue;
        attribute oxygenFlowRate : VolumeFlowRateValue;
        attribute transferEfficiency : Real;
    }
    
    part def HeatExchanger {
        doc /* Regulates blood temperature during bypass */
        port bloodInlet : BloodFlowPort;
        port bloodOutlet : BloodFlowPort;
        port waterInlet;
        port waterOutlet;
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute waterFlowRate : VolumeFlowRateValue;
    }
    
    part def ArterialLineFilter {
        doc /* Removes microemboli and particulates from arterial blood */
        port inlet : BloodFlowPort;
        port outlet : BloodFlowPort;
        attribute poreSize : LengthValue;
        attribute filteringEfficiency : Real;
    }
    
    part def FlowMeter {
        port measurementPoint : BloodFlowPort;
        out attribute measuredFlow : VolumeFlowRateValue;
        attribute accuracy : Real;
    }
    
    part def PressureMonitor {
        port measurementPoint : BloodFlowPort;
        out attribute measuredPressure : PressureValue;
        attribute alarmThresholdLow : PressureValue;
        attribute alarmThresholdHigh : PressureValue;
    }
    
    part def OxygenSaturationMonitor {
        port measurementPoint : BloodFlowPort;
        out attribute measuredSaturation : BloodOxygenSaturation;
        attribute targetSaturation : BloodOxygenSaturation;
    }
    
    part def TemperatureProbe {
        port measurementPoint : BloodFlowPort;
        out attribute measuredTemperature : TemperatureValue;
    }
    
    part def LevelSensor {
        out attribute reservoirLevel : VolumeValue;
        attribute criticalLowLevel : VolumeValue;
    }
    
    part def BypassController {
        in attribute venousFlow : VolumeFlowRateValue;
        in attribute arterialFlow : VolumeFlowRateValue;
        in attribute venousPressure : PressureValue;
        in attribute arterialPressure : PressureValue;
        in attribute oxygenSaturation : BloodOxygenSaturation;
        in attribute bloodTemperature : TemperatureValue;
        in attribute reservoirLevel : VolumeValue;
        
        out attribute pumpSpeedCommand : Real;
        out attribute oxygenFlowCommand : VolumeFlowRateValue;
        out attribute waterFlowCommand : VolumeFlowRateValue;
        out attribute alarmActive : Boolean;
        
        attribute targetFlowRate : VolumeFlowRateValue;
        attribute targetTemperature : TemperatureValue;
        attribute targetSaturation : BloodOxygenSaturation;
    }
    
    action def MonitorVitalParameters {
        in venousFlow : VolumeFlowRateValue;
        in arterialFlow : VolumeFlowRateValue;
        in venousPressure : PressureValue;
        in arterialPressure : PressureValue;
        in oxygenSaturation : BloodOxygenSaturation;
        in temperature : TemperatureValue;
        in reservoirLevel : VolumeValue;
        
        out parametersNormal : Boolean;
        out criticalAlarm : Boolean;
    }
    
    action def ControlPumpFlow {
        in currentFlow : VolumeFlowRateValue;
        in targetFlow : VolumeFlowRateValue;
        in arterialPressure : PressureValue;
        
        out pumpSpeed : Real;
    }
    
    action def RegulateOxygenation {
        in currentSaturation : BloodOxygenSaturation;
        in targetSaturation : BloodOxygenSaturation;
        in bloodFlow : VolumeFlowRateValue;
        
        out oxygenFlow : VolumeFlowRateValue;
    }
    
    action def ManageTemperature {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        
        out waterFlow : VolumeFlowRateValue;
    }
    
    action def OxygenateAndDecarboxylate {
        in venousBlood : VenousBlood;
        in oxygenSupply : VolumeFlowRateValue;
        
        out arterialBlood : ArterialBlood;
    }
    
    action def PerformCardiopulmonaryBypass {
        doc /* Main bypass operation coordinating all subsystems */
        
        first start;
        then action primingPhase {
            doc /* Fill circuit with priming solution and remove air */
        }
        then merge bypassCycle;
        then action monitorParameters : MonitorVitalParameters {
            in venousFlow;
            in arterialFlow;
            in venousPressure;
            in arterialPressure;
            in oxygenSaturation;
            in temperature;
            in reservoirLevel;
            out parametersNormal;
            out criticalAlarm;
        }
        then decide;
            if monitorParameters.criticalAlarm then handleEmergency;
            if monitorParameters.parametersNormal then normalOperation;
        
        action normalOperation {
            action drainVenousBlood {
                doc /* Remove deoxygenated blood from patient via venous cannula */
            }
            then action collectInReservoir {
                doc /* Accumulate blood in venous reservoir */
            }
            then action pumpBlood : ControlPumpFlow {
                in currentFlow;
                in targetFlow;
                in arterialPressure;
                out pumpSpeed;
            }
            then action oxygenate : OxygenateAndDecarboxylate {
                in venousBlood;
                in oxygenSupply;
                out arterialBlood;
            }
            then action regulateOxygen : RegulateOxygenation {
                in currentSaturation;
                in targetSaturation;
                in bloodFlow;
                out oxygenFlow;
            }
            then action controlTemperature : ManageTemperature {
                in currentTemp;
                in targetTemp;
                out waterFlow;
            }
            then action filterArterialBlood {
                doc /* Remove microemboli before returning blood */
            }
            then action returnArterialBlood {
                doc /* Infuse oxygenated blood to patient via arterial cannula */
            }
        }
        then bypassCycle;
        
        action handleEmergency {
            doc /* Handle critical alarms and safety protocols */
        }
        then bypassCycle;
        
        accept weaningInitiated;
        then action weaningPhase {
            doc /* Gradually reduce bypass support as heart resumes function */
        }
        then action terminateBypass {
            doc /* Stop pump and remove cannulas */
        }
        then done;
    }
    
    part cardiopulmonaryBypassCircuit {
        doc /* Complete CPB system providing temporary cardiopulmonary support during cardiac surgery */
        
        part venousCannula : VenousCannula {
            doc /* Inserted into right atrium or vena cava */
        }
        
        part arterialCannula : ArterialCannula {
            doc /* Inserted into aorta or femoral artery */
        }
        
        part reservoir : VenousReservoir {
            doc /* Cardiotomy reservoir with integrated filter */
        }
        
        part pump : RollerPump {
            doc /* Main blood pump driving circuit flow */
        }
        
        part oxygenator : MembraneOxygenator {
            doc /* Hollow fiber membrane oxygenator */
        }
        
        part heatExchanger : HeatExchanger {
            doc /* Integrated or separate temperature control unit */
        }
        
        part arterialFilter : ArterialLineFilter {
            doc /* 40-micron arterial line filter */
        }
        
        part venousFlowMeter : FlowMeter;
        part arterialFlowMeter : FlowMeter;
        part venousPressureMonitor : PressureMonitor;
        part arterialPressureMonitor : PressureMonitor;
        part saturationMonitor : OxygenSaturationMonitor;
        part temperatureProbe : TemperatureProbe;
        part levelSensor : LevelSensor;
        
        part controller : BypassController {
            doc /* Perfusionist control console and monitoring system */
        }
        
        connection venousDrainage connect venousCannula.circuitConnection to reservoir.inlet;
        connection reservoirToPump connect reservoir.outlet to pump.inlet;
        connection pumpToOxygenator connect pump.outlet to oxygenator.bloodInlet;
        connection oxygenatorToHeatExchanger connect oxygenator.bloodOutlet to heatExchanger.bloodInlet;
        connection heatExchangerToFilter connect heatExchanger.bloodOutlet to arterialFilter.inlet;
        connection filterToArterial connect arterialFilter.outlet to arterialCannula.circuitConnection;
        
        connection monitorVenousFlow connect venousFlowMeter.measurementPoint to reservoir.inlet;
        connection monitorArterialFlow connect arterialFlowMeter.measurementPoint to arterialFilter.outlet;
        connection monitorVenousPressure connect venousPressureMonitor.measurementPoint to reservoir.inlet;
        connection monitorArterialPressure connect arterialPressureMonitor.measurementPoint to arterialFilter.outlet;
        connection monitorSaturation connect saturationMonitor.measurementPoint to arterialFilter.outlet;
        connection monitorTemperature connect temperatureProbe.measurementPoint to heatExchanger.bloodOutlet;
        
        perform action bypassOperation : PerformCardiopulmonaryBypass;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'CPB-REQ-001'> primaryMission : FunctionalRequirement {
        doc /* The Cardiopulmonary Bypass System shall temporarily assume the function of the heart and lungs, 
             maintaining systemic circulation and gas exchange during cardiac surgery when the heart is arrested. */
        
        subject cardiopulmonaryBypassCircuit;
        
        require adequatePerfusion;
        require effectiveOxygenation;
        require temperatureManagement;
        require safeOperation;
    }
    
    requirement <'CPB-REQ-002'> adequatePerfusion : PerformanceRequirement {
        doc /* The system shall maintain blood flow rate at 2.2 to 2.4 L/min/m² body surface area */
        
        subject cardiopulmonaryBypassCircuit.pump;
        
        require constraint {
            cardiopulmonaryBypassCircuit.arterialFlowMeter.measuredFlow >= 2.2 and
            cardiopulmonaryBypassCircuit.arterialFlowMeter.measuredFlow <= 2.4
        }
    }
    
    requirement <'CPB-REQ-003'> effectiveOxygenation : PerformanceRequirement {
        doc /* The system shall maintain arterial oxygen saturation at or above 95% */
        
        subject cardiopulmonaryBypassCircuit.oxygenator;
        
        require constraint {
            cardiopulmonaryBypassCircuit.saturationMonitor.measuredSaturation >= 95.0
        }
    }
    
    requirement <'CPB-REQ-004'> temperatureManagement : PerformanceRequirement {
        doc /* The system shall maintain blood temperature between 28°C and 37°C as required by surgical protocol */
        
        subject cardiopulmonaryBypassCircuit.heatExchanger;
        
        require constraint {
            cardiopulmonaryBypassCircuit.temperatureProbe.measuredTemperature >= 28.0 and
            cardiopulmonaryBypassCircuit.temperatureProbe.measuredTemperature <= 37.0
        }
    }
    
    requirement <'CPB-REQ-005'> arterialPressureControl : SafetyRequirement {
        doc /* The system shall maintain mean arterial pressure between 50 and 80 mmHg */
        
        subject cardiopulmonaryBypassCircuit.pump;
        
        require constraint {
            cardiopulmonaryBypassCircuit.arterialPressureMonitor.measuredPressure >= 50.0 and
            cardiopulmonaryBypassCircuit.arterialPressureMonitor.measuredPressure <= 80.0
        }
    }
    
    requirement <'CPB-REQ-006'> emboliProtection : SafetyRequirement {
        doc /* The arterial line filter shall remove particulates and microemboli larger than 40 microns */
        
        subject cardiopulmonaryBypassCircuit.arterialFilter;
        
        require constraint {
            cardiopulmonaryBypassCircuit.arterialFilter.filteringEfficiency >= 0.98
        }
    }
    
    requirement <'CPB-REQ-007'> reservoirSafety : SafetyRequirement {
        doc /* The system shall alarm if venous reservoir level falls below critical minimum */
        
        subject cardiopulmonaryBypassCircuit.reservoir;
        
        require constraint {
            cardiopulmonaryBypassCircuit.levelSensor.reservoirLevel > 
            cardiopulmonaryBypassCircuit.levelSensor.criticalLowLevel
        }
    }
    
    requirement <'CPB-REQ-008'> safeOperation : SafetyRequirement {
        doc /* The system shall provide continuous monitoring and alarming for all critical parameters */
        
        subject cardiopulmonaryBypassCircuit.controller;
        
        require arterialPressureControl;
        require emboliProtection;
        require reservoirSafety;
    }
}
