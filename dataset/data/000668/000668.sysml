package LiverSupportSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BloodFlowRate :> Real;
    
    attribute def ToxinConcentration {
        attribute value : Real;
        attribute unit : String;
    }
    
    attribute def TemperatureValue :> Real;
    
    attribute def PressureValue :> Real;
    
    attribute def AreaValue :> Real;
    
    attribute def TimeValue :> Real;
    
    item def Blood {
        attribute toxinLevel : ToxinConcentration;
        attribute temperature : TemperatureValue;
        attribute oxygenSaturation : Real;
    }
    
    item def FilteredBlood :> Blood {
        assert constraint { toxinLevel.value < 0.2 }
    }
    
    item def Dialysate {
        attribute flowRate : BloodFlowRate;
    }
    
    item def WasteFluid {
        attribute toxinContent : ToxinConcentration;
    }
    
    port def BloodInletPort {
        in item blood : Blood;
        attribute flowRate : BloodFlowRate;
        attribute pressure : PressureValue;
    }
    
    port def BloodOutletPort {
        out item filteredBlood : FilteredBlood;
        attribute flowRate : BloodFlowRate;
        attribute pressure : PressureValue;
    }
    
    port def WastePort {
        out item waste : WasteFluid;
    }
    
    port def DialysatePort {
        in item dialysate : Dialysate;
        attribute flowRate : BloodFlowRate;
    }
    
    part def BloodPump {
        port inlet : BloodInletPort;
        port outlet : BloodOutletPort;
        attribute pumpSpeed : Real;
        attribute targetFlowRate : BloodFlowRate;
        
        perform action pumpBlood {
            in bloodIn : Blood;
            out bloodOut : Blood;
        }
    }
    
    part def DialysisFilter {
        port bloodIn : BloodInletPort;
        port bloodOut : BloodOutletPort;
        port dialysateIn : DialysatePort;
        port wasteOut : WastePort;
        
        attribute membraneArea : AreaValue;
        attribute filterEfficiency : Real;
        
        perform action filterToxins {
            in contaminatedBlood : Blood;
            in dialysateFlow : Dialysate;
            out cleanBlood : FilteredBlood;
            out wasteProducts : WasteFluid;
        }
    }
    
    part def TemperatureRegulator {
        port bloodIn : BloodInletPort;
        port bloodOut : BloodOutletPort;
        
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        
        perform action regulateTemperature {
            in blood : Blood;
            out heatedBlood : Blood;
        }
    }
    
    part def PressureMonitor {
        attribute currentPressure : PressureValue;
        attribute minPressure : PressureValue;
        attribute maxPressure : PressureValue;
        
        perform action monitorPressure {
            in pressure : PressureValue;
            out alert : Boolean;
        }
    }
    
    part def ToxinSensor {
        attribute measuredToxinLevel : ToxinConcentration;
        
        perform action measureToxins {
            in blood : Blood;
            out toxinLevel : ToxinConcentration;
        }
    }
    
    part def ControlUnit {
        attribute systemState : SystemStateKind;
        attribute treatmentDuration : TimeValue;
        
        perform action controlSystem {
            in toxinLevel : ToxinConcentration;
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            out pumpCommand : Real;
            out alarmSignal : Boolean;
        }
    }
    
    enum def SystemStateKind {
        idle;
        priming;
        treating;
        rinsing;
        alarm;
        shutdown;
    }
    
    signal def PrimeCommand;
    signal def PrimingComplete;
    signal def AlarmCondition;
    signal def TreatmentComplete;
    signal def ShutdownCommand;
    signal def RinsingComplete;
    
    state def LiverSupportSystemStateMachine {
        entry; then idle;
        
        state idle;
        transition idle_to_priming
            first idle
            accept PrimeCommand
            then priming;
        
        state priming;
        transition priming_to_treating
            first priming
            accept PrimingComplete
            then treating;
        
        state treating {
            state monitoring {
                do action monitorVitals {
                    in toxinLevel : ToxinConcentration;
                    in pressure : PressureValue;
                    out status : Boolean;
                }
            }
        }
        transition treating_to_alarm
            first treating
            accept AlarmCondition
            then alarm;
        
        transition treating_to_rinsing
            first treating
            accept TreatmentComplete
            then rinsing;
        
        state alarm;
        transition alarm_to_shutdown
            first alarm
            accept ShutdownCommand
            then shutdown;
        
        state rinsing;
        transition rinsing_to_idle
            first rinsing
            accept RinsingComplete
            then idle;
        
        state shutdown;
        transition shutdown_to_done
            first shutdown
            then done;
    }
    
    action def PerformLiverSupport {
        first start;
        then merge continueTreatment;
        
        action monitorBlood {
            out toxinLevel : ToxinConcentration;
            out pressure : PressureValue;
            out temperature : TemperatureValue;
        }
        then decide;
        
        if monitorBlood.toxinLevel.value > 0.5 or 
           monitorBlood.pressure > 200.0 then triggerAlarm;
        if monitorBlood.toxinLevel.value <= 0.2 and 
           monitorBlood.pressure <= 200.0 then pumpAndFilter;
        
        action pumpAndFilter {
            action pumpBloodAction;
            then action filterBloodAction;
            then action regulateTempAction;
        }
        then continueTreatment;
        
        action triggerAlarm;
        then done;
    }
    
    part def LiverSupportSystem {
        attribute systemState : SystemStateKind = SystemStateKind::idle;
        
        part pump : BloodPump {
            attribute :>> targetFlowRate = 200.0;
        }
        
        part dialysisFilter : DialysisFilter {
            attribute :>> membraneArea = 1.5;
            attribute :>> filterEfficiency = 0.85;
        }
        
        part tempRegulator : TemperatureRegulator {
            attribute :>> targetTemperature = 310.15;
        }
        
        part pressureMonitor : PressureMonitor {
            attribute :>> minPressure = 50.0;
            attribute :>> maxPressure = 200.0;
        }
        
        part toxinSensor : ToxinSensor;
        
        part controller : ControlUnit {
            attribute :>> treatmentDuration = 240.0;
        }
        
        connection pumpToFilter connect pump.outlet to dialysisFilter.bloodIn;
        connection filterToRegulator connect dialysisFilter.bloodOut to tempRegulator.bloodIn;
        
        perform action treatmentCycle : PerformLiverSupport;
        
        exhibit state systemBehavior : LiverSupportSystemStateMachine;
    }
    
    part liverSupportSystem : LiverSupportSystem;
    
    requirement <'REQ-LSS-001'> primaryFunction {
        doc /* The liver support system shall perform extracorporeal blood 
             * purification to remove toxins and metabolic waste products 
             * from the blood of patients with acute or chronic liver failure.
             */
        subject system : LiverSupportSystem;
    }
    
    requirement <'REQ-LSS-002'> toxinRemoval {
        doc /* The system shall reduce blood toxin concentration to below 
             * 0.2 units within a single treatment cycle.
             */
        subject system : LiverSupportSystem;
        assert constraint {
            system.dialysisFilter.filterEfficiency >= 0.80
        }
    }
    
    requirement <'REQ-LSS-003'> bloodFlowRate {
        doc /* The system shall maintain a blood flow rate between 
             * 150 and 250 mL/min during treatment.
             */
        subject pump : BloodPump;
        assert constraint {
            pump.targetFlowRate >= 150.0 and 
            pump.targetFlowRate <= 250.0
        }
    }
    
    requirement <'REQ-LSS-004'> temperatureControl {
        doc /* The system shall maintain blood temperature at 37°C ± 0.5°C 
             * throughout the treatment process.
             */
        subject regulator : TemperatureRegulator;
        assert constraint {
            regulator.targetTemperature >= 309.65 and 
            regulator.targetTemperature <= 310.65
        }
    }
    
    requirement <'REQ-LSS-005'> pressureSafety {
        doc /* The system shall monitor blood pressure continuously and 
             * trigger an alarm if pressure exceeds safe operating limits.
             */
        subject monitor : PressureMonitor;
        assert constraint {
            monitor.maxPressure <= 200.0 and 
            monitor.minPressure >= 50.0
        }
    }
    
    requirement <'REQ-LSS-006'> treatmentDuration {
        doc /* The system shall support continuous treatment sessions 
             * of at least 4 hours duration.
             */
        subject controller : ControlUnit;
        assert constraint {
            controller.treatmentDuration >= 240.0
        }
    }
    
    satisfy primaryFunction by liverSupportSystem;
    satisfy toxinRemoval by liverSupportSystem.dialysisFilter;
    satisfy bloodFlowRate by liverSupportSystem.pump;
    satisfy temperatureControl by liverSupportSystem.tempRegulator;
    satisfy pressureSafety by liverSupportSystem.pressureMonitor;
    satisfy treatmentDuration by liverSupportSystem.controller;
}
