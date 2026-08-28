package MedicalBloodPumpingSystem {
    import ScalarValues::*;
    
    package Units {
        unit mmHg;
        unit L_per_min;
        unit RPM;
        unit cP;
    }
    
    package ValueTypes {
        import Units::*;
        value type PressureValue :> Real { unit mmHg; }
        value type FlowRateValue :> Real { unit L_per_min; }
        value type RotationalSpeedValue :> Real { unit RPM; }
        value type ViscosityValue :> Real { unit cP; }
    }
    
    package Items {
        item Blood;
        item Thrombus;
    }
    
    package Ports {
        import ValueTypes::*;
        import Items::*;
        
        port def BloodFlowPort {
            in item Blood;
            out item Blood;
        }
        port def PressureOutPort {
            out pressure : PressureValue;
        }
        port def PressureInPort {
            in pressure : PressureValue;
        }
        port def FlowRateOutPort {
            out flowRate : FlowRateValue;
        }
        port def FlowRateInPort {
            in flowRate : FlowRateValue;
        }
        port def ViscosityOutPort {
            out viscosity : ViscosityValue;
        }
        port def SpeedCommandOutPort {
            out speed : RotationalSpeedValue;
        }
        port def SpeedCommandInPort {
            in speed : RotationalSpeedValue;
        }
        port def ThrombusAlertOutPort {
            out alert : Boolean;
        }
        port def ThrombusAlertInPort {
            in alert : Boolean;
        }
    }
    
    package Requirements {
        import ValueTypes::*;
        requirement def TargetFlowRequirement {
            subject pump;
            attribute targetFlow : FlowRateValue = 5.0 [L_per_min];
            objective {
                doc "The pump shall maintain a target flow rate of 5.0 L/min."
            }
        }
        requirement def ThrombusManagementRequirement {
            subject system;
            objective {
                doc "The system shall detect thrombus and attempt clearing before emergency shutdown."
            }
        }
    }
    
    package Components {
        import ValueTypes::*;
        import Ports::*;
        import Items::*;
        
        part def Motor {
            port speedCmd : SpeedCommandInPort;
            attribute currentSpeed : RotationalSpeedValue;
            perform action spin {
                out speed : RotationalSpeedValue;
            }
        }
        
        part def Impeller {
            attribute numBlades : Integer = 5;
        }
        
        part def Chamber {
            port inlet : BloodFlowPort;
            port outlet : BloodFlowPort;
        }
        
        part def PressureSensor {
            port pressureOut : PressureOutPort;
            attribute measuredPressure : PressureValue;
            perform action measurePressure {
                out pressure : PressureValue;
            }
        }
        
        part def FlowRateSensor {
            port flowRateOut : FlowRateOutPort;
            attribute measuredFlowRate : FlowRateValue;
            perform action measureFlowRate {
                out flowRate : FlowRateValue;
            }
        }
        
        part def BloodPump {
            port inlet : BloodFlowPort;
            port outlet : BloodFlowPort;
            port motorCmd : SpeedCommandInPort;
            port inletPressureOut : PressureOutPort;
            port outletPressureOut : PressureOutPort;
            port flowRateOut : FlowRateOutPort;
            
            attribute targetFlow : FlowRateValue = 5.0 [L_per_min];
            
            part motor : Motor;
            part impeller : Impeller;
            part chamber : Chamber;
            part inletPressureSensor : PressureSensor;
            part outletPressureSensor : PressureSensor;
            part flowRateSensor : FlowRateSensor;
            
            connection motorCmdConn connect motorCmd to motor.speedCmd;
            connection inletConn connect inlet to chamber.inlet;
            connection outletConn connect chamber.outlet to outlet;
            
            flow connection bloodFlow connect inlet to outlet;
            
            connection inletPressureConn connect inletPressureSensor.pressureOut to inletPressureOut;
            connection outletPressureConn connect outletPressureSensor.pressureOut to outletPressureOut;
            connection flowRateConn connect flowRateSensor.flowRateOut to flowRateOut;
            
            perform action pumpBlood {
                in bloodIn : Blood;
                out bloodOut : Blood;
            }
        }
        
        part def ThrombusDetector {
            port inletPressureIn : PressureInPort;
            port outletPressureIn : PressureInPort;
            port viscosityOut : ViscosityOutPort;
            port alertOut : ThrombusAlertOutPort;
            
            attribute estimatedViscosity : ViscosityValue;
            attribute pressureDifference : PressureValue;
            attribute thrombusSuspected : Boolean = false;
            
            perform action detectThrombus {
                in inletPressure : PressureValue;
                in outletPressure : PressureValue;
                out viscosity : ViscosityValue;
                out alert : Boolean;
            }
        }
        
        part def PumpController {
            port flowRateIn : FlowRateInPort;
            port thrombusAlertIn : ThrombusAlertInPort;
            port speedCommandOut : SpeedCommandOutPort;
            
            attribute targetFlow : FlowRateValue = 5.0 [L_per_min];
            attribute currentSpeed : RotationalSpeedValue = 0 [RPM];
            
            state machine ControlStateMachine {
                state idle;
                state priming;
                state operating;
                state monitoring;
                state thrombusDetected;
                state clearing;
                state emergency;
                state stopped;
                
                transition init to idle;
                transition idle to priming when primingCommand;
                transition priming to operating when primingComplete;
                transition operating to monitoring when operatingStable;
                transition monitoring to thrombusDetected when thrombusAlertIn.alert == true;
                transition thrombusDetected to clearing when clotConfirmed;
                transition clearing to monitoring when clearingSuccessful;
                transition clearing to emergency when clearingFailed;
                transition emergency to stopped when emergencyShutdownComplete;
                transition monitoring to stopped when stopCommand;
            }
        }
    }
    
    package System {
        import Components::*;
        import Requirements::*;
        
        part def BloodPumpingSystem {
            part pump : BloodPump;
            part thrombusDetector : ThrombusDetector;
            part controller : PumpController;
            
            connection inletPressureToDetectorConn connect pump.inletPressureOut to thrombusDetector.inletPressureIn;
            connection outletPressureToDetectorConn connect pump.outletPressureOut to thrombusDetector.outletPressureIn;
            connection flowRateToControllerConn connect pump.flowRateOut to controller.flowRateIn;
            connection thrombusAlertConn connect thrombusDetector.alertOut to controller.thrombusAlertIn;
            connection speedCmdConn connect controller.speedCommandOut to pump.motorCmd;
            
            satisfy TargetFlowRequirement by pump;
            satisfy ThrombusManagementRequirement by self;
        }
    }
}
