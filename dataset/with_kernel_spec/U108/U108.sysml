package MedicalBloodPumpSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        item def Blood;
        item def PrimeCmd;
        item def StartCmd;
        item def StopCmd;
        item def ThrombusAlertEvent;
        item def ThrombusCleared;
        item def ClearFailure;
        
        attribute def PressureValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def ViscosityValue :> Real;
        
        port def BloodInPort {
            in item blood : Blood;
            out attribute pressure : PressureValue;
            out attribute viscosity : ViscosityValue;
        }
        port def BloodOutPort {
            out item blood : Blood;
            out attribute pressure : PressureValue;
            out attribute flowRate : FlowRateValue;
        }
        port def CommandPort {
            in item primeCmd : PrimeCmd;
            in item startCmd : StartCmd;
            in item stopCmd : StopCmd;
        }
        port def AlertPort {
            out item alert : ThrombusAlertEvent;
        }
        
        part def Impeller {
            attribute numBlades : Integer = 5;
        }
        
        part def Motor {
            attribute speed : Real;
            perform action driveImpeller;
        }
        
        part def PressureSensor {
            attribute measuredPressure : PressureValue;
            perform action measurePressure;
        }
        
        part def FlowRateSensor {
            attribute measuredFlowRate : FlowRateValue;
            perform action measureFlowRate;
        }
        
        part def ThrombusDetector {
            in attribute inletPressure : PressureValue;
            in attribute outletPressure : PressureValue;
            in attribute viscosity : ViscosityValue;
            attribute thrombusSuspected : Boolean;
            port alertOut : AlertPort;
            perform action detectThrombus;
        }
        
        action def PumpBlood;
        action def ClearPump;
        action def EmergencyShutdown;
        
        part def Pump {
            part impeller : Impeller;
            part motor : Motor;
            port inlet : BloodInPort;
            port outlet : BloodOutPort;
            port cmdPort : CommandPort;
            attribute targetFlowRate : FlowRateValue = 5.0;
            perform action pumpBlood : PumpBlood;
        }
        
        requirement def FlowRateRequirement {
            doc /* The pump shall maintain a target blood flow rate of 5.0 liters per minute during normal operation. */
            subject pump : Pump;
            attribute targetFlow : FlowRateValue = 5.0;
        }
        requirement def SafetyRequirement {
            doc /* The system shall detect and manage thrombus formation to prevent patient harm. */
            subject system : BloodPumpSystem;
        }
        
        part def BloodPumpSystem {
            part pump : Pump;
            part inletPressureSensor : PressureSensor;
            part outletPressureSensor : PressureSensor;
            part flowRateSensor : FlowRateSensor;
            part thrombusDetector : ThrombusDetector;
            port systemInlet : BloodInPort;
            port systemOutlet : BloodOutPort;
            port systemCmd : CommandPort;
            
            perform action pumpBlood : PumpBlood;
            perform action clearPump : ClearPump;
            perform action emergencyShutdown : EmergencyShutdown;
            
            connect systemInlet to pump.inlet;
            connect pump.outlet to systemOutlet;
            connect systemCmd to pump.cmdPort;
            
            bind inletPressureSensor.measuredPressure = pump.inlet.pressure;
            bind outletPressureSensor.measuredPressure = pump.outlet.pressure;
            bind flowRateSensor.measuredFlowRate = pump.outlet.flowRate;
            bind thrombusDetector.inletPressure = inletPressureSensor.measuredPressure;
            bind thrombusDetector.outletPressure = outletPressureSensor.measuredPressure;
            bind thrombusDetector.viscosity = pump.inlet.viscosity;
            
            exhibit state systemStates {
                entry; then idle;
                
                state idle;
                transition idle_to_priming
                    first idle
                    accept PrimeCmd
                    then priming;
                
                state priming;
                transition priming_to_operating
                    first priming
                    accept StartCmd
                    then operating;
                
                state operating {
                    do pumpBlood;
                }
                transition operating_to_thrombusDetected
                    first operating
                    accept ThrombusAlertEvent
                    then thrombusDetected;
                transition operating_to_stopped
                    first operating
                    accept StopCmd
                    then stopped;
                
                state thrombusDetected;
                transition thrombusDetected_to_clearing
                    first thrombusDetected
                    then clearing;
                
                state clearing {
                    do clearPump;
                }
                transition clearing_to_operating
                    first clearing
                    accept ThrombusCleared
                    then operating;
                transition clearing_to_emergency
                    first clearing
                    accept ClearFailure
                    then emergency;
                
                state emergency {
                    do emergencyShutdown;
                }
                transition emergency_to_stopped
                    first emergency
                    then stopped;
                
                state stopped;
                transition stopped_to_idle
                    first stopped
                    accept PrimeCmd
                    then idle;
            }
        }
    }
}
