package 'Cardiopulmonary Bypass System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    item def Blood;
    item def Oxygen;
    item def CarbonDioxide;
    
    attribute def FlowRateValue :> ISQ::VolumeFlowRate;
    attribute def PressureValue :> ISQ::Pressure;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperature;
    attribute def SaturationValue :> ScalarValues::Real;
    attribute def VolumeValue :> ISQ::Volume;
    
    item def ControlCommand;
    item def SensorReading;
    
    attribute def 'Start';
    attribute def 'Prime Complete';
    attribute def 'Stop';
    attribute def 'Alarm Condition';
    attribute def 'Reset';
    
    action def 'Prime Circuit';
    action def 'Regulate Flow';
    action def 'Monitor Vitals';
    action def 'Trigger Alarm';
    
    state def 'Controller States';
    
    port def BloodPort {
        out item blood : Blood;
    }
    
    port def GasPort {
        in item o2 : Oxygen;
        out item co2 : CarbonDioxide;
    }
    
    port def ControlPort {
        out item command : ControlCommand;
    }
    
    port def MonitorPort {
        in item reading : SensorReading;
    }
    
    part def Patient {
        port venous_access : BloodPort;
        port arterial_access : ~BloodPort;
    }
    
    part def VenousCannula {
        port patient_out : ~BloodPort;
        port reservoir_out : BloodPort;
    }
    
    part def VenousReservoir {
        port cannula_in : ~BloodPort;
        port pump_out : BloodPort;
        port control_in : ~ControlPort;
        attribute level : VolumeValue;
    }
    
    part def RollerPump {
        port reservoir_in : ~BloodPort;
        port oxygenator_out : BloodPort;
        port control_in : ~ControlPort;
        attribute flowRate : FlowRateValue;
    }
    
    part def MembraneOxygenator {
        port pump_in : ~BloodPort;
        port heat_exchanger_out : BloodPort;
        port gas_exchange : GasPort;
        port control_in : ~ControlPort;
    }
    
    part def HeatExchanger {
        port oxygenator_in : ~BloodPort;
        port filter_out : BloodPort;
        port control_in : ~ControlPort;
        attribute temperature : TemperatureValue;
    }
    
    part def ArterialLineFilter {
        port heat_exchanger_in : ~BloodPort;
        port cannula_out : BloodPort;
    }
    
    part def ArterialCannula {
        port filter_in : ~BloodPort;
        port patient_in : BloodPort;
    }
    
    abstract part def Sensor {
        port monitor_out : ~MonitorPort;
    }
    
    part def FlowMeter :> Sensor {
        attribute flowValue : FlowRateValue;
    }
    
    part def PressureMonitor :> Sensor {
        attribute pressureValue : PressureValue;
    }
    
    part def TemperatureProbe :> Sensor {
        attribute tempValue : TemperatureValue;
    }
    
    part def OxygenSaturationMonitor :> Sensor {
        attribute satValue : SaturationValue;
    }
    
    part def LevelSensor :> Sensor {
        attribute levelValue : VolumeValue;
    }
    
    part def BypassController {
        port control_out : ControlPort;
        port monitor_in : MonitorPort;
        
        action 'prime circuit' : 'Prime Circuit';
        action 'regulate flow' : 'Regulate Flow';
        action 'monitor vitals' : 'Monitor Vitals';
        action 'trigger alarm' : 'Trigger Alarm';
        
        exhibit state 'controller states': 'Controller States' {
            entry; then Off;
            state Off;
            accept 'Start' then Priming;
            state Priming {
                do 'prime circuit';
                accept 'Prime Complete' then Running;
            }
            state Running {
                do 'regulate flow';
                do 'monitor vitals';
                accept 'Stop' then Off;
                accept 'Alarm Condition' then Alarm;
            }
            state Alarm {
                do 'trigger alarm';
                accept 'Reset' then Running;
            }
        }
    }
    
    part def CPBSystem {
        part patient : Patient;
        part venousCannula : VenousCannula;
        part venousReservoir : VenousReservoir;
        part rollerPump : RollerPump;
        part membraneOxygenator : MembraneOxygenator;
        part heatExchanger : HeatExchanger;
        part arterialLineFilter : ArterialLineFilter;
        part arterialCannula : ArterialCannula;
        
        part bypassController : BypassController;
        
        part flowMeter : FlowMeter;
        part pressureMonitor : PressureMonitor;
        part temperatureProbe : TemperatureProbe;
        part oxygenSaturationMonitor : OxygenSaturationMonitor;
        part levelSensor : LevelSensor;
        
        connect patient.venous_access to venousCannula.patient_out;
        connect venousCannula.reservoir_out to venousReservoir.cannula_in;
        connect venousReservoir.pump_out to rollerPump.reservoir_in;
        connect rollerPump.oxygenator_out to membraneOxygenator.pump_in;
        connect membraneOxygenator.heat_exchanger_out to heatExchanger.oxygenator_in;
        connect heatExchanger.filter_out to arterialLineFilter.heat_exchanger_in;
        connect arterialLineFilter.cannula_out to arterialCannula.filter_in;
        connect arterialCannula.patient_in to patient.arterial_access;
        
        connect bypassController.control_out to venousReservoir.control_in;
        connect bypassController.control_out to rollerPump.control_in;
        connect bypassController.control_out to membraneOxygenator.control_in;
        connect bypassController.control_out to heatExchanger.control_in;
        
        connect flowMeter.monitor_out to bypassController.monitor_in;
        connect pressureMonitor.monitor_out to bypassController.monitor_in;
        connect temperatureProbe.monitor_out to bypassController.monitor_in;
        connect oxygenSaturationMonitor.monitor_out to bypassController.monitor_in;
        connect levelSensor.monitor_out to bypassController.monitor_in;
    }
    
    requirement def 'CPB Requirements' {
        requirement 'Drain Blood' {
            doc /* The system must drain deoxygenated blood from the patient. */
        }
        requirement 'Oxygenate Blood' {
            doc /* The system must oxygenate the blood. */
        }
        requirement 'Control Temperature' {
            doc /* The system must control blood temperature. */
        }
        requirement 'Filter Blood' {
            doc /* The system must filter out air bubbles and particulates. */
        }
        requirement 'Return Blood' {
            doc /* The system must return oxygenated blood to the patient. */
        }
    }
}
