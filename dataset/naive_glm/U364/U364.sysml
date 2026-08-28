package PuritanBennettVentilator {
    import ISQ::*;
    
    // Value Types
    item def Gas;
    item def Air :> Gas;
    item def Oxygen :> Gas;
    item def BlendedGas :> Gas;
    
    value type PressureValue :> Real { unit 'cmH2O'; }
    value type FlowValue :> Real { unit 'L/min'; }
    value type VolumeValue :> Real { unit 'mL'; }
    value type OxygenFraction :> Real { unit '%'; }
    
    // Port defs
    port def GasPort {
        out item gas: Gas;
        in value pressure: PressureValue;
        in value flow: FlowValue;
    }
    
    port def ControlPort {
        out value command: Real;
        in value feedback: Real;
    }
    
    port def SensorPort {
        out value measurement: Real;
    }
    
    // Parts
    part def AirCompressor {
        port gasOut: GasPort;
        attribute status: String;
    }
    
    part def OxygenSource {
        port gasOut: GasPort;
    }
    
    part def GasMixer {
        port airIn: GasPort;
        port oxygenIn: GasPort;
        port gasOut: GasPort;
        port controlIn: ControlPort;
        attribute targetFiO2: OxygenFraction;
    }
    
    part def InspiratoryValve {
        port gasIn: GasPort;
        port gasOut: GasPort;
        port controlIn: ControlPort;
        attribute valveOpen: Boolean;
    }
    
    part def ExpiratoryValve {
        port gasIn: GasPort;
        port gasOut: GasPort;
        port controlIn: ControlPort;
        attribute valveOpen: Boolean;
        attribute targetPEEP: PressureValue;
    }
    
    part def UserInterface {
        port settingsOut: ControlPort;
        attribute tidalVolume: VolumeValue;
        attribute respRate: Integer;
        attribute peep: PressureValue;
        attribute fio2: OxygenFraction;
    }
    
    part def PressureTransducer {
        port sensorOut: SensorPort;
        attribute measuredPressure: PressureValue;
    }
    
    part def FlowTransducer {
        port sensorOut: SensorPort;
        attribute measuredFlow: FlowValue;
    }
    
    part def OxygenSensor {
        port sensorOut: SensorPort;
        attribute measuredFiO2: OxygenFraction;
    }
    
    part def VolumeMonitor {
        port flowIn: SensorPort;
        port dataOut: SensorPort;
        attribute calculatedVolume: VolumeValue;
        
        action def IntegrateFlow {
            in flow: FlowValue;
            out volume: VolumeValue;
        }
    }
    
    part def AlarmModule {
        port dataIn: SensorPort;
        port alarmOut: ControlPort;
        attribute alarmState: String;
        attribute currentPressure: PressureValue;
        attribute currentVolume: VolumeValue;
        
        state def AlarmStates {
            state Normal;
            state HighPressureAlarm;
            state LowVolumeAlarm;
            state ApneaAlarm;
            
            transition Normal_to_HighPressure first Normal if (currentPressure > 40) then HighPressureAlarm;
            transition HighPressure_to_Normal first HighPressureAlarm if (currentPressure <= 40) then Normal;
            transition Normal_to_LowVolume first Normal if (currentVolume < 100) then LowVolumeAlarm;
            transition LowVolume_to_Normal first LowVolumeAlarm if (currentVolume >= 100) then Normal;
        }
    }
    
    part def BreathController {
        port settingsIn: ControlPort;
        port pressureIn: SensorPort;
        port flowIn: SensorPort;
        port volumeIn: SensorPort;
        port oxygenIn: SensorPort;
        port mixerControl: ControlPort;
        port inspiratoryControl: ControlPort;
        port expiratoryControl: ControlPort;
        port alarmControl: ControlPort;
        
        attribute targetTidalVolume: VolumeValue;
        attribute targetPressure: PressureValue;
        attribute targetFiO2: OxygenFraction;
        attribute targetPEEP: PressureValue;
        
        state def BreathCycle {
            state Inspiration {
                entry action { inspiratoryControl.command = 1.0; expiratoryControl.command = 0.0; }
                do action { 
                    if (pressureIn.measurement > targetPressure) { inspiratoryControl.command = 0.5; }
                }
            }
            state Expiration {
                entry action { inspiratoryControl.command = 0.0; expiratoryControl.command = 1.0; }
                do action { 
                    if (pressureIn.measurement < targetPEEP) { expiratoryControl.command = 0.5; }
                }
            }
            state ApneaCheck;
            
            transition Insp_to_Exp first Inspiration if (volumeIn.measurement >= targetTidalVolume) then Expiration;
            transition Exp_to_Insp first Expiration after 3 [s] then Inspiration;
        }
    }
    
    part def PatientCircuit {
        port inspiratoryIn: GasPort;
        port expiratoryOut: GasPort;
        port patientConnection: GasPort;
    }
    
    part def VentilatorSystem {
        part airCompressor: AirCompressor;
        part oxygenSource: OxygenSource;
        part gasMixer: GasMixer;
        part inspiratoryValve: InspiratoryValve;
        part expiratoryValve: ExpiratoryValve;
        part userInterface: UserInterface;
        part pressureTransducer: PressureTransducer;
        part flowTransducer: FlowTransducer;
        part oxygenSensor: OxygenSensor;
        part volumeMonitor: VolumeMonitor;
        part alarmModule: AlarmModule;
        part breathController: BreathController;
        part patientCircuit: PatientCircuit;
        
        connection def GasFlow {
            end source: GasPort;
            end target: GasPort;
        }
        
        connection def ControlFlow {
            end source: ControlPort;
            end target: ControlPort;
        }
        
        connection def SensorFlow {
            end source: SensorPort;
            end target: SensorPort;
        }
        
        // Gas Connections
        connection gasFlow1: GasFlow connect airCompressor.gasOut to gasMixer.airIn;
        connection gasFlow2: GasFlow connect oxygenSource.gasOut to gasMixer.oxygenIn;
        connection gasFlow3: GasFlow connect gasMixer.gasOut to inspiratoryValve.gasIn;
        connection gasFlow4: GasFlow connect inspiratoryValve.gasOut to patientCircuit.inspiratoryIn;
        connection gasFlow5: GasFlow connect patientCircuit.expiratoryOut to expiratoryValve.gasIn;
        
        // Control Connections
        connection ctrl1: ControlFlow connect userInterface.settingsOut to breathController.settingsIn;
        connection ctrl2: ControlFlow connect breathController.mixerControl to gasMixer.controlIn;
        connection ctrl3: ControlFlow connect breathController.inspiratoryControl to inspiratoryValve.controlIn;
        connection ctrl4: ControlFlow connect breathController.expiratoryControl to expiratoryValve.controlIn;
        
        // Sensor Connections
        connection sens1: SensorFlow connect pressureTransducer.sensorOut to breathController.pressureIn;
        connection sens2: SensorFlow connect flowTransducer.sensorOut to breathController.flowIn;
        connection sens3: SensorFlow connect flowTransducer.sensorOut to volumeMonitor.flowIn;
        connection sens4: SensorFlow connect volumeMonitor.dataOut to breathController.volumeIn;
        connection sens5: SensorFlow connect oxygenSensor.sensorOut to breathController.oxygenIn;
        connection sens6: SensorFlow connect pressureTransducer.sensorOut to alarmModule.dataIn;
        connection sens7: SensorFlow connect volumeMonitor.dataOut to alarmModule.dataIn;
    }
    
    requirement def VentilatorRequirements {
        subject v: VentilatorSystem;
        
        requirement SafePressureLimit {
            doc /* The ventilator must not deliver pressure exceeding 40 cmH2O. */
            require v.pressureTransducer.measuredPressure <= 40;
        }
        
        requirement AccurateVolumeDelivery {
            doc /* The delivered volume must match the set tidal volume within 10%. */
            require v.volumeMonitor.calculatedVolume >= v.userInterface.tidalVolume * 0.9;
            require v.volumeMonitor.calculatedVolume <= v.userInterface.tidalVolume * 1.1;
        }
        
        requirement ApneaDetection {
            doc /* The system must trigger an alarm if no breath is detected for 20 seconds. */
            require v.alarmModule.alarmState == "ApneaAlarm";
        }
    }
}
